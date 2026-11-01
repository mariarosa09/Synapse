//
//  PasswordResetController.swift
//  Synapse
//
//  "Forgot Password?" with an emailed one-time code instead of a link:
//  1. resetPasswordForEmail sends the code ("Reset Password" template uses {{ .Token }}).
//  2. verifyOTP(type: .recovery) signs the user in for a moment, then the new password is saved.
//  SessionController holds navigation while this happens so the screen isn't swapped mid-way.
//

import Foundation
import Supabase

@MainActor
@Observable
final class PasswordResetController {
    enum Step { case requestCode, enterCode }

    var step: Step = .requestCode
    var email = ""
    var code = ""
    var newPassword = ""
    var confirmation = ""
    var isWorking = false
    var errorMessage: String?
    var infoMessage: String?
    var resendCooldown = 0

    @ObservationIgnored private var codeVerified = false
    @ObservationIgnored private var completed = false
    @ObservationIgnored private var cooldownTask: Task<Void, Never>?

    init(email: String = "") {
        self.email = email.trimmed
    }

    func sendCode() async {
        errorMessage = nil
        infoMessage = nil
        let address = email.trimmed.lowercased()
        guard address.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard resendCooldown == 0 else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            try await supabase.auth.resetPasswordForEmail(address)
            email = address
            step = .enterCode
            codeVerified = false
            infoMessage = "If an account exists for \(address), a reset code is on its way."
            startCooldown()
        } catch {
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    func resetPassword(session: SessionController) async {
        errorMessage = nil
        infoMessage = nil
        let token = code.filter(\.isNumber)
        guard codeVerified || OTPVerificationController.codeLengths.contains(token.count) else {
            errorMessage = "Enter the code from the email."
            return
        }
        if let problem = PasswordRules.validate(newPassword) { errorMessage = problem; return }
        guard newPassword == confirmation else { errorMessage = "The passwords don't match."; return }

        isWorking = true
        defer { isWorking = false }
        session.beginPasswordRecovery()
        do {
            if !codeVerified {
                try await supabase.auth.verifyOTP(email: email, token: token, type: .recovery)
                codeVerified = true
            }
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            completed = true
            infoMessage = "Password updated. Signing you in…"
            cooldownTask?.cancel()
            await session.endPasswordRecovery()   // continues into the app with the new password
        } catch {
            errorMessage = ErrorMessages.message(for: error)
            if !codeVerified {
                code = ""
                await session.endPasswordRecovery()
            }
            // If the code was verified but saving failed (e.g. same password), stay here so the user can retry.
        }
    }

    /// Leaving the screen half-way: never keep a recovery session that didn't set a new password.
    func leave(session: SessionController) async {
        cooldownTask?.cancel()
        guard session.isRecoveringPassword, !completed else { return }
        if codeVerified {
            try? await supabase.auth.signOut(scope: .local)
        }
        await session.endPasswordRecovery()
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = 60
        cooldownTask = Task { [weak self] in
            while let self, self.resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.resendCooldown -= 1
            }
        }
    }
}
