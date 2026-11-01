//
//  BasicInformationModel.swift
//  Synapse
//
//  A row in public.basic_information: an allergy or a medical condition with an
//  active / inactive status.
//

import Foundation

nonisolated enum BasicInfoKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case allergy, condition

    var id: String { rawValue }
    var title: String { self == .allergy ? "Allergy" : "Medical Condition" }
}

nonisolated struct BasicInformationModel: Identifiable, Codable, Sendable, Equatable {
    var id: UUID = UUID()
    var kind: BasicInfoKind = .allergy
    var title: String = ""
    var startDate: Date = Calendar.current.startOfDay(for: .now)
    /// Set when the entry becomes inactive.
    var endDate: Date? = nil
    var active: Bool = true
    var notes: String = ""

    init(id: UUID = UUID(), kind: BasicInfoKind = .allergy, title: String = "",
         startDate: Date = Calendar.current.startOfDay(for: .now),
         endDate: Date? = nil, active: Bool = true, notes: String = "") {
        self.id = id
        self.kind = kind
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.active = active
        self.notes = notes
    }

    func matches(search query: String) -> Bool {
        let q = query.trimmed
        guard !q.isEmpty else { return true }
        return [title, notes, kind.title].contains { $0.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Supabase coding (user_id is filled by the database default auth.uid())

    enum CodingKeys: String, CodingKey {
        case id, kind, title, active, notes
        case startDate = "start_date"
        case endDate = "end_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = BasicInfoKind(rawValue: try c.decodeIfPresent(String.self, forKey: .kind) ?? "") ?? .allergy
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        startDate = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .startDate)) ?? Calendar.current.startOfDay(for: .now)
        endDate = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .endDate))
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(title, forKey: .title)
        try c.encode(DBDate.dayString(startDate), forKey: .startDate)
        // Encoded as JSON null when nil so reactivating an entry clears its end date.
        try c.encode(endDate.map { DBDate.dayString($0) }, forKey: .endDate)
        try c.encode(active, forKey: .active)
        try c.encode(notes, forKey: .notes)
    }
}
