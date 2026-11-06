//
//  DateRangePickerField.swift
//  BlissUI
//
//  A closed field showing a range of days ("Mar 3 – 9, 2026"); a click opens
//  `DateRangeCalendar` in a popover: presets beside a month whose days you
//  click start-then-end, with a hover preview of the range. It closes once a
//  range is complete or a preset picked.
//
//  A native `.popover`, like `DatePickerField`: a floating panel can't become
//  key, so the grid's arrow keys, Return and VoiceOver wouldn't reach it.
//

import SwiftUI

/// A date-range field that opens a range calendar with optional presets.
///
/// ```swift
/// DateRangePickerField("Period", selection: $range, presets: DateRangePreset.standard)
/// ```
///
/// Both bounds of the range are the start of their day.
public struct DateRangePickerField: View {
    private let title: LocalizedStringKey?
    private let selection: Binding<ClosedRange<Date>?>
    private let isOptional: Bool
    private let placeholder: LocalizedStringKey?
    private let presets: [DateRangePreset]
    private let minimumDate: Date?
    private let maximumDate: Date?

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @State private var isPresented = false

    /// A field that always holds a range.
    /// - Parameters:
    ///   - title: A label before the field, looked up in your app's strings; nil for none.
    ///   - selection: The days; both bounds are the start of their day.
    ///   - presets: Named ranges listed beside the calendar.
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    public init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<ClosedRange<Date>>,
        presets: [DateRangePreset] = [],
        minimumDate: Date? = nil,
        maximumDate: Date? = nil
    ) {
        self.title = title
        self.selection = Binding(
            get: { selection.wrappedValue },
            set: { newValue in if let newValue { selection.wrappedValue = newValue } }
        )
        self.isOptional = false
        self.placeholder = nil
        self.presets = presets
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
    }

    /// A field that can be empty: it shows `placeholder` until a range is
    /// picked, and the calendar offers Clear.
    /// - Parameters:
    ///   - title: A label before the field, looked up in your app's strings; nil for none.
    ///   - selection: The days, or nil; both bounds are the start of their day.
    ///   - placeholder: Shown while empty, from your app's strings; nil for "Select dates".
    ///   - presets: Named ranges listed beside the calendar.
    ///   - minimumDate: The first day that can be picked (any time on it).
    ///   - maximumDate: The last day that can be picked.
    public init(
        _ title: LocalizedStringKey? = nil,
        selection: Binding<ClosedRange<Date>?>,
        placeholder: LocalizedStringKey? = nil,
        presets: [DateRangePreset] = [],
        minimumDate: Date? = nil,
        maximumDate: Date? = nil
    ) {
        self.title = title
        self.selection = selection
        self.isOptional = true
        self.placeholder = placeholder
        self.presets = presets
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
    }

    private var valueText: Text {
        guard let range = selection.wrappedValue else {
            return placeholder.map { Text($0) } ?? Text("Select dates", bundle: .module)
        }
        return Text(verbatim: DateRangeFormatting.string(for: range, calendar: calendar, locale: locale))
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
            .accessibilityLabel(title.map { Text($0) } ?? Text("Date range", bundle: .module))
            .accessibilityValue(valueText)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                popoverCalendar
                    .onExitCommand { isPresented = false }
            }
        }
    }

    private var popoverCalendar: some View {
        DateRangeCalendar(
            selection: selection,
            allowsClear: isOptional,
            presets: presets,
            minimumDate: minimumDate,
            maximumDate: maximumDate,
            isInPopover: true,
            onCommit: { isPresented = false }
        )
    }
}

// MARK: - Previews

private struct DateRangePickerFieldPreview: View {
    @State private var period = DateRangePreset.lastDays(7).range()
    @State private var trip: ClosedRange<Date>?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DateRangePickerField("Period", selection: $period, presets: DateRangePreset.standard)
            DateRangePickerField("Trip", selection: $trip, minimumDate: Date())
        }
        .padding(Spacing.lg)
    }
}

#Preview("Date range picker field", traits: .fixedLayout(width: 380, height: 140)) {
    DateRangePickerFieldPreview()
}
