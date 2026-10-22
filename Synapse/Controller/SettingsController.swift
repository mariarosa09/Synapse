//
//  SettingsController.swift
//  Synapse
//
//  Preferences live in users/{uid}/settings/preferences and are mirrored into
//  NotificationController so reminders follow the switches immediately.
//

import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class SettingsController {
    var settings = AppSettings()
    var isLoaded = false
    var errorMessage: String?

    private let db = Firestore.firestore()
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var userId: String?

    private var document: DocumentReference? {
        guard let userId else { return nil }
        return db.collection("users").document(userId).collection("settings").document("preferences")
    }

    func start(uid: String) {
        stop()
        userId = uid
        listener = document?.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let snapshot else { return }
            if snapshot.exists, let data = snapshot.data() {
                self.settings = AppSettings(dictionary: data)
            } else if !snapshot.metadata.isFromCache {
                // First run: persist the defaults.
                self.document?.setData(AppSettings().dictionary)
                self.settings = AppSettings()
            } else {
                return   // cache miss, wait for the server
            }
            self.isLoaded = true
            NotificationController.shared.update(settings: self.settings)
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        userId = nil
        settings = AppSettings()
        isLoaded = false
    }

    /// Applies a change locally right away (so the UI and reminders react instantly) and saves it to Firestore.
    func update(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        settings = updated
        NotificationController.shared.update(settings: updated)

        guard let document else { return }
        var data = updated.dictionary
        data["updatedAt"] = FieldValue.serverTimestamp()
        document.setData(data) { [weak self] error in
            if let error { self?.errorMessage = error.localizedDescription }
        }
    }
}
