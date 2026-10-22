//
//  UserProfile.swift
//  Synapse
//
//  The signed-in user's document at users/{uid}.
//

import Foundation
import FirebaseFirestore

struct UserProfile {
    var uid: String
    var firstname = ""
    var middleInitial = ""
    var surname = ""
    var email = ""
    var photoURL: String?
    var sex: String?
    var bloodGroup: String?
    var birthdate: Date?
    var onboardingComplete = false
    var deleted = false
    var deletedAt: Date?

    var fullName: String {
        var parts: [String] = [firstname]
        let initial = middleInitial.trimmed
        if !initial.isEmpty { parts.append(initial.hasSuffix(".") ? initial : initial + ".") }
        parts.append(surname)
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    var age: Int? {
        guard let birthdate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthdate, to: Date()).year
    }

    init(uid: String, dictionary: [String: Any]) {
        self.uid = uid
        firstname = dictionary["firstname"] as? String ?? ""
        middleInitial = dictionary["middleInitial"] as? String ?? ""
        surname = dictionary["surname"] as? String ?? ""
        email = dictionary["email"] as? String ?? ""
        photoURL = dictionary["photoURL"] as? String
        sex = dictionary["sex"] as? String
        bloodGroup = dictionary["bloodGroup"] as? String
        birthdate = (dictionary["birthdate"] as? Timestamp)?.dateValue()
        onboardingComplete = dictionary["onboardingComplete"] as? Bool ?? false
        deleted = dictionary["deleted"] as? Bool ?? false
        deletedAt = (dictionary["deletedAt"] as? Timestamp)?.dateValue()
    }
}
