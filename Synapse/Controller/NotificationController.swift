//
//  NotificationController.swift
//  Synapse
//
//  Owns every local notification the app schedules.
//
//  How it works
//  - The data controllers push their latest lists (and SettingsController pushes the
//    settings) here whenever Firestore changes. After every push the whole schedule is
//    rebuilt and reconciled with what iOS has pending.
//  - Every request has a deterministic identifier, so rebuilding can never create
//    duplicates; anything pending that is no longer wanted (edited, deactivated, expired,
//    completed, deleted, reminders switched off) is removed.
//  - iOS keeps at most 64 pending local notifications per app, so reminders are scheduled
//    in a rolling window: appointments first (up to `appointmentBudget`), then the nearest
//    medicine doses fill the remaining slots. The window is refilled every time the app
//    becomes active or any data/settings change.
//

import Foundation
import UserNotifications

enum NotificationPermission {
    case notDetermined, denied, allowed
}

@MainActor
final class NotificationController {
    static let shared = NotificationController()

    static let pendingLimit = 64
    private let appointmentBudget = 14
    private let medicineHorizonDays = 14

    private let center = UNUserNotificationCenter.current()
    private let prefix = "synapse."
    private let medicinePrefix = "synapse.med."
    private let appointmentPrefix = "synapse.appt."

    private var medicines: [MedicineInformation] = []
    private var appointments: [Appointment] = []
    private var settings = AppSettings()
    private var hasMedicines = false
    private var hasAppointments = false
    private var hasSettings = false

    private var isSyncing = false
    private var syncQueued = false

    private init() {}

    // MARK: - Inputs

    func update(medicines: [MedicineInformation]) {
        self.medicines = medicines
        hasMedicines = true
        requestSync()
    }

    func update(appointments: [Appointment]) {
        self.appointments = appointments
        hasAppointments = true
        requestSync()
    }

    func update(settings: AppSettings) {
        self.settings = settings
        hasSettings = true
        requestSync()
    }

    /// Forgets in-memory data. With `removePending` also cancels everything iOS has pending (used on logout).
    func reset(removePending: Bool) {
        medicines = []
        appointments = []
        settings = AppSettings()
        hasMedicines = false
        hasAppointments = false
        hasSettings = false
        if removePending {
            Task { await removePendingRequests(where: { _ in true }) }
        }
    }

    // MARK: - Permission

    func permission() async -> NotificationPermission {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    /// Asks iOS for permission if it hasn't been asked yet. Returns whether reminders can be delivered.
    @discardableResult
    func ensureAuthorization() async -> Bool {
        switch await permission() {
        case .allowed:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            requestSync()
            return granted
        }
    }

    func requestAuthorizationIfNeeded() async {
        if await permission() == .notDetermined {
            _ = await ensureAuthorization()
        }
    }

    // MARK: - Syncing

    /// Rebuilds the schedule. Calls made while a rebuild is running are coalesced into one more pass.
    func requestSync() {
        guard hasMedicines, hasAppointments, hasSettings else { return }
        if isSyncing {
            syncQueued = true
            return
        }
        isSyncing = true
        Task {
            repeat {
                syncQueued = false
                await performSync()
            } while syncQueued
            isSyncing = false
        }
    }

    private func performSync() async {
        guard await permission() == .allowed, settings.notificationsEnabled else {
            await removePendingRequests(where: { _ in true })
            return
        }

        let now = Date()
        let appointmentRequests = settings.appointmentRemindersActive ? appointmentRequests(now: now) : []
        let medicineSlots = max(0, Self.pendingLimit - appointmentRequests.count)
        let medicineRequests = settings.medicineRemindersActive ? medicineRequests(now: now, limit: medicineSlots) : []

        let desired = appointmentRequests + medicineRequests
        let desiredIDs = Set(desired.map(\.identifier))

        // Remove whatever is pending but no longer wanted.
        await removePendingRequests(where: { !desiredIDs.contains($0) })

        // Adding a request with an existing identifier replaces it, so edits propagate and duplicates are impossible.
        for request in desired {
            do { try await center.add(request) } catch { print("Notification scheduling failed: \(error.localizedDescription)") }
        }
    }

    private func removePendingRequests(where shouldRemove: (String) -> Bool) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && shouldRemove($0) }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    // MARK: - Appointments

    private func appointmentRequests(now: Date) -> [UNNotificationRequest] {
        appointments
            .filter { $0.status == .scheduled && $0.reminderDate > now }   // no reminders for past or completed appointments
            .sorted { $0.startDate < $1.startDate }
            .prefix(appointmentBudget)
            .map { appointment in
                let content = UNMutableNotificationContent()
                content.title = "Appointment in 5 minutes"
                var details = [appointment.title]
                if !appointment.doctor.trimmed.isEmpty { details.append("with \(appointment.doctor.trimmed)") }
                if !appointment.location.trimmed.isEmpty { details.append("at \(appointment.location.trimmed)") }
                content.body = details.joined(separator: " ") + " · " + appointment.startDate.formatted(date: .omitted, time: .shortened)
                content.sound = .default
                content.userInfo = ["type": "appointment", "id": appointment.id.uuidString]
                return UNNotificationRequest(identifier: appointmentPrefix + appointment.id.uuidString,
                                             content: content,
                                             trigger: trigger(for: appointment.reminderDate))
            }
    }

    // MARK: - Medicines

    private func medicineRequests(now: Date, limit: Int) -> [UNNotificationRequest] {
        guard limit > 0 else { return [] }
        let calendar = Calendar.current
        var doses: [(date: Date, medicine: MedicineInformation)] = []

        for medicine in medicines where medicine.active {
            let boundary = medicine.endBoundary
            guard boundary > now else { continue }                         // expired
            let firstDay = max(calendar.startOfDay(for: medicine.startDate), calendar.startOfDay(for: now))

            for offset in 0..<medicineHorizonDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay), day < boundary else { break }
                for minutes in medicine.effectiveIntakeMinutes {
                    guard let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) else { continue }
                    if fire > now && fire < boundary { doses.append((fire, medicine)) }
                }
            }
        }

        return doses
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { dose in
                let medicine = dose.medicine
                let content = UNMutableNotificationContent()
                content.title = "Time to take \(medicine.medication)"
                var body = medicine.amount.trimmed.isEmpty ? "It's time for your medicine." : "Take \(medicine.amount.trimmed)."
                if !medicine.instructions.trimmed.isEmpty { body += " \(medicine.instructions.trimmed)" }
                content.body = body
                content.sound = .default
                content.userInfo = ["type": "medicine", "id": medicine.id.uuidString]
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dose.date)
                let stamp = String(format: "%04d%02d%02d%02d%02d", parts.year ?? 0, parts.month ?? 0,
                                   parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
                return UNNotificationRequest(identifier: "\(medicinePrefix)\(medicine.id.uuidString).\(stamp)",
                                             content: content,
                                             trigger: trigger(for: dose.date))
            }
    }

    private func trigger(for date: Date) -> UNCalendarNotificationTrigger {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }
}
