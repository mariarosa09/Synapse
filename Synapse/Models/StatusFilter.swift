//
//  StatusFilter.swift
//  Synapse
//

import Foundation

/// All / Active / Inactive filter used by Basic Information and Medicines.
enum StatusFilter: String, CaseIterable, Identifiable {
    case all, active, inactive

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func includes(active isActive: Bool) -> Bool {
        switch self {
        case .all: return true
        case .active: return isActive
        case .inactive: return !isActive
        }
    }
}
