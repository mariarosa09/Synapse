//
//  AppointmentController.swift
//  Synapse
//
//  CRUD for public.appointments. Shared by Home ("today") and the Calendar, so a change made
//  on one screen shows up on the other immediately. Every change re-syncs the
//  five-minutes-before reminders through NotificationController.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class AppointmentController {
    var appointments: [Appointment] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var userId: UUID?

    // MARK: - Loading

    func start(uid: UUID) {
        stop()
        userId = uid
        Task { await reload() }
    }

    func stop() {
        userId = nil
        appointments = []
        isLoading = false
        errorMessage = nil
    }

    func reload() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { if userId == uid { isLoading = false } }
        do {
            let items: [Appointment] = try await supabase.from(Table.appointments)
                .select()
                .eq("user_id", value: uid)
                .order("start_at", ascending: true)
                .execute()
                .value
            guard userId == uid else { return }
            apply(items)
        } catch {
            guard userId == uid else { return }
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    private func apply(_ items: [Appointment]) {
        appointments = items.sorted { $0.startDate < $1.startDate }
        NotificationController.shared.update(appointments: appointments)
    }

    // MARK: - Queries used by Home and the calendar

    func appointments(on date: Date) -> [Appointment] {
        appointments.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func hasAppointments(on date: Date) -> Bool {
        appointments.contains { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    func appointment(withID id: UUID?) -> Appointment? {
        guard let id else { return nil }
        return appointments.first { $0.id == id }
    }

    // MARK: - Validation

    func validationError(for appointment: Appointment) -> String? {
        if appointment.title.trimmed.isEmpty { return "Please enter a title." }
        if appointment.endDate <= appointment.startDate { return "The end time must be after the start time." }
        return nil
    }

    // MARK: - CRUD

    @discardableResult
    func save(_ appointment: Appointment) -> Bool {
        if let message = validationError(for: appointment) {
            errorMessage = message
            return false
        }
        guard let uid = userId else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = appointment
        item.title = item.title.trimmed
        item.doctor = item.doctor.trimmed
        item.location = item.location.trimmed
        item.notes = item.notes.trimmed
        errorMessage = nil

        var updated = appointments
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item } else { updated.append(item) }
        apply(updated)

        Task {
            do {
                try await supabase.from(Table.appointments).upsert(item, onConflict: "id", returning: .minimal).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
        return true
    }

    /// Ticking the checklist marks an appointment completed (which cancels its reminder).
    func setStatus(_ appointment: Appointment, completed: Bool) {
        var item = appointment
        item.status = completed ? .completed : .scheduled
        save(item)
    }

    func delete(_ appointment: Appointment) {
        guard let uid = userId else { return }
        apply(appointments.filter { $0.id != appointment.id })
        Task {
            do {
                try await supabase.from(Table.appointments).delete(returning: .minimal).eq("id", value: appointment.id).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
    }

    private func fail(_ error: Error, uid: UUID) async {
        guard userId == uid else { return }
        errorMessage = ErrorMessages.message(for: error)
        await reload()
    }
}
