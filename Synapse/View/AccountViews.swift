//
//  AccountViews.swift
//  Synapse
//
//  Edit Profile, Change Email, Change Password and Appearance screens.
//

import SwiftUI
import PhotosUI

// MARK: - Shared layout bits

private struct FormMessages: View {
    var controller: ProfileController

    var body: some View {
        if let error = controller.errorMessage {
            Text(error)
                .font(.custom("DM Sans", size: 13))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let success = controller.successMessage {
            Text(success)
                .font(.custom("DM Sans", size: 13))
                .foregroundStyle(Color.myDarkBlue)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrimaryActionButton: View {
    let title: String
    let isWorking: Bool
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.custom("DM Sans", size: 16))
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(enabled ? Color.myDarkBlue : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .disabled(isWorking || !enabled)
    }
}

// MARK: - Edit profile (name + picture)

struct EditProfile: View {
    @Environment(SessionController.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var controller = ProfileController()
    @State private var firstname = ""
    @State private var middleInitial = ""
    @State private var surname = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var loaded = false
    @State private var attemptedSave = false
    @State private var confirmRemove = false

    private var hasPhoto: Bool { session.profile?.photoURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            HeadingNoDesc(back: true, title: "Edit Profile")
            ScrollView {
                VStack(spacing: 20) {
                    AvatarView(photoURL: session.profile?.photoURL, size: 130)
                        .overlay {
                            if controller.isWorking {
                                Circle().fill(Color.black.opacity(0.3))
                                ProgressView().tint(.white)
                            }
                        }

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(hasPhoto ? "Replace Photo" : "Upload Photo", systemImage: "photo.fill")
                                .font(.custom("DM Sans", size: 14))
                                .foregroundStyle(Color.myDarkBlue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(Capsule().fill(Color.myLightBlue))
                        }
                        .disabled(controller.isWorking)

                        if hasPhoto {
                            Button {
                                confirmRemove = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.custom("DM Sans", size: 14))
                                    .foregroundStyle(.red)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Capsule().fill(Color.red.opacity(0.1)))
                            }
                            .disabled(controller.isWorking)
                        }
                    }

                    HStack {
                        Input(title: "FIRSTNAME*", logoName: "", text: $firstname,
                              isValid: .constant(!attemptedSave || !firstname.trimmed.isEmpty),
                              errorMessage: "First name is required")
                        Input(title: "MI", logoName: "", text: $middleInitial, isValid: .constant(true), errorMessage: "")
                            .frame(maxWidth: 70)
                    }
                    Input(title: "SURNAME*", logoName: "", text: $surname,
                          isValid: .constant(!attemptedSave || !surname.trimmed.isEmpty),
                          errorMessage: "Surname is required")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EMAIL")
                            .font(.custom("DM Sans", size: 12))
                        Text(session.profile?.email ?? "")
                            .font(.custom("DM Sans", size: 15))
                            .foregroundStyle(.secondary)
                        Text("Change your email under Data & Account.")
                            .font(.custom("DM Sans", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    FormMessages(controller: controller)

                    PrimaryActionButton(title: "SAVE CHANGES", isWorking: controller.isWorking && selectedPhoto == nil) {
                        attemptedSave = true
                        Task {
                            if await controller.updateName(firstname: firstname, middleInitial: middleInitial, surname: surname) {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !loaded, let profile = session.profile else { return }
            firstname = profile.firstname
            middleInitial = profile.middleInitial
            surname = profile.surname
            loaded = true
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    _ = await controller.uploadPhoto(data: data)
                } else {
                    controller.errorMessage = "That image couldn't be loaded."
                }
                selectedPhoto = nil
            }
        }
        .confirmationDialog("Remove your profile picture?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove Picture", role: .destructive) {
                Task { _ = await controller.removePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Change email

struct ChangeEmailView: View {
    @Environment(SessionController.self) private var session
    @State private var controller = ProfileController()
    @State private var newEmail = ""
    @State private var password = ""
    @State private var validEmail = true
    @State private var validPassword = true

    var body: some View {
        VStack(spacing: 0) {
            HeadingNoDesc(back: true, title: "Change Email")
            ScrollView {
                VStack(spacing: 20) {
                    Text("Your current email is \(session.profile?.email ?? ""). For your security we'll ask for your password and send a verification link to the new address. Your email only changes after you open that link.")
                        .font(.custom("DM Sans", size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Input(title: "NEW EMAIL", logoName: "envelope.fill", text: $newEmail, isValid: $validEmail,
                          errorMessage: "Please enter a valid email address.")
                        .onChange(of: newEmail) { _, value in
                            validEmail = value.isEmpty || (value.contains("@") && value.contains("."))
                        }
                    Input(title: "CURRENT PASSWORD", logoName: "lock.fill", text: $password, isValid: $validPassword,
                          errorMessage: "Enter your password.")

                    FormMessages(controller: controller)

                    PrimaryActionButton(title: "SEND VERIFICATION LINK", isWorking: controller.isWorking,
                                        enabled: !newEmail.trimmed.isEmpty && !password.isEmpty) {
                        Task {
                            if await controller.changeEmail(to: newEmail, password: password) {
                                password = ""
                            }
                        }
                    }
                }
                .padding(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Change password

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

                    FormMessages(controller: controller)

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
                .padding(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @Environment(SessionController.self) private var session

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeadingNoDesc(back: true, title: "Appearance")
            Text("Choose how Synapse looks.")
                .font(.custom("DM Sans", size: 15))
                .foregroundStyle(Color.primary.opacity(0.7))
                .padding(.top)
                .padding(.horizontal, 30)

            ForEach(AppearanceMode.allCases) { mode in
                Button {
                    session.settings.update { $0.appearance = mode }
                } label: {
                    HStack {
                        Image(systemName: session.settings.settings.appearance == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.myDarkBlue)
                            .font(.title3)
                        Text(mode.title)
                            .font(.custom("DM Sans", size: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                }
                if mode != AppearanceMode.allCases.last {
                    Divider()
                        .frame(height: 1)
                        .overlay(Color.myDarkBlue)
                        .padding(.horizontal, 30)
                }
            }
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    EditProfile()
}
