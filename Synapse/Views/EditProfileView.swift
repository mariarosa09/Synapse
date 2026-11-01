//
//  EditProfileView.swift
//  Synapse
//
//  Edit the profile name and upload / replace / remove the profile picture.
//  Pictures are stored in the private `avatars` Supabase Storage bucket (ProfileController)
//  and shown through a signed URL, so they reappear after logging out or restarting the app.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
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
    @State private var isPhotoWork = false

    private var hasPhoto: Bool { session.profile?.avatarPath != nil }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeadingNoDesc(back: true, title: "Edit Profile")
                ScrollView {
                    VStack(spacing: 20) {
                        AvatarView(url: session.avatarURL, size: 130)
                            .overlay {
                                if isPhotoWork {
                                    Circle().fill(Color.black.opacity(0.3))
                                    ProgressView().tint(.white)
                                }
                            }

                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label(hasPhoto ? "Replace Photo" : "Upload Photo", systemImage: "photo.fill")
                                    .font(.synBody)
                                    .foregroundStyle(Color.myDarkBlue)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Capsule().fill(Color.myLightBlue))
                            }
                            .disabled(controller.isWorking)

                            if hasPhoto {
                                Button {
                                    controller.clearMessages()
                                    confirmRemove = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                        .font(.synBody)
                                        .foregroundStyle(.red)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 14)
                                        .background(Capsule().fill(Color.red.opacity(0.1)))
                                }
                                .disabled(controller.isWorking)
                            }
                        }

                        HStack(alignment: .top) {
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
                                .font(.synLabel)
                            Text(session.profile?.email ?? "")
                                .font(.synBody)
                                .foregroundStyle(.secondary)
                            NavigationLink {
                                ChangeEmailView()
                            } label: {
                                Text("Change email")
                                    .font(.synLabel)
                                    .foregroundStyle(Color.myDarkBlue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        FormMessages(error: confirmRemove ? nil : controller.errorMessage,
                                     success: controller.successMessage)

                        PrimaryActionButton(title: "SAVE CHANGES", isWorking: controller.isWorking && !isPhotoWork) {
                            attemptedSave = true
                            Task {
                                if await controller.updateName(firstname: firstname, middleInitial: middleInitial,
                                                               surname: surname, session: session) {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(30)
                }
            }

            if confirmRemove {
                ConfirmationPopup(
                    title: "Remove Picture",
                    message: "Remove your profile picture? The default picture will be shown instead.",
                    confirmTitle: "Remove",
                    isWorking: controller.isWorking,
                    errorMessage: controller.errorMessage,
                    onCancel: { confirmRemove = false },
                    onConfirm: {
                        Task {
                            isPhotoWork = true
                            if await controller.removePhoto(session: session) { confirmRemove = false }
                            isPhotoWork = false
                        }
                    }
                )
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
                isPhotoWork = true
                if let data = try? await item.loadTransferable(type: Data.self) {
                    _ = await controller.uploadPhoto(data: data, session: session)
                } else {
                    controller.errorMessage = "That image couldn't be loaded."
                }
                isPhotoWork = false
                selectedPhoto = nil
            }
        }
    }
}

#Preview {
    NavigationStack { EditProfileView() }
        .environment(SessionController())
}
