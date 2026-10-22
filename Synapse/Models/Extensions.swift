//
//  Extensions.swift
//  Synapse
//
//  Small shared helpers used by models, controllers and views.
//

import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Date {
    /// Builds a date on `day` at the given minutes-after-midnight.
    static func minutesToDate(_ minutes: Int, on day: Date = .now) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    var minutesSinceMidnight: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Password rules shared by account creation and "Change Password".
enum PasswordRules {
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
