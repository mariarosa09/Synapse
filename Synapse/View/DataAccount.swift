//
//  DataAccount.swift
//  Synapse
//
//  Created by Mac-LAB on 9/4/26.
//

import SwiftUI

struct DataAccount: View {
    @Environment(SessionController.self) private var session
    @State private var controller = ProfileController()
    @State var clearDataPopup: Bool = false
    @State var deleteAccountPopup: Bool = false
    var body: some View {
        ZStack {
            VStack (spacing: 20) {
                HeadingNoDesc(back: true, title: "Data & Account")
                NavigationLink {
                    ChangeEmailView()
                } label: {
                    SettingSections(next: true, title: "Change Email", icon: "envelope.fill")
                        .padding(.horizontal, 30)
                        .padding(.top)
                }
                Divider()
                    .frame(height: 1)
                    .overlay(Color.myDarkBlue)
                    .padding(.horizontal, 30)
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingSections(next: true, title: "Change Password", icon: "lock.fill")
                        .padding(.horizontal, 30)
                }
                Divider()
                    .frame(height: 1)
                    .overlay(Color.myDarkBlue)
                    .padding(.horizontal, 30)
                Button {
                    controller.clearMessages()
                    clearDataPopup.toggle()
                } label: {
                    HStack {
                        Image(systemName: "eraser.fill")
                            .font(.title3)
                            .foregroundStyle(Color.myDarkBlue)
                            .padding(.horizontal, 4)
                        VStack (alignment: .leading) {
                            Text("Clear Data")
                                .font(.custom("DM Sans", size: 16))
                                .foregroundStyle(.black)
                            Text("This action cannot be undone.")
                                .font(.custom("DM Sans", size: 13))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }.padding(.horizontal, 30)
                }
                Divider()
                    .frame(height: 1)
                    .overlay(Color.myDarkBlue)
                    .padding(.horizontal, 30)
                Button {
                    controller.clearMessages()
                    deleteAccountPopup.toggle()
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                        VStack (alignment: .leading) {
                            Text("Delete Account")
                                .font(.custom("DM Sans", size: 16))
                                .foregroundStyle(.red)
                            Text("Your account can be recovered within 30 days by logging in again.")
                                .font(.custom("DM Sans", size: 13))
                                .foregroundStyle(.red.opacity(0.70))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }.padding(.horizontal, 30)

                }

                if let message = controller.successMessage {
                    Text(message)
                        .font(.custom("DM Sans", size: 13))
                        .foregroundStyle(Color.myDarkBlue)
                        .padding(.horizontal, 30)
                }
                Spacer()
            }
            
            if clearDataPopup {
                Color.black.opacity(0.2).ignoresSafeArea()
                ClearConfirmDialog(isVisible: $clearDataPopup, controller: controller)
            }
            
            if deleteAccountPopup {
                Color.black.opacity(0.2).ignoresSafeArea()
                DeleteConfirmDialog(isVisible: $deleteAccountPopup, controller: controller, session: session)
            }

        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ClearConfirmDialog: View {
    @Binding var isVisible: Bool
    var controller: ProfileController
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Text("Clear Data")
                .foregroundStyle(Color.red)
                .font(.custom("Graduate", size: 16))
            Text("Are you sure you want to clear all your data? Your medical records, basic information, medicines and appointments will be permanently deleted.")
                .font(.custom("DM Sans", size: 14))
                .foregroundStyle(.primary)
            if let error = controller.errorMessage {
                Text(error)
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                if controller.isWorking { ProgressView().padding(.trailing, 8) }
                Button {
                    isVisible = false
                } label: {
                    Text("Cancel")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.gray)
                        .padding()
                }
                .disabled(controller.isWorking)
                Button {
                    Task {
                        if await controller.clearData() { isVisible = false }
                    }
                } label: {
                    Text("Clear")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.red)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill().foregroundStyle(Color.red.opacity(0.1)))
                }
                .disabled(controller.isWorking)
            }
        }
        .popupCard()
    }
}

struct DeleteConfirmDialog: View {
    @Binding var isVisible: Bool
    var controller: ProfileController
    var session: SessionController
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Text("Delete Account")
                .foregroundStyle(Color.red)
                .font(.custom("Graduate", size: 16))
            Text("After 30 days of inactivity, your account cannot be recovered. Are you sure you want to delete your account?")
                .font(.custom("DM Sans", size: 14))
                .foregroundStyle(.primary)
            if let error = controller.errorMessage {
                Text(error)
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                if controller.isWorking { ProgressView().padding(.trailing, 8) }
                Button {
                    isVisible = false
                } label: {
                    Text("Cancel")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.gray)
                        .padding()
                }
                .disabled(controller.isWorking)
                Button {
                    Task {
                        // On success the session signs out and the app returns to the welcome screen.
                        _ = await controller.deleteAccount(session: session)
                    }
                } label: {
                    Text("Delete")
                        .font(.custom("DM Sans", size: 12))
                        .foregroundStyle(Color.red)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill().foregroundStyle(Color.red.opacity(0.1)))
                }
                .disabled(controller.isWorking)
            }
        }
        .popupCard()
    }
}

#Preview {
    DataAccount()
        .environment(SessionController())
}
