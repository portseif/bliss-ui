//
//  CalendarMonthPanel.swift
//  BlissUI
//
//  The month view every calendar is built from: a header (month title, ‹ Today
//  ›), the weekday initials in the locale's order, and a six-week day grid.
//  `MonthCalendar` shows it at the regular size with markers; the date pickers'
//  popovers and `DateRangeCalendar` show the compact one.
//
//  The grid is ONE Tab stop with a roving focused day, like the native date
//  picker and the ARIA date-grid pattern — not 42 Tab stops. Arrows move the
//  day, Page Up / Page Down the month (⇧ for a year), Home / End the week,
//  and Space (Return too, through `FocusVisibilityService`) picks it. The
//  cells aren't buttons for the same reason; each is its own accessibility
//  element with the button trait, so VoiceOver still reads and presses days.
//

import SwiftUI

// MARK: - Selection

/// What the day grid draws as picked.
enum CalendarGridSelection: Equatable {
    /// One day, or none yet.
    case day(Date?)
    /// A committed range, or a start still waiting for its end.
    case range(ClosedRange<Date>?, pendingStart: Date?)
}

/// How a picked day is filled.
enum CalendarSelectionTint {
    /// The neutral row wash: a browsing calendar's days carry colored markers,
    /// and an accent fill would swallow them.
    case neutral
    /// An accent fill, like a checkmark: the pickers, which carry no markers.
    case accent
}

/// The in-range band behind a day.
struct CalendarDayBand: Equatable {
    /// A hover (or keyboard) preview of the range before its end is picked.
    var isPreview: Bool
    /// The band ends at this day's leading / trailing edge: a range end or the
    /// edge of the week row.
    var capsLeading: Bool
    var capsTrailing: Bool
}

// MARK: - Panel

/// Header, weekday row and day grid, with the displayed month and the
/// keyboard's focused day kept here. Picks go out through `onPick`.
struct CalendarMonthPanel: View {
    let selection: CalendarGridSelection
    let tint: CalendarSelectionTint
    let isCompact: Bool
    let bounds: CalendarBounds
    var markers: ((Date) -> [CalendarDayMarker])? = nil
    /// Return picks the focused day even before a ring shows — in a picker's
    /// popover, where Return means "choose". Elsewhere Return stays the
    /// window's default action until the ring is up (it then arrives as Space).
    var handlesReturn = false
    /// Takes keyboard focus when it appears (a picker's popover).
    var focusesOnAppear = false
    /// Today picks today (a single-date calendar); otherwise it only shows it.
    var todayPicks = true
    let onPick: (Date) -> Void

    @Environment(\.calendar) private var calendar
    @State private var displayedMonth: Date
    @State private var focusedDay: Date
    @FocusState private var gridIsFocused: Bool

    init(
        selection: CalendarGridSelection,
        tint: CalendarSelectionTint,
        isCompact: Bool,
        bounds: CalendarBounds,
        markers: ((Date) -> [CalendarDayMarker])? = nil,
        handlesReturn: Bool = false,
        focusesOnAppear: Bool = false,
        todayPicks: Bool = true,
        onPick: @escaping (Date) -> Void
    ) {
        self.selection = selection
        self.tint = tint
        self.isCompact = isCompact
        self.bounds = bounds
        self.markers = markers
        self.handlesReturn = handlesReturn
        self.focusesOnAppear = focusesOnAppear
        self.todayPicks = todayPicks
        self.onPick = onPick
        // Seeded from the selection; `onAppear` re-seeds with the environment's
        // calendar (a `.blissTheme()` re-ID rebuilds this state anyway).
        let calendar = Calendar.current
        let opening = bounds.clamp(calendar.startOfDay(for: Self.anchor(of: selection) ?? Date()))
        _displayedMonth = State(initialValue: CalendarGridMath.startOfMonth(opening, calendar: calendar))
        _focusedDay = State(initialValue: opening)
    }

    /// The day a selection opens on: the picked day, a range's pending start,
    /// or a committed range's end.
    static func anchor(of selection: CalendarGridSelection) -> Date? {
        switch selection {
        case .day(let day): return day
        case .range(let range, let pendingStart): return pendingStart ?? range?.upperBound
        }
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var previousMonth: Date? {
        calendar.date(byAdding: .month, value: -1, to: displayedMonth)
    }

    private var nextMonth: Date? {
        calendar.date(byAdding: .month, value: 1, to: displayedMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? Spacing.xs : Spacing.sm) {
            CalendarMonthHeader(
                month: displayedMonth,
                isCompact: isCompact,
                canShowPrevious: previousMonth.map { bounds.containsAnyDay(inMonthStartingAt: $0, calendar: calendar) } ?? false,
                canShowNext: nextMonth.map { bounds.containsAnyDay(inMonthStartingAt: $0, calendar: calendar) } ?? false,
                isTodayEnabled: todayPicks
                    ? bounds.contains(today)
                    : bounds.containsAnyDay(inMonthStartingAt: CalendarGridMath.startOfMonth(today, calendar: calendar), calendar: calendar),
                onPrevious: { showMonth(previousMonth) },
                onToday: showToday,
                onNext: { showMonth(nextMonth) }
            )
            CalendarWeekdayHeader(isCompact: isCompact)
            CalendarDayGrid(
                month: displayedMonth,
                focusedDay: focusedDay,
                gridIsFocused: $gridIsFocused,
                selection: selection,
                tint: tint,
                bounds: bounds,
                isCompact: isCompact,
                markers: markers,
                handlesReturn: handlesReturn,
                onPick: pick,
                onMove: moveFocus
            )
        }
        .onAppear {
            reseed()
            guard focusesOnAppear else { return }
            gridIsFocused = true
            // A popover's window turns key just after its content appears;
            // ask again once it has, or the first focus request is dropped.
            Task { @MainActor in gridIsFocused = true }
        }
        .onChange(of: selection) { _, newSelection in follow(newSelection) }
    }

    // MARK: Actions

    private func reseed() {
        let opening = bounds.clamp(calendar.startOfDay(for: Self.anchor(of: selection) ?? Date()))
        displayedMonth = CalendarGridMath.startOfMonth(opening, calendar: calendar)
        focusedDay = opening
    }

    /// A click or a key picked `day`: focus lands on it, and a day from the
    /// next or previous month's edge brings that month in.
    private func pick(_ day: Date) {
        guard bounds.contains(day) else { return }
        focusedDay = day
        if !isDisplayed(day) {
            withAnimation(Animations.selection) {
                displayedMonth = CalendarGridMath.startOfMonth(day, calendar: calendar)
            }
        }
        onPick(day)
    }

    /// The selection changed (here or in the app): bring it into view unless
    /// some of it is already shown — picking a range's end on the next month
    /// mustn't jump back to its start.
    private func follow(_ newSelection: CalendarGridSelection) {
        guard let anchor = Self.anchor(of: newSelection).map(calendar.startOfDay(for:)) else { return }
        if case .range(let range?, nil) = newSelection, intersectsDisplayedMonth(range) {
            return
        }
        focusedDay = bounds.clamp(anchor)
        guard !isDisplayed(anchor) else { return }
        withAnimation(Animations.selection) {
            displayedMonth = CalendarGridMath.startOfMonth(anchor, calendar: calendar)
        }
    }

    /// Keyboard moves never animate: the month flips at once under the key.
    private func moveFocus(_ step: CalendarStep) {
        let target = bounds.clamp(step.apply(to: focusedDay, calendar: calendar))
        focusedDay = target
        if !isDisplayed(target) {
            displayedMonth = CalendarGridMath.startOfMonth(target, calendar: calendar)
        }
    }

    /// The month arrows: the focused day keeps its day of the month (the 31st
    /// lands on the 30th or the 28th), held inside the bounds.
    private func showMonth(_ month: Date?) {
        guard let month else { return }
        let start = CalendarGridMath.startOfMonth(month, calendar: calendar)
        let dayOffset = calendar.component(.day, from: focusedDay) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 28
        let candidate = calendar.date(byAdding: .day, value: min(dayOffset, daysInMonth - 1), to: start) ?? start
        withAnimation(Animations.selection) {
            displayedMonth = start
            focusedDay = bounds.clamp(calendar.startOfDay(for: candidate))
        }
    }

    private func showToday() {
        if todayPicks {
            pick(today)
            return
        }
        let target = bounds.clamp(today)
        withAnimation(Animations.selection) {
            displayedMonth = CalendarGridMath.startOfMonth(target, calendar: calendar)
            focusedDay = target
        }
    }

    private func isDisplayed(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    }

    private func intersectsDisplayedMonth(_ range: ClosedRange<Date>) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return false }
        return range.lowerBound < interval.end && range.upperBound >= interval.start
    }
}

// MARK: - Header

/// "March 2026" with ‹ Today › beside it.
struct CalendarMonthHeader: View {
    let month: Date
    let isCompact: Bool
    let canShowPrevious: Bool
    let canShowNext: Bool
    let isTodayEnabled: Bool
    let onPrevious: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    /// "LLLL" is the standalone month name — the nominative form Slavic
    /// languages use for a title (a template, so the order follows the locale).
    private var title: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return formatter.string(from: month)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(verbatim: title)
                .font(isCompact ? Typography.bodySmallSemibold : Typography.headingSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.sm)

            HStack(spacing: Spacing.xxs) {
                monthArrow("chevron.backward", label: String(localized: "Previous month", bundle: .module), isEnabled: canShowPrevious, action: onPrevious)

                todayButton
                    .fixedSize()
                    .disabled(!isTodayEnabled)

                monthArrow("chevron.forward", label: String(localized: "Next month", bundle: .module), isEnabled: canShowNext, action: onNext)
            }
        }
    }

    /// A bordered button beside the regular calendar; a ghost one in the
    /// pickers' narrow header, where a border would crowd the title.
    @ViewBuilder
    private var todayButton: some View {
        let button = Button(action: onToday) {
            Text("Today", bundle: .module).font(Typography.labelSmall)
        }
        if isCompact {
            button.buttonStyle(GhostButtonStyle(compact: true))
        } else {
            button.buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }

    private func monthArrow(_ symbol: String, label: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        // backward / forward, not left / right: they mirror in right-to-left
        // layouts, where the previous month sits on the right.
        HoverIconButton(systemImage: symbol, size: Sizing.iconTiny, chipPadding: Spacing.xs, help: label, action: action)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - Weekday Header

/// The weekday initials, starting on the locale's first weekday. Hidden from
/// VoiceOver: each day reads its full weekday itself.
struct CalendarWeekdayHeader: View {
    let isCompact: Bool

    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: 0) {
            // By position: the initials repeat (S M T W T F S), so they can't
            // be their own IDs.
            ForEach(Array(CalendarGridMath.weekdaySymbols(calendar).enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .font(isCompact ? Typography.captionSmall : Typography.captionTiny)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Day Grid

/// The six-week grid: one Tab stop whose arrow keys move the focused day.
struct CalendarDayGrid: View {
    let month: Date
    let focusedDay: Date
    var gridIsFocused: FocusState<Bool>.Binding
    let selection: CalendarGridSelection
    let tint: CalendarSelectionTint
    let bounds: CalendarBounds
    let isCompact: Bool
    let markers: ((Date) -> [CalendarDayMarker])?
    let handlesReturn: Bool
    let onPick: (Date) -> Void
    let onMove: (CalendarStep) -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var hoveredDay: Date?
    /// Read so the keyboard's range preview follows the ring's visibility.
    private var focusVisibility: FocusVisibilityService { .shared }

    private var rowSpacing: CGFloat { isCompact ? Spacing.hairline : Spacing.xxs }

    var body: some View {
        let days = CalendarGridMath.gridDays(forMonthContaining: month, calendar: calendar)
        let shownRange = displayedRange
        VStack(spacing: rowSpacing) {
            ForEach(0..<CalendarGridMath.weeksShown, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<CalendarGridMath.daysPerWeek, id: \.self) { column in
                        let index = week * CalendarGridMath.daysPerWeek + column
                        if days.indices.contains(index) {
                            cell(for: days[index], column: column, shownRange: shownRange)
                        }
                    }
                }
            }
        }
        .focusable()
        .focused(gridIsFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .pageUp, .pageDown, .home, .end], phases: [.down, .repeat]) { press in
            guard let step = step(for: press) else { return .ignored }
            onMove(step)
            return .handled
        }
        // Key-down only: a held key would pick again and again.
        .onKeyPress(keys: pickKeys, phases: .down) { _ in
            onPick(focusedDay)
            return .handled
        }
        .onHover { hovering in
            if !hovering { hoveredDay = nil }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Keys

    private var pickKeys: Set<KeyEquivalent> {
        handlesReturn ? [.space, .return] : [.space]
    }

    private func step(for press: KeyPress) -> CalendarStep? {
        let isRightToLeft = layoutDirection == .rightToLeft
        switch press.key {
        case .leftArrow: return .days(isRightToLeft ? 1 : -1)
        case .rightArrow: return .days(isRightToLeft ? -1 : 1)
        case .upArrow: return .weeks(-1)
        case .downArrow: return .weeks(1)
        case .pageUp: return press.modifiers.contains(.shift) ? .years(-1) : .months(-1)
        case .pageDown: return press.modifiers.contains(.shift) ? .years(1) : .months(1)
        case .home: return .startOfWeek
        case .end: return .endOfWeek
        default: return nil
        }
    }

    // MARK: Range

    /// The range to band: the committed one, or — while a start waits for its
    /// end — a preview out to the hovered day (or the keyboard's day while the
    /// ring shows).
    private var displayedRange: (range: ClosedRange<Date>, isPreview: Bool)? {
        guard case .range(let committed, let pendingStart) = selection else { return nil }
        guard let pendingStart else { return committed.map { ($0, false) } }
        let keyboardDay = gridIsFocused.wrappedValue && focusVisibility.showsFocusRings ? focusedDay : nil
        guard let previewEnd = hoveredDay ?? keyboardDay, bounds.contains(previewEnd) else { return nil }
        return (CalendarGridMath.orderedRange(pendingStart, previewEnd, calendar: calendar), true)
    }

    private func isPicked(_ day: Date, shownRange: (range: ClosedRange<Date>, isPreview: Bool)?) -> Bool {
        switch selection {
        case .day(let picked):
            return picked.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        case .range(let committed, let pendingStart):
            if let pendingStart {
                // The start, and the end the preview reaches.
                if day == pendingStart { return true }
                guard let shownRange else { return false }
                return day == shownRange.range.lowerBound || day == shownRange.range.upperBound
            }
            guard let committed else { return false }
            return day == committed.lowerBound || day == committed.upperBound
        }
    }

    private func band(for day: Date, column: Int, shownRange: (range: ClosedRange<Date>, isPreview: Bool)?) -> CalendarDayBand? {
        guard let shownRange, shownRange.range.lowerBound != shownRange.range.upperBound,
              shownRange.range.contains(day) else { return nil }
        return CalendarDayBand(
            isPreview: shownRange.isPreview,
            capsLeading: day == shownRange.range.lowerBound || column == 0,
            capsTrailing: day == shownRange.range.upperBound || column == CalendarGridMath.daysPerWeek - 1
        )
    }

    // MARK: Cells

    private func cell(for day: Date, column: Int, shownRange: (range: ClosedRange<Date>, isPreview: Bool)?) -> some View {
        let isEnabled = bounds.contains(day)
        let picked = isPicked(day, shownRange: shownRange)
        return CalendarDayCell(
            day: day,
            isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
            isToday: calendar.isDateInToday(day),
            isEnabled: isEnabled,
            isPicked: picked,
            band: band(for: day, column: column, shownRange: shownRange),
            tint: tint,
            isHovered: hoveredDay == day,
            hasKeyboardFocus: gridIsFocused.wrappedValue && focusedDay == day,
            markers: markers?(day) ?? [],
            isCompact: isCompact
        )
        .onHover { hovering in
            guard isEnabled else { return }
            withAnimation(Animations.hover) {
                if hovering {
                    hoveredDay = day
                } else if hoveredDay == day {
                    hoveredDay = nil
                }
            }
        }
        .onTapGesture {
            guard isEnabled else { return }
            // A click puts the keys here too, so the arrows carry on from it.
            gridIsFocused.wrappedValue = true
            onPick(day)
        }
        .accessibilityAction {
            guard isEnabled else { return }
            onPick(day)
        }
    }
}

// MARK: - Day Cell

/// One day: its number (over up to three marker dots at the regular size), the
/// picked fill, the range band, hover, today's ring and the keyboard's ring.
private struct CalendarDayCell: View {
    let day: Date
    let isInMonth: Bool
    let isToday: Bool
    let isEnabled: Bool
    let isPicked: Bool
    let band: CalendarDayBand?
    let tint: CalendarSelectionTint
    let isHovered: Bool
    let hasKeyboardFocus: Bool
    let markers: [CalendarDayMarker]
    let isCompact: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    /// At most this many dots; the rest read as "+N".
    private let maximumDots = 3

    /// Half the gap between neighboring days: the band runs through it, the
    /// day fills stop short of it.
    private var inset: CGFloat { isCompact ? Spacing.hairline / 2 : Spacing.hairline }
    private let cornerRadius = Sizing.radiusDefault
    /// Room for the number over a row of marker dots, or the number alone.
    private var height: CGFloat { isCompact ? Sizing.controlDefault + Spacing.hairline : Sizing.controlLarge + Spacing.xs }

    private var dayShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var isAccentPicked: Bool { isPicked && tint == .accent }

    private var dayFill: Color {
        if isPicked {
            return tint == .accent ? Color.accent : RowTint.selected(scheme)
        }
        return isHovered && isEnabled ? RowTint.hover(scheme) : .clear
    }

    private var bandFill: Color {
        guard let band else { return .clear }
        return band.isPreview ? RowTint.hover(scheme) : RowTint.selected(scheme)
    }

    private var numberStyle: AnyShapeStyle {
        if isAccentPicked { return AnyShapeStyle(AccentHue.contrastForeground) }
        if !isEnabled { return AnyShapeStyle(.quaternary) }
        return isInMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private var numberFont: Font {
        if isCompact {
            return isPicked || isToday ? Typography.bodySmallSemibold : Typography.labelMedium
        }
        return isPicked || isToday ? Typography.captionSemibold : Typography.labelSmall
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(day, format: Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day())
                .font(numberFont)
                .foregroundStyle(numberStyle)
            if !isCompact {
                markerDots
                    .opacity(isInMonth && isEnabled ? 1 : 0.4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background { dayShape.fill(dayFill) }
        .overlay {
            // Today: a quiet accent ring, dropped once the day is picked.
            if isToday && !isPicked {
                dayShape.strokeBorder(Color.accent.opacity(0.5), lineWidth: 1)
            }
        }
        .focusRing(isFocused: hasKeyboardFocus, cornerRadius: cornerRadius)
        .padding(.horizontal, inset)
        .background { bandShape }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day, format: Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isPicked || band != nil ? [.isButton, .isSelected] : [.isButton])
        .disabled(!isEnabled)
    }

    /// The band runs edge to edge between days, so a range reads as one strip;
    /// it's capped (rounded and inset like a day) at the range's ends and at
    /// the edges of the week.
    @ViewBuilder
    private var bandShape: some View {
        if let band {
            UnevenRoundedRectangle(
                topLeadingRadius: band.capsLeading ? cornerRadius : 0,
                bottomLeadingRadius: band.capsLeading ? cornerRadius : 0,
                bottomTrailingRadius: band.capsTrailing ? cornerRadius : 0,
                topTrailingRadius: band.capsTrailing ? cornerRadius : 0,
                style: .continuous
            )
            .fill(bandFill)
            .padding(.leading, band.capsLeading ? inset : 0)
            .padding(.trailing, band.capsTrailing ? inset : 0)
        }
    }

    private var markerDots: some View {
        HStack(spacing: Spacing.hairline) {
            ForEach(Array(markers.prefix(maximumDots).enumerated()), id: \.offset) { _, marker in
                Circle()
                    .fill(marker.color)
                    .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
            }
            if markers.count > maximumDots {
                Text(verbatim: "+" + (markers.count - maximumDots).formatted(.number.locale(locale)))
                    .font(Typography.captionTiny)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: Sizing.statusCircle)
    }

    /// "Today" and the markers' labels, after the date VoiceOver reads.
    private var accessibilityValue: Text {
        var parts: [Text] = []
        if isToday { parts.append(Text("Today", bundle: .module)) }
        parts += markers.compactMap { $0.label.map { Text($0) } }
        guard let first = parts.first else { return Text(verbatim: "") }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: ", ") + $1 }
    }
}
