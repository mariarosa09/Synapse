//
//  Sex.swift
//  Synapse
//
//  Option for the onboarding ("Tell Us About You") screen. Stored in profiles.sex.
//

import Foundation

// Identity is the name so selections survive view re-creation.
nonisolated struct Sex: Identifiable, Hashable, Sendable {
    let name: String
    var id: String { name }

    static let all = [Sex(name: "Female"), Sex(name: "Male")]
}
