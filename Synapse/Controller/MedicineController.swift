//
//  MedicineController.swift
//  Synapse
//
//  CRUD for users/{uid}/medicines. Every Firestore change is forwarded to
//  NotificationController, which creates / updates / cancels the reminders.
//

import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class MedicineController {
    var medicines: [MedicineInformation] = []
    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var userId: String?

    private var collection: CollectionReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("medicines")
    }

    // MARK: - Listening

    func start(uid: String) {
        stop()
        userId = uid
        isLoading = true
        listener = collection?.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            let items = (snapshot?.documents ?? [])
                .compactMap { MedicineInformation(dictionary: $0.data()) }
                .sorted { $0.medication.localizedCaseInsensitiveCompare($1.medication) == .orderedAscending }
            self.medicines = items
            NotificationController.shared.update(medicines: items)
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        userId = nil
        medicines = []
        isLoading = false
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
    @discardableResult
    func save(_ medicine: MedicineInformation) -> Bool {
        if let message = validationError(for: medicine) {
            errorMessage = message
            return false
        }
        guard let collection else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = medicine
        item.medication = item.medication.trimmed
        item.amount = item.amount.trimmed
        item.instructions = item.instructions.trimmed
        errorMessage = nil
        collection.document(item.id.uuidString).setData(item.dictionary) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
        return true
    }

    func setActive(_ medicine: MedicineInformation, active: Bool) {
        guard let collection else { return }
        collection.document(medicine.id.uuidString).updateData(["active": active]) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }

    func delete(_ medicine: MedicineInformation) {
        guard let collection else { return }
        collection.document(medicine.id.uuidString).delete { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }
}
