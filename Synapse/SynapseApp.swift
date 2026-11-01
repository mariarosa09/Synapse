//
//  SynapseApp.swift
//  Synapse
//
//  Created by Mac-LAB on 8/25/26.
//
//  App entry point. The backend is Supabase (see Controllers/SupabaseManager.swift);
//  screens live in Views/, logic in Controllers/, data types in Models/.
//

import SwiftUI
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        applyPickerTint()
        return true
    }

    /// Dark-blue tint for every picker (date pickers, segmented pickers), matching Color.myDarkBlue.
    private func applyPickerTint() {
        let darkBlue = UIColor(red: 0, green: 74 / 255, blue: 173 / 255, alpha: 1)
        UIDatePicker.appearance().tintColor = darkBlue
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = darkBlue
        segmented.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: darkBlue], for: .normal)
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
    @State private var session = SessionController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                // Synapse has a single light design; there is no appearance setting.
                .preferredColorScheme(.light)
                .tint(Color.myDarkBlue)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await session.appDidBecomeActive() }
                    }
                }
        }
    }
}
