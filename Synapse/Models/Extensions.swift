//
//  Extensions.swift
//  Synapse
//
//  Small shared helpers used by models, controllers and views.
//  Marked `nonisolated` because the project defaults to MainActor isolation and the
//  Supabase models (decoded off the main actor) use them too.
//

import Foundation

extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Basic shape check for an email address ("name@domain.tld").
    nonisolated var isValidEmail: Bool {
        let value = trimmed
        guard value.count <= 254 else { return false }
        return value.range(of: #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil
    }
}

extension Date {
    /// Builds a date on `day` at the given minutes-after-midnight.
    nonisolated static func minutesToDate(_ minutes: Int, on day: Date = .now) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    nonisolated var minutesSinceMidnight: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Password rules shared by account creation, password reset and "Change Password".
nonisolated enum PasswordRules {
    /// Returns a human readable message listing what is missing, or nil if the password is valid.
    static func validate(_ text: String) -> String? {
        var missing: [String] = []
        if text.count < 8 { missing.append("at least 8 characters") }
        if !text.contains(where: { $0.isUppercase }) { missing.append("an uppercase letter") }
        if !text.contains(where: { $0.isLowercase }) { missing.append("a lowercase letter") }
        if text.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil { missing.append("a special character") }
        return missing.isEmpty ? nil : "Password needs: " + missing.joined(separator: ", ") + "."
    }
}
