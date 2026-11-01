//
//  UserProfile.swift
//  Synapse
//
//  The signed-in user's row in public.profiles (id = auth.users.id).
//  The profile picture lives in the private `avatars` bucket at `avatarPath`.
//

import Foundation

nonisolated struct UserProfile: Codable, Sendable, Equatable {
    var id: UUID
    var firstname = ""
    var middleInitial = ""
    var surname = ""
    var email = ""
    /// Storage path inside the `avatars` bucket, e.g. "<user id>/avatar-<uuid>.jpg". nil = default picture.
    var avatarPath: String?
    var sex: String?
    var bloodGroup: String?
    var birthdate: Date?
    var onboardingComplete = false
    var deleted = false
    var deletedAt: Date?

    init(id: UUID, email: String = "") {
        self.id = id
        self.email = email
    }

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

    // MARK: - Supabase coding

    enum CodingKeys: String, CodingKey {
        case id, firstname, surname, email, sex, deleted, birthdate
        case middleInitial = "middle_initial"
        case avatarPath = "avatar_path"
        case bloodGroup = "blood_group"
        case onboardingComplete = "onboarding_complete"
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        firstname = try c.decodeIfPresent(String.self, forKey: .firstname) ?? ""
        middleInitial = try c.decodeIfPresent(String.self, forKey: .middleInitial) ?? ""
        surname = try c.decodeIfPresent(String.self, forKey: .surname) ?? ""
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        let path = try c.decodeIfPresent(String.self, forKey: .avatarPath)
        avatarPath = (path?.isEmpty ?? true) ? nil : path
        sex = try c.decodeIfPresent(String.self, forKey: .sex)
        bloodGroup = try c.decodeIfPresent(String.self, forKey: .bloodGroup)
        birthdate = DBDate.day(from: try c.decodeIfPresent(String.self, forKey: .birthdate))
        onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        deletedAt = DBDate.timestamp(from: try c.decodeIfPresent(String.self, forKey: .deletedAt))
    }

    /// Only the fields a client creates the row with. Email is overwritten by a database trigger
    /// with the authenticated email; photo, onboarding and deletion fields are changed with targeted updates.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(firstname, forKey: .firstname)
        try c.encode(middleInitial, forKey: .middleInitial)
        try c.encode(surname, forKey: .surname)
        try c.encode(email, forKey: .email)
    }
}
