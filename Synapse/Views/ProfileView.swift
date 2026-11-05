//
//  ProfileView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//
//  Profile summary (photo, name, email), General Settings and Logout. The logout confirmation
//  is the app's custom pop-up, shown by MainTabView over the whole screen.
//

import SwiftUI

struct ProfileView: View {
    @Environment(SessionController.self) private var session
    @Binding var showLogoutPopup: Bool

    var body: some View {
        VStack(spacing: 20) {
            HeadingNoDesc(back: false, title: "Profile")
            NavigationLink {
                EditProfileView()
            } label: {
                ProfileSummary(name: session.profile?.fullName ?? "",
                               email: session.profile?.email ?? "",
                               avatarURL: session.avatarURL,
                               avatarImage: session.avatarImage)
            }
            GeneralSettings()
            LogoutButton {
                showLogoutPopup = true
            }
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProfileSummary: View {
    let name: String
    let email: String
    let avatarURL: URL?
    var avatarImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 20) {
            AvatarView(url: avatarURL, localImage: avatarImage, size: 150)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.myDarkBlue)
                        .background(Circle().fill(Color(.systemBackground)))
                }
            Text(name)
                .font(.synSection)
                .foregroundStyle(Color.myDarkBlue)
                .multilineTextAlignment(.center)
            Text(email)
                .font(.synRow)
                .foregroundStyle(Color.myDarkBlue)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, -10)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(Color.myLightBlue)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.myDarkBlue, lineWidth: 1)
        )
        .padding(.horizontal, 30)
    }
}

struct GeneralSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.synSection)
            NavigationLink {
                DataAccountView()
            } label: {
                SettingSections(next: true, title: "Data & Account", icon: "person.fill")
            }
            Divider()
                .frame(height: 1)
                .overlay(Color.myDarkBlue)
            NavigationLink {
                SettingsView()
            } label: {
                SettingSections(next: true, title: "Notifications", icon: "bell.fill")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.myDarkBlue, lineWidth: 1))
        .padding(.horizontal, 30)
    }
}

struct LogoutButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingSections(next: false, title: "Logout", icon: "rectangle.portrait.and.arrow.right.fill")
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.myDarkBlue))
                .padding(.horizontal, 30)
        }
    }
}

struct SettingSections: View {
    let next: Bool
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.myDarkBlue)
                .padding(.horizontal, 4)
            Text(title)
                .font(.synRow)
                .foregroundStyle(.black)
            Spacer()
            if next {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.myDarkBlue)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { ProfileView(showLogoutPopup: .constant(false)) }
        .environment(SessionController())
}
