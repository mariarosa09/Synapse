//
//  ChangePasswordView.swift
//  Synapse
//
//  Change the password through Supabase Auth after confirming the current one.
//

import SwiftUI

struct ChangePasswordView: View {
    @State private var controller = ProfileController()
    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var validCurrent = true
    @State private var validNew = true
    @State private var validConfirmation = true
    @State private var newPasswordMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            HeadingNoDesc(back: true, title: "Change Password")
            ScrollView {
                VStack(spacing: 20) {
                    if !controller.usesPasswordLogin {
                        NoticeCard(systemImage: "person.badge.key.fill",
                                   text: "You sign in with \(controller.providerName), so Synapse has no separate password. Manage your password in your \(controller.providerName) account.")
                    } else {
                        passwordForm
                    }
                }
                .padding(30)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var passwordForm: some View {
        VStack(spacing: 20) {
            Input(title: "CURRENT PASSWORD", logoName: "lock.fill", text: $current, isValid: $validCurrent,
                  errorMessage: "Enter your current password.")
            Input(title: "NEW PASSWORD", logoName: "lock.fill", text: $newPassword, isValid: $validNew,
                  errorMessage: newPasswordMessage)
                .onChange(of: newPassword) { _, value in
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
                    validConfirmation = confirmation.isEmpty || confirmation == value
                }
            Input(title: "RE-ENTER NEW PASSWORD", logoName: "lock.fill", text: $confirmation, isValid: $validConfirmation,
                  errorMessage: "The passwords don't match.")
                .onChange(of: confirmation) { _, value in
                    validConfirmation = value.isEmpty || value == newPassword
                }

            FormMessages(error: controller.errorMessage, success: controller.successMessage)

            PrimaryActionButton(title: "UPDATE PASSWORD", isWorking: controller.isWorking,
                                enabled: !current.isEmpty && !newPassword.isEmpty && !confirmation.isEmpty) {
                Task {
                    if await controller.changePassword(current: current, new: newPassword, confirmation: confirmation) {
                        current = ""
                        newPassword = ""
                        confirmation = ""
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ChangePasswordView() }
}
