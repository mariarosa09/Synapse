//
//  ProfileController.swift
//  Synapse
//
//  User-initiated account actions used by Profile, Edit Profile, Change Email, Change Password
//  and Data & Account: name, profile picture, email (with OTP), password, clear data, delete account.
//

import SwiftUI
import UIKit
import Supabase

@Observable
@MainActor
final class ProfileController {
    var isWorking = false
    var errorMessage: String?
    var successMessage: String?
    /// Set after Supabase accepted an email change; the screen then asks for the OTP sent to this address.
    var pendingEmail: String?

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    /// The sign-in method of the current account: "email", "google" or "apple".
    var signInProvider: String {
        supabase.auth.currentUser?.appMetadata["provider"]?.stringValue ?? "email"
    }

    /// Google / Apple accounts have no Synapse password, so password-confirmed changes don't apply.
    var usesPasswordLogin: Bool { signInProvider == "email" }

    var providerName: String {
        switch signInProvider {
        case "google": return "Google"
        case "apple": return "Apple"
        default: return signInProvider.capitalized
        }
    }

    private func currentUserID(_ session: SessionController) -> UUID? {
        session.userID ?? supabase.auth.currentUser?.id
    }

    // MARK: - Name

    func updateName(firstname: String, middleInitial: String, surname: String, session: SessionController) async -> Bool {
        clearMessages()
        let first = firstname.trimmed, last = surname.trimmed, initial = middleInitial.trimmed
        guard !first.isEmpty else { errorMessage = "First name is required."; return false }
        guard !last.isEmpty else { errorMessage = "Surname is required."; return false }
        guard initial.count <= 10 else { errorMessage = "Middle initial is too long."; return false }
        guard let uid = currentUserID(session) else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            let values: [String: AnyJSON] = [
                "firstname": .string(first),
                "middle_initial": .string(initial),
                "surname": .string(last)
            ]
            try await supabase.from(Table.profiles).update(values, returning: .minimal).eq("id", value: uid).execute()
            // Keep the Auth user metadata in step (best effort).
            _ = try? await supabase.auth.update(user: UserAttributes(data: values))
            await session.reloadProfile()
            successMessage = "Profile updated."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    // MARK: - Profile picture (private `avatars` bucket)

    /// Uploads a new picture, points the profile at it, then deletes the previous file.
    /// A fresh file name per upload means caches can never show the old picture.
    func uploadPhoto(data: Data, session: SessionController) async -> Bool {
        clearMessages()
        guard let uid = currentUserID(session) else { errorMessage = "You need to be logged in."; return false }
        guard let image = UIImage(data: data) else {
            errorMessage = "That image couldn't be read."
            return false
        }
        let resizedImage = Self.resized(image, maxSide: 800)
        guard let jpeg = resizedImage.jpegData(compressionQuality: 0.8) else {
            errorMessage = "That image couldn't be read."
            return false
        }

        isWorking = true
        defer { isWorking = false }
        let oldPath = session.profile?.avatarPath
        let newPath = "\(uid.uuidString.lowercased())/avatar-\(UUID().uuidString.lowercased()).jpg"
        let bucket = supabase.storage.from(Bucket.avatars)
        do {
            try await bucket.upload(newPath, data: jpeg, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false))
            do {
                try await supabase.from(Table.profiles)
                    .update(["avatar_path": AnyJSON.string(newPath)], returning: .minimal)
                    .eq("id", value: uid)
                    .execute()
            } catch {
                _ = try? await bucket.remove(paths: [newPath])   // don't leave an orphan behind
                throw error
            }
            // The database now points at the new file: Home, Profile and Edit Profile switch to it right away,
            // even if reloading the profile or signing the URL takes a moment (or fails).
            session.avatarChanged(path: newPath, image: UIImage(data: jpeg) ?? resizedImage)
            await session.refreshAvatarURL(force: true)
            // Only now that the new picture is in place is the previous file deleted.
            if let oldPath, !oldPath.isEmpty, oldPath != newPath {
                _ = try? await bucket.remove(paths: [oldPath])
            }
            await session.reloadProfile()
            successMessage = oldPath == nil ? "Profile picture uploaded." : "Profile picture replaced."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    func removePhoto(session: SessionController) async -> Bool {
        clearMessages()
        guard let uid = currentUserID(session) else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            if let path = session.profile?.avatarPath, !path.isEmpty {
                // Removing a file that is already gone succeeds with an empty result.
                _ = try await supabase.storage.from(Bucket.avatars).remove(paths: [path])
            }
            try await supabase.from(Table.profiles)
                .update(["avatar_path": AnyJSON.null], returning: .minimal)
                .eq("id", value: uid)
                .execute()
            session.avatarChanged(path: nil, image: nil)     // every screen shows the default picture at once
            await session.reloadProfile()
            successMessage = "Profile picture removed."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        let scale = largest > maxSide ? maxSide / largest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        // Redrawing also applies the EXIF orientation, so the uploaded JPEG is always upright.
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Email & password (both confirm the current password first)

    private func reauthenticate(password: String) async throws {
        guard let email = supabase.auth.currentUser?.email else { throw AppError("This account has no email address.") }
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch let error as AuthError where error.errorCode == .invalidCredentials {
            throw AppError("Your current password is incorrect.")
        }
    }

    /// Step 1: confirm the password, then ask Supabase to email a verification code to the new address.
    /// The email in Supabase Auth changes only after that code is verified (step 2).
    func changeEmail(to newEmail: String, password: String) async -> Bool {
        clearMessages()
        let email = newEmail.trimmed.lowercased()
        guard email.isValidEmail else { errorMessage = "Please enter a valid email address."; return false }
        guard let current = supabase.auth.currentUser?.email else { errorMessage = "You need to be logged in."; return false }
        guard email != current.lowercased() else { errorMessage = "That is already your email address."; return false }
        guard !password.isEmpty else { errorMessage = "Enter your current password to confirm."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await reauthenticate(password: password)
            try await supabase.auth.update(user: UserAttributes(email: email))
            pendingEmail = email
            successMessage = "We sent a verification code to \(email). Enter it below to finish changing your email."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    /// Step 2: verify the OTP. Supabase updates the auth email and the database trigger mirrors it into profiles.
    func verifyEmailChange(code: String, session: SessionController) async -> Bool {
        clearMessages()
        guard let email = pendingEmail else { errorMessage = "Start the email change again."; return false }
        let token = code.filter(\.isNumber)
        guard token.count >= 6 else { errorMessage = "Enter the code from the email."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await supabase.auth.verifyOTP(email: email, token: token, type: .emailChange)
            pendingEmail = nil
            await session.reloadProfile()
            successMessage = "Your email is now \(email)."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    func resendEmailChangeCode() async {
        clearMessages()
        guard let email = pendingEmail else { return }
        do {
            try await supabase.auth.resend(email: email, type: .emailChange)
            successMessage = "A new code was sent to \(email)."
        } catch {
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    func cancelEmailChange() {
        pendingEmail = nil
        clearMessages()
    }

    func changePassword(current: String, new: String, confirmation: String) async -> Bool {
        clearMessages()
        guard !current.isEmpty else { errorMessage = "Enter your current password."; return false }
        if let problem = PasswordRules.validate(new) { errorMessage = problem; return false }
        guard new == confirmation else { errorMessage = "The new passwords don't match."; return false }
        guard new != current else { errorMessage = "Choose a password different from the current one."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            try await reauthenticate(password: current)
            try await supabase.auth.update(user: UserAttributes(password: new))
            successMessage = "Password updated."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    // MARK: - Clear data / delete account

    /// Deletes all health data (records + their files, basic information, medicines, appointments).
    /// The account, profile name/photo and settings are kept. Reminders are cancelled as the lists empty out.
    func clearData(session: SessionController) async -> Bool {
        clearMessages()
        guard let uid = currentUserID(session) else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        defer { isWorking = false }
        do {
            // 1. Files first, while their paths are still recorded.
            let rows: [[String: String]] = try await supabase.from(Table.attachments)
                .select("storage_path")
                .eq("user_id", value: uid)
                .execute()
                .value
            let paths = rows.compactMap { $0["storage_path"] }
            for start in stride(from: 0, to: paths.count, by: 100) {
                let chunk = Array(paths[start..<min(start + 100, paths.count)])
                _ = try await supabase.storage.from(Bucket.medicalRecords).remove(paths: chunk)
            }

            // 2. Rows (attachments go with their records through ON DELETE CASCADE).
            for table in [Table.medicalRecords, Table.basicInformation, Table.medicines, Table.appointments] {
                try await supabase.from(table).delete(returning: .minimal).eq("user_id", value: uid).execute()
            }

            await session.reloadProfile()
            await session.medicalRecords.reload()
            await session.basicInfo.reload()
            await session.medicines.reload()
            await session.appointments.reload()
            successMessage = "Your data was cleared."
            return true
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }

    /// Soft-deletes the account: it is flagged as deleted and the user is signed out. Logging in again
    /// within 30 days restores it (see SessionController). Purging older accounts permanently needs a
    /// scheduled server-side job (see supabase/SETUP.md), which can't live in the app.
    func deleteAccount(session: SessionController) async -> Bool {
        clearMessages()
        guard let uid = currentUserID(session) else { errorMessage = "You need to be logged in."; return false }

        isWorking = true
        session.isDeletingAccount = true
        do {
            let values: [String: AnyJSON] = [
                "deleted": .bool(true),
                "deleted_at": .string(DBDate.timestampString(Date()))
            ]
            try await supabase.from(Table.profiles).update(values, returning: .minimal).eq("id", value: uid).execute()
            isWorking = false
            await session.signOut()
            session.notice = "Your account was deleted. Log in again within 30 days to restore it."
            return true
        } catch {
            session.isDeletingAccount = false
            isWorking = false
            errorMessage = ErrorMessages.message(for: error)
            return false
        }
    }
}
