//
//  NumberField.swift
//  BlissUI
//
//  A formatted number between − and + buttons, in the shared input box:
//  - Typing applies as it goes (clamped to the range); Return or leaving the
//    field shows the number that took, so invalid input reverts
//  - ↑ / ↓ step it, Shift steps ten at a time; the buttons repeat while held
//  - An optional unit after the number ("days", "px")
//
//  Replaces a native `Stepper`, which shows the system focus ring instead of
//  the shared one and is only a Tab stop with Keyboard navigation on.
//

import AppKit
import SwiftUI

/// A number field with − / + buttons, a range, a step and an optional unit.
///
/// ```swift
/// NumberField("Days to keep", value: $retentionDays, in: 1...365, unit: "days")
/// NumberField("Line height", value: $lineHeight, in: 1...3, step: 0.1)
/// ```
///
/// `title` is what VoiceOver reads; it isn't drawn, so put a visible label
/// beside the field (a form row's title). Steps land on a grid anchored at the
/// range's lower bound. Integer bindings show no decimals; floating-point ones
/// show as many as `step` needs unless you pass `fractionDigits`. Follows
/// `.controlSize` (`.small` for dense rows).
public struct NumberField<Value>: View {
    private let title: LocalizedStringKey
    @Binding private var value: Value
    private let stepping: SteppedRange
    private let unit: LocalizedStringKey?
    private let toDouble: (Value) -> Double
    private let fromDouble: (Double) -> Value

    @Environment(\.locale) private var locale
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    /// What's typed, applied to `value` as it changes. A `TextField(value:)`
    /// only commits on Return or losing focus, so a sheet's Save (its Return
    /// shortcut) could run with the number from before.
    @State private var text = ""
    /// The value the last keystroke applied. When `value` changes to it, the
    /// text stays as typed — "5" on its way to "50" in a field whose minimum
    /// is 10 shouldn't turn into "10" under the cursor.
    @State private var typedValue: Double?

    private init(
        title: LocalizedStringKey,
        value: Binding<Value>,
        stepping: SteppedRange,
        unit: LocalizedStringKey?,
        toDouble: @escaping (Value) -> Double,
        fromDouble: @escaping (Double) -> Value
    ) {
        self.title = title
        self._value = value
        self.stepping = stepping
        self.unit = unit
        self.toDouble = toDouble
        self.fromDouble = fromDouble
    }

    // MARK: Metrics

    /// Button side, number font and glyph font for the control size. The
    /// buttons sit `Spacing.hairline` inside the box, so the box is the control
    /// height: 28pt like the compact buttons, 24pt small.
    private var metrics: (buttonSize: CGFloat, font: Font, glyphFont: Font) {
        switch controlSize {
        case .mini, .small:
            return (Sizing.controlSmall - 2 * Spacing.hairline, Typography.labelSmall, Typography.labelXTinyBold)
        default:
            return (Sizing.controlDefault - 2 * Spacing.hairline, Typography.bodySmall, Typography.labelTinyBold)
        }
    }

    // MARK: Body

    public var body: some View {
        let metrics = metrics
        let current = toDouble(value)
        HStack(spacing: Spacing.hairline) {
            stepButton(direction: -1, systemImage: "minus", label: Text("Decrement", bundle: .module), current: current, size: metrics.buttonSize, font: metrics.glyphFont)
            numberArea(current: current, font: metrics.font)
            stepButton(direction: 1, systemImage: "plus", label: Text("Increment", bundle: .module), current: current, size: metrics.buttonSize, font: metrics.glyphFont)
        }
        .padding(Spacing.hairline)
        .inputBox(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .onAppear { text = formatted(current) }
        // − / +, the arrows, the binding changing elsewhere: show the number
        // that took. A keystroke's own change keeps the text as typed.
        .onChange(of: current) { _, newValue in
            if let typedValue, stepping.rounded(newValue) == typedValue { return }
            typedValue = nil
            let display = formatted(newValue)
            if text != display { text = display }
        }
        .onChange(of: locale) { _, _ in commit() }
    }

    private func numberArea(current: Double, font: Font) -> some View {
        HStack(spacing: Spacing.xxs) {
            ZStack(alignment: unit == nil ? .center : .trailing) {
                // Sizes the field to the widest value in range, so it never
                // resizes (and the buttons never shift) as the number changes.
                Text(verbatim: widthTemplate)
                    .hidden()
                    .accessibilityHidden(true)
                TextField(title, text: $text, prompt: Text(verbatim: formatted(current)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(unit == nil ? .center : .trailing)
                    .focused($isFocused)
                    .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                        let direction = press.key == .upArrow ? 1 : -1
                        step(by: SteppedRange.steps(direction: direction, isLarge: press.modifiers.contains(.shift)))
                        return .handled
                    }
                    .onSubmit { commit() }
                    .onChange(of: text) { _, newText in apply(typed: newText) }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    .accessibilityValue(accessibilityValue(for: current))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: step(by: 1)
                        case .decrement: step(by: -1)
                        @unknown default: break
                        }
                    }
            }
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
                    // Read as part of the field's value.
                    .accessibilityHidden(true)
            }
        }
        .font(font.monospacedDigit())
        .padding(.horizontal, Spacing.xxs)
    }

    private func stepButton(direction: Int, systemImage: String, label: Text, current: Double, size: CGFloat, font: Font) -> some View {
        let canStep = stepping.canStep(from: current, by: direction)
        return Button {
            // Shift-click steps ten, like Shift-↑.
            step(by: SteppedRange.steps(direction: direction, isLarge: NSEvent.modifierFlags.contains(.shift)))
        } label: {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(canStep && isEnabled ? .secondary : .quaternary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
        .buttonRepeatBehavior(.enabled)
        .disabled(!canStep)
        .accessibilityLabel(label)
    }

    // MARK: Editing

    private func step(by steps: Int) {
        guard isEnabled else { return }
        let next = stepping.stepped(toDouble(value), by: steps)
        typedValue = nil
        if toDouble(value) != next { value = fromDouble(next) }
        // Even when the value didn't move (already at the bound), the text
        // may still hold something typed past it.
        let display = formatted(next)
        if text != display { text = display }
    }

    /// Keeps what can be part of a number, and applies it once it reads as one.
    private func apply(typed newText: String) {
        let filtered = NumberFieldText.filtered(
            newText,
            allowsFraction: stepping.fractionDigits > 0,
            allowsNegative: stepping.range.lowerBound < 0,
            locale: locale
        )
        guard filtered == newText else {
            text = filtered
            return
        }
        // Our own formatting coming back around.
        guard newText != formatted(toDouble(value)) else { return }
        guard let parsed = NumberFieldText.parse(filtered, locale: locale) else { return }
        let normalized = stepping.normalized(parsed)
        typedValue = normalized
        if stepping.rounded(toDouble(value)) != normalized { value = fromDouble(normalized) }
    }

    /// Return or leaving the field: show the number that took, so anything
    /// that didn't read as one (or ran past the range) reverts.
    private func commit() {
        typedValue = nil
        let display = formatted(toDouble(value))
        if text != display { text = display }
    }

    // MARK: Text

    private func formatted(_ number: Double) -> String {
        NumberFieldText.format(number, fractionDigits: stepping.fractionDigits, locale: locale)
    }

    private var widthTemplate: String {
        let bounds = [stepping.range.lowerBound, stepping.range.upperBound]
        let samples = bounds.map { $0.isFinite ? formatted($0) : String(repeating: "0", count: 6) }
        return NumberFieldText.widthTemplate(for: samples)
    }

    /// The number and its unit, composed rather than localized — the unit is
    /// the caller's string, already in the app's language, so the key here
    /// ("%@ %@") never needs a translation.
    private func accessibilityValue(for number: Double) -> Text {
        guard let unit else { return Text(verbatim: formatted(number)) }
        return Text("\(formatted(number)) \(Text(unit))")
    }
}

// MARK: - Initializers

extension NumberField where Value: BinaryInteger {
    /// A whole-number field.
    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - value: The number. Typing applies as it goes, clamped to `range`.
    ///   - range: The lowest and highest values.
    ///   - step: How far − / + and ↑ / ↓ move it (Shift: ten steps).
    ///   - unit: Drawn after the number ("days", "px"), from your app's strings.
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value = 1,
        unit: LocalizedStringKey? = nil
    ) {
        let lowerBound = range.lowerBound
        let upperBound = range.upperBound
        self.init(
            title: title,
            value: value,
            stepping: SteppedRange(range: Double(lowerBound)...Double(upperBound), step: Double(step), fractionDigits: 0),
            unit: unit,
            toDouble: { Double($0) },
            // A value past what `Value` holds (Int.max through Double) takes the bound.
            fromDouble: { number in
                Value(exactly: number.rounded()) ?? (number <= Double(lowerBound) ? lowerBound : upperBound)
            }
        )
    }
}

extension NumberField where Value: BinaryFloatingPoint {
    /// A decimal field.
    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - value: The number. Typing applies as it goes, clamped to `range`.
    ///   - range: The lowest and highest values.
    ///   - step: How far − / + and ↑ / ↓ move it (Shift: ten steps).
    ///   - fractionDigits: Decimals shown and kept; nil takes what `step` needs.
    ///   - unit: Drawn after the number ("px", "s"), from your app's strings.
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value = 1,
        fractionDigits: Int? = nil,
        unit: LocalizedStringKey? = nil
    ) {
        self.init(
            title: title,
            value: value,
            stepping: SteppedRange(range: Double(range.lowerBound)...Double(range.upperBound), step: Double(step), fractionDigits: fractionDigits),
            unit: unit,
            toDouble: { Double($0) },
            fromDouble: { Value($0) }
        )
    }
}

// MARK: - Previews

#Preview("Number field", traits: .fixedLayout(width: 320, height: 200)) {
    @Previewable @State var days = 30
    @Previewable @State var port = 2222
    @Previewable @State var opacity = 0.85

    VStack(alignment: .leading, spacing: Spacing.md) {
        NumberField("Days to keep", value: $days, in: 1...365, unit: "days")
        NumberField("Port", value: $port, in: 1...65_535)
        NumberField("Opacity", value: $opacity, in: 0...1, step: 0.05)
        NumberField("Days to keep", value: $days, in: 1...365, unit: "days")
            .controlSize(.small)
    }
    .padding(Spacing.lg)
}
