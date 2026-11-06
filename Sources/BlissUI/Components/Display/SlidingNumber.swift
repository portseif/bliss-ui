//
//  SlidingNumber.swift
//  BlissUI
//
//  An animated number display where each digit slides vertically
//  when the value changes. Inspired by motion-primitives sliding-number.
//

import SwiftUI

/// A number display with smooth vertical sliding animation for each digit
public struct SlidingNumber: View {
    let value: Int
    var font: Font = .system(size: 24, weight: .medium, design: .default)
    var color: Color = .primary
    var padToDigits: Int? = nil
    var tracking: CGFloat = 0

    public init(
        value: Int,
        font: Font = .system(size: 24, weight: .medium, design: .default),
        color: Color = .primary,
        padToDigits: Int? = nil,
        tracking: CGFloat = 0
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.padToDigits = padToDigits
        self.tracking = tracking
    }

    // Spring animation parameters (matching motion-primitives)
    private let springResponse: Double = 0.4
    private let springDamping: Double = 0.8

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
            // Minus sign for negative numbers
            if isNegative {
                Text("-")
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
                        tracking: tracking,
                        springResponse: springResponse,
                        springDamping: springDamping
                    )
                }
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
    let springResponse: Double
    let springDamping: Double

    // All possible digits stacked vertically
    private let digits = Array(0...9)

    var body: some View {
        // Measure the height of a single digit
        Text("0")
            .font(font)
            .tracking(tracking)
            .foregroundStyle(.clear)
            .overlay {
                GeometryReader { geometry in
                    let digitHeight = geometry.size.height

                    VStack(spacing: 0) {
                        ForEach(digits, id: \.self) { d in
                            Text("\(d)")
                                .font(font)
                                .tracking(tracking)
                                .foregroundStyle(color)
                                .frame(height: digitHeight)
                        }
                    }
                    .offset(y: -CGFloat(digit) * digitHeight)
                    .animation(
                        .spring(response: springResponse, dampingFraction: springDamping),
                        value: digit
                    )
                }
                .clipped()
            }
    }
}

// MARK: - Previews

#Preview("Basic Sliding Number") {
    struct DemoView: View {
        @State private var count = 0

        var body: some View {
            VStack(spacing: 32) {
                SlidingNumber(
                    value: count,
                    font: .system(size: 48, weight: .semibold, design: .default),
                    color: .primary
                )

                HStack(spacing: 16) {
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
            .padding(40)
        }
    }

    return DemoView()
}

#Preview("Padded Digits") {
    struct DemoView: View {
        @State private var seconds = 0

        var body: some View {
            VStack(spacing: 24) {
                // Timer-style display
                HStack(spacing: 4) {
                    SlidingNumber(
                        value: seconds / 60,
                        font: .system(size: 36, weight: .regular, design: .monospaced),
                        padToDigits: 2
                    )

                    Text(":")
                        .font(.system(size: 36, weight: .regular, design: .monospaced))

                    SlidingNumber(
                        value: seconds % 60,
                        font: .system(size: 36, weight: .regular, design: .monospaced),
                        padToDigits: 2
                    )
                }

                Button("Add 1 second") {
                    seconds += 1
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(40)
        }
    }

    return DemoView()
}
