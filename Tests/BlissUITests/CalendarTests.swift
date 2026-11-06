import Foundation
import Testing
@testable import BlissUI

/// The calendar's day math: the month grid across locales and first weekdays,
/// keyboard steps, min/max bounds, range ordering, presets and the time field.
@Suite struct CalendarTests {
    // MARK: Fixtures

    nonisolated private static func calendar(
        locale: String = "en_US",
        firstWeekday: Int? = nil,
        timeZone: String = "UTC"
    ) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: locale)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        if let firstWeekday { calendar.firstWeekday = firstWeekday }
        return calendar
    }

    nonisolated private static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Weekday header

    @Test func weekdayHeaderStartsOnTheFirstWeekday() {
        let sunday = Self.calendar(locale: "en_US", firstWeekday: 1)
        #expect(CalendarGridMath.weekdaySymbols(sunday) == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(CalendarGridMath.fullWeekdaySymbols(sunday).first == "Sunday")

        let monday = Self.calendar(locale: "de_DE", firstWeekday: 2)
        #expect(CalendarGridMath.fullWeekdaySymbols(monday).first == "Montag")
        #expect(CalendarGridMath.fullWeekdaySymbols(monday).last == "Sonntag")

        let saturday = Self.calendar(locale: "en_US", firstWeekday: 7)
        #expect(CalendarGridMath.fullWeekdaySymbols(saturday) == ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"])
    }

    @Test func weekdayHeaderUsesTheLocalesNames() {
        let french = Self.calendar(locale: "fr_FR", firstWeekday: 2)
        #expect(CalendarGridMath.fullWeekdaySymbols(french).first == "lundi")
        let japanese = Self.calendar(locale: "ja_JP", firstWeekday: 1)
        #expect(CalendarGridMath.weekdaySymbols(japanese).first == "日")
    }

    // MARK: Month grid

    /// February 2026 starts on a Sunday and has 28 days.
    @Test(arguments: [(1, 0), (2, 6), (7, 1)])
    func gridLeadsWithThePreviousMonth(firstWeekday: Int, leading: Int) {
        let calendar = Self.calendar(firstWeekday: firstWeekday)
        let february = Self.day(2026, 2, 14, in: calendar)
        #expect(CalendarGridMath.leadingDayCount(forMonthContaining: february, calendar: calendar) == leading)

        let days = CalendarGridMath.gridDays(forMonthContaining: february, calendar: calendar)
        #expect(days.count == 42)
        #expect(days[leading] == Self.day(2026, 2, 1, in: calendar))
        #expect(calendar.component(.weekday, from: days[0]) == firstWeekday)
    }

    @Test func gridDaysAreConsecutiveStartsOfDayAcrossDST() {
        // US daylight saving starts on March 8, 2026.
        let calendar = Self.calendar(firstWeekday: 1, timeZone: "America/New_York")
        let days = CalendarGridMath.gridDays(forMonthContaining: Self.day(2026, 3, 20, in: calendar), calendar: calendar)
        #expect(days.count == 42)
        for (earlier, later) in zip(days, days.dropFirst()) {
            #expect(calendar.startOfDay(for: later) == later)
            #expect(calendar.dateComponents([.day], from: earlier, to: later).day == 1)
        }
    }

    @Test func columnIndexFollowsTheFirstWeekday() {
        let monday = Self.calendar(firstWeekday: 2)
        // March 4, 2026 is a Wednesday.
        #expect(CalendarGridMath.columnIndex(of: Self.day(2026, 3, 4, in: monday), calendar: monday) == 2)
        let sunday = Self.calendar(firstWeekday: 1)
        #expect(CalendarGridMath.columnIndex(of: Self.day(2026, 3, 4, in: sunday), calendar: sunday) == 3)
    }

    // MARK: Keyboard steps

    @Test func monthStepsClampToTheShorterMonth() {
        let calendar = Self.calendar()
        #expect(CalendarStep.months(1).apply(to: Self.day(2026, 1, 31, in: calendar), calendar: calendar) == Self.day(2026, 2, 28, in: calendar))
        #expect(CalendarStep.months(1).apply(to: Self.day(2028, 1, 31, in: calendar), calendar: calendar) == Self.day(2028, 2, 29, in: calendar))
        #expect(CalendarStep.months(-1).apply(to: Self.day(2026, 3, 31, in: calendar), calendar: calendar) == Self.day(2026, 2, 28, in: calendar))
        #expect(CalendarStep.years(1).apply(to: Self.day(2028, 2, 29, in: calendar), calendar: calendar) == Self.day(2029, 2, 28, in: calendar))
    }

    @Test func dayAndWeekStepsCrossMonths() {
        let calendar = Self.calendar()
        #expect(CalendarStep.days(1).apply(to: Self.day(2026, 2, 28, in: calendar), calendar: calendar) == Self.day(2026, 3, 1, in: calendar))
        #expect(CalendarStep.weeks(-1).apply(to: Self.day(2026, 3, 3, in: calendar), calendar: calendar) == Self.day(2026, 2, 24, in: calendar))
    }

    @Test func weekEndsFollowTheFirstWeekday() {
        let monday = Self.calendar(firstWeekday: 2)
        let wednesday = Self.day(2026, 3, 4, hour: 15, in: monday)
        #expect(CalendarStep.startOfWeek.apply(to: wednesday, calendar: monday) == Self.day(2026, 3, 2, in: monday))
        #expect(CalendarStep.endOfWeek.apply(to: wednesday, calendar: monday) == Self.day(2026, 3, 8, in: monday))

        let sunday = Self.calendar(firstWeekday: 1)
        #expect(CalendarStep.startOfWeek.apply(to: wednesday, calendar: sunday) == Self.day(2026, 3, 1, in: sunday))
        #expect(CalendarStep.endOfWeek.apply(to: wednesday, calendar: sunday) == Self.day(2026, 3, 7, in: sunday))
    }

    // MARK: Picking

    @Test func pickingADayKeepsTheTimeOfDay() {
        let calendar = Self.calendar()
        let previous = Self.day(2026, 3, 4, hour: 9, minute: 30, in: calendar)
        let picked = CalendarGridMath.day(Self.day(2026, 3, 12, in: calendar), keepingTimeOf: previous, calendar: calendar)
        #expect(picked == Self.day(2026, 3, 12, hour: 9, minute: 30, in: calendar))
        #expect(CalendarGridMath.day(Self.day(2026, 3, 12, hour: 18, in: calendar), keepingTimeOf: nil, calendar: calendar) == Self.day(2026, 3, 12, in: calendar))
    }

    @Test func rangesPickInEitherOrder() {
        let calendar = Self.calendar()
        let early = Self.day(2026, 3, 3, hour: 8, in: calendar)
        let late = Self.day(2026, 3, 9, hour: 20, in: calendar)
        let expected = Self.day(2026, 3, 3, in: calendar)...Self.day(2026, 3, 9, in: calendar)
        #expect(CalendarGridMath.orderedRange(early, late, calendar: calendar) == expected)
        #expect(CalendarGridMath.orderedRange(late, early, calendar: calendar) == expected)
        #expect(CalendarGridMath.orderedRange(early, early, calendar: calendar).lowerBound == CalendarGridMath.orderedRange(early, early, calendar: calendar).upperBound)
    }

    // MARK: Bounds

    @Test func boundsClampDaysAndRanges() {
        let calendar = Self.calendar()
        let bounds = CalendarBounds(
            minimum: Self.day(2026, 3, 10, hour: 15, in: calendar),
            maximum: Self.day(2026, 3, 20, hour: 9, in: calendar),
            calendar: calendar
        )
        #expect(bounds.minimum == Self.day(2026, 3, 10, in: calendar))
        #expect(bounds.contains(Self.day(2026, 3, 10, in: calendar)))
        #expect(bounds.contains(Self.day(2026, 3, 20, in: calendar)))
        #expect(!bounds.contains(Self.day(2026, 3, 9, in: calendar)))
        #expect(!bounds.contains(Self.day(2026, 3, 21, in: calendar)))
        #expect(bounds.clamp(Self.day(2026, 2, 1, in: calendar)) == Self.day(2026, 3, 10, in: calendar))
        #expect(bounds.clamp(Self.day(2026, 4, 1, in: calendar)) == Self.day(2026, 3, 20, in: calendar))

        let overlapping = Self.day(2026, 3, 1, in: calendar)...Self.day(2026, 3, 15, in: calendar)
        #expect(bounds.clamp(overlapping) == Self.day(2026, 3, 10, in: calendar)...Self.day(2026, 3, 15, in: calendar))
        let before = Self.day(2026, 2, 1, in: calendar)...Self.day(2026, 2, 28, in: calendar)
        #expect(bounds.clamp(before) == nil)
    }

    @Test func aMaximumBeforeTheMinimumIsRaisedToIt() {
        let calendar = Self.calendar()
        let bounds = CalendarBounds(minimum: Self.day(2026, 3, 10, in: calendar), maximum: Self.day(2026, 3, 1, in: calendar), calendar: calendar)
        #expect(bounds.maximum == bounds.minimum)
        #expect(bounds.contains(Self.day(2026, 3, 10, in: calendar)))
    }

    @Test func monthArrowsStopAtMonthsWithNoPickableDay() {
        let calendar = Self.calendar()
        let bounds = CalendarBounds(minimum: Self.day(2026, 3, 31, in: calendar), maximum: Self.day(2026, 5, 1, in: calendar), calendar: calendar)
        #expect(!bounds.containsAnyDay(inMonthStartingAt: Self.day(2026, 2, 1, in: calendar), calendar: calendar))
        #expect(bounds.containsAnyDay(inMonthStartingAt: Self.day(2026, 3, 1, in: calendar), calendar: calendar))
        #expect(bounds.containsAnyDay(inMonthStartingAt: Self.day(2026, 5, 1, in: calendar), calendar: calendar))
        #expect(!bounds.containsAnyDay(inMonthStartingAt: Self.day(2026, 6, 1, in: calendar), calendar: calendar))
        #expect(CalendarBounds.unbounded.containsAnyDay(inMonthStartingAt: Self.day(1900, 1, 1, in: calendar), calendar: calendar))
    }

    // MARK: Presets

    @MainActor
    @Test func presetsWorkFromToday() {
        let calendar = Self.calendar()
        let today = Self.day(2026, 3, 15, hour: 14, in: calendar)
        let start = Self.day(2026, 3, 15, in: calendar)

        #expect(DateRangePreset.today.range(today: today, calendar: calendar) == start...start)
        #expect(DateRangePreset.yesterday.range(today: today, calendar: calendar) == Self.day(2026, 3, 14, in: calendar)...Self.day(2026, 3, 14, in: calendar))
        #expect(DateRangePreset.lastDays(7).range(today: today, calendar: calendar) == Self.day(2026, 3, 9, in: calendar)...start)
        #expect(DateRangePreset.lastDays(30).range(today: today, calendar: calendar).lowerBound == Self.day(2026, 2, 14, in: calendar))
        #expect(DateRangePreset.thisMonth.range(today: today, calendar: calendar) == Self.day(2026, 3, 1, in: calendar)...start)
        #expect(DateRangePreset.lastMonth.range(today: today, calendar: calendar) == Self.day(2026, 2, 1, in: calendar)...Self.day(2026, 2, 28, in: calendar))
        #expect(DateRangePreset.lastDays(0).range(today: today, calendar: calendar) == start...start)
    }

    @MainActor
    @Test func presetsClampToTheBounds() {
        let calendar = Self.calendar()
        let today = Self.day(2026, 3, 15, in: calendar)
        let bounds = CalendarBounds(minimum: Self.day(2026, 3, 12, in: calendar), maximum: nil, calendar: calendar)
        #expect(bounds.clamp(DateRangePreset.lastDays(7).range(today: today, calendar: calendar)) == Self.day(2026, 3, 12, in: calendar)...today)
        #expect(bounds.clamp(DateRangePreset.lastMonth.range(today: today, calendar: calendar)) == nil)
    }

    // MARK: Formatting

    @Test func rangesFormatTheLocalesWay() {
        let calendar = Self.calendar()
        let range = Self.day(2026, 3, 3, in: calendar)...Self.day(2026, 3, 9, in: calendar)
        let english = DateRangeFormatting.string(for: range, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(english.contains("Mar"))
        #expect(english.contains("3"))
        #expect(english.contains("9"))
        #expect(english.contains("2026"))
        let german = DateRangeFormatting.string(for: range, calendar: calendar, locale: Locale(identifier: "de_DE"))
        #expect(german.contains("März"))

        let single = Self.day(2026, 3, 3, in: calendar)...Self.day(2026, 3, 3, in: calendar)
        let singleText = DateRangeFormatting.string(for: single, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(singleText.contains("3"))
        #expect(!singleText.contains("–"))
    }

    // MARK: Time field

    @Test func timeLayoutsFollowTheLocalePattern() {
        let english = TimeFieldLayout(pattern: "h:mm a")
        #expect(english.parts == [.hour, .literal(":"), .minute, .literal(" "), .period])
        #expect(english.hourCycle == .oneToTwelve)
        #expect(!english.padsHour)

        let german = TimeFieldLayout(pattern: "HH:mm")
        #expect(german.parts == [.hour, .literal(":"), .minute])
        #expect(german.hourCycle == .zeroToTwentyThree)
        #expect(german.padsHour)

        let korean = TimeFieldLayout(pattern: "a h:mm")
        #expect(korean.segments == [.period, .hour, .minute])

        let finnish = TimeFieldLayout(pattern: "H.mm")
        #expect(finnish.parts == [.hour, .literal("."), .minute])

        let quoted = TimeFieldLayout(pattern: "HH 'h' mm")
        #expect(quoted.parts == [.hour, .literal(" h "), .minute])

        #expect(TimeFieldLayout(locale: Locale(identifier: "en_US")).hourCycle.usesPeriod)
        #expect(!TimeFieldLayout(locale: Locale(identifier: "de_DE")).hourCycle.usesPeriod)
    }

    @Test func twelveHourFieldsMapHours() {
        let layout = TimeFieldLayout(pattern: "h:mm a")
        #expect(layout.displayHour(0) == 12)
        #expect(layout.displayHour(13) == 1)
        #expect(layout.displayHour(12) == 12)
        // Typing keeps the morning or afternoon.
        #expect(layout.hour(fromTyped: 12, currentHour: 3) == 0)
        #expect(layout.hour(fromTyped: 12, currentHour: 15) == 12)
        #expect(layout.hour(fromTyped: 9, currentHour: 15) == 21)
        #expect(layout.hour(fromTyped: 13, currentHour: 15) == nil)
        #expect(layout.hour(fromTyped: 0, currentHour: 15) == nil)

        let twentyFour = TimeFieldLayout(pattern: "HH:mm")
        #expect(twentyFour.hour(fromTyped: 0, currentHour: 15) == 0)
        #expect(twentyFour.hour(fromTyped: 23, currentHour: 1) == 23)
        #expect(twentyFour.hour(fromTyped: 24, currentHour: 1) == nil)
    }

    @Test func minuteStepsSnapToTheInterval() {
        #expect(TimeStepping.step(minute: 37, by: 1, interval: 5) == 40)
        #expect(TimeStepping.step(minute: 37, by: -1, interval: 5) == 35)
        #expect(TimeStepping.step(minute: 40, by: 1, interval: 5) == 45)
        #expect(TimeStepping.step(minute: 55, by: 1, interval: 5) == 0)
        #expect(TimeStepping.step(minute: 0, by: -1, interval: 15) == 45)
        #expect(TimeStepping.step(minute: 7, by: 1, interval: 1) == 8)
        #expect(TimeStepping.step(hour: 23, by: 1) == 0)
        #expect(TimeStepping.step(hour: 0, by: -1) == 23)
    }
}
