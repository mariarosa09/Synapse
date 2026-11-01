//
//  MainTabView.swift
//  Synapse
//
//  Created by Mac-LAB on 9/1/26.
//
//  The tab bar (Home, Calendar, Profile). The custom logout pop-up is hosted here so its
//  dimmed backdrop covers the whole screen, tab bar included, on every iPhone size.
//

import SwiftUI

struct MainTabView: View {
    @Environment(SessionController.self) private var session
    @State private var showLogoutPopup = false
    @State private var isLoggingOut = false

    var body: some View {
        ZStack {
            TabView {
                VStack {
                    HomeView()
                }
                .tabItem {
                    Image(systemName: "house.fill")
                }
                VStack {
                    CalendarView()
                }
                .tabItem {
                    Image(systemName: "calendar")
                }
                VStack {
                    ProfileView(showLogoutPopup: $showLogoutPopup)
                }
                .tabItem {
                    Image(systemName: "person.fill")
                }
            }
            .tint(Color.myDarkBlue)

            if showLogoutPopup {
                ConfirmationPopup(
                    title: "Logout",
                    message: "Are you sure you want to log out of Synapse?",
                    confirmTitle: "Logout",
                    destructive: true,
                    isWorking: isLoggingOut,
                    onCancel: { showLogoutPopup = false },
                    onConfirm: logout
                )
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showLogoutPopup)
    }

    /// Signs out through Supabase Auth; RootView then shows the Login screen.
    private func logout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        Task {
            await session.signOut()
            isLoggingOut = false
            showLogoutPopup = false
        }
    }
}

#Preview {
    NavigationStack { MainTabView() }
        .environment(SessionController())
}
