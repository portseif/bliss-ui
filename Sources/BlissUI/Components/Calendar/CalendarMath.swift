//
//  CalendarMath.swift
//  BlissUI
//
//  The day math every calendar view shares: the six-week month grid, the
//  weekday header in the locale's order, keyboard steps, min/max bounds and
//  range ordering. Pure and `nonisolated`, so it's tested across locales and
//  first weekdays without a view.
//
//  Every "day" here is the START of that day in the calendar's time zone —
//  compare days with `==` only after `startOfDay`, never raw `Date`s.
//

import Foundation

// MARK: - Grid Math

nonisolated enum CalendarGridMath {
    static let daysPerWeek = 7
    /// Six weeks always: every month fits, and the grid's height never jumps
    /// as you page through months.
    static let weeksShown = 6

    /// Weekday initials ("S M T W T F S") in display order, starting from the
    /// calendar's first weekday (the user's Language & Region setting).
    static func weekdaySymbols(_ calendar: Calendar) -> [String] {
        rotatedToFirstWeekday(calendar.veryShortStandaloneWeekdaySymbols, calendar)
    }

    /// Full weekday names in display order, for VoiceOver and tests.
    static func fullWeekdaySymbols(_ calendar: Calendar) -> [String] {
        rotatedToFirstWeekday(calendar.standaloneWeekdaySymbols, calendar)
    }

    private static func rotatedToFirstWeekday(_ symbols: [String], _ calendar: Calendar) -> [String] {
        let first = calendar.firstWeekday - 1
        guard symbols.indices.contains(first) else { return symbols }
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The first day of the month containing `date`.
    static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Where `day` sits in its week row, 0 = the calendar's first weekday.
    static func columnIndex(of day: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: day)
        return ((weekday - calendar.firstWeekday) % daysPerWeek + daysPerWeek) % daysPerWeek
    }

    /// How many days of the previous month lead the grid of `date`'s month.
    static func leadingDayCount(forMonthContaining date: Date, calendar: Calendar) -> Int {
        columnIndex(of: startOfMonth(date, calendar: calendar), calendar: calendar)
    }

    /// The 42 days (six weeks) shown for the month containing `date`: the
    /// month plus the previous month's tail and the next month's head.
    static func gridDays(forMonthContaining date: Date, calendar: Calendar) -> [Date] {
        let firstOfMonth = startOfMonth(date, calendar: calendar)
        let leading = columnIndex(of: firstOfMonth, calendar: calendar)
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) else { return [] }
        // Re-normalized per day: a DST change inside the grid shifts the hour.
        return (0..<(daysPerWeek * weeksShown)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart).map(calendar.startOfDay(for:))
        }
    }

    /// `day` (any time on it) at the time of day `source` carries, so picking a
    /// new day keeps the time already chosen. No source: the start of the day.
    static func day(_ day: Date, keepingTimeOf source: Date?, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        guard let source else { return start }
        let time = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: start
        ) ?? start
    }

    /// The days from the earlier of `first` and `second` to the later, so a
    /// range can be picked end-first.
    static func orderedRange(_ first: Date, _ second: Date, calendar: Calendar) -> ClosedRange<Date> {
        let a = calendar.startOfDay(for: first)
        let b = calendar.startOfDay(for: second)
        return min(a, b)...max(a, b)
    }

    /// A range of whole days: both bounds at the start of their day.
    static func normalized(_ range: ClosedRange<Date>, calendar: Calendar) -> ClosedRange<Date> {
        orderedRange(range.lowerBound, range.upperBound, calendar: calendar)
    }
}

// MARK: - Keyboard Steps

/// One keyboard move of a calendar's focused day.
nonisolated enum CalendarStep: Equatable {
    /// ← / → (mirrored in right-to-left layouts).
    case days(Int)
    /// ↑ / ↓.
    case weeks(Int)
    /// Page Up / Page Down. Jan 31 + 1 month lands on the last day of February.
    case months(Int)
    /// ⇧ Page Up / ⇧ Page Down.
    case years(Int)
    /// Home.
    case startOfWeek
    /// End.
    case endOfWeek

    /// The day this step lands on from `day`.
    func apply(to day: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        let moved: Date?
        switch self {
        case .days(let count):
            moved = calendar.date(byAdding: .day, value: count, to: start)
        case .weeks(let count):
            moved = calendar.date(byAdding: .day, value: count * CalendarGridMath.daysPerWeek, to: start)
        case .months(let count):
            moved = calendar.date(byAdding: .month, value: count, to: start)
        case .years(let count):
            moved = calendar.date(byAdding: .year, value: count, to: start)
        case .startOfWeek:
            moved = calendar.date(byAdding: .day, value: -CalendarGridMath.columnIndex(of: start, calendar: calendar), to: start)
        case .endOfWeek:
            let index = CalendarGridMath.columnIndex(of: start, calendar: calendar)
            moved = calendar.date(byAdding: .day, value: CalendarGridMath.daysPerWeek - 1 - index, to: start)
        }
        return calendar.startOfDay(for: moved ?? start)
    }
}

// MARK: - Bounds

/// The days a calendar lets you pick, from `minimum` through `maximum` (whole
/// days, both included). Either end may be open.
nonisolated struct CalendarBounds: Equatable {
    let minimum: Date?
    let maximum: Date?

    static let unbounded = CalendarBounds(minimum: nil, maximum: nil)

    private init(minimum: Date?, maximum: Date?) {
        self.minimum = minimum
        self.maximum = maximum
    }

    /// Normalizes both ends to their day; a maximum before the minimum is
    /// raised to it, so there's always at least one day to pick.
    init(minimum: Date?, maximum: Date?, calendar: Calendar) {
        let lower = minimum.map(calendar.startOfDay(for:))
        var upper = maximum.map(calendar.startOfDay(for:))
        if let lower, let current = upper, current < lower { upper = lower }
        self.init(minimum: lower, maximum: upper)
    }

    /// Whether `day` (a start of day) can be picked.
    func contains(_ day: Date) -> Bool {
        if let minimum, day < minimum { return false }
        if let maximum, day > maximum { return false }
        return true
    }

    /// `day` moved to the nearest day that can be picked.
    func clamp(_ day: Date) -> Date {
        if let minimum, day < minimum { return minimum }
        if let maximum, day > maximum { return maximum }
        return day
    }

    /// The part of `range` that can be picked, or nil when none of it can —
    /// how a preset like "Last 30 days" behaves next to a minimum date.
    func clamp(_ range: ClosedRange<Date>) -> ClosedRange<Date>? {
        let lower = minimum.map { max($0, range.lowerBound) } ?? range.lowerBound
        let upper = maximum.map { min($0, range.upperBound) } ?? range.upperBound
        return lower <= upper ? lower...upper : nil
    }

    /// Whether any day of the month starting at `firstOfMonth` can be picked —
    /// the month arrows stop at a month with none.
    func containsAnyDay(inMonthStartingAt firstOfMonth: Date, calendar: Calendar) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: firstOfMonth) else { return true }
        // The interval's end is the next month's first instant.
        let lastDay = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))
        if let minimum, lastDay < minimum { return false }
        if let maximum, interval.start > maximum { return false }
        return true
    }
}
