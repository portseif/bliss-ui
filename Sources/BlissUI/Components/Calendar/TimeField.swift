//
//  TimeField.swift
//  BlissUI
//
//  A time of day as segments — hour, minute, optional seconds and, in 12-hour
//  locales, AM/PM — in the locale's order and with its separators ("9:41 AM",
//  "09:41", "9.41", "오전 9:41"). Each segment is a Tab stop that ↑ / ↓ step
//  and digits type into, like the native date picker's text field. A list of
//  times in a menu would open at midnight, 36 rows above 9 AM. It's the time
//  half of a `DatePickerField(showsTime:)` and a field of its own ("Quiet
//  hours", "Daily at").
//

import SwiftUI

// MARK: - Layout

/// The segments and separators of the locale's short time, parsed from its
/// date-format pattern ("h:mm a", "HH:mm", "a h:mm", "HH:mm:ss").
nonisolated struct TimeFieldLayout: Equatable {
    enum Part: Hashable {
        case hour
        case minute
        case second
        case period
        case literal(String)
    }

    /// How hours are numbered (the pattern letter: K, h, H, k).
    enum HourCycle: Equatable {
        case zeroToEleven
        case oneToTwelve
        case zeroToTwentyThree
        case oneToTwentyFour

        var usesPeriod: Bool { self == .zeroToEleven || self == .oneToTwelve }
    }

    let parts: [Part]
    let hourCycle: HourCycle
    /// "HH" pads the hour to two digits; "h" doesn't.
    let padsHour: Bool

    /// The locale's own hour cycle and order: "j" is its preferred hour, which
    /// honors the 24-hour setting in System Settings.
    init(locale: Locale, showsSeconds: Bool = false) {
        let template = showsSeconds ? "jmmss" : "jmm"
        self.init(pattern: DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale) ?? (showsSeconds ? "HH:mm:ss" : "HH:mm"))
    }

    init(pattern: String) {
        var parts: [Part] = []
        var hourCycle = HourCycle.zeroToTwentyThree
        var padsHour = true
        var literal = ""
        var isQuoted = false
        let characters = Array(pattern)
        var index = 0

        func flushLiteral() {
            guard !literal.isEmpty else { return }
            parts.append(.literal(literal))
            literal = ""
        }

        while index < characters.count {
            let character = characters[index]
            if character == "'" {
                // '' is a literal apostrophe; a lone ' opens or closes quoting.
                if index + 1 < characters.count, characters[index + 1] == "'" {
                    literal.append("'")
                    index += 2
                } else {
                    isQuoted.toggle()
                    index += 1
                }
                continue
            }
            guard !isQuoted, character.isLetter else {
                literal.append(character)
                index += 1
                continue
            }
            var runLength = 1
            while index + runLength < characters.count, characters[index + runLength] == character { runLength += 1 }
            switch character {
            case "h", "H", "k", "K":
                flushLiteral()
                parts.append(.hour)
                padsHour = runLength >= 2
                hourCycle = switch character {
                case "h": .oneToTwelve
                case "K": .zeroToEleven
                case "k": .oneToTwentyFour
                default: .zeroToTwentyThree
                }
            case "m":
                flushLiteral()
                parts.append(.minute)
            case "s":
                flushLiteral()
                parts.append(.second)
            case "a", "b", "B":
                flushLiteral()
                parts.append(.period)
            default:
                break
            }
            index += runLength
        }
        flushLiteral()

        // A pattern without a period still needs one to reach the afternoon.
        if hourCycle.usesPeriod, !parts.contains(.period) {
            parts += [.literal(" "), .period]
        }
        self.parts = parts
        self.hourCycle = hourCycle
        self.padsHour = padsHour
    }

    /// The hour as this layout numbers it, from a 0–23 hour.
    func displayHour(_ hour: Int) -> Int {
        switch hourCycle {
        case .zeroToEleven: return hour % 12
        case .oneToTwelve: return hour % 12 == 0 ? 12 : hour % 12
        case .zeroToTwentyThree: return hour
        case .oneToTwentyFour: return hour == 0 ? 24 : hour
        }
    }

    /// The 0–23 hour for a typed one, keeping the morning or afternoon of
    /// `currentHour` in a 12-hour layout. Nil when it isn't an hour here.
    func hour(fromTyped typed: Int, currentHour: Int) -> Int? {
        switch hourCycle {
        case .zeroToEleven:
            guard (0...11).contains(typed) else { return nil }
            return typed + (currentHour >= 12 ? 12 : 0)
        case .oneToTwelve:
            guard (1...12).contains(typed) else { return nil }
            return typed % 12 + (currentHour >= 12 ? 12 : 0)
        case .zeroToTwentyThree:
            return (0...23).contains(typed) ? typed : nil
        case .oneToTwentyFour:
            guard (1...24).contains(typed) else { return nil }
            return typed % 24
        }
    }

    /// The largest hour that can be typed, which decides when a typed digit
    /// is already a whole hour ("3" can't start a 12-hour "3x").
    var maximumTypedHour: Int {
        switch hourCycle {
        case .zeroToEleven: return 11
        case .oneToTwelve: return 12
        case .zeroToTwentyThree: return 23
        case .oneToTwentyFour: return 24
        }
    }

    var segments: [Part] { parts.filter { if case .literal = $0 { false } else { true } } }
}

// MARK: - Stepping

nonisolated enum TimeStepping {
    /// `minute` moved one step of `interval` up or down, snapping to the
    /// interval first (9:37 ↑ by 5 → 9:40) and wrapping within the hour.
    static func step(minute: Int, by direction: Int, interval: Int) -> Int {
        let interval = max(1, min(interval, 30))
        let snapped: Int
        if minute % interval == 0 {
            snapped = minute + direction * interval
        } else {
            snapped = direction > 0 ? (minute / interval + 1) * interval : (minute / interval) * interval
        }
        return ((snapped % 60) + 60) % 60
    }

    /// `hour` (0–23) moved by `direction`, wrapping around the day.
    static func step(hour: Int, by direction: Int) -> Int {
        ((hour + direction) % 24 + 24) % 24
    }
}

// MARK: - Field

/// A time of day, edited segment by segment.
///
/// ```swift
/// TimeField("Quiet hours start", selection: $quietStart)
/// TimeField("Daily at", selection: $runTime, minuteInterval: 15)
/// ```
///
/// Disabled while `selection` is nil (a `DatePickerField` with no date yet);
/// pass a date to edit its time, the day is kept. The segments follow the
/// locale: the user's 12- or 24-hour setting, its separators, and AM/PM where
/// it has one. `showsSeconds` adds a seconds segment.
public struct TimeField: View {
    private let title: LocalizedStringKey?
    @Binding private var date: Date?
    private let minuteInterval: Int
    private let showsSeconds: Bool

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @FocusState private var focusedSegment: TimeFieldLayout.Part?
    /// Digits typed into the focused segment so far (a two-digit hour arrives
    /// one key at a time).
    @State private var typedDigits = ""

    /// - Parameters:
    ///   - title: The field's VoiceOver label, looked up in your app's strings.
    ///   - selection: The date whose time of day is edited; nil disables the field.
    ///   - minuteInterval: How far ↑ / ↓ move the minutes.
    ///   - showsSeconds: Adds a seconds segment after the minutes.
    public init(
        _ title: LocalizedStringKey,
        selection: Binding<Date?>,
        minuteInterval: Int = 5,
        showsSeconds: Bool = false
    ) {
        self.title = title
        self._date = selection
        self.minuteInterval = minuteInterval
        self.showsSeconds = showsSeconds
    }

    /// A field that always holds a time (the day of `selection` is kept).
    public init(
        _ title: LocalizedStringKey,
        selection: Binding<Date>,
        minuteInterval: Int = 5,
        showsSeconds: Bool = false
    ) {
        self.init(
            title,
            selection: Binding<Date?>(
                get: { selection.wrappedValue },
                set: { newValue in if let newValue { selection.wrappedValue = newValue } }
            ),
            minuteInterval: minuteInterval,
            showsSeconds: showsSeconds
        )
    }

    /// The time half of a `DatePickerField`, labeled by its segments alone.
    init(selection: Binding<Date?>, minuteInterval: Int) {
        self.title = nil
        self._date = selection
        self.minuteInterval = minuteInterval
        self.showsSeconds = false
    }

    private var layout: TimeFieldLayout { TimeFieldLayout(locale: locale, showsSeconds: showsSeconds) }

    private var components: (hour: Int, minute: Int, second: Int)? {
        guard let date else { return nil }
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }

    public var body: some View {
        if let title {
            field.accessibilityLabel(Text(title))
        } else {
            field
        }
    }

    private var field: some View {
        let layout = layout
        return HStack(spacing: 0) {
            ForEach(Array(layout.parts.enumerated()), id: \.offset) { _, part in
                if case .literal(let text) = part {
                    Text(verbatim: text)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    segment(part, layout: layout)
                }
            }
        }
        .font(Typography.labelMedium)
        .monospacedDigit()
        .padding(.horizontal, Spacing.fieldPaddingH)
        .frame(minHeight: Sizing.controlDefault)
        .inputBox(isFocused: focusedSegment != nil)
        .disabled(date == nil)
        .opacity(date == nil ? Animations.disabledOpacity : 1)
        .onChange(of: focusedSegment) { _, _ in typedDigits = "" }
        .accessibilityElement(children: .contain)
    }

    // MARK: Segments

    private func segment(_ part: TimeFieldLayout.Part, layout: TimeFieldLayout) -> some View {
        let isFocused = focusedSegment == part
        return Text(verbatim: text(for: part, layout: layout))
            .foregroundStyle(isFocused ? AnyShapeStyle(AccentHue.contrastForeground) : AnyShapeStyle(.primary))
            // Half a hairline: the focused block hugs its digits.
            .padding(.horizontal, Spacing.hairline / 2)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .fill(isFocused ? Color.accent : .clear)
            }
            .contentShape(Rectangle())
            .focusable()
            .focused($focusedSegment, equals: part)
            .focusEffectDisabled()
            .onTapGesture { focusedSegment = part }
            .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
                step(part, by: press.key == .upArrow ? 1 : -1)
                return .handled
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
                moveFocus(from: part, by: press.key == .rightArrow ? 1 : -1, layout: layout)
                return .handled
            }
            .onKeyPress(phases: .down) { press in
                type(press.characters, into: part, layout: layout) ? .handled : .ignored
            }
            .accessibilityElement()
            .accessibilityLabel(label(for: part))
            .accessibilityValue(Text(verbatim: text(for: part, layout: layout)))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: step(part, by: 1)
                case .decrement: step(part, by: -1)
                @unknown default: break
                }
            }
    }

    private func label(for part: TimeFieldLayout.Part) -> Text {
        switch part {
        case .hour: return Text("Hour", bundle: .module)
        case .minute: return Text("Minute", bundle: .module)
        case .second: return Text("Second", bundle: .module)
        default: return Text("AM/PM", bundle: .module)
        }
    }

    private func text(for part: TimeFieldLayout.Part, layout: TimeFieldLayout) -> String {
        guard let components else {
            return part == .period ? calendar.amSymbol : "--"
        }
        switch part {
        case .hour:
            let hour = layout.displayHour(components.hour)
            return hour.formatted(.number.locale(locale).grouping(.never).precision(.integerLength(layout.padsHour ? 2 : 1)))
        case .minute:
            return components.minute.formatted(.number.locale(locale).grouping(.never).precision(.integerLength(2)))
        case .second:
            return components.second.formatted(.number.locale(locale).grouping(.never).precision(.integerLength(2)))
        case .period:
            return components.hour >= 12 ? calendar.pmSymbol : calendar.amSymbol
        case .literal(let text):
            return text
        }
    }

    // MARK: Editing

    private func setTime(hour: Int, minute: Int, second: Int) {
        guard let date else { return }
        self.date = calendar.date(bySettingHour: hour, minute: minute, second: second, of: date) ?? date
    }

    private func step(_ part: TimeFieldLayout.Part, by direction: Int) {
        guard let components else { return }
        typedDigits = ""
        switch part {
        case .hour:
            setTime(hour: TimeStepping.step(hour: components.hour, by: direction), minute: components.minute, second: components.second)
        case .minute:
            setTime(hour: components.hour, minute: TimeStepping.step(minute: components.minute, by: direction, interval: minuteInterval), second: components.second)
        case .second:
            setTime(hour: components.hour, minute: components.minute, second: TimeStepping.step(minute: components.second, by: direction, interval: 1))
        case .period:
            setTime(hour: (components.hour + 12) % 24, minute: components.minute, second: components.second)
        case .literal:
            break
        }
    }

    private func moveFocus(from part: TimeFieldLayout.Part, by offset: Int, layout: TimeFieldLayout) {
        let segments = layout.segments
        guard let index = segments.firstIndex(of: part) else { return }
        let target = index + offset
        guard segments.indices.contains(target) else { return }
        focusedSegment = segments[target]
    }

    /// Digits set the hour, minute or second as they're typed and move on once
    /// the segment is whole; the first letter of AM or PM picks the period.
    private func type(_ characters: String, into part: TimeFieldLayout.Part, layout: TimeFieldLayout) -> Bool {
        guard let components, let character = characters.first else { return false }
        if part == .period {
            let typed = String(character).lowercased()
            if calendar.amSymbol.lowercased().hasPrefix(typed), components.hour >= 12 {
                setTime(hour: components.hour - 12, minute: components.minute, second: components.second)
                return true
            }
            if calendar.pmSymbol.lowercased().hasPrefix(typed), components.hour < 12 {
                setTime(hour: components.hour + 12, minute: components.minute, second: components.second)
                return true
            }
            return calendar.amSymbol.lowercased().hasPrefix(typed) || calendar.pmSymbol.lowercased().hasPrefix(typed)
        }
        guard let digit = character.wholeNumberValue else { return false }
        let maximum = part == .hour ? layout.maximumTypedHour : 59
        var candidate = Int(typedDigits + String(digit)) ?? digit
        var digits = typedDigits + String(digit)
        if candidate > maximum {
            // Starts over: "13" in a 12-hour field is a new "3".
            candidate = digit
            digits = String(digit)
        }
        switch part {
        case .hour:
            guard let hour = layout.hour(fromTyped: candidate, currentHour: components.hour) else {
                typedDigits = digits
                return true
            }
            setTime(hour: hour, minute: components.minute, second: components.second)
        case .minute:
            setTime(hour: components.hour, minute: candidate, second: components.second)
        case .second:
            setTime(hour: components.hour, minute: components.minute, second: candidate)
        default:
            return false
        }
        // Whole once it has two digits, or once no second digit could follow.
        if digits.count >= 2 || candidate * 10 > maximum {
            typedDigits = ""
            moveFocus(from: part, by: 1, layout: layout)
        } else {
            typedDigits = digits
        }
        return true
    }
}

// MARK: - Previews

#Preview("Time field", traits: .fixedLayout(width: 320, height: 120)) {
    @Previewable @State var start: Date? = Date()
    @Previewable @State var run = Date()
    VStack(alignment: .leading, spacing: Spacing.md) {
        TimeField("Quiet hours start", selection: $start)
        TimeField("Daily at", selection: $run, minuteInterval: 15, showsSeconds: true)
    }
    .padding(Spacing.lg)
}
