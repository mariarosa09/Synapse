//
//  DataAccountView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/4/26.
//
//  Change email / password, clear all health data, or delete the account.
//  Confirmations use the app's custom pop-up.
//

import SwiftUI

struct DataAccountView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = ProfileController()
    @State private var clearDataPopup = false
    @State private var deleteAccountPopup = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                HeadingNoDesc(back: true, title: "Data & Account")
                NavigationLink {
                    ChangeEmailView()
                } label: {
                    SettingSections(next: true, title: "Change Email", icon: "envelope.fill")
                        .padding(.horizontal, 30)
                        .padding(.top)
                }
                divider
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingSections(next: true, title: "Change Password", icon: "lock.fill")
                        .padding(.horizontal, 30)
                }
                divider
                Button {
                    controller.clearMessages()
                    clearDataPopup = true
                } label: {
                    HStack {
                        Image(systemName: "eraser.fill")
                            .font(.title3)
                            .foregroundStyle(Color.myDarkBlue)
                            .padding(.horizontal, 4)
                        VStack(alignment: .leading) {
                            Text("Clear Data")
                                .font(.synRow)
                                .foregroundStyle(.black)
                            Text("This action cannot be undone.")
                                .font(.synCaption)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
                divider
                Button {
                    controller.clearMessages()
                    deleteAccountPopup = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                        VStack(alignment: .leading) {
                            Text("Delete Account")
                                .font(.synRow)
                                .foregroundStyle(.red)
                            Text("Your account can be recovered within 30 days by logging in again.")
                                .font(.synCaption)
                                .foregroundStyle(.red.opacity(0.70))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }

                if let message = controller.successMessage {
                    Text(message)
                        .font(.synCaption)
                        .foregroundStyle(Color.myDarkBlue)
                        .padding(.horizontal, 30)
                }
                Spacer()
            }

            if clearDataPopup {
                ConfirmationPopup(
                    title: "Clear Data",
                    message: "Are you sure you want to clear all your data? Your medical records and their files, basic information, medicines and appointments will be permanently deleted.",
                    confirmTitle: "Clear",
                    isWorking: controller.isWorking,
                    errorMessage: controller.errorMessage,
                    onCancel: { clearDataPopup = false },
                    onConfirm: {
                        Task { if await controller.clearData(session: session) { clearDataPopup = false } }
                    }
                )
            }

            if deleteAccountPopup {
                ConfirmationPopup(
                    title: "Delete Account",
                    message: "After 30 days of inactivity, your account cannot be recovered. Are you sure you want to delete your account?",
                    confirmTitle: "Delete",
                    isWorking: controller.isWorking,
                    errorMessage: controller.errorMessage,
                    onCancel: { deleteAccountPopup = false },
                    onConfirm: {
                        // On success the session signs out and the app returns to the Login screen.
                        Task { _ = await controller.deleteAccount(session: session) }
                    }
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var divider: some View {
        Divider()
            .frame(height: 1)
            .overlay(Color.myDarkBlue)
            .padding(.horizontal, 30)
    }
}

#Preview {
    NavigationStack { DataAccountView() }
        .environment(SessionController())
}
