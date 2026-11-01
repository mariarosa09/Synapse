//
//  OTPVerificationController.swift
//  Synapse
//
//  Verifies the one-time code Supabase emails after sign-up (no verification links).
//  Handles resending with a cooldown, and invalid / expired codes.
//

import Foundation
import Supabase

@MainActor
@Observable
final class OTPVerificationController {
    let email: String
    let purpose: OTPPurpose

    var code = ""
    var isVerifying = false
    var isResending = false
    var errorMessage: String?
    var infoMessage: String?
    var verified = false
    /// Seconds left before another code can be requested (Supabase allows one email per minute).
    var resendCooldown = 0

    static let codeLengths = 6...10
    private static let cooldownSeconds = 60

    @ObservationIgnored private var cooldownTask: Task<Void, Never>?

    init(email: String, purpose: OTPPurpose = .signup) {
        self.email = email
        self.purpose = purpose
    }

    var sanitizedCode: String { String(code.filter(\.isNumber).prefix(Self.codeLengths.upperBound)) }
    var canSubmit: Bool { Self.codeLengths.contains(sanitizedCode.count) && !isVerifying }

    func onAppear() {
        if resendCooldown == 0 && !verified { startCooldown() }   // a code was just sent
    }

    func verify(session: SessionController) async {
        errorMessage = nil
        infoMessage = nil
        let token = sanitizedCode
        guard Self.codeLengths.contains(token.count) else {
            errorMessage = "Enter the code from the email we sent to \(email)."
            return
        }

        isVerifying = true
        defer { isVerifying = false }
        do {
            try await supabase.auth.verifyOTP(email: email, token: token, type: purpose.verifyType)
            verified = true
            infoMessage = "Email verified!"
            cooldownTask?.cancel()
            // SessionController receives the new session and moves on to "Tell Us About You".
            await session.refresh()
        } catch {
            code = ""
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    func resend() async {
        guard resendCooldown == 0, !isResending else { return }
        errorMessage = nil
        infoMessage = nil
        isResending = true
        defer { isResending = false }
        do {
            try await supabase.auth.resend(email: email, type: purpose.resendType)
            code = ""
            infoMessage = "A new code was sent to \(email). Earlier codes no longer work."
            startCooldown()
        } catch {
            errorMessage = ErrorMessages.message(for: error)
        }
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = Self.cooldownSeconds
        cooldownTask = Task { [weak self] in
            while let self, self.resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.resendCooldown -= 1
            }
        }
    }

    func stop() {
        cooldownTask?.cancel()
        cooldownTask = nil
    }
}
