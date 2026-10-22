//
//  AppointmentModel.swift
//  Synapse
//
//  Created by Mac-LAB on 9/24/26.
//

import Foundation
import FirebaseFirestore

enum AppointmentStatus: String, CaseIterable, Identifiable {
    case scheduled, completed

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Appointment: Identifiable {
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

    init?(dictionary: [String: Any]) {
        guard let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString),
              let start = (dictionary["startDate"] as? Timestamp)?.dateValue() else { return nil }
        id = uuid
        title = dictionary["title"] as? String ?? ""
        doctor = dictionary["doctor"] as? String ?? ""
        location = dictionary["location"] as? String ?? ""
        startDate = start
        endDate = (dictionary["endDate"] as? Timestamp)?.dateValue() ?? start.addingTimeInterval(3600)
        notes = dictionary["notes"] as? String ?? ""
        status = AppointmentStatus(rawValue: dictionary["status"] as? String ?? "") ?? .scheduled
    }

    var dictionary: [String: Any] {
        [
            "id": id.uuidString,
            "title": title,
            "doctor": doctor,
            "location": location,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "notes": notes,
            "status": status.rawValue
        ]
    }
}
