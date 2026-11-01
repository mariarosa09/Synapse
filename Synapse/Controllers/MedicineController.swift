//
//  MedicineController.swift
//  Synapse
//
//  CRUD, filtering and search for public.medicines. Every change is forwarded to
//  NotificationController, which creates / updates / cancels the reminders.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class MedicineController {
    var medicines: [MedicineInformation] = []
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
        medicines = []
        isLoading = false
        errorMessage = nil
    }

    /// Fetches the latest medicines from Supabase and re-syncs the reminder schedule.
    func reload() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { if userId == uid { isLoading = false } }
        do {
            let items: [MedicineInformation] = try await supabase.from(Table.medicines)
                .select()
                .eq("user_id", value: uid)
                .order("medication", ascending: true)
                .execute()
                .value
            guard userId == uid else { return }
            apply(items)
        } catch {
            guard userId == uid else { return }
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    private func apply(_ items: [MedicineInformation]) {
        medicines = items.sorted { $0.medication.localizedCaseInsensitiveCompare($1.medication) == .orderedAscending }
        NotificationController.shared.update(medicines: medicines)
    }

    // MARK: - Filtering + search

    /// Medicines matching the All / Active / Inactive filter and the search text.
    func medicines(matching filter: StatusFilter, search: String) -> [MedicineInformation] {
        medicines.filter { filter.includes(active: $0.active) && $0.matches(search: search) }
    }

    // MARK: - Validation

    func validationError(for medicine: MedicineInformation) -> String? {
        if medicine.medication.trimmed.isEmpty { return "Please enter the medicine name." }
        if medicine.amount.trimmed.isEmpty { return "Please enter the dosage." }
        if !MedicineInformation.allowedFrequencies.contains(medicine.frequency) { return "Frequency must be between 1 and 4 times a day." }
        if medicine.endDate < Calendar.current.startOfDay(for: medicine.startDate) { return "The end date can't be before the start date." }
        if medicine.usesCustomTimes && Set(medicine.intakeMinutes).count != medicine.intakeMinutes.count {
            return "Each intake time must be different."
        }
        return nil
    }

    // MARK: - CRUD

    /// Creates or updates a medicine. Returns false (and sets `errorMessage`) if validation fails.
    /// The list and the reminders update immediately; the write to Supabase happens in the background.
    @discardableResult
    func save(_ medicine: MedicineInformation) -> Bool {
        if let message = validationError(for: medicine) {
            errorMessage = message
            return false
        }
        guard let uid = userId else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = medicine
        item.medication = item.medication.trimmed
        item.amount = item.amount.trimmed
        item.instructions = item.instructions.trimmed
        if !item.usesCustomTimes { item.intakeMinutes = [] }
        errorMessage = nil

        var updated = medicines
        if let index = updated.firstIndex(where: { $0.id == item.id }) { updated[index] = item } else { updated.append(item) }
        apply(updated)

        Task {
            do {
                try await supabase.from(Table.medicines).upsert(item, onConflict: "id", returning: .minimal).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
        return true
    }

    func setActive(_ medicine: MedicineInformation, active: Bool) {
        var item = medicine
        item.active = active
        save(item)
    }

    func delete(_ medicine: MedicineInformation) {
        guard let uid = userId else { return }
        apply(medicines.filter { $0.id != medicine.id })   // cancels its reminders right away
        Task {
            do {
                try await supabase.from(Table.medicines).delete(returning: .minimal).eq("id", value: medicine.id).execute()
            } catch {
                await fail(error, uid: uid)
            }
        }
    }

    /// Shows the error and restores the list from the server so the UI never lies.
    private func fail(_ error: Error, uid: UUID) async {
        guard userId == uid else { return }
        errorMessage = ErrorMessages.message(for: error)
        await reload()
    }
}
