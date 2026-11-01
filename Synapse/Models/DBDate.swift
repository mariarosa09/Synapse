//
//  DBDate.swift
//  Synapse
//
//  Converts between Swift dates and the strings PostgreSQL (PostgREST) sends and accepts.
//  - `date` columns ("2026-10-30") are calendar days: they are read and written in the
//    device's time zone so a birthdate or start date never shifts by a day.
//  - `timestamptz` columns are exact moments, written as ISO-8601 in UTC.
//

import Foundation

nonisolated enum DBDate {

    // MARK: - date columns

    /// "yyyy-MM-dd" (or the date part of a timestamp) -> local midnight of that day.
    static func day(from string: String?) -> Date? {
        guard let string, string.count >= 10 else { return nil }
        let parts = string.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Local calendar day -> "yyyy-MM-dd".
    static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    // MARK: - timestamptz columns

    /// Parses PostgREST timestamps such as "2026-10-30T02:00:00+00:00" or
    /// "2026-10-30T02:00:00.123456+00:00" (microseconds are trimmed to milliseconds first).
    static func timestamp(from string: String?) -> Date? {
        guard var value = string?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let tIndex = value.firstIndex(of: " "), value[value.startIndex..<tIndex].count == 10 {
            value.replaceSubrange(tIndex...tIndex, with: "T")
        }
        value = trimFraction(value)

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: value) { return date }

        return day(from: value)
    }

    /// Exact moment -> "2026-10-30T02:00:00.000Z".
    static func timestampString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    /// Keeps at most three fractional digits, which ISO8601DateFormatter always understands.
    private static func trimFraction(_ value: String) -> String {
        guard let dot = value.firstIndex(of: ".") else { return value }
        var end = value.index(after: dot)
        while end < value.endIndex, value[end].isNumber { end = value.index(after: end) }
        let digits = value[value.index(after: dot)..<end]
        guard digits.count > 3 else { return value }
        let kept = digits.prefix(3)
        return String(value[..<dot]) + "." + String(kept) + String(value[end...])
    }
}
