//
//  DateRangeCalendar.swift
//  BlissUI
//
//  Picks a range of days: click the start, then the end (either order), with
//  the days between banded and a hover preview of the range while the end is
//  still open. Presets ("Last 7 days", "This month", or your own) sit in a
//  column beside it. It's the body of `DateRangePickerField`'s popover, public
//  so it can be hosted inline or in your own panel.
//

import SwiftUI

// MARK: - Preset

/// A named range offered beside the calendar — "Last 7 days", "This month" —
/// worked out from today when it's shown.
public struct DateRangePreset: Identifiable {
    public let id: String
    public let title: LocalizedStringKey
    private let makeRange: (_ today: Date, _ calendar: Calendar) -> ClosedRange<Date>

    /// A preset of your own. `title` is looked up in your app's strings.
    /// - Parameters:
    ///   - id: Stable identity for the preset row.
    ///   - range: The days it covers, from the start of today and the calendar.
    public init(
        id: String,
        title: LocalizedStringKey,
        range: @escaping (_ today: Date, _ calendar: Calendar) -> ClosedRange<Date>
    ) {
        self.id = id
        self.title = title
        self.makeRange = range
    }

    /// The days the preset covers on `today`, both bounds at the start of their day.
    public func range(today: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
        CalendarGridMath.normalized(makeRange(calendar.startOfDay(for: today), calendar), calendar: calendar)
    }

    // MARK: Built-in presets

    /// Today alone.
    public static var today: DateRangePreset {
        DateRangePreset(id: "today", title: .verbatim(String(localized: "Today", bundle: .module))) { today, _ in
            today...today
        }
    }

    /// Yesterday alone.
    public static var yesterday: DateRangePreset {
        DateRangePreset(id: "yesterday", title: .verbatim(String(localized: "Yesterday", bundle: .module))) { today, calendar in
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            return yesterday...yesterday
        }
    }

    /// The last `count` days, today included.
    public static func lastDays(_ count: Int) -> DateRangePreset {
        let days = max(1, count)
        return DateRangePreset(id: "last-\(days)-days", title: .verbatim(String(localized: "Last \(days) days", bundle: .module))) { today, calendar in
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
            return start...today
        }
    }

    /// The first of this month through today.
    public static var thisMonth: DateRangePreset {
        DateRangePreset(id: "this-month", title: .verbatim(String(localized: "This month", bundle: .module))) { today, calendar in
            CalendarGridMath.startOfMonth(today, calendar: calendar)...today
        }
    }

    /// The whole of the previous month.
    public static var lastMonth: DateRangePreset {
        DateRangePreset(id: "last-month", title: .verbatim(String(localized: "Last month", bundle: .module))) { today, calendar in
            let thisMonth = CalendarGridMath.startOfMonth(today, calendar: calendar)
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth
            let end = calendar.date(byAdding: .day, value: -1, to: thisMonth) ?? thisMonth
            return start...end
        }
    }

    /// Today, Last 7 days, Last 30 days, This month.
    public static var standard: [DateRangePreset] {
        [.today, .lastDays(7), .lastDays(30), .thisMonth]
    }
}

// MARK: - Date Range Calendar

/// A month calendar that picks a range of days, with optional presets.
///
/// ```swift
/// DateRangeCalendar(selection: $range, presets: DateRangePreset.standard)
/// ```
///
/// The first click sets the start and the second the end, in either order;
/// until then the range previews out to the pointer (or the keyboard's day).
/// Both bounds are the START of their day: to filter by it, compare with
/// `calendar.startOfDay(for:)`, or end at the day after `upperBound`.
public struct DateRangeCalendar: View {
    private let selection: Binding<ClosedRange<Date>?>
    private let presets: [DateRangePreset]
    private let minimumDate: Date?
    private let maximumDate: Date?
    private let allowsClear: Bool
    private let onCommit: () -> Void
    /// In the field's popover: Return picks, and focus starts in the grid.
    private let isInPopover: Bool

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    /// The start picked so far, waiting for its end.
    @State private var pendingStart: Date?

    /// A range that's always set.
    /// - Parameters:
    ///   - selection: The picked days; both bounds are the start of their day.
    ///   - presets: Named ranges listed beside the calendar.
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    ///   - onCommit: Called when a range is completed or a preset picked.
    public init(
        selection: Binding<ClosedRange<Date>>,
        presets: [DateRangePreset] = [],
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        onCommit: @escaping () -> Void = {}
    ) {
        self.init(
            selection: Binding(
                get: { selection.wrappedValue },
                set: { newValue in if let newValue { selection.wrappedValue = newValue } }
            ),
            allowsClear: false,
            presets: presets,
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            isInPopover: false,
            onCommit: onCommit
        )
    }

    /// A range that can be empty, with a Clear button.
    /// - Parameters:
    ///   - selection: The picked days, or nil; both bounds are the start of their day.
    ///   - presets: Named ranges listed beside the calendar.
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    ///   - onCommit: Called when a range is completed, a preset picked or the range cleared.
    public init(
        selection: Binding<ClosedRange<Date>?>,
        presets: [DateRangePreset] = [],
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        onCommit: @escaping () -> Void = {}
    ) {
        self.init(
            selection: selection,
            allowsClear: true,
            presets: presets,
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            isInPopover: false,
            onCommit: onCommit
        )
    }

    init(
        selection: Binding<ClosedRange<Date>?>,
        allowsClear: Bool,
        presets: [DateRangePreset],
        minimumDate: Date?,
        maximumDate: Date?,
        isInPopover: Bool,
        onCommit: @escaping () -> Void
    ) {
        self.selection = selection
        self.allowsClear = allowsClear
        self.presets = presets
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.isInPopover = isInPopover
        self.onCommit = onCommit
    }

    private var bounds: CalendarBounds {
        CalendarBounds(minimum: minimumDate, maximum: maximumDate, calendar: calendar)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if !presets.isEmpty {
                presetColumn
                    .padding(Spacing.sm)
                    .fixedSize(horizontal: true, vertical: false)
                Divider()
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CalendarMonthPanel(
                    selection: .range(selection.wrappedValue.map { CalendarGridMath.normalized($0, calendar: calendar) }, pendingStart: pendingStart),
                    tint: .accent,
                    isCompact: true,
                    bounds: bounds,
                    handlesReturn: isInPopover,
                    focusesOnAppear: isInPopover,
                    todayPicks: false,
                    onPick: pick
                )
                .frame(width: DatePickerMetrics.calendarWidth)
                Divider()
                footer
            }
            .padding(Spacing.md)
        }
        .fixedSize()
        // Esc drops a start still waiting for its end; with none, it passes on
        // (the field's popover closes).
        .onKeyPress(.escape) {
            guard pendingStart != nil else { return .ignored }
            withAnimation(Animations.selection) { pendingStart = nil }
            return .handled
        }
    }

    // MARK: Picking

    private func pick(_ day: Date) {
        guard let start = pendingStart else {
            withAnimation(Animations.selection) { pendingStart = day }
            return
        }
        withAnimation(Animations.selection) {
            pendingStart = nil
            selection.wrappedValue = CalendarGridMath.orderedRange(start, day, calendar: calendar)
        }
        onCommit()
    }

    private func apply(_ preset: DateRangePreset) {
        guard let range = bounds.clamp(preset.range(calendar: calendar)) else { return }
        withAnimation(Animations.selection) {
            pendingStart = nil
            selection.wrappedValue = range
        }
        onCommit()
    }

    // MARK: Presets

    private var presetColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            ForEach(presets) { preset in
                let range = bounds.clamp(preset.range(calendar: calendar))
                DateRangePresetRow(
                    title: preset.title,
                    isSelected: pendingStart == nil && range != nil && range == selection.wrappedValue.map { CalendarGridMath.normalized($0, calendar: calendar) },
                    action: { apply(preset) }
                )
                .disabled(range == nil)
            }
        }
    }

    // MARK: Footer

    /// The range so far — or what to pick next — and Clear.
    private var footer: some View {
        HStack(spacing: Spacing.sm) {
            status
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if allowsClear {
                Button {
                    withAnimation(Animations.selection) {
                        pendingStart = nil
                        selection.wrappedValue = nil
                    }
                    onCommit()
                } label: {
                    Text("Clear", bundle: .module).font(Typography.labelSmall)
                }
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(selection.wrappedValue == nil && pendingStart == nil)
            }
        }
        .frame(minHeight: Sizing.controlDefault)
    }

    @ViewBuilder
    private var status: some View {
        if pendingStart != nil {
            Text("Select an end date", bundle: .module)
        } else if let range = selection.wrappedValue {
            Text(verbatim: DateRangeFormatting.string(for: range, calendar: calendar, locale: locale))
        } else {
            Text("Select a start date", bundle: .module)
        }
    }
}

// MARK: - Preset Row

/// One preset: a Tab stop with the shared ring and hover wash, the selected
/// one on the row's selected fill with a checkmark.
private struct DateRangePresetRow: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
                Spacer(minLength: Spacing.sm)
                Image(systemName: "checkmark")
                    .font(Typography.labelSmall)
                    .foregroundStyle(Color.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isSelected ? RowTint.selected(scheme) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusDefault))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Formatting

/// A day range as the locale writes one: "Mar 3 – 9, 2026", "3.–9. März 2026".
nonisolated enum DateRangeFormatting {
    static func string(for range: ClosedRange<Date>, calendar: Calendar, locale: Locale) -> String {
        let days = CalendarGridMath.normalized(range, calendar: calendar)
        let style = Date.IntervalFormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        return (days.lowerBound..<max(days.upperBound, days.lowerBound)).formatted(style)
    }
}

// MARK: - Previews

private struct DateRangeCalendarPreview: View {
    @State private var range: ClosedRange<Date>? = DateRangePreset.lastDays(7).range()

    var body: some View {
        DateRangeCalendar(selection: $range, presets: DateRangePreset.standard + [.lastMonth])
            .padding(Spacing.lg)
    }
}

#Preview("Date range calendar", traits: .fixedLayout(width: 480, height: 380)) {
    DateRangeCalendarPreview()
}
