//
//  ConfirmationPopup.swift
//  Synapse
//
//  The app's custom confirmation pop-up (used instead of the default iOS alert) for Logout,
//  Clear Data, Delete Account, deleting appointments / attachments and removing the profile picture.
//  Same card, typography, spacing, corner radius and buttons as the other Synapse pop-ups.
//

import SwiftUI

struct ConfirmationPopup: View {
    let title: String
    let message: String
    var confirmTitle: String = "Confirm"
    /// Red title and button for actions that remove something or end the session.
    var destructive: Bool = true
    var isWorking: Bool = false
    var errorMessage: String? = nil
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var accent: Color { destructive ? .red : .myDarkBlue }

    var body: some View {
        ZStack {
            // Dimmed backdrop; tapping it cancels, like the other pop-ups.
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { if !isWorking { onCancel() } }

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .foregroundStyle(accent)
                    .font(.synSection)
                Text(message)
                    .font(.synBody)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.synLabel)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    if isWorking { ProgressView().padding(.trailing, 8) }
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.synLabel)
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                    .disabled(isWorking)
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.synLabel)
                            .foregroundStyle(accent)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(destructive ? Color.red.opacity(0.1) : Color.myLightBlue))
                    }
                    .disabled(isWorking)
                }
            }
            .popupCard()
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ConfirmationPopup(title: "Logout", message: "Are you sure you want to log out of Synapse?",
                      confirmTitle: "Logout", onCancel: {}, onConfirm: {})
}
