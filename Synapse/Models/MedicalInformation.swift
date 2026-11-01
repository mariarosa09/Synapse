//
//  MedicalInformation.swift
//  Synapse
//
//  A medical record: a row in public.medical_records plus its attachments
//  (embedded from public.medical_record_attachments when fetched).
//

import Foundation

nonisolated struct MedicalInformation: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String = ""
    var date: Date = Calendar.current.startOfDay(for: .now)
    /// Free-text category, e.g. "Lab result", "Prescription", "Imaging".
    var category: String = ""
    var notes: String = ""
    /// Read-only here: attachments are written through AttachmentController.
    var attachments: [MedicalAttachment] = []

    init(id: UUID = UUID(), title: String = "", date: Date = Calendar.current.startOfDay(for: .now),
         category: String = "", notes: String = "", attachments: [MedicalAttachment] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.category = category
        self.notes = notes
        self.attachments = attachments
    }

    /// Matches the title, category, notes, date or any attachment's file name.
    func matches(search query: String) -> Bool {
        let q = query.trimmed
        guard !q.isEmpty else { return true }
        let fields = [title, category, notes,
                      date.formatted(date: .abbreviated, time: .omitted),
                      date.formatted(date: .long, time: .omitted)] + attachments.map(\.fileName)
        return fields.contains { $0.localizedCaseInsensitiveContains(q) }
    }

    // MARK: - Supabase coding

    enum CodingKeys: String, CodingKey {
        case id, title, category, notes
        case date = "record_date"
        case attachments = "medical_record_attachments"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .date)) ?? Calendar.current.startOfDay(for: .now)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        let files = try c.decodeIfPresent([MedicalAttachment].self, forKey: .attachments) ?? []
        attachments = files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    /// Attachments are never sent with the record row; user_id comes from the database default.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(DBDate.dayString(date), forKey: .date)
        try c.encode(category, forKey: .category)
        try c.encode(notes, forKey: .notes)
    }
}
