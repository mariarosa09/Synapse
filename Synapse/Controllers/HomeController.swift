//
//  HomeController.swift
//  Synapse
//
//  Logic behind the Home screen: the profile summary card and "Schedule For Today".
//  Appointment data itself is owned by the session's AppointmentController (shared with the calendar).
//

import SwiftUI

@MainActor
@Observable
final class HomeController {

    // MARK: - Profile summary

    func displayName(for profile: UserProfile?) -> String {
        let name = profile?.fullName ?? ""
        return name.isEmpty ? "Welcome!" : name
    }

    func ageText(for profile: UserProfile?) -> String {
        guard let age = profile?.age else { return "Age not set" }
        return age == 1 ? "1 year old" : "\(age) years old"
    }

    func bloodTypeText(for profile: UserProfile?) -> String {
        guard let blood = profile?.bloodGroup, !blood.isEmpty else { return "Blood type not set" }
        return "\(blood) type"
    }

    // MARK: - Today's schedule

    /// Today's appointments (scheduled and completed), earliest first. Cancelled ones are hidden.
    func todaysAppointments(from appointments: AppointmentController, now: Date = .now) -> [Appointment] {
        appointments.appointments(on: now).filter { $0.status != .cancelled }
    }

    func isLoading(_ appointments: AppointmentController) -> Bool {
        appointments.isLoading && appointments.appointments.isEmpty
    }

    /// Ticking an appointment marks it completed (its reminder is cancelled); unticking schedules it again.
    func toggleCompleted(_ appointment: Appointment, in appointments: AppointmentController) {
        appointments.setStatus(appointment, completed: !appointment.isChecked)
    }
}
