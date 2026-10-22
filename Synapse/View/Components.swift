//
//  Components.swift
//  Synapse
//
//  Small reusable pieces shared by several screens.
//

import SwiftUI

/// Profile picture from Firebase Storage, falling back to the app logo.
struct AvatarView: View {
    let photoURL: String?
    var size: CGFloat = 100

    var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .opacity(1)
                    case .failure:
                        Image("Profile").resizable().scaledToFit()
                            .opacity(1)
                    default:
                        ProgressView().tint(Color.myDarkBlue)
                    }
                }
            } else {
                Image("Profile").resizable().scaledToFit()
                    .opacity(1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.myDarkBlue, lineWidth: 1))
    }
}
#Preview("With Photo") {
    AvatarView(photoURL: "https://picsum.photos")
}

#Preview("Placeholder / No Photo") {
    AvatarView(photoURL: nil)
}


struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text(message)
                .font(.custom("DM Sans", size: 13))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.08)))
        .padding(.horizontal, 30)
    }
}

struct StatusBadge: View {
    let active: Bool

    var body: some View {
        Text(active ? "Active" : "Inactive")
            .font(.custom("DM Sans", size: 12))
            .fontWeight(.semibold)
            .foregroundStyle(active ? Color.myDarkBlue : Color.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(active ? Color.myLightBlue : Color.gray.opacity(0.15)))
    }
}

/// "LABEL" + rounded text field, matching the existing pop-up forms.
struct PopupField: View {
    let title: String
    @Binding var text: String
    var capitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.custom("DM Sans", size: 12))
                .padding(.top, 10)
            TextField("", text: $text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(capitalization)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
        }
    }
}

/// Cancel / Save pair used at the bottom of pop-ups.
struct PopupButtons: View {
    var saveTitle: String = "Save"
    var saveEnabled: Bool = true
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(Color.gray)
                    .padding()
            }
            Button(action: onSave) {
                Text(saveTitle)
                    .font(.custom("DM Sans", size: 12))
                    .foregroundStyle(saveEnabled ? Color.myDarkBlue : Color.gray)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(saveEnabled ? Color.myLightBlue : Color.gray.opacity(0.15)))
            }
            .disabled(!saveEnabled)
        }
    }
}

extension View {
    /// The white rounded card used by every pop-up.
    func popupCard() -> some View {
        self
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.myDarkBlue, lineWidth: 1))
            .padding(40)
    }
}

/// Floating "+" button used on list screens.
struct AddFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.myDarkBlue)
                .padding(-4)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.trailing, 35)
        .padding(.bottom, 15)
    }
}
