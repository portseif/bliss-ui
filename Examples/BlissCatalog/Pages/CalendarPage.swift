//
//  CalendarPage.swift
//  BlissCatalog
//
//  The "Calendar & Dates" page.
//

import BlissUI
import SwiftUI

struct CalendarPage: View {
    @State private var browsedDay = Date()
    @State private var pickedDay = Date()
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var reminder = Date()
    @State private var endDate: Date?
    @State private var period = DateRangePreset.lastDays(7).range()
    @State private var trip: ClosedRange<Date>?
    @State private var inlineRange: ClosedRange<Date>? = DateRangePreset.thisMonth.range()

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text("Weekday order, month names and the first day of the week follow the user's Language & Region settings. Click a day, or Tab into the grid and use the arrow keys, Page Up / Page Down and Space.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            DemoBlock(title: "Month calendar") {
                MonthCalendar(
                    selection: $browsedDay,
                    markers: { CalendarSampleEvents.markers(on: $0) },
                    legend: CalendarSampleEvents.legend
                ) { day in
                    CalendarSampleDayPanel(day: day)
                }
            }

            DemoBlock(title: "Compact calendar") {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    MonthCalendar(selection: $pickedDay, style: .compact)
                    MonthCalendar(
                        selection: $pickedDay,
                        minimumDate: today,
                        maximumDate: Calendar.current.date(byAdding: .day, value: 20, to: today),
                        style: .compact
                    )
                }
            }

            DemoBlock(title: "Date picker") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DatePickerField("Due date", selection: $dueDate, minimumDate: today)
                    DatePickerField("Reminder", selection: $reminder, showsTime: true)
                    DatePickerField("Ends", selection: $endDate, placeholder: "Never")
                }
                .frame(maxWidth: 420)
            }

            DemoBlock(title: "Date range picker") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    DateRangePickerField("Period", selection: $period, presets: DateRangePreset.standard + [.lastMonth])
                    DateRangePickerField("Trip", selection: $trip, placeholder: "Any dates", minimumDate: today)
                }
                .frame(maxWidth: 420)
            }

            DemoBlock(title: "Range calendar") {
                DateRangeCalendar(selection: $inlineRange, presets: DateRangePreset.standard + [.yesterday, .lastMonth])
                    .background {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .strokeBorder(Color.menuBorder, lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Sample data

/// A few made-up events around today, keyed by day.
enum CalendarSampleEvents {
    struct Event: Identifiable {
        let id: Int
        let title: String
        let kind: Kind
        let date: Date
    }

    enum Kind {
        case release, meeting, reminder

        var color: Color {
            switch self {
            case .release: return Success.success500
            case .meeting: return Info.info500
            case .reminder: return Warning.warning500
            }
        }

        var label: LocalizedStringKey {
            switch self {
            case .release: return "Release"
            case .meeting: return "Meeting"
            case .reminder: return "Reminder"
            }
        }

        var icon: String {
            switch self {
            case .release: return "shippingbox"
            case .meeting: return "person.2"
            case .reminder: return "bell"
            }
        }
    }

    static let legend = [Kind.release, .meeting, .reminder].map { CalendarDayMarker(color: $0.color, label: $0.label) }

    /// Offsets in days from today, with an hour.
    private static let schedule: [(dayOffset: Int, hour: Int, title: String, kind: Kind)] = [
        (-9, 10, "Design review", .meeting),
        (-6, 16, "Ship 1.2", .release),
        (-3, 9, "Standup", .meeting),
        (-3, 14, "Renew certificates", .reminder),
        (-1, 11, "Planning", .meeting),
        (0, 9, "Standup", .meeting),
        (0, 13, "Ship 1.3", .release),
        (0, 15, "Write release notes", .reminder),
        (2, 10, "Retro", .meeting),
        (5, 9, "Standup", .meeting),
        (5, 11, "Interview", .meeting),
        (5, 13, "Vendor call", .meeting),
        (5, 15, "Roadmap", .meeting),
        (5, 17, "Book travel", .reminder),
        (8, 12, "Ship 1.4 beta", .release),
        (12, 10, "Quarterly review", .meeting),
    ]

    static var events: [Event] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return schedule.enumerated().compactMap { index, item in
            guard let day = calendar.date(byAdding: .day, value: item.dayOffset, to: today),
                  let date = calendar.date(bySettingHour: item.hour, minute: 0, second: 0, of: day) else { return nil }
            return Event(id: index, title: item.title, kind: item.kind, date: date)
        }
    }

    static func events(on day: Date) -> [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    static func markers(on day: Date) -> [CalendarDayMarker] {
        events(on: day).map { CalendarDayMarker(color: $0.kind.color, label: $0.kind.label) }
    }
}

/// The detail beside the month calendar: the day's events, newest first.
struct CalendarSampleDayPanel: View {
    let day: Date

    var body: some View {
        let events = CalendarSampleEvents.events(on: day)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(Typography.headingSmall)
                Text(events.isEmpty ? "No events" : "\(events.count) events")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if events.isEmpty {
                Text("Nothing on this day.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.md)
            } else {
                DividedForEach(events) { event in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(event.kind.color.opacity(0.16))
                            .frame(width: Sizing.iconXLarge - Spacing.xxs, height: Sizing.iconXLarge - Spacing.xxs)
                            .overlay {
                                Image(systemName: event.kind.icon)
                                    .font(Typography.captionSmall)
                                    .foregroundStyle(event.kind.color)
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: event.title)
                                .font(Typography.labelMedium)
                                .lineLimit(1)
                            Text(event.kind.label)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Spacing.sm)
                        Text(event.date, format: .dateTime.hour().minute())
                            .font(Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                    .rowHover()
                }
            }
        }
    }
}
