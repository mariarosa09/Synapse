//
//  RootView.swift
//  Synapse
//
//  Chooses the screen from SessionController's state. The navigation stack is rebuilt on every
//  state change so no stale screens survive a login, logout or account deletion.
//

import SwiftUI

struct RootView: View {
    @Environment(SessionController.self) private var session
    @State private var splashFinished = false

    var body: some View {
        Group {
            if !splashFinished || session.state == .loading {
                SplashScreenView()
            } else {
                NavigationStack {
                    switch session.state {
                    case .signedOut:
                        if session.returnToLogin {
                            LoginView()
                        } else {
                            OverviewView()
                        }
                    case .needsOnboarding:
                        AboutYouView()
                    case .ready:
                        MainTabView()
                    case .loading:
                        SplashScreenView()
                    }
                }
                .id(session.state)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { splashFinished = true }
        }
    }
}

#Preview {
    RootView()
        .environment(SessionController())
}
