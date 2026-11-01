//
//  ForgotPasswordView.swift
//  Synapse
//
//  Password reset with an emailed one-time code (no reset links):
//  1. enter the account email -> Supabase sends a code,
//  2. enter the code and a new password -> the password is updated and the user is signed in.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(SessionController.self) private var session
    @State private var controller: PasswordResetController
    @State private var validEmail = true
    @State private var validNew = true
    @State private var newPasswordMessage = ""
    @State private var validConfirmation = true

    init(email: String = "") {
        _controller = State(initialValue: PasswordResetController(email: email))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AuthHeading(title: "Reset Password",
                            subtitle: controller.step == .requestCode
                                ? "We'll email you a code to reset your password"
                                : "Enter the code we sent to \(controller.email)")

                if controller.step == .requestCode {
                    requestCodeStep
                } else {
                    enterCodeStep
                }
            }
            .padding(30)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            // Never keep a half-finished recovery session.
            Task { await controller.leave(session: session) }
        }
    }

    private var requestCodeStep: some View {
        VStack(spacing: 20) {
            Input(title: "EMAIL", logoName: "envelope.fill", text: $controller.email, isValid: $validEmail,
                  errorMessage: "Please enter a valid email address.", keyboard: .emailAddress)
                .onChange(of: controller.email) { _, value in
                    validEmail = value.isEmpty || value.isValidEmail
                }

            FormMessages(error: controller.errorMessage, success: controller.infoMessage)

            PrimaryActionButton(title: controller.resendCooldown > 0 ? "SEND CODE (\(controller.resendCooldown)s)" : "SEND CODE",
                                isWorking: controller.isWorking,
                                enabled: controller.email.isValidEmail && controller.resendCooldown == 0) {
                Task { await controller.sendCode() }
            }
        }
    }

    private var enterCodeStep: some View {
        VStack(spacing: 20) {
            OTPCodeField(code: $controller.code, maxLength: OTPVerificationController.codeLengths.upperBound)

            Input(title: "NEW PASSWORD", logoName: "lock.fill", text: $controller.newPassword, isValid: $validNew,
                  errorMessage: newPasswordMessage)
                .onChange(of: controller.newPassword) { _, value in
                    if value.isEmpty {
                        validNew = true
                        newPasswordMessage = ""
                    } else if let problem = PasswordRules.validate(value) {
                        validNew = false
                        newPasswordMessage = problem
                    } else {
                        validNew = true
                        newPasswordMessage = ""
                    }
                    validConfirmation = controller.confirmation.isEmpty || controller.confirmation == value
                }

            Input(title: "RE-ENTER NEW PASSWORD", logoName: "lock.fill", text: $controller.confirmation,
                  isValid: $validConfirmation, errorMessage: "The passwords don't match.")
                .onChange(of: controller.confirmation) { _, value in
                    validConfirmation = value.isEmpty || value == controller.newPassword
                }

            FormMessages(error: controller.errorMessage, success: controller.infoMessage)

            PrimaryActionButton(title: "RESET PASSWORD", isWorking: controller.isWorking,
                                enabled: !controller.code.isEmpty && !controller.newPassword.isEmpty && !controller.confirmation.isEmpty) {
                Task { await controller.resetPassword(session: session) }
            }

            SecondaryActionButton(title: controller.resendCooldown > 0 ? "RESEND CODE (\(controller.resendCooldown)s)" : "RESEND CODE",
                                  enabled: controller.resendCooldown == 0 && !controller.isWorking) {
                Task { await controller.sendCode() }
            }

            Button {
                controller.step = .requestCode
                controller.code = ""
                controller.errorMessage = nil
                controller.infoMessage = nil
            } label: {
                Text("Use a different email")
                    .font(.synLabel)
                    .foregroundColor(.myDarkBlue)
            }
        }
    }
}

#Preview {
    NavigationStack { ForgotPasswordView() }
        .environment(SessionController())
}
