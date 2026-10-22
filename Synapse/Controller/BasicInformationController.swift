//
//  BasicInformationController.swift
//  Synapse
//
//  CRUD for users/{uid}/basicInformation (allergies and medical conditions).
//

import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class BasicInformationController {
    var entries: [BasicInformationModel] = []
    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var userId: String?

    private var collection: CollectionReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("basicInformation")
    }

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
            self.entries = (snapshot?.documents ?? [])
                .compactMap { BasicInformationModel(dictionary: $0.data()) }
                .sorted { $0.startDate > $1.startDate }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        userId = nil
        entries = []
        isLoading = false
    }

    func entries(matching filter: StatusFilter) -> [BasicInformationModel] {
        entries.filter { filter.includes(active: $0.active) }
    }

    func validationError(for entry: BasicInformationModel) -> String? {
        if entry.title.trimmed.isEmpty { return "Please enter a name." }
        if entry.startDate > Date() { return "The start date can't be in the future." }
        return nil
    }

    @discardableResult
    func save(_ entry: BasicInformationModel) -> Bool {
        if let message = validationError(for: entry) {
            errorMessage = message
            return false
        }
        guard let collection else {
            errorMessage = "You need to be logged in."
            return false
        }
        var item = entry
        item.title = item.title.trimmed
        item.notes = item.notes.trimmed
        // Keep the end date consistent with the status.
        if item.active { item.endDate = nil } else if item.endDate == nil { item.endDate = Date() }
        errorMessage = nil
        collection.document(item.id.uuidString).setData(item.dictionary) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
        return true
    }

    func setActive(_ entry: BasicInformationModel, active: Bool) {
        var item = entry
        item.active = active
        save(item)
    }

    func delete(_ entry: BasicInformationModel) {
        guard let collection else { return }
        collection.document(entry.id.uuidString).delete { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }
}
