//
//  MedicalRecordController.swift
//  Synapse
//
//  Created by Mac-LAB on 10/6/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

@Observable
@MainActor
final class MedicalRecordController {
    var records: [MedicalInformation] = []
    var isLoading: Bool = false
    var isSaving: Bool = false
    var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()
    
    @ObservationIgnored private nonisolated(unsafe) var listenerRegistration: ListenerRegistration?

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var recordsCollection: CollectionReference? {
        guard let userId = currentUserId else { return nil }
        return db.collection("users").document(userId).collection("medicalRecords")
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Firebase Storage File Upload
    
    /// Uploads file data to Firebase Storage and returns the download URL string asynchronously.
    @discardableResult
    func uploadFile(data: Data, mimeType: String = "image/jpeg") async throws -> String {
        guard let userId = currentUserId else {
            let error = NSError(domain: "MedicalRecordController", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found for file uploads."])
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        let uniqueFileName = "\(UUID().uuidString).jpg"
        let fileReference = storage
            .child("users")
            .child(userId)
            .child("medicalRecords")
            .child(uniqueFileName)
            
        let metadata = StorageMetadata()
        metadata.contentType = mimeType
        
        do {
            _ = try await fileReference.putDataAsync(data, metadata: metadata)
            let url = try await fileReference.downloadURL()
            return url.absoluteString
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    // MARK: - Realtime Listener & Fetching

    func startListening() {
        guard let collection = recordsCollection else {
            self.errorMessage = "No authenticated user found."
            return
        }

        self.isLoading = true
        listenerRegistration?.remove()

        // Real-time listeners remain block/closure based from Firebase,
        // but we handle the state updates cleanly on the MainActor.
        listenerRegistration = collection
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }

                self.records = documents.compactMap { MedicalInformation(dictionary: $0.data()) }
                self.isLoading = false
            }
    }

    func stopListening() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }

    // MARK: - CRUD Operations

    func addRecord(title: String, date: Date = .now, notes: String = "", files: [String] = []) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NSError(domain: "MedicalRecordController", code: 400, userInfo: [NSLocalizedDescriptionKey: "Title cannot be empty."])
        }
        
        guard let collection = recordsCollection else {
            let error = NSError(domain: "MedicalRecordController", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found."])
            self.errorMessage = error.localizedDescription
            throw error
        }

        let newRecord = MedicalInformation(
            title: trimmedTitle,
            date: date,
            file: files,
            notes: notes
        )

        self.isSaving = true
        self.errorMessage = nil

        do {
            try await collection.document(newRecord.id.uuidString).setData(newRecord.dictionary)
            self.isSaving = false
        } catch {
            self.isSaving = false
            self.errorMessage = error.localizedDescription
            throw error
        }
    }

    func updateRecord(id: UUID, title: String, date: Date, notes: String, files: [String]) async throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw NSError(domain: "MedicalRecordController", code: 400, userInfo: [NSLocalizedDescriptionKey: "Title cannot be empty."])
        }
        guard let collection = recordsCollection else {
            let error = NSError(domain: "MedicalRecordController", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found."])
            self.errorMessage = error.localizedDescription
            throw error
        }

        let previousFiles = records.first(where: { $0.id == id })?.file ?? []
        let updated = MedicalInformation(id: id, title: trimmedTitle, date: date, file: files, notes: notes)

        self.isSaving = true
        self.errorMessage = nil
        do {
            try await collection.document(id.uuidString).setData(updated.dictionary)
            self.isSaving = false
        } catch {
            self.isSaving = false
            self.errorMessage = error.localizedDescription
            throw error
        }

        // Attachments removed in the editor are also removed from Firebase Storage.
        for url in Set(previousFiles).subtracting(files) {
            await deleteStoredFile(urlString: url)
        }
    }

    private func deleteStoredFile(urlString: String) async {
        guard urlString.hasPrefix("https://") || urlString.hasPrefix("gs://") else { return }
        try? await Storage.storage().reference(forURL: urlString).delete()
    }

    func deleteRecord(at offsets: IndexSet) {
        guard let collection = recordsCollection else { return }

        // Local array deletion happens instantly for UI snappy responsiveness
        let recordsToRemove = offsets.map { records[$0] }
        self.records.remove(atOffsets: offsets)
        
        // Fire-and-forget deletion requests via background Tasks
        for record in recordsToRemove {
            Task {
                do {
                    try await collection.document(record.id.uuidString).delete()
                    for url in record.file { await deleteStoredFile(urlString: url) }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
