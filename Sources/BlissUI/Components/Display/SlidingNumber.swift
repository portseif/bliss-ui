//
//  SlidingNumber.swift
//  BlissUI
//
//  An animated number display where each digit slides vertically
//  when the value changes. Inspired by motion-primitives sliding-number.
//

import SwiftUI

/// A `SlidingNumber`'s type size.
public enum SlidingNumberSize: Hashable, Sendable {
    /// `headingLarge` (20pt) — a count in a row.
    case small
    /// `displayMediumMedium` (24pt) — the default.
    case regular
    /// `displayHero` (48pt) — a dashboard's one number.
    case large

    var font: Font {
        switch self {
        case .small: Typography.headingLarge
        case .regular: Typography.displayMediumMedium
        case .large: Typography.displayHero
        }
    }
}

/// A number display with smooth vertical sliding animation for each digit.
/// Under Reduce Motion the digits snap.
public struct SlidingNumber: View {
    let value: Int
    var font: Font = Typography.displayMediumMedium
    var color: Color = .primary
    var padToDigits: Int? = nil
    var tracking: CGFloat = 0
    var prefix: String? = nil
    var suffix: String? = nil

    /// - Parameters:
    ///   - value: The number.
    ///   - size: One of the shared type sizes.
    ///   - color: The digits' color.
    ///   - padToDigits: Leading zeros up to this many digits ("07").
    ///   - tracking: Letter spacing.
    ///   - prefix: Drawn before the digits in the same font ("$").
    ///   - suffix: Drawn after them ("%", "ms").
    public init(
        value: Int,
        size: SlidingNumberSize = .regular,
        color: Color = .primary,
        padToDigits: Int? = nil,
        tracking: CGFloat = 0,
        prefix: String? = nil,
        suffix: String? = nil
    ) {
        self.value = value
        self.font = size.font
        self.color = color
        self.padToDigits = padToDigits
        self.tracking = tracking
        self.prefix = prefix
        self.suffix = suffix
    }

    /// The digits in a font of your own (a `Typography` token).
    public init(
        value: Int,
        font: Font,
        color: Color = .primary,
        padToDigits: Int? = nil,
        tracking: CGFloat = 0,
        prefix: String? = nil,
        suffix: String? = nil
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.padToDigits = padToDigits
        self.tracking = tracking
        self.prefix = prefix
        self.suffix = suffix
    }

    private var displayString: String {
        if let pad = padToDigits {
            return String(format: "%0\(pad)d", abs(value))
        }
        return String(abs(value))
    }

    private var isNegative: Bool {
        value < 0
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let prefix {
                Text(verbatim: prefix)
                    .font(font)
                    .foregroundStyle(color)
            }

            // Minus sign for negative numbers
            if isNegative {
                Text(verbatim: "-")
                    .font(font)
                    .foregroundStyle(color)
            }

            // Each digit gets its own sliding column
            ForEach(Array(displayString.enumerated()), id: \.offset) { index, character in
                if character == "," || character == "." {
                    Text(String(character))
                        .font(font)
                        .foregroundStyle(color)
                        .tracking(tracking)
                } else if let digit = Int(String(character)) {
                    SlidingDigit(
                        digit: digit,
                        font: font,
                        color: color,
                        tracking: tracking
                    )
                }
            }

            if let suffix {
                Text(verbatim: suffix)
                    .font(font)
                    .foregroundStyle(color)
            }
        }
    }
}

/// A single sliding digit column
private struct SlidingDigit: View {
    let digit: Int
    let font: Font
    let color: Color
    var tracking: CGFloat = 0

    // All possible digits stacked vertically
    private let digits = Array(0...9)

    var body: some View {
        // Measure the height of a single digit
        Text(verbatim: "0")
            .font(font)
            .tracking(tracking)
            .foregroundStyle(.clear)
            .overlay {
                GeometryReader { geometry in
                    let digitHeight = geometry.size.height

                    VStack(spacing: 0) {
                        ForEach(digits, id: \.self) { d in
                            Text(verbatim: "\(d)")
                                .font(font)
                                .tracking(tracking)
                                .foregroundStyle(color)
                                .frame(height: digitHeight)
                        }
                    }
                    .offset(y: -CGFloat(digit) * digitHeight)
                    // A sliding column is motion: under Reduce Motion it snaps.
                    .animation(prefersReducedMotion ? nil : Animations.slidingNumber, value: digit)
                }
                .clipped()
            }
    }
}

// MARK: - Previews

#Preview("Basic Sliding Number", traits: .fixedLayout(width: 420, height: 260)) {
    struct DemoView: View {
        @State private var count = 0

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                SlidingNumber(value: count, size: .large)

                HStack(spacing: Spacing.lg) {
                    Button("-10") { count -= 10 }
                        .buttonStyle(SecondaryButtonStyle())

                    Button("-1") { count -= 1 }
                        .buttonStyle(SecondaryButtonStyle())

                    Button("+1") { count += 1 }
                        .buttonStyle(PrimaryButtonStyle())

                    Button("+10") { count += 10 }
                        .buttonStyle(PrimaryButtonStyle())
                }

                Button("Random") {
                    count = Int.random(in: 0...9999)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Spacing.xxl)
        }
    }

    return DemoView()
}

#Preview("Padded Digits", traits: .fixedLayout(width: 360, height: 200)) {
    struct DemoView: View {
        @State private var seconds = 0

        var body: some View {
            VStack(spacing: Spacing.xl) {
                // Timer-style display
                HStack(spacing: Spacing.xxs) {
                    SlidingNumber(value: seconds / 60, font: Typography.codeLarge, padToDigits: 2)
                    Text(verbatim: ":")
                        .font(Typography.codeLarge)
                    SlidingNumber(value: seconds % 60, font: Typography.codeLarge, padToDigits: 2)
                }

                SlidingNumber(value: seconds, size: .small, prefix: "$", suffix: ".00")

                Button("Add 1 second") {
                    seconds += 1
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Spacing.xxl)
        }
    }

    return DemoView()
}
