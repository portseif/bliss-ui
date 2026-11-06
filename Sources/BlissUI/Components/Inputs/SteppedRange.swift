//
//  SteppedRange.swift
//  BlissUI
//
//  The arithmetic behind `NumberField` and `BlissSlider`: a closed range, the
//  step that moves through it, and how many fraction digits a value keeps.
//  Everything runs in `Double` so one implementation serves integer and
//  floating-point bindings; the components convert at their edges.
//

import Foundation

// MARK: - Stepped range

/// A range a value steps through. Steps land on a grid anchored at the lower
/// bound (or 0 when it's unbounded), so a field that starts at 1 with a step of
/// 5 goes 1, 6, 11 — and an off-grid value (typed, or set from outside) snaps
/// to the next grid point in the direction of the step before moving on.
struct SteppedRange: Equatable {
    var range: ClosedRange<Double>
    /// The distance one step moves. 0 or less means continuous (no grid).
    var step: Double
    /// The digits after the decimal point a value keeps — 0 for integers.
    var fractionDigits: Int

    /// Shift multiplies a keyboard step by this.
    static let largeStepMultiplier = 10

    /// The most fraction digits a derived precision uses.
    static let maximumFractionDigits = 6

    init(range: ClosedRange<Double>, step: Double, fractionDigits: Int? = nil) {
        self.range = range
        self.step = step
        self.fractionDigits = fractionDigits.map { min(max($0, 0), Self.maximumFractionDigits) }
            ?? Self.derivedFractionDigits(step: step, lowerBound: range.lowerBound)
    }

    /// The precision a step implies: 0.05 keeps two digits, 0.5 one, 1 none.
    /// A lower bound off the integer grid (0.5…10 in whole steps) counts too,
    /// since every grid point inherits its fraction.
    static func derivedFractionDigits(step: Double, lowerBound: Double) -> Int {
        var digits = fractionDigits(of: step)
        if lowerBound.isFinite { digits = max(digits, fractionDigits(of: lowerBound)) }
        return digits
    }

    /// How many decimal places `value` needs, up to `maximumFractionDigits`.
    static func fractionDigits(of value: Double) -> Int {
        guard value.isFinite else { return 0 }
        for digits in 0..<maximumFractionDigits {
            let scaled = abs(value) * pow(10, Double(digits))
            if abs(scaled - scaled.rounded()) < 1e-9 * max(1, scaled) { return digits }
        }
        return maximumFractionDigits
    }

    /// Where the grid starts.
    private var gridAnchor: Double {
        range.lowerBound.isFinite ? range.lowerBound : 0
    }

    var isContinuous: Bool { step <= 0 || !step.isFinite }

    // MARK: Clamping and rounding

    func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// `value` at the kept precision — so 0.1 + 0.2 lands on 0.3, and a typed
    /// 0.333 in a 0.01 field is stored as what the field will show.
    func rounded(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        let scale = pow(10, Double(fractionDigits))
        return (value * scale).rounded() / scale
    }

    /// A typed or dragged value as it's stored: rounded, then clamped.
    func normalized(_ value: Double) -> Double {
        clamped(rounded(value))
    }

    // MARK: Stepping

    /// `value` moved by `steps` (negative steps down). An off-grid value first
    /// snaps to the grid in the step's direction — 2.37 in 0.5 steps goes up to
    /// 2.5, down to 2.0 — and the result is clamped to the range.
    func stepped(_ value: Double, by steps: Int) -> Double {
        guard steps != 0 else { return normalized(value) }
        guard !isContinuous else { return normalized(value + Double(steps) * continuousKeyboardStep) }
        let position = (value - gridAnchor) / step
        let nearest = position.rounded()
        let base: Double
        if abs(position - nearest) < 1e-9 * max(1, abs(position)) {
            base = nearest
        } else {
            base = steps > 0 ? position.rounded(.down) : position.rounded(.up)
        }
        return normalized(gridAnchor + (base + Double(steps)) * step)
    }

    /// The nearest grid point to `value`, clamped — where a drag lands.
    func snapped(_ value: Double) -> Double {
        guard !isContinuous else { return normalized(value) }
        let position = ((value - gridAnchor) / step).rounded()
        return normalized(gridAnchor + position * step)
    }

    /// Whether a step in that direction would change `value` — the stepper
    /// buttons disable at the ends of the range.
    func canStep(from value: Double, by steps: Int) -> Bool {
        stepped(value, by: steps) != normalized(value)
    }

    /// One arrow-key press on a continuous range: 1% of it (Shift: 10%).
    var continuousKeyboardStep: Double {
        let span = range.upperBound - range.lowerBound
        return span.isFinite && span > 0 ? span / 100 : 1
    }

    /// Steps for one key press: Shift takes ten.
    static func steps(direction: Int, isLarge: Bool) -> Int {
        direction * (isLarge ? largeStepMultiplier : 1)
    }

    // MARK: Fractions (sliders)

    /// Where `value` sits in the range, 0…1.
    func fraction(of value: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, span.isFinite else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// The value at `fraction` (0…1) of the range, before snapping.
    func value(atFraction fraction: Double) -> Double {
        range.lowerBound + min(max(fraction, 0), 1) * (range.upperBound - range.lowerBound)
    }

    /// The grid points' fractions, for tick marks — empty when continuous or
    /// when there'd be more than `limit` of them (too dense to read).
    func tickFractions(limit: Int) -> [Double] {
        guard !isContinuous else { return [] }
        let span = range.upperBound - range.lowerBound
        guard span > 0, span.isFinite else { return [] }
        let intervals = Int((span / step + 1e-9).rounded(.down))
        guard intervals >= 1, intervals < limit else { return [] }
        return (0...intervals).map { index in
            fraction(of: range.lowerBound + Double(index) * step)
        }
    }
}

// MARK: - Typed numbers

/// Formatting and parsing a number the way the user's locale writes it.
enum NumberFieldText {
    /// `value` with exactly `fractionDigits` decimals, no grouping — a field
    /// that edits "1,024" would trip over its own separator.
    static func format(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        // -0.0 (stepping down onto zero) would print as "-0".
        (value == 0 ? 0 : value).formatted(
            FloatingPointFormatStyle<Double>(locale: locale)
                .precision(.fractionLength(fractionDigits))
                .grouping(.never)
        )
    }

    /// The number in `text`, or nil when it doesn't read as one ("", "-", "1.2.3").
    static func parse(_ text: String, locale: Locale) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard isWellFormed(trimmed, locale: locale) else { return nil }
        let style = FloatingPointFormatStyle<Double>(locale: locale)
        // As typed, then with a hyphen for the Unicode minus (or the reverse,
        // for a locale that formats with U+2212).
        let candidates = [trimmed, trimmed.replacingOccurrences(of: unicodeMinus, with: "-"), trimmed.replacingOccurrences(of: "-", with: unicodeMinus)]
        for candidate in candidates {
            if let value = try? Double(candidate, format: style, lenient: false), value.isFinite {
                return value
            }
        }
        return nil
    }

    /// Digits with at most one decimal separator and a minus only in front —
    /// the parser alone reads "1.2.3" as 1.2.
    static func isWellFormed(_ text: String, locale: Locale) -> Bool {
        let decimalSeparator = locale.decimalSeparator ?? "."
        var body = Substring(text)
        if let first = body.first, first == "-" || String(first) == unicodeMinus { body = body.dropFirst() }
        guard body.contains(where: \.isNumber) else { return false }
        let parts = body.components(separatedBy: decimalSeparator)
        return parts.count <= 2 && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    /// `text` with everything a number can't contain taken out: digits, plus
    /// the locale's decimal separator when fractions are allowed and a minus
    /// sign when negatives are.
    static func filtered(_ text: String, allowsFraction: Bool, allowsNegative: Bool, locale: Locale) -> String {
        let decimalSeparator = locale.decimalSeparator ?? "."
        return String(text.filter { character in
            if character.isNumber { return true }
            if allowsFraction, String(character) == decimalSeparator { return true }
            if allowsNegative, character == "-" || String(character) == Self.unicodeMinus { return true }
            return false
        })
    }

    /// U+2212, the minus some locales format negatives with.
    static let unicodeMinus = "\u{2212}"

    /// A string as wide as the widest of `samples`, digits widened to "0", so
    /// a field sized to it fits every value in range without resizing.
    static func widthTemplate(for samples: [String], maximumLength: Int = 10) -> String {
        let longest = samples.max { $0.count < $1.count } ?? ""
        let widened = String(longest.prefix(maximumLength).map { $0.isNumber ? "0" : $0 })
        return widened.count < 2 ? "00" : widened
    }
}
