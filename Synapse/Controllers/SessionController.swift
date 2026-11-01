//
//  SessionController.swift
//  Synapse
//
//  Single source of truth for "who is signed in and where should the app be".
//
//  signedOut       -> Overview / Login / Create Account / OTP verification
//  needsOnboarding -> AboutYou (verified user whose profile isn't complete yet)
//  ready           -> the tab bar
//
//  It listens to Supabase Auth state changes, loads the user's profile from public.profiles,
//  owns the session-long data controllers, and keeps the profile picture's signed URL fresh.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class SessionController {
    enum State: Hashable { case loading, signedOut, needsOnboarding, ready }

    var state: State = .loading
    var profile: UserProfile?
    /// Signed URL of the profile picture (private bucket). nil = show the default picture.
    var avatarURL: URL?
    /// A one-off message for the login screen (for example after an account was removed).
    var notice: String?
    /// Set while the delete-account flow is running so the profile loader doesn't "recover" the account.
    var isDeletingAccount = false
    /// After the user logs out (or deletes the account) the signed-out flow starts at Login, not the welcome screen.
    var returnToLogin = false
    /// While a password reset is verifying its OTP the user is briefly signed in; keep them on the reset screen.
    @ObservationIgnored private(set) var isRecoveringPassword = false

    let settings = SettingsController()
    let medicines = MedicineController()
    let appointments = AppointmentController()
    let basicInfo = BasicInformationController()
    let medicalRecords = MedicalRecordController()

    private static let recoveryWindow: TimeInterval = 30 * 24 * 60 * 60

    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var activeUserID: UUID?
    @ObservationIgnored private var dataStarted = false
    @ObservationIgnored private var avatarURLPath: String?
    @ObservationIgnored private var avatarURLExpiry: Date?

    var userID: UUID? { activeUserID }

    init() {
        authTask = Task { [weak self] in
            for await change in supabase.auth.authStateChanges {
                guard let self else { return }
                await self.handle(event: change.event, session: change.session)
            }
        }
    }

    // MARK: - Auth state

    private func handle(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession:
            // The stored session may be expired; `auth.session` refreshes it (or throws if it can't).
            if session != nil, let fresh = try? await supabase.auth.session {
                await authChanged(fresh.user)
            } else {
                await authChanged(nil)
            }
        case .signedIn, .tokenRefreshed, .mfaChallengeVerified:
            await authChanged(session?.user)
        case .userUpdated:
            await authChanged(session?.user)
            if session?.user.id == activeUserID { await reloadProfile() }   // e.g. email change confirmed
        case .signedOut, .userDeleted:
            await authChanged(nil)
        case .passwordRecovery:
            break   // handled by the reset password screen
        }
    }

    private func authChanged(_ user: User?) async {
        if isRecoveringPassword { return }

        guard let user, user.emailConfirmedAt != nil else {
            // Signed out, or signed in but the email isn't verified yet: stay in the login / OTP flow.
            stopEverything(clearNotifications: true)
            state = .signedOut
            return
        }
        if activeUserID == user.id, profile != nil { return }

        stopEverything(clearNotifications: false)
        activeUserID = user.id
        state = .loading
        await loadProfile(user: user)
    }

    /// Re-evaluates the app state (for example right after an OTP was verified).
    func refresh() async {
        guard let user = supabase.auth.currentUser else {
            await authChanged(nil)
            return
        }
        if activeUserID == user.id, profile != nil {
            await reloadProfile()
        } else {
            await authChanged(user)
        }
    }

    func appDidBecomeActive() async {
        guard supabase.auth.currentSession != nil, activeUserID != nil else { return }
        do {
            _ = try await supabase.auth.session   // refreshes the token if needed
        } catch {
            if ErrorMessages.isSessionInvalid(error) {
                notice = "Your session expired. Please log in again."
                await signOut()
                return
            }
        }
        await reloadProfile()
        guard state == .ready else { return }
        // Pull the latest rows from Supabase; each controller then re-syncs the reminders.
        await settings.reload()
        await medicines.reload()
        await appointments.reload()
        await basicInfo.reload()
        await medicalRecords.reload()
        NotificationController.shared.requestSync()   // refills the rolling reminder window
    }

    /// Signs out through Supabase Auth. RootView then shows the Login screen.
    func signOut() async {
        isDeletingAccount = false
        returnToLogin = true
        do {
            try await supabase.auth.signOut()
        } catch {
            // A network failure must not leave the user stuck: drop the local session anyway.
            try? await supabase.auth.signOut(scope: .local)
        }
        await authChanged(nil)
    }

    // MARK: - Password recovery hold

    func beginPasswordRecovery() { isRecoveringPassword = true }

    func endPasswordRecovery() async {
        isRecoveringPassword = false
        await refresh()
    }

    // MARK: - Profile

    private func loadProfile(user: User) async {
        do {
            let rows: [UserProfile] = try await supabase.from(Table.profiles)
                .select()
                .eq("id", value: user.id)
                .limit(1)
                .execute()
                .value
            guard activeUserID == user.id else { return }

            var loaded: UserProfile
            if let existing = rows.first {
                loaded = existing
            } else {
                // The sign-up trigger normally creates this row; create it if it is missing.
                loaded = UserProfile(id: user.id, email: user.email ?? "")
                // Email sign-up sends firstname / surname; Google and Apple send a full name.
                let metadata = user.userMetadata
                let fullName = (metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue ?? "").trimmed
                let nameParts = fullName.split(separator: " ", maxSplits: 1).map(String.init)
                loaded.firstname = metadata["firstname"]?.stringValue ?? metadata["given_name"]?.stringValue ?? nameParts.first ?? ""
                loaded.middleInitial = metadata["middle_initial"]?.stringValue ?? ""
                loaded.surname = metadata["surname"]?.stringValue ?? metadata["family_name"]?.stringValue
                    ?? (nameParts.count > 1 ? nameParts[1] : "")
                try await supabase.from(Table.profiles).upsert(loaded, onConflict: "id").execute()
            }

            if loaded.deleted {
                if isDeletingAccount { return }
                if let deletedAt = loaded.deletedAt, Date().timeIntervalSince(deletedAt) > Self.recoveryWindow {
                    notice = "This account was deleted more than 30 days ago and can no longer be recovered."
                    await signOut()
                    return
                }
                // Logging in again within 30 days restores the account.
                try await supabase.from(Table.profiles)
                    .update(["deleted": AnyJSON.bool(false), "deleted_at": AnyJSON.null])
                    .eq("id", value: user.id)
                    .execute()
                loaded.deleted = false
                loaded.deletedAt = nil
            }

            apply(profile: loaded)
        } catch {
            guard activeUserID == user.id else { return }
            if ErrorMessages.isSessionInvalid(error) {
                notice = "Your session expired. Please log in again."
                await signOut()
                return
            }
            // Keep the stored session so the next launch / login can retry.
            notice = "We couldn't load your account: \(ErrorMessages.message(for: error))"
            stopEverything(clearNotifications: false)
            state = .signedOut
        }
    }

    /// Fetches the profile again after it was changed (name, photo, onboarding, email).
    func reloadProfile() async {
        guard let uid = activeUserID else { return }
        do {
            let rows: [UserProfile] = try await supabase.from(Table.profiles)
                .select()
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value
            guard activeUserID == uid, let loaded = rows.first, !loaded.deleted || isDeletingAccount else { return }
            apply(profile: loaded)
        } catch {
            print("Profile reload failed: \(ErrorMessages.message(for: error))")
        }
    }

    private func apply(profile loaded: UserProfile) {
        let photoChanged = loaded.avatarPath != profile?.avatarPath
        profile = loaded
        if photoChanged || avatarURLExpired { Task { await refreshAvatarURL() } }

        if loaded.onboardingComplete {
            startDataIfNeeded(uid: loaded.id)
            state = .ready
        } else {
            state = .needsOnboarding
        }
    }

    // MARK: - Profile picture (private bucket -> signed URL)

    private var avatarURLExpired: Bool {
        guard let avatarURLExpiry else { return true }
        return avatarURLExpiry.timeIntervalSinceNow < 60 * 60
    }

    func refreshAvatarURL() async {
        guard let path = profile?.avatarPath, !path.isEmpty else {
            avatarURL = nil
            avatarURLPath = nil
            avatarURLExpiry = nil
            return
        }
        if path == avatarURLPath, avatarURL != nil, !avatarURLExpired { return }
        do {
            let url = try await supabase.storage.from(Bucket.avatars)
                .createSignedURL(path: path, expiresIn: Bucket.signedURLLifetime)
            guard profile?.avatarPath == path else { return }
            avatarURL = url
            avatarURLPath = path
            avatarURLExpiry = Date().addingTimeInterval(TimeInterval(Bucket.signedURLLifetime))
        } catch {
            // Missing file or no access: fall back to the default picture.
            avatarURL = nil
            avatarURLPath = nil
            avatarURLExpiry = nil
            print("Avatar URL failed: \(ErrorMessages.message(for: error))")
        }
    }

    // MARK: - Session data

    private func startDataIfNeeded(uid: UUID) {
        guard !dataStarted else { return }
        dataStarted = true
        settings.start(uid: uid)
        medicines.start(uid: uid)
        appointments.start(uid: uid)
        basicInfo.start(uid: uid)
        medicalRecords.start(uid: uid)
        Task { await NotificationController.shared.requestAuthorizationIfNeeded() }
    }

    private func stopEverything(clearNotifications: Bool) {
        activeUserID = nil
        profile = nil
        avatarURL = nil
        avatarURLPath = nil
        avatarURLExpiry = nil
        dataStarted = false
        settings.stop()
        medicines.stop()
        appointments.stop()
        basicInfo.stop()
        medicalRecords.stop()
        NotificationController.shared.reset(removePending: clearNotifications)
    }
}
