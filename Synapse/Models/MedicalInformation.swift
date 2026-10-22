//
//  MedicalIformation.swift
//  Synapse
//
//  Created by Mac-LAB on 9/10/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Basic Information (allergies & medical conditions)

enum BasicInfoKind: String, CaseIterable, Identifiable {
    case allergy, condition

    var id: String { rawValue }
    var title: String { self == .allergy ? "Allergy" : "Medical Condition" }
}

struct BasicInformationModel: Identifiable {
    var id: UUID = UUID()
    var kind: BasicInfoKind = .allergy
    var title: String = ""
    var startDate: Date = .now
    var endDate: Date? = nil
    var active: Bool = true
    var notes: String = ""

    init(id: UUID = UUID(), kind: BasicInfoKind = .allergy, title: String = "", startDate: Date = .now,
         endDate: Date? = nil, active: Bool = true, notes: String = "") {
        self.id = id
        self.kind = kind
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.active = active
        self.notes = notes
    }

    init?(dictionary: [String: Any]) {
        guard let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString) else { return nil }
        self.id = uuid
        self.kind = BasicInfoKind(rawValue: dictionary["kind"] as? String ?? "") ?? .allergy
        self.title = dictionary["title"] as? String ?? ""
        self.startDate = (dictionary["startDate"] as? Timestamp)?.dateValue() ?? .now
        self.endDate = (dictionary["endDate"] as? Timestamp)?.dateValue()
        self.active = dictionary["active"] as? Bool ?? true
        self.notes = dictionary["notes"] as? String ?? ""
    }

    var dictionary: [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "kind": kind.rawValue,
            "title": title,
            "startDate": Timestamp(date: startDate),
            "active": active,
            "notes": notes
        ]
        if let endDate { data["endDate"] = Timestamp(date: endDate) }
        return data
    }
}

// MARK: - Medical records

struct MedicalInformation: Identifiable {
    let id: UUID
    var title: String = ""
    var date: Date = .now
    var file: [String] = []
    var notes: String = "Notes"
    
    init(id: UUID = UUID(), title: String = "", date: Date = .now, file: [String] = [], notes: String = "Notes") {
        self.id = id
        self.title = title
        self.date = date
        self.file = file
        self.notes = notes
    }
    
    init?(dictionary: [String: Any]) {
        if let idString = dictionary["id"] as? String, let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.title = dictionary["title"] as? String ?? ""
        
        if let timestamp = dictionary["date"] as? Timestamp {
            self.date = timestamp.dateValue()
        } else {
            self.date = .now
        }
        
        self.file = dictionary["file"] as? [String] ?? []
        self.notes = dictionary["notes"] as? String ?? "Notes"
    }
    
    var dictionary: [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "date": Timestamp(date: date),
            "file": file,
            "notes": notes
        ]
    }
}
