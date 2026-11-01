//
//  Blood.swift
//  Synapse
//
//  Blood group option for the onboarding ("Tell Us About You") screen. Stored in profiles.blood_group.
//

import Foundation

// Identity is the name so selections survive view re-creation.
nonisolated struct Blood: Identifiable, Hashable, Sendable {
    let name: String
    var id: String { name }

    static let all = ["A+", "B+", "AB+", "O+", "A-", "B-", "AB-", "O-"].map { Blood(name: $0) }
}
