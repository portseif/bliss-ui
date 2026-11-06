//
//  DateFormatting.swift
//  BlissUI
//
//  Shared date / time / size display formatting used across views, models,
//  and services.
//

import Foundation

/// Namespace for common date, time, and byte-count display formatting.
/// Formatters are created per call — `DateFormatter` isn't thread-safe and
/// some callers run off the main actor.
public enum DateFormatting {

    // MARK: - Day Label

    /// Day-bucket label for timeline grouping: "Today", "Yesterday", or "MMM d".
    public static func formatDayLabel(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let formatter = DateFormatter()
        // A template, not a fixed format, so the month/day order follows the locale.
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: date)
    }

    // MARK: - Elapsed Time

    /// Elapsed time as "m:ss" (e.g. "1:23").
    public static func formatElapsedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Timestamp

    /// The current date/time rendered with the given format. The compact
    /// default is the form used in backup filenames.
    public static func currentTimestamp(format: String = "yyyyMMdd_HHmmss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: Date())
    }

    // MARK: - Clock Time

    /// "02:00" → "2:00 AM". Returns the input unchanged when it isn't "HH:mm".
    public static func formatClock(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return hhmm }
        return formatClock(hour: hour, minute: minute)
    }

    /// (hour: 2, minute: 0) → "2:00 AM".
    public static func formatClock(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        let formatter = DateFormatter()
        // "j" = the locale's hour cycle, so 24-hour locales don't get AM/PM.
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }

    // MARK: - Byte Count

    /// Byte count for display (e.g. "45.2 MB").
    public static func formatByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Compact Relative Time

    /// Tight single-unit age for timeline metadata: "now", "5m", "2h", "9d",
    /// "3w", then "MMM d" beyond a month. `withSuffix` appends " ago" to the
    /// unit forms (e.g. "3d ago") for rows where the bare unit reads ambiguous.
    /// A future moment as a whole phrase: "in 3h", "in 9d" (certificate expiry).
    /// `formatRelativeCompact` only measures the past, so a future date read "now".
    public static func formatTimeUntil(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        switch interval {
        case ..<60: return String(localized: "now")
        case ..<3600: return String(localized: "in \(Int(interval / 60))m")
        case ..<86_400: return String(localized: "in \(Int(interval / 3600))h")
        default: return String(localized: "in \(Int(interval / 86_400))d")
        }
    }

    public static func formatRelativeCompact(_ date: Date, withSuffix: Bool = false) -> String {
        let interval = Date().timeIntervalSince(date)
        // Whole phrases per unit (not a spliced " ago"): word order differs by language.
        switch interval {
        case ..<60: return String(localized: "now")
        case ..<3600:
            let minutes = Int(interval / 60)
            return withSuffix ? String(localized: "\(minutes)m ago") : String(localized: "\(minutes)m")
        case ..<86_400:
            let hours = Int(interval / 3600)
            return withSuffix ? String(localized: "\(hours)h ago") : String(localized: "\(hours)h")
        case ..<604_800:
            let days = Int(interval / 86_400)
            return withSuffix ? String(localized: "\(days)d ago") : String(localized: "\(days)d")
        case ..<2_592_000:
            let weeks = Int(interval / 604_800)
            return withSuffix ? String(localized: "\(weeks)w ago") : String(localized: "\(weeks)w")
        default:
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("MMMd")
            return formatter.string(from: date)
        }
    }
}
