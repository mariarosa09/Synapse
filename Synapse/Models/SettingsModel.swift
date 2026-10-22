//
//  SettingsModel.swift
//  Synapse
//
//  Created by Mac-LAB on 9/24/26.
//

import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Stored at users/{uid}/settings/preferences.
struct AppSettings {
    var notificationsEnabled = true
    var medicineReminders = true
    var appointmentReminders = true
    var appearance: AppearanceMode = .system

    /// Effective values: the master switch overrides the individual ones.
    var medicineRemindersActive: Bool { notificationsEnabled && medicineReminders }
    var appointmentRemindersActive: Bool { notificationsEnabled && appointmentReminders }

    init() {}

    init(dictionary: [String: Any]) {
        notificationsEnabled = dictionary["notificationsEnabled"] as? Bool ?? true
        medicineReminders = dictionary["medicineReminders"] as? Bool ?? true
        appointmentReminders = dictionary["appointmentReminders"] as? Bool ?? true
        appearance = AppearanceMode(rawValue: dictionary["appearance"] as? String ?? "") ?? .system
    }

    var dictionary: [String: Any] {
        [
            "notificationsEnabled": notificationsEnabled,
            "medicineReminders": medicineReminders,
            "appointmentReminders": appointmentReminders,
            "appearance": appearance.rawValue
        ]
    }
}
