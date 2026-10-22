//
//  SessionController.swift
//  Synapse
//
//  Single source of truth for "who is signed in and where should the app be".
//
//  signedOut       -> Overview / Login / Create Account
//  needsOnboarding -> AboutYou (verified user whose profile isn't complete yet)
//  ready           -> the tab bar
//
//  It also owns the session-long Firestore listeners, so profile changes show up
//  everywhere and reminders stay in sync no matter which screen is open.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class SessionController {
    enum State: Hashable { case loading, signedOut, needsOnboarding, ready }

    var state: State = .loading
    var profile: UserProfile?
    /// A one-off message for the login screen (for example after an account was removed).
    var notice: String?
    /// Set while the delete-account flow is running so the profile listener doesn't "recover" the account.
    var isDeletingAccount = false

    let settings = SettingsController()
    let medicines = MedicineController()
    let appointments = AppointmentController()
    let basicInfo = BasicInformationController()

    private static let recoveryWindow: TimeInterval = 30 * 24 * 60 * 60

    private let db = Firestore.firestore()
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var profileListener: ListenerRegistration?
    @ObservationIgnored private var activeUID: String?
    @ObservationIgnored private var dataStarted = false

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.authChanged(user) }
        }
    }

    // MARK: - Auth state

    private func authChanged(_ user: User?) {
        guard let user, user.isEmailVerified else {
            // Signed out, or signed in but the email isn't confirmed yet: stay in the login / verify flow.
            stopEverything(clearNotifications: true)
            state = .signedOut
            return
        }
        if activeUID == user.uid, profileListener != nil { return }

        stopEverything(clearNotifications: false)
        activeUID = user.uid
        state = .loading
        listenToProfile(uid: user.uid)
    }

    /// Re-reads the Firebase user (for example after the email was verified) and re-evaluates the app state.
    func refresh() async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await user.reload()
        } catch {
            if AuthMessages.isSessionInvalid(error) {
                notice = "Your account details changed. Please log in again."
                signOut()
                return
            }
        }
        authChanged(Auth.auth().currentUser)
        if let profile { syncEmailIfNeeded(profile) }
    }

    func appDidBecomeActive() async {
        guard Auth.auth().currentUser != nil else { return }
        await refresh()
        NotificationController.shared.requestSync()   // refills the rolling reminder window
    }

    func signOut() {
        isDeletingAccount = false
        do { try Auth.auth().signOut() } catch { print("Sign out failed: \(error.localizedDescription)") }
    }

    // MARK: - Profile

    private func listenToProfile(uid: String) {
        profileListener = db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            self?.handleProfile(snapshot, error, uid: uid)
        }
    }

    private func handleProfile(_ snapshot: DocumentSnapshot?, _ error: Error?, uid: String) {
        guard uid == activeUID else { return }

        if let error {
            notice = "We couldn't load your account: \(error.localizedDescription)"
            signOut()
            return
        }
        guard let snapshot else { return }

        guard snapshot.exists, let data = snapshot.data() else {
            // Verified user without a profile document: create a minimal one (never from a cache-only miss).
            if !snapshot.metadata.isFromCache {
                db.collection("users").document(uid).setData([
                    "uid": uid,
                    "email": Auth.auth().currentUser?.email ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "onboardingComplete": false,
                    "deleted": false
                ], merge: true)
            }
            return
        }

        let loaded = UserProfile(uid: uid, dictionary: data)

        if loaded.deleted {
            if isDeletingAccount || snapshot.metadata.hasPendingWrites { return }
            if let deletedAt = loaded.deletedAt, Date().timeIntervalSince(deletedAt) > Self.recoveryWindow {
                notice = "This account was deleted more than 30 days ago and can no longer be recovered."
                signOut()
            } else {
                // Logging in again within 30 days restores the account.
                db.collection("users").document(uid).updateData(["deleted": false, "deletedAt": FieldValue.delete()])
            }
            return
        }

        profile = loaded
        syncEmailIfNeeded(loaded)

        if loaded.onboardingComplete {
            startDataIfNeeded(uid: uid)
            state = .ready
        } else {
            state = .needsOnboarding
        }
    }

    /// After the user confirms a new email address, Firebase Auth already has it; mirror it into Firestore.
    private func syncEmailIfNeeded(_ profile: UserProfile) {
        guard let authEmail = Auth.auth().currentUser?.email, !authEmail.isEmpty,
              authEmail.lowercased() != profile.email.lowercased() else { return }
        db.collection("users").document(profile.uid).updateData(["email": authEmail])
    }

    // MARK: - Session data

    private func startDataIfNeeded(uid: String) {
        guard !dataStarted else { return }
        dataStarted = true
        settings.start(uid: uid)
        medicines.start(uid: uid)
        appointments.start(uid: uid)
        basicInfo.start(uid: uid)
        Task { await NotificationController.shared.requestAuthorizationIfNeeded() }
    }

    private func stopEverything(clearNotifications: Bool) {
        profileListener?.remove()
        profileListener = nil
        activeUID = nil
        profile = nil
        dataStarted = false
        settings.stop()
        medicines.stop()
        appointments.stop()
        basicInfo.stop()
        NotificationController.shared.reset(removePending: clearNotifications)
    }
}
