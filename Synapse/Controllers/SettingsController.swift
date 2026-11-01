//
//  SettingsController.swift
//  Synapse
//
//  General settings live in public.user_settings (one row per user) and are mirrored into
//  NotificationController so reminders follow the switches immediately. Turning reminders off
//  never deletes medicines or appointments; it only removes pending notifications.
//

import SwiftUI
import Supabase

@Observable
@MainActor
final class SettingsController {
    var settings = AppSettings()
    var isLoaded = false
    var errorMessage: String?

    @ObservationIgnored private var userId: UUID?

    func start(uid: UUID) {
        stop()
        userId = uid
        Task { await reload() }
    }

    func stop() {
        userId = nil
        settings = AppSettings()
        isLoaded = false
        errorMessage = nil
    }

    /// Restores the saved preferences (creating the row with defaults on first use).
    func reload() async {
        guard let uid = userId else { return }
        do {
            let rows: [AppSettings] = try await supabase.from(Table.settings)
                .select("notifications_enabled, medicine_reminders, appointment_reminders")
                .eq("user_id", value: uid)
                .limit(1)
                .execute()
                .value
            guard userId == uid else { return }
            if let saved = rows.first {
                settings = saved
            } else {
                settings = AppSettings()
                try await save(settings, for: uid)
            }
            isLoaded = true
            errorMessage = nil
            NotificationController.shared.update(settings: settings)
        } catch {
            guard userId == uid else { return }
            errorMessage = ErrorMessages.message(for: error)
            // Still let reminders run with the last known values.
            NotificationController.shared.update(settings: settings)
        }
    }

    /// Applies a change locally right away (so the UI and reminders react instantly) and saves it to Supabase.
    func update(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        let previous = settings
        settings = updated
        NotificationController.shared.update(settings: updated)

        guard let uid = userId else { return }
        Task {
            do {
                try await save(updated, for: uid)
                errorMessage = nil
            } catch {
                guard userId == uid else { return }
                errorMessage = ErrorMessages.message(for: error)
                settings = previous
                NotificationController.shared.update(settings: previous)
            }
        }
    }

    private func save(_ value: AppSettings, for uid: UUID) async throws {
        let payload: [String: AnyJSON] = [
            "user_id": .string(uid.uuidString),
            "notifications_enabled": .bool(value.notificationsEnabled),
            "medicine_reminders": .bool(value.medicineReminders),
            "appointment_reminders": .bool(value.appointmentReminders)
        ]
        try await supabase.from(Table.settings)
            .upsert(payload, onConflict: "user_id", returning: .minimal)
            .execute()
    }
}
