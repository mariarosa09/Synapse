//
//  MedicineInformation.swift
//  Synapse
//
//  A row in public.medicines.
//

import Foundation

nonisolated struct MedicineInformation: Identifiable, Codable, Sendable, Equatable {
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
        switch frequency {
        case 1: return "Once daily"
        case 2: return "Twice daily"
        case 3: return "Three times daily"
        default: return "\(frequency) times daily"
        }
    }

    var timesText: String {
        effectiveIntakeMinutes
            .map { Date.minutesToDate($0).formatted(date: .omitted, time: .shortened) }
            .joined(separator: ", ")
    }

    func matches(search query: String) -> Bool {
        let q = query.trimmed
        guard !q.isEmpty else { return true }
        return [medication, amount, instructions, frequencyText].contains { $0.localizedCaseInsensitiveContains(q) }
    }

    init() {}

    // MARK: - Supabase coding

    enum CodingKeys: String, CodingKey {
        case id, medication, amount, frequency, instructions, active
        case intakeMinutes = "intake_minutes"
        case startDate = "start_date"
        case endDate = "end_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        medication = try c.decodeIfPresent(String.self, forKey: .medication) ?? ""
        amount = try c.decodeIfPresent(String.self, forKey: .amount) ?? ""
        frequency = min(max(try c.decodeIfPresent(Int.self, forKey: .frequency) ?? 1, 1), 4)
        intakeMinutes = try c.decodeIfPresent([Int].self, forKey: .intakeMinutes) ?? []
        startDate = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .startDate)) ?? Calendar.current.startOfDay(for: .now)
        endDate = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .endDate)) ?? startDate
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(medication, forKey: .medication)
        try c.encode(amount, forKey: .amount)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(intakeMinutes, forKey: .intakeMinutes)
        try c.encode(DBDate.dayString(startDate), forKey: .startDate)
        try c.encode(DBDate.dayString(endDate), forKey: .endDate)
        try c.encode(instructions, forKey: .instructions)
        try c.encode(active, forKey: .active)
    }
}
