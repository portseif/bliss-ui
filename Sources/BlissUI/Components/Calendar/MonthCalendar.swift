//
//  MonthCalendar.swift
//  BlissUI
//
//  A month calendar for browsing things by day: a six-week grid with colored
//  dots on the days that have something, beside an optional day-detail panel
//  for the selected day. Out-of-month days are dimmed, today wears a quiet
//  accent ring, and the selected day takes the neutral row wash — an accent
//  fill would swallow the dots.
//
//  `.compact` is the date pickers' calendar, for inline use: small days, the
//  picked one filled with the accent, no dots.
//
//  Keyboard: the grid is one Tab stop. Arrows move the focused day, Page Up /
//  Page Down change the month (⇧ for a year), Home / End jump within the
//  week, and Space selects. Each day hovers with the list rows' fill.
//

import SwiftUI

// MARK: - Day Marker

/// One mark on a calendar day — a dot in your color. A day shows up to three;
/// more read as "+N". `label` is what VoiceOver adds after the date (and the
/// legend's text), looked up in your app's strings like `Text("…")`.
public struct CalendarDayMarker {
    public var color: Color
    public var label: LocalizedStringKey?

    public init(color: Color, label: LocalizedStringKey? = nil) {
        self.color = color
        self.label = label
    }
}

// MARK: - Style

/// How big a `MonthCalendar` draws its days.
public enum MonthCalendarStyle: Sendable {
    /// Tall days with room for marker dots under the number; the selected day
    /// takes the neutral row wash so the dots stay legible.
    case regular
    /// The date pickers' calendar: small days at a fixed width, the selected
    /// day filled with the accent. Markers aren't drawn (VoiceOver still reads
    /// their labels).
    case compact
}

// MARK: - Month Calendar

/// A month calendar with per-day markers and an optional detail panel for
/// the selected day.
///
/// ```swift
/// MonthCalendar(selection: $day, markers: { day in
///     events(on: day).map { CalendarDayMarker(color: $0.color, label: $0.kindName) }
/// }) { day in
///     DayEventsList(day: day)
/// }
/// ```
///
/// `markers` is asked for each of the 42 days shown, on every render — keep it
/// a lookup (a dictionary keyed by `Calendar.startOfDay`), not a scan. Weekdays,
/// the first day of the week and the month names follow the environment's
/// `calendar` and `locale` (the user's Language & Region settings).
public struct MonthCalendar<DayDetail: View>: View {
    private let selection: Binding<Date?>
    private let markers: (Date) -> [CalendarDayMarker]
    private let legend: [CalendarDayMarker]
    private let minimumDate: Date?
    private let maximumDate: Date?
    private let style: MonthCalendarStyle
    private let dayDetail: ((Date) -> DayDetail)?

    @Environment(\.calendar) private var calendar

    /// A calendar with a detail panel for the selected day beside it.
    /// - Parameters:
    ///   - selection: The selected day. A pick keeps the time of day already in it.
    ///   - minimumDate: The first day that can be selected (any time on it).
    ///   - maximumDate: The last day that can be selected.
    ///   - markers: The dots for a day (passed as the start of the day).
    ///   - legend: Markers with labels, listed under the grid.
    ///   - style: Regular days with markers, or the pickers' compact ones.
    ///   - dayDetail: The panel beside the grid, for the selected day.
    public init(
        selection: Binding<Date>,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        markers: @escaping (Date) -> [CalendarDayMarker] = { _ in [] },
        legend: [CalendarDayMarker] = [],
        style: MonthCalendarStyle = .regular,
        @ViewBuilder dayDetail: @escaping (Date) -> DayDetail
    ) {
        self.selection = Binding(
            get: { selection.wrappedValue },
            set: { newValue in if let newValue { selection.wrappedValue = newValue } }
        )
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.markers = markers
        self.legend = legend
        self.style = style
        self.dayDetail = dayDetail
    }

    public var body: some View {
        if let dayDetail, let day = selection.wrappedValue {
            HStack(alignment: .top, spacing: Spacing.xl) {
                calendarColumn
                    .frame(maxWidth: .infinity, alignment: .top)
                Divider()
                dayDetail(day)
                    .frame(
                        minWidth: Sizing.sidebarMinWidth,
                        idealWidth: Sizing.sidebarDefaultWidth,
                        maxWidth: Sizing.sidebarMaxWidth,
                        alignment: .topLeading
                    )
            }
        } else {
            calendarColumn
        }
    }

    private var calendarColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CalendarMonthPanel(
                selection: .day(selection.wrappedValue),
                tint: style == .compact ? .accent : .neutral,
                isCompact: style == .compact,
                bounds: CalendarBounds(minimum: minimumDate, maximum: maximumDate, calendar: calendar),
                markers: markers,
                onPick: { day in
                    withAnimation(Animations.selection) {
                        selection.wrappedValue = CalendarGridMath.day(day, keepingTimeOf: selection.wrappedValue, calendar: calendar)
                    }
                }
            )
            .frame(width: style == .compact ? DatePickerMetrics.calendarWidth : nil)
            if legend.contains(where: { $0.label != nil }) {
                CalendarLegend(markers: legend)
                    .padding(.top, Spacing.xs)
            }
        }
    }
}

extension MonthCalendar where DayDetail == EmptyView {
    /// A calendar on its own.
    /// - Parameters:
    ///   - selection: The selected day. A pick keeps the time of day already in it.
    ///   - minimumDate: The first day that can be selected (any time on it).
    ///   - maximumDate: The last day that can be selected.
    ///   - markers: The dots for a day (passed as the start of the day).
    ///   - legend: Markers with labels, listed under the grid.
    ///   - style: Regular days with markers, or the pickers' compact ones.
    public init(
        selection: Binding<Date>,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        markers: @escaping (Date) -> [CalendarDayMarker] = { _ in [] },
        legend: [CalendarDayMarker] = [],
        style: MonthCalendarStyle = .regular
    ) {
        self.selection = Binding(
            get: { selection.wrappedValue },
            set: { newValue in if let newValue { selection.wrappedValue = newValue } }
        )
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.markers = markers
        self.legend = legend
        self.style = style
        self.dayDetail = nil
    }

    /// A calendar whose selection can be empty — no day is selected until one
    /// is picked.
    public init(
        selection: Binding<Date?>,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        markers: @escaping (Date) -> [CalendarDayMarker] = { _ in [] },
        legend: [CalendarDayMarker] = [],
        style: MonthCalendarStyle = .regular
    ) {
        self.selection = selection
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.markers = markers
        self.legend = legend
        self.style = style
        self.dayDetail = nil
    }
}

// MARK: - Legend

/// What the dots mean: a dot and its label for each labeled marker.
private struct CalendarLegend: View {
    let markers: [CalendarDayMarker]

    var body: some View {
        FlowLayout(spacing: Spacing.lg) {
            ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
                if let label = marker.label {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(marker.color)
                            .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                        Text(label)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Previews

private struct MonthCalendarPreview: View {
    @State private var day = Date()

    private func markers(for day: Date) -> [CalendarDayMarker] {
        let dayOfMonth = Calendar.current.component(.day, from: day)
        switch dayOfMonth % 6 {
        case 0: return [CalendarDayMarker(color: Success.success500, label: "Done")]
        case 2: return [CalendarDayMarker(color: Info.info500), CalendarDayMarker(color: Warning.warning500)]
        case 4 where dayOfMonth > 20: return Array(repeating: CalendarDayMarker(color: Info.info500), count: 5)
        default: return []
        }
    }

    var body: some View {
        MonthCalendar(
            selection: $day,
            markers: markers(for:),
            legend: [
                CalendarDayMarker(color: Success.success500, label: "Done"),
                CalendarDayMarker(color: Info.info500, label: "Scheduled"),
                CalendarDayMarker(color: Warning.warning500, label: "Manual"),
            ]
        ) { day in
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(day, format: .dateTime.weekday(.wide).month().day())
                    .font(Typography.headingSmall)
                Divider()
                Text(verbatim: "Nothing on this day.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
    }
}

#Preview("Month calendar", traits: .fixedLayout(width: 820, height: 420)) {
    MonthCalendarPreview()
}

#Preview("Month calendar · compact", traits: .fixedLayout(width: 300, height: 300)) {
    MonthCalendar(selection: .constant(Date()), style: .compact)
        .padding(Spacing.lg)
}
