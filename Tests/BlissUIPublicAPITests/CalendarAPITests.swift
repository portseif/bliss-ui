import Foundation
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the calendar and date-picker
/// components, built the way an app would build them.
@MainActor
@Suite struct CalendarAPITests {
    private struct Event: Identifiable {
        let id: Int
        let date: Date
        let color: Color
    }

    @Test func monthCalendarIsReachable() {
        let events = [Event(id: 1, date: Date(), color: .green)]
        _ = MonthCalendar(selection: .constant(Date()))
        _ = MonthCalendar(
            selection: .constant(Date()),
            minimumDate: Date().addingTimeInterval(-86_400 * 30),
            maximumDate: Date().addingTimeInterval(86_400 * 30),
            markers: { day in
                events
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                    .map { CalendarDayMarker(color: $0.color, label: "Event") }
            },
            legend: [CalendarDayMarker(color: .green, label: "Event")]
        )
        _ = MonthCalendar(selection: .constant(nil as Date?), style: .compact)
        _ = MonthCalendar(selection: .constant(Date()), style: .regular) { day in
            Text(day, format: .dateTime.month().day())
        }
        let styles: [MonthCalendarStyle] = [.regular, .compact]
        #expect(styles.count == 2)
    }

    @Test func dayMarkerKeepsItsValues() {
        var marker = CalendarDayMarker(color: .red)
        #expect(marker.label == nil)
        marker.label = "Deadline"
        marker.color = .blue
        #expect(marker.label != nil)
    }

    @Test func datePickerFieldIsReachable() {
        _ = DatePickerField(selection: .constant(Date()))
        _ = DatePickerField("Due", selection: .constant(Date()), minimumDate: Date(), maximumDate: nil, showsTime: true, minuteInterval: 15)
        _ = DatePickerField(selection: .constant(nil as Date?))
        _ = DatePickerField("Ends", selection: .constant(nil as Date?), placeholder: "Never", minimumDate: nil, maximumDate: Date(), showsTime: true)
    }

    @Test func dateRangeComponentsAreReachable() {
        let week = DateRangePreset.lastDays(7).range()
        _ = DateRangePickerField(selection: .constant(week))
        _ = DateRangePickerField("Period", selection: .constant(week), presets: DateRangePreset.standard, minimumDate: nil, maximumDate: Date())
        _ = DateRangePickerField(selection: .constant(nil as ClosedRange<Date>?))
        _ = DateRangePickerField("Trip", selection: .constant(nil as ClosedRange<Date>?), placeholder: "Any dates", presets: [.today], minimumDate: Date())

        _ = DateRangeCalendar(selection: .constant(week))
        _ = DateRangeCalendar(selection: .constant(week), presets: [.thisMonth, .lastMonth], minimumDate: nil, maximumDate: nil) {}
        _ = DateRangeCalendar(selection: .constant(nil as ClosedRange<Date>?), presets: DateRangePreset.standard, onCommit: {})
    }

    @Test func presetsAreDataAnAppCanSupply() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 14))!

        let quarter = DateRangePreset(id: "quarter", title: "This quarter") { today, calendar in
            let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
            return start...today
        }
        #expect(quarter.id == "quarter")
        #expect(quarter.range(today: today, calendar: calendar).lowerBound == calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        let presets: [DateRangePreset] = DateRangePreset.standard + [.yesterday, .lastMonth, .lastDays(90)]
        #expect(Set(presets.map(\.id)).count == presets.count)
        for preset in presets {
            let range = preset.range(today: today, calendar: calendar)
            #expect(range.upperBound <= calendar.startOfDay(for: today))
        }
    }
}
