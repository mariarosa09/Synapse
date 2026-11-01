//
//  Appointment.swift
//  Synapse
//
//  A row in public.appointments.
//

import Foundation

nonisolated enum AppointmentStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case scheduled, completed, cancelled

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

nonisolated struct Appointment: Identifiable, Codable, Sendable, Equatable {
    var id = UUID()
    var title: String = ""
    var doctor: String = ""
    var location: String = ""
    var startDate: Date
    var endDate: Date
    var notes: String = ""
    var status: AppointmentStatus = .scheduled

    /// Checklist state on Home / Calendar maps to the appointment status.
    var isChecked: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .scheduled }
    }

    /// Reminders fire exactly five minutes before the start.
    static let reminderLeadTime: TimeInterval = 5 * 60
    var reminderDate: Date { startDate.addingTimeInterval(-Self.reminderLeadTime) }

    var timeRangeText: String {
        "\(startDate.formatted(date: .omitted, time: .shortened)) – \(endDate.formatted(date: .omitted, time: .shortened))"
    }

    init(id: UUID = UUID(), title: String = "", doctor: String = "", location: String = "",
         startDate: Date, endDate: Date, notes: String = "", status: AppointmentStatus = .scheduled) {
        self.id = id
        self.title = title
        self.doctor = doctor
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.status = status
    }

    /// A blank appointment, pre-filled with a sensible start time on the selected calendar day.
    static func newDraft(on day: Date = .now) -> Appointment {
        let calendar = Calendar.current
        let nextHour = calendar.nextDate(after: .now, matching: DateComponents(minute: 0, second: 0),
                                         matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        var start = nextHour
        if day > Date(), !calendar.isDateInToday(day) {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        }
        return Appointment(startDate: start, endDate: start.addingTimeInterval(3600))
    }

    // MARK: - Supabase coding (user_id is filled by the database default auth.uid())

    enum CodingKeys: String, CodingKey {
        case id, title, doctor, location, notes, status
        case startDate = "start_at"
        case endDate = "end_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        doctor = try c.decodeIfPresent(String.self, forKey: .doctor) ?? ""
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        let start = DBDate.timestamp(from: try c.decodeIfPresent(String.self, forKey: .startDate)) ?? .now
        startDate = start
        endDate = DBDate.timestamp(from: try c.decodeIfPresent(String.self, forKey: .endDate)) ?? start.addingTimeInterval(3600)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        status = AppointmentStatus(rawValue: try c.decodeIfPresent(String.self, forKey: .status) ?? "") ?? .scheduled
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(doctor, forKey: .doctor)
        try c.encode(location, forKey: .location)
        try c.encode(DBDate.timestampString(startDate), forKey: .startDate)
        try c.encode(DBDate.timestampString(endDate), forKey: .endDate)
        try c.encode(notes, forKey: .notes)
        try c.encode(status.rawValue, forKey: .status)
    }
}
