//
//  Profile.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//

import SwiftUI

struct Profile: View {
    @Environment(SessionController.self) private var session
    var body: some View {
        VStack (spacing: 20){
            HeadingNoDesc(back: false, title: "Profile")
            NavigationLink {
                EditProfile()
            } label: {
                ProfileSummary(name: session.profile?.fullName ?? "",
                               email: session.profile?.email ?? "",
                               photoURL: session.profile?.photoURL)
            }
            GeneralSettings()
            Logout()
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ProfileSummary: View {
    let name: String
    let email: String
    let photoURL: String?
    var body: some View {
        VStack (spacing: 20) {
            AvatarView(photoURL: photoURL, size: 150)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.myDarkBlue)
                        .background(Circle().fill(Color(.systemBackground)))
                }
            Text(name)
                .font(.custom("Graduate", size: 18))
                .foregroundStyle(Color.myDarkBlue)
            Text(email)
                .font(.custom("DM Sans", size: 16))
                .foregroundStyle(Color.myDarkBlue)
                .fontWeight(.semibold)
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
        VStack (alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.custom("Graduate", size: 16))
            NavigationLink {
                DataAccount()
            } label: {
                SettingSections(next: true, title: "Data & Account", icon: "person.fill")
            }
            Divider()
                .frame(height: 1)
                .overlay(Color.myDarkBlue)
            NavigationLink {
                Notification()
            } label:  {
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

struct Logout: View {
    @Environment(SessionController.self) private var session
    @State private var confirm = false

    var body: some View {
        Button {
            confirm = true
        } label: {
            SettingSections(next: false, title: "Logout", icon: "rectangle.portrait.and.arrow.right.fill")
                .foregroundStyle(.black)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.myDarkBlue))
                .padding(.horizontal, 30)
        }
        .confirmationDialog("Log out of Synapse?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { session.signOut() }
            Button("Cancel", role: .cancel) {}
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
                .font(.custom("DM Sans", size: 16))
                .foregroundStyle(.black)
            Spacer()
            if next {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.myDarkBlue)
            }
        }

    }
}

#Preview {
    Profile()
        .environment(SessionController())
}
