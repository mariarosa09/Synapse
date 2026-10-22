//
//  Notification.swift
//  Synapse
//
//  Created by Mac-LAB on 9/4/26.
//

import SwiftUI

struct Notification: View {
    @Environment(SessionController.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var permission: NotificationPermission = .notDetermined
    @State private var showDeniedAlert = false

    private var settings: AppSettings { session.settings.settings }

    var body: some View {
        VStack (alignment: .leading, spacing: 20) {
            HeadingNoDesc(back: true, title: "Notification")
            Text("Manage reminder alerts for your health.")
                .font(.custom("DM Sans", size: 15))
                .foregroundStyle(Color.primary.opacity(0.7))
                .padding(.top)
                .padding(.horizontal, 30)
            NotificationToggle(isEnabled: binding(\.notificationsEnabled), title: "All Notifications", icon: "bell.badge.fill", description: "Turn every reminder on or off")
                .padding(.horizontal, 30)
            Divider()
                .frame(height: 1)
                .overlay(Color.myDarkBlue)
                .padding(.horizontal, 30)
            NotificationToggle(isEnabled: binding(\.medicineReminders), title: "Medicine", icon: "pills.fill", description: "Remind to take medicines")
                .padding(.horizontal, 30)
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1 : 0.4)
            Divider()
                .frame(height: 1)
                .overlay(Color.myDarkBlue)
                .padding(.horizontal, 30)
            NotificationToggle(isEnabled: binding(\.appointmentReminders), title: "Schedules", icon: "clock.fill", description: "Remind 5 minutes before appointments")
                .padding(.horizontal, 30)
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1 : 0.4)

            if permission == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications are turned off for Synapse in iOS Settings, so reminders can't be delivered.")
                        .font(.custom("DM Sans", size: 13))
                        .foregroundStyle(.red)
                    Button("Open iOS Settings") { openSystemSettings() }
                        .font(.custom("DM Sans", size: 13))
                        .foregroundStyle(Color.myDarkBlue)
                }
                .padding(.horizontal, 30)
            }
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { permission = await NotificationController.shared.permission() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { permission = await NotificationController.shared.permission() }
            }
        }
        .alert("Notifications are blocked", isPresented: $showDeniedAlert) {
            Button("Open Settings") { openSystemSettings() }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Allow notifications for Synapse in iOS Settings to receive reminders.")
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in Task { await set(keyPath, to: newValue) } }
        )
    }

    private func set(_ keyPath: WritableKeyPath<AppSettings, Bool>, to value: Bool) async {
        if value {
            let granted = await NotificationController.shared.ensureAuthorization()
            permission = await NotificationController.shared.permission()
            if !granted {
                showDeniedAlert = true
                return
            }
        }
        session.settings.update { $0[keyPath: keyPath] = value }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct NotificationToggle: View {
    @Binding var isEnabled: Bool
    var title: String
    var icon: String
    var description: String
    var body: some View {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(Color.myDarkBlue)
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.custom("DM Sans", size: 18))
                            .foregroundStyle(.primary)
                        Text(description)
                            .font(.custom("DM Sans", size: 13))
                            .foregroundStyle(Color.primary.opacity(0.7))
                    }
                }
            }
            .tint(Color.myDarkBlue)
            .padding(.vertical, 4)
        
    }
}

#Preview {
    Notification()
        .environment(SessionController())
}
