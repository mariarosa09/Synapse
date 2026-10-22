//
//  BasicInformationModel.swift
//  Synapse
//
//  Created by Mac-LAB on 9/17/26.
//

import Foundation

// Identity is the name so selections survive view re-creation.
struct Sex: Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct Blood: Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct PersonalInfo: Identifiable {
    var id = UUID()
    var sex: Sex
    var blood: Blood
    var birthdate: Date
}
