//
//  OTPVerificationView.swift
//  Synapse
//
//  Replaces the old "click the link in your email" screen: the user types the one-time code
//  Supabase emailed them. Supports resending (with a cooldown) and shows clear errors for
//  invalid or expired codes. Once verified, SessionController moves on to "Tell Us About You".
//

import SwiftUI

struct OTPVerificationView: View {
    @Environment(SessionController.self) private var session
    @State private var controller: OTPVerificationController

    init(email: String, purpose: OTPPurpose = .signup) {
        _controller = State(initialValue: OTPVerificationController(email: email, purpose: purpose))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AuthHeading(title: "Verify Email", subtitle: "Enter the code we emailed you to activate your account")

                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 60))
                    .foregroundColor(Color.myDarkBlue)

                Text("We sent a verification code to\n\(controller.email)")
                    .font(.synRow)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                OTPCodeField(code: $controller.code, maxLength: OTPVerificationController.codeLengths.upperBound)
                    .disabled(controller.verified)
                    .onSubmit { submit() }

                FormMessages(error: controller.errorMessage, success: controller.infoMessage)

                PrimaryActionButton(title: "VERIFY",
                                    isWorking: controller.isVerifying,
                                    enabled: controller.canSubmit && !controller.verified) {
                    submit()
                }

                SecondaryActionButton(title: resendTitle,
                                      enabled: controller.resendCooldown == 0 && !controller.isResending && !controller.verified) {
                    Task { await controller.resend() }
                }

                Text("The code expires after a while. If it doesn't work, request a new one; only the latest code is valid. Check your spam folder if you can't find the email.")
                    .font(.synLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(30)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.onAppear() }
        .onDisappear { controller.stop() }
    }

    private var resendTitle: String {
        if controller.isResending { return "SENDING…" }
        return controller.resendCooldown > 0 ? "RESEND CODE (\(controller.resendCooldown)s)" : "RESEND CODE"
    }

    private func submit() {
        guard controller.canSubmit else { return }
        Task { await controller.verify(session: session) }
    }
}

#Preview {
    NavigationStack { OTPVerificationView(email: "name@example.com") }
        .environment(SessionController())
}
