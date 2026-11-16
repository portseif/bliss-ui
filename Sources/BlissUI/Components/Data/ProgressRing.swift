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
/// ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Success.success500, label: "Steps")
/// ```
public struct ProgressRing: View {
    /// What sits inside the ring: `ProgressReadout`, the same choices as a
    /// bar's readout.
    public typealias CenterLabel = ProgressReadout

    private let value: Double
    private let total: Double
    private let center: ProgressReadout
    private let tint: Color
    private let size: CGFloat
    private let lineWidth: CGFloat
    private let font: Font?
    private let label: LocalizedStringKey?
    private let accessibilityLabel: LocalizedStringKey?

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - value: Progress toward `total`, clamped to the ring.
    ///   - total: The value that closes the ring.
    ///   - center: The label inside the ring.
    ///   - tint: The arc — a mark, like `ProgressBar`'s fill.
    ///   - size: The ring's diameter.
    ///   - lineWidth: The arc's thickness; nil picks one for `size` (3 up to
    ///     40pt, 4 up to 64, 6 past that).
    ///   - font: The center label's font; nil picks one that fits `size`.
    ///   - label: A caption under the ring, looked up in your app's strings.
    ///     Also what VoiceOver calls the ring unless `accessibilityLabel` says otherwise.
    ///   - accessibilityLabel: What VoiceOver calls the ring ("Progress" when
    ///     neither label is set).
    public init(
        value: Double,
        total: Double = 1,
        center: ProgressReadout = .none,
        tint: Color = Color.accent,
        size: CGFloat = Sizing.controlMedium,
        lineWidth: CGFloat? = nil,
        font: Font? = nil,
        label: LocalizedStringKey? = nil,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.value = value
        self.total = total
        self.center = center
        self.tint = tint
        self.size = size
        self.lineWidth = lineWidth ?? Self.lineWidth(for: size)
        self.font = font
        self.label = label
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let fraction = DataMetrics.fraction(value, of: total)
        VStack(spacing: Spacing.xs) {
            ring(fraction)
            if let label {
                Text(label)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((accessibilityLabel ?? label).map { Text($0) } ?? Text("Progress", bundle: .module))
        .accessibilityValue(Text(fraction, format: DataMetrics.percentFormat))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func ring(_ fraction: Double) -> some View {
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
                .minimumScaleFactor(DataMetrics.minimumScaleFactor)
                // Clear of the arc by a point: the label's box is the inner diameter.
                .padding(.horizontal, lineWidth + 1)
        }
        .frame(width: size, height: size)
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

    /// The arc for a diameter: a hair thicker as the ring grows, so a 72pt
    /// ring doesn't draw a 32pt ring's thread.
    static func lineWidth(for size: CGFloat) -> CGFloat {
        let medium = Sizing.controlXLarge
        let large = Sizing.controlXLarge + Sizing.iconLarge
        if size < medium { return 3 }
        if size < large { return 4 }
        return 6
    }

    /// The largest token whose "100%" still fits inside the ring. The
    /// breakpoints are measured: the inner diameter at which "100%" in the
    /// next token up stops fitting.
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

#Preview(traits: .fixedLayout(width: 360, height: 140)) {
    HStack(alignment: .top, spacing: Spacing.lg) {
        ProgressRing(value: 0.25)
        ProgressRing(value: 0.62, center: .percentage, size: 44)
        ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Success.success500, size: 56, label: "Steps")
        ProgressRing(value: 0.9, center: .percentage, tint: Warning.warning500, size: 72)
    }
    .padding(Spacing.xl)
}
