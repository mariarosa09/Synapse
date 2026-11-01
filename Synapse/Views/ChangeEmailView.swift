//
//  ChangeEmailView.swift
//  Synapse
//
//  Change the account email with a one-time code:
//  1. confirm the current password and enter the new address -> Supabase emails a code to it,
//  2. enter the code -> Supabase Auth switches the email and the profile row follows (database trigger).
//

import SwiftUI

struct ChangeEmailView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = ProfileController()
    @State private var newEmail = ""
    @State private var password = ""
    @State private var code = ""
    @State private var validEmail = true
    @State private var validPassword = true

    var body: some View {
        VStack(spacing: 0) {
            HeadingNoDesc(back: true, title: "Change Email")
            ScrollView {
                VStack(spacing: 20) {
                    if !controller.usesPasswordLogin {
                        NoticeCard(systemImage: "person.badge.key.fill",
                                   text: "You sign in with \(controller.providerName), so your email comes from that account (\(session.profile?.email ?? "")). To use a different email, sign in with that \(controller.providerName) account or create a Synapse account with email and password.")
                    } else if let pending = controller.pendingEmail {
                        verifyStep(pending)
                    } else {
                        requestStep
                    }
                }
                .padding(30)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var requestStep: some View {
        VStack(spacing: 20) {
            Text("Your current email is \(session.profile?.email ?? ""). For your security we'll ask for your password, then send a verification code to the new address. Your email only changes after you enter that code.")
                .font(.synBody)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Input(title: "NEW EMAIL", logoName: "envelope.fill", text: $newEmail, isValid: $validEmail,
                  errorMessage: "Please enter a valid email address.", keyboard: .emailAddress)
                .onChange(of: newEmail) { _, value in
                    validEmail = value.isEmpty || value.isValidEmail
                }
            Input(title: "CURRENT PASSWORD", logoName: "lock.fill", text: $password, isValid: $validPassword,
                  errorMessage: "Enter your password.")

            FormMessages(error: controller.errorMessage, success: controller.successMessage)

            PrimaryActionButton(title: "SEND VERIFICATION CODE", isWorking: controller.isWorking,
                                enabled: newEmail.isValidEmail && !password.isEmpty) {
                Task {
                    if await controller.changeEmail(to: newEmail, password: password) {
                        password = ""
                        code = ""
                    }
                }
            }
        }
    }

    private func verifyStep(_ pending: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 50))
                .foregroundColor(Color.myDarkBlue)

            Text("Enter the code we sent to\n\(pending)")
                .font(.synBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            OTPCodeField(code: $code, maxLength: OTPVerificationController.codeLengths.upperBound)

            FormMessages(error: controller.errorMessage, success: controller.successMessage)

            PrimaryActionButton(title: "VERIFY & CHANGE EMAIL", isWorking: controller.isWorking,
                                enabled: OTPVerificationController.codeLengths.contains(code.count)) {
                Task {
                    if await controller.verifyEmailChange(code: code, session: session) {
                        code = ""
                        newEmail = ""
                    }
                }
            }

            SecondaryActionButton(title: "RESEND CODE", enabled: !controller.isWorking) {
                Task { await controller.resendEmailChangeCode() }
            }

            Button {
                controller.cancelEmailChange()
                code = ""
            } label: {
                Text("Use a different email")
                    .font(.synLabel)
                    .foregroundColor(.myDarkBlue)
            }
        }
    }
}

#Preview {
    NavigationStack { ChangeEmailView() }
        .environment(SessionController())
}
