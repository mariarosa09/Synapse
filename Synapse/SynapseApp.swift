//
//  SynapseApp.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show reminders as banners even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@main
struct SynapseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: SessionController

    init() {
        // Firebase must be configured before anything touches Auth or Firestore.
        FirebaseApp.configure()
        _session = State(initialValue: SessionController())
    }

    private var colorScheme: ColorScheme? {
        switch session.settings.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(colorScheme)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await session.appDidBecomeActive() }
                    }
                }
        }
    }
}

/// Chooses the screen from the session state. The stack is rebuilt on every state change so no stale
/// screens (for example Data & Account after deleting the account) survive a login or logout.
struct RootView: View {
    @Environment(SessionController.self) private var session
    @State private var splashFinished = false

    var body: some View {
        Group {
            if !splashFinished || session.state == .loading {
                SplashScreen()
            } else {
                NavigationStack {
                    switch session.state {
                    case .signedOut:
                        Overview()
                    case .needsOnboarding:
                        AboutYou()
                    case .ready:
                        NavigationBar()
                    case .loading:
                        SplashScreen()
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

extension Color {
    static let myDarkBlue = Color(red: 0/255, green: 74/255, blue: 173/255)
    static let myLightBlue = Color(red: 224/255, green: 239/255, blue: 251/255)
}


struct Logo: View {
    var body: some View {
        HStack {
                Spacer()
                Image("Logo")
                .resizable()
                .scaledToFit()
                .padding(7)
                .background(Color.white)
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .shadow(radius: 3)
            }
            .padding(.bottom, 30)
    }
}

struct Heading: View {
    let back: Bool
    let title: String
    let description: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack (alignment: .top) {
            VStack (alignment: .leading) {
                Spacer().frame(height: 45)
                
                HStack {
                    if back {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 5)
                        }
                    }
                    
                    VStack (alignment: .leading) {
                        Text(title)
                            .font(Font.custom("Graduate", size: 20))
                            .foregroundStyle(Color.white)
                            .padding(.bottom, 5)
                        Text(description)
                            .font(Font.custom("DM Sans", size: 14))
                            .foregroundStyle(Color.white)
                    }
                    
                    Spacer()
                }
            }
            
            Logo()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 10)
    }
}

struct HeadingNoDesc: View {
    let back: Bool
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack (alignment: .top) {
            VStack (alignment: .leading) {
                Spacer().frame(height: 45)
                
                HStack {
                    if back {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 25))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 5)
                        }
                    }
                    
                    Text(title)
                        .font(Font.custom("Graduate", size: 20))
                        .foregroundStyle(Color.white)
                    
                    Spacer()
                }
            }
            
            Logo()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .background(Color.myDarkBlue)
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 10)
    }
}

#Preview {
    RootView()
        .environment(SessionController())
}
