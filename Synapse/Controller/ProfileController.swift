//
//  ProfileController.swift
//  Synapse
//
//  User-initiated account actions: name, photo, email, password, clear data, delete account.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@Observable
@MainActor
final class ProfileController {
    var isWorking = false
    var errorMessage: String?
    var successMessage: String?

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()

    private var user: User? { Auth.auth().currentUser }
    private func userDocument(_ uid: String) -> DocumentReference { db.collection("users").document(uid) }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    // MARK: - Name

    func updateName(firstname: String, middleInitial: String, surname: String) async -> Bool {
        clearMessages()
        let first = firstname.trimmed, last = surname.trimmed
        guard !first.isEmpty else { errorMessage = "First name is required."; return false }
        guard !last.isEmpty else { errorMessage = "Surname is required."; return false }
        guard let user else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await userDocument(user.uid).updateData([
                "firstname": first,
                "middleInitial": middleInitial.trimmed,
                "surname": last
            ])
            // Keep the Firebase Auth display name in step (best effort).
            let request = user.createProfileChangeRequest()
            request.displayName = "\(first) \(last)"
            try? await request.commitChanges()
            successMessage = "Profile updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Photo

    private func avatarReference(_ uid: String) -> StorageReference {
        storage.child("users").child(uid).child("profile").child("avatar.jpg")
    }

    /// Uploads (or replaces) the profile picture.
    func uploadPhoto(data: Data) async -> Bool {
        clearMessages()
        guard let user else { errorMessage = "You need to be logged in."; return false }
        guard let image = UIImage(data: data), let jpeg = Self.resized(image, maxSide: 800).jpegData(compressionQuality: 0.8) else {
            errorMessage = "That image couldn't be read."
            return false
        }

        isWorking = true
        defer { isWorking = false }
        do {
            let reference = avatarReference(user.uid)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await reference.putDataAsync(jpeg, metadata: metadata)
            let url = try await reference.downloadURL()
            try await userDocument(user.uid).updateData(["photoURL": url.absoluteString])
            successMessage = "Profile picture updated."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removePhoto() async -> Bool {
        clearMessages()
        guard let user else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            do {
                try await avatarReference(user.uid).delete()
            } catch {
                // Already gone is fine; anything else is a real failure.
                if (error as NSError).code != StorageErrorCode.objectNotFound.rawValue { throw error }
            }
            try await userDocument(user.uid).updateData(["photoURL": FieldValue.delete()])
            successMessage = "Profile picture removed."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxSide else { return image }
        let scale = maxSide / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Email & password (both require re-authentication)

    private func reauthenticate(_ user: User, password: String) async throws {
        guard let email = user.email else { throw AppError("This account has no email address.") }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }

    /// Re-authenticates, then asks Firebase to send a verification link to the new address.
    /// The email in Firebase Auth changes only after that link is opened; Firestore is updated
    /// by SessionController as soon as it sees the new address.
    func changeEmail(to newEmail: String, password: String) async -> Bool {
        clearMessages()
        let email = newEmail.trimmed
        guard email.contains("@"), email.contains(".") else { errorMessage = "Please enter a valid email address."; return false }
        guard let user else { errorMessage = "You need to be logged in."; return false }
        guard email.lowercased() != (user.email ?? "").lowercased() else { errorMessage = "That is already your email address."; return false }
        guard !password.isEmpty else { errorMessage = "Enter your current password to confirm."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await reauthenticate(user, password: password)
            try await user.sendEmailVerification(beforeUpdatingEmail: email)
            successMessage = "We sent a verification link to \(email). Your email will change once you open it, then log in again if asked."
            return true
        } catch {
            errorMessage = AuthMessages.message(for: error)
            return false
        }
    }

    func changePassword(current: String, new: String, confirmation: String) async -> Bool {
        clearMessages()
        guard !current.isEmpty else { errorMessage = "Enter your current password."; return false }
        if let problem = PasswordRules.validate(new) { errorMessage = problem; return false }
        guard new == confirmation else { errorMessage = "The new passwords don't match."; return false }
        guard new != current else { errorMessage = "Choose a password different from the current one."; return false }
        guard let user else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await reauthenticate(user, password: current)
            try await user.updatePassword(to: new)
            successMessage = "Password updated."
            return true
        } catch {
            errorMessage = AuthMessages.message(for: error)
            return false
        }
    }

    // MARK: - Clear data / delete account

    /// Deletes all health data (records, basic information, medicines, appointments) and their stored files.
    /// The account, profile and settings are kept. Reminders are cancelled automatically as the lists empty out.
    func clearData() async -> Bool {
        clearMessages()
        guard let user else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            let userRef = userDocument(user.uid)
            for name in ["medicalRecords", "basicInformation", "medicines", "appointments"] {
                let documents = try await userRef.collection(name).getDocuments().documents
                for chunk in stride(from: 0, to: documents.count, by: 400) {
                    let batch = db.batch()
                    documents[chunk..<min(chunk + 400, documents.count)].forEach { batch.deleteDocument($0.reference) }
                    try await batch.commit()
                }
            }

            let files = try await storage.child("users").child(user.uid).child("medicalRecords").listAll()
            for item in files.items { try? await item.delete() }

            try await userRef.updateData([
                "sex": FieldValue.delete(),
                "bloodGroup": FieldValue.delete(),
                "birthdate": FieldValue.delete()
            ])
            successMessage = "Your data was cleared."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Soft-deletes the account: it is flagged as deleted and the user is signed out. Logging in again
    /// within 30 days restores it (see SessionController). Permanently purging older accounts needs a
    /// server-side job (Cloud Function / TTL), which can't live in the app.
    func deleteAccount(session: SessionController) async -> Bool {
        clearMessages()
        guard let user else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        session.isDeletingAccount = true
        do {
            try await userDocument(user.uid).updateData([
                "deleted": true,
                "deletedAt": FieldValue.serverTimestamp()
            ])
            isWorking = false
            session.signOut()
            return true
        } catch {
            session.isDeletingAccount = false
            isWorking = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}
