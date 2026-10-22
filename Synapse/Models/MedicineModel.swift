//
//  MedicineModel.swift
//  Synapse
//

import Foundation
import FirebaseFirestore

struct MedicineInformation: Identifiable {
    var id = UUID()
    var medication: String = ""
    var amount: String = ""            // dosage
    var frequency: Int = 1             // times per day (1...4)
    /// Minutes after midnight for each dose. Empty means "distribute automatically".
    var intakeMinutes: [Int] = []
    var startDate: Date = Calendar.current.startOfDay(for: .now)
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: .now)) ?? .now
    var instructions: String = ""
    var active: Bool = true

    static let allowedFrequencies = 1...4

    /// Evenly spreads doses between 8:00 and 20:00 (1x = 8:00, 2x = 8:00/20:00, 3x = 8:00/14:00/20:00, 4x = every 4 hours).
    static func defaultIntakeMinutes(for frequency: Int) -> [Int] {
        let first = 8 * 60
        let last = 20 * 60
        guard frequency > 1 else { return [first] }
        let step = (last - first) / (frequency - 1)
        return (0..<frequency).map { first + $0 * step }
    }

    var usesCustomTimes: Bool { intakeMinutes.count == frequency }

    var effectiveIntakeMinutes: [Int] {
        usesCustomTimes ? intakeMinutes.sorted() : Self.defaultIntakeMinutes(for: frequency)
    }

    /// First moment after the last day of the course.
    var endBoundary: Date {
        let lastDay = Calendar.current.startOfDay(for: endDate)
        return Calendar.current.date(byAdding: .day, value: 1, to: lastDay) ?? endDate
    }

    var isExpired: Bool { endBoundary <= Date() }

    var frequencyText: String {
        frequency == 1 ? "Once daily" : "\(frequency) times daily"
    }

    var timesText: String {
        effectiveIntakeMinutes
            .map { Date.minutesToDate($0).formatted(date: .omitted, time: .shortened) }
            .joined(separator: ", ")
    }

    init() {}

    init?(dictionary: [String: Any]) {
        guard let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString) else { return nil }
        id = uuid
        medication = dictionary["medication"] as? String ?? ""
        amount = dictionary["amount"] as? String ?? ""
        frequency = min(max(dictionary["frequency"] as? Int ?? 1, 1), 4)
        intakeMinutes = dictionary["intakeMinutes"] as? [Int] ?? []
        startDate = (dictionary["startDate"] as? Timestamp)?.dateValue() ?? .now
        endDate = (dictionary["endDate"] as? Timestamp)?.dateValue() ?? .now
        instructions = dictionary["instructions"] as? String ?? dictionary["notes"] as? String ?? ""
        active = dictionary["active"] as? Bool ?? true
    }

    var dictionary: [String: Any] {
        [
            "id": id.uuidString,
            "medication": medication,
            "amount": amount,
            "frequency": frequency,
            "intakeMinutes": intakeMinutes,
            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),
            "instructions": instructions,
            "active": active
        ]
    }
}
