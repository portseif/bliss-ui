//
//  ProgressRing.swift
//  BlissUI
//
//  A determinate progress ring with an optional center label — the round
//  counterpart to `ProgressBar`. Indeterminate work keeps using
//  `ThinkingSpinner`, the one spinner.
//

import SwiftUI

/// A circular progress ring, filling clockwise from 12 o'clock.
///
/// ```swift
/// ProgressRing(value: 0.4)
/// ProgressRing(value: done, total: steps, center: .percentage, size: 48)
/// ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Success.success500)
/// ```
public struct ProgressRing: View {
    /// What sits inside the ring.
    public enum CenterLabel {
        /// Nothing — a bare ring (the compact size for a row or a button).
        case none
        /// The whole percent, rounded down.
        case percentage
        /// Your own short text ("3/5"), looked up in your app's strings.
        case text(LocalizedStringKey)
    }

    private let value: Double
    private let total: Double
    private let center: CenterLabel
    private let tint: Color
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let font: Font?
    private let accessibilityLabel: LocalizedStringKey?

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - value: Progress toward `total`, clamped to the ring.
    ///   - total: The value that closes the ring.
    ///   - center: The label inside the ring.
    ///   - tint: The arc — a mark, like `ProgressBar`'s fill.
    ///   - size: The ring's diameter.
    ///   - lineWidth: The arc's thickness.
    ///   - font: The center label's font; nil picks one that fits `size`.
    ///   - accessibilityLabel: What VoiceOver calls the ring ("Progress" when nil).
    public init(
        value: Double,
        total: Double = 1,
        center: CenterLabel = .none,
        tint: Color = Color.accent,
        size: CGFloat = 32,
        lineWidth: CGFloat = 3,
        font: Font? = nil,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.value = value
        self.total = total
        self.center = center
        self.tint = tint
        self.size = size
        self.lineWidth = lineWidth
        self.font = font
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let fraction = DataMetrics.fraction(value, of: total)
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(DataTrack.color(colorScheme), lineWidth: lineWidth)
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // The toast's progress ring's spring, so they move alike.
                .animation(prefersReducedMotion ? nil : Animations.disclosure, value: fraction)
            centerLabel(fraction)
                .font(font ?? Self.centerFont(innerDiameter: size - lineWidth * 2))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, lineWidth + 1)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel.map { Text($0) } ?? Text("Progress", bundle: .module))
        .accessibilityValue(Text(fraction, format: DataMetrics.percentFormat))
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private func centerLabel(_ fraction: Double) -> some View {
        switch center {
        case .none:
            EmptyView()
        case .percentage:
            Text(fraction, format: DataMetrics.percentFormat)
                .contentTransition(prefersReducedMotion ? .opacity : .numericText(value: fraction))
                .animation(prefersReducedMotion ? nil : Animations.disclosure, value: fraction)
        case .text(let text):
            Text(text)
        }
    }

    /// The largest token whose "100%" still fits inside the ring.
    static func centerFont(innerDiameter: CGFloat) -> Font {
        switch innerDiameter {
        case ..<28: return Typography.labelXTiny
        case ..<38: return Typography.labelTiny
        case ..<50: return Typography.caption
        case ..<72: return Typography.headingSmall
        default: return Typography.headingLarge
        }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 320, height: 120)) {
    HStack(spacing: Spacing.lg) {
        ProgressRing(value: 0.25)
        ProgressRing(value: 0.62, center: .percentage, size: 44)
        ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Success.success500, size: 56, lineWidth: 4)
        ProgressRing(value: 0.9, center: .percentage, tint: Warning.warning500, size: 72, lineWidth: 6)
    }
    .padding(Spacing.xl)
}
