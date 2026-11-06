//
//  DatePickerField.swift
//  BlissUI
//
//  A closed field showing the picked date, with the dropdown trigger's look;
//  a click (or Space) opens a compact month calendar to pick a day. Optional
//  minimum / maximum days, an optional empty state with Clear, and an
//  optional time of day edited in place beside it.
//
//  The calendar opens in a native `.popover`, not a floating menu, for the
//  same reason the color picker does: a floating panel can't become key, so
//  focus — and with it the arrow keys that move the day, Return to choose and
//  VoiceOver's cursor — would stay in the window behind it. A popover is a key
//  window of its own: the grid takes focus as it opens, Esc closes it, and
//  focus returns to the field.
//

import SwiftUI

// MARK: - Metrics

enum DatePickerMetrics {
    /// The pickers' calendar: seven 34pt days, room for a two-digit number
    /// with its ring.
    static let calendarWidth = CGFloat(CalendarGridMath.daysPerWeek) * (Sizing.controlMedium + Spacing.hairline)
}

// MARK: - Date Picker Field

/// A date field that opens a calendar.
///
/// ```swift
/// DatePickerField("Due date", selection: $dueDate, minimumDate: .now)
/// DatePickerField("Reminder", selection: $reminder, showsTime: true)
/// DatePickerField("Ends", selection: $endDate, placeholder: "Never")   // Date?
/// ```
///
/// Picking a day keeps the time of day already in the selection. The date is
/// written the way the user's locale writes one ("Mar 5, 2026", "5 mars 2026").
public struct DatePickerField: View {
    private let title: LocalizedStringKey?
    private let selection: Binding<Date?>
    private let placeholder: LocalizedStringKey?
    private let allowsClear: Bool
    private let minimumDate: Date?
    private let maximumDate: Date?
    private let showsTime: Bool
    private let minuteInterval: Int

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @State private var isPresented = false

    /// A field that always holds a date.
    /// - Parameters:
    ///   - title: A label before the field, looked up in your app's strings; nil for none.
    ///   - selection: The date.
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    ///   - showsTime: Adds an hour and minute field after the date.
    ///   - minuteInterval: How far ↑ / ↓ move the minutes.
    public init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<Date>,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        showsTime: Bool = false,
        minuteInterval: Int = 5
    ) {
        self.title = title
        self.selection = Binding(
            get: { selection.wrappedValue },
            set: { newValue in if let newValue { selection.wrappedValue = newValue } }
        )
        self.placeholder = nil
        self.allowsClear = false
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.showsTime = showsTime
        self.minuteInterval = minuteInterval
    }

    /// A field that can be empty: it shows `placeholder` until a day is
    /// picked, and the calendar offers Clear.
    /// - Parameters:
    ///   - title: A label before the field, looked up in your app's strings; nil for none.
    ///   - selection: The date, or nil.
    ///   - placeholder: Shown while empty, from your app's strings; nil for "Select a date".
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    ///   - showsTime: Adds an hour and minute field after the date (disabled while empty).
    ///   - minuteInterval: How far ↑ / ↓ move the minutes.
    public init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<Date?>,
        placeholder: LocalizedStringKey? = nil,
        minimumDate: Date? = nil,
        maximumDate: Date? = nil,
        showsTime: Bool = false,
        minuteInterval: Int = 5
    ) {
        self.title = title
        self.selection = selection
        self.placeholder = placeholder
        self.allowsClear = true
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.showsTime = showsTime
        self.minuteInterval = minuteInterval
    }

    private var bounds: CalendarBounds {
        CalendarBounds(minimum: minimumDate, maximum: maximumDate, calendar: calendar)
    }

    private var valueText: Text {
        guard let date = selection.wrappedValue else {
            return placeholder.map { Text($0) } ?? Text("Select a date", bundle: .module)
        }
        return Text(date, format: Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let title {
                Text(title)
                Spacer()
            }
            Button {
                isPresented.toggle()
            } label: {
                DateFieldLabel(text: valueText, isPlaceholder: selection.wrappedValue == nil)
            }
            .buttonStyle(FloatingMenuPickerButtonStyle(isActive: isPresented))
            .accessibilityLabel(title.map { Text($0) } ?? Text("Date", bundle: .module))
            .accessibilityValue(valueText)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                DatePickerPopover(
                    selection: selection,
                    bounds: bounds,
                    allowsClear: allowsClear,
                    onDone: { isPresented = false }
                )
            }
            if showsTime {
                TimeOfDayField(date: selection, minuteInterval: minuteInterval)
            }
        }
    }
}

// MARK: - Field Label

/// The trigger's label: a calendar glyph, the value, and the dropdown chevron.
struct DateFieldLabel: View {
    let text: Text
    let isPlaceholder: Bool

    var body: some View {
        HStack(spacing: Spacing.inlineSpacing) {
            Image(systemName: "calendar")
                .font(Typography.labelMedium)
                .accessibilityHidden(true)
            text
                .lineLimit(1)
                .opacity(isPlaceholder ? 0.7 : 1)
            Image(systemName: "chevron.up.chevron.down")
                .font(Typography.bodySmallSemibold)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Popover

/// The popover's body: the compact calendar (focused as it opens, Return
/// picks) and, for an optional date, Clear.
private struct DatePickerPopover: View {
    let selection: Binding<Date?>
    let bounds: CalendarBounds
    let allowsClear: Bool
    let onDone: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CalendarMonthPanel(
                selection: .day(selection.wrappedValue),
                tint: .accent,
                isCompact: true,
                bounds: bounds,
                handlesReturn: true,
                focusesOnAppear: true,
                todayPicks: true,
                onPick: { day in
                    selection.wrappedValue = CalendarGridMath.day(day, keepingTimeOf: selection.wrappedValue, calendar: calendar)
                    onDone()
                }
            )
            .frame(width: DatePickerMetrics.calendarWidth)
            if allowsClear {
                Divider()
                HStack {
                    Spacer()
                    Button {
                        selection.wrappedValue = nil
                        onDone()
                    } label: {
                        Text("Clear", bundle: .module).font(Typography.labelSmall)
                    }
                    .buttonStyle(GhostButtonStyle(compact: true))
                    .disabled(selection.wrappedValue == nil)
                }
            }
        }
        .padding(Spacing.md)
        .onExitCommand(perform: onDone)
    }
}

// MARK: - Previews

private struct DatePickerFieldPreview: View {
    @State private var dueDate = Date()
    @State private var reminder = Date()
    @State private var endDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DatePickerField(selection: $dueDate, minimumDate: Date())
            DatePickerField(selection: $reminder, showsTime: true)
            DatePickerField(selection: $endDate, placeholder: "Never")
        }
        .padding(Spacing.lg)
    }
}

#Preview("Date picker field", traits: .fixedLayout(width: 360, height: 180)) {
    DatePickerFieldPreview()
}
