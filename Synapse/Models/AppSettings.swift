//
//  AppSettings.swift
//  Synapse
//
//  General settings stored in public.user_settings (one row per user).
//  Appearance options were removed on purpose: the app always uses its default look.
//

import Foundation

nonisolated struct AppSettings: Codable, Sendable, Equatable {
    var notificationsEnabled = true
    var medicineReminders = true
    var appointmentReminders = true

    /// Effective values: the master switch overrides the individual ones.
    var medicineRemindersActive: Bool { notificationsEnabled && medicineReminders }
    var appointmentRemindersActive: Bool { notificationsEnabled && appointmentReminders }

    init() {}

    enum CodingKeys: String, CodingKey {
        case notificationsEnabled = "notifications_enabled"
        case medicineReminders = "medicine_reminders"
        case appointmentReminders = "appointment_reminders"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        medicineReminders = try c.decodeIfPresent(Bool.self, forKey: .medicineReminders) ?? true
        appointmentReminders = try c.decodeIfPresent(Bool.self, forKey: .appointmentReminders) ?? true
    }
}
