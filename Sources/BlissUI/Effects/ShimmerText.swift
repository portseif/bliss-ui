//
//  ShimmerText.swift
//  BlissUI
//
//  A text view with an animated shimmer effect that sweeps across the text.
//  Inspired by motion-primitives text-shimmer component.
//

import SwiftUI

/// Text with a bright band sweeping across it. Animates a masked gradient's
/// `.offset` — a gradient `ShapeStyle`'s stored phase doesn't interpolate in
/// SwiftUI, so a style-based shimmer jumps to its end state instead of sweeping.
public struct ShimmerTextOverlay: View {
    /// One sweep, in seconds — the pace a progress toast's phase text sweeps at.
    public static let defaultDuration: Double = 2.2
    /// The band's width as a fraction of the text's width.
    public static let defaultBandWidth: CGFloat = 0.4

    private let label: Text
    var font: Font = Typography.labelMedium
    var baseColor: Color = .secondary
    var shimmerColor: Color = .primary
    var duration: Double = ShimmerTextOverlay.defaultDuration
    var shimmerWidth: CGFloat = ShimmerTextOverlay.defaultBandWidth
    var isActive = true

    /// - Parameters:
    ///   - text: The text to draw, as-is.
    ///   - font: The text's font.
    ///   - baseColor: The text's resting color.
    ///   - shimmerColor: The color of the band that sweeps across it.
    ///   - duration: Seconds for one sweep.
    ///   - shimmerWidth: The band's width, as a fraction of the text's width.
    ///   - isActive: Stops the sweep without swapping the view — the text stays
    ///     where it is in its resting color when the work finishes.
    public init(
        text: String,
        font: Font = Typography.labelMedium,
        baseColor: Color = .secondary,
        shimmerColor: Color = .primary,
        duration: Double = ShimmerTextOverlay.defaultDuration,
        shimmerWidth: CGFloat = ShimmerTextOverlay.defaultBandWidth,
        isActive: Bool = true
    ) {
        self.init(label: Text(verbatim: text), font: font, baseColor: baseColor, shimmerColor: shimmerColor, duration: duration, shimmerWidth: shimmerWidth, isActive: isActive)
    }

    /// The same, for a key looked up in your app's strings.
    public init(
        _ text: LocalizedStringKey,
        font: Font = Typography.labelMedium,
        baseColor: Color = .secondary,
        shimmerColor: Color = .primary,
        duration: Double = ShimmerTextOverlay.defaultDuration,
        shimmerWidth: CGFloat = ShimmerTextOverlay.defaultBandWidth,
        isActive: Bool = true
    ) {
        self.init(label: Text(text), font: font, baseColor: baseColor, shimmerColor: shimmerColor, duration: duration, shimmerWidth: shimmerWidth, isActive: isActive)
    }

    private init(label: Text, font: Font, baseColor: Color, shimmerColor: Color, duration: Double, shimmerWidth: CGFloat, isActive: Bool) {
        self.label = label
        self.font = font
        self.baseColor = baseColor
        self.shimmerColor = shimmerColor
        self.duration = duration
        self.shimmerWidth = shimmerWidth
        self.isActive = isActive
    }

    public var body: some View {
        ZStack {
            // Base text layer
            label
                .font(font)
                .foregroundStyle(baseColor)

            // Reduce Motion (or a finished job): just the base text, no sweeping band.
            if isActive && !prefersReducedMotion {
                // Shimmer overlay. The band position is derived from the clock via
                // TimelineView rather than a repeatForever withAnimation — a state-driven
                // sweep gets cancelled when any ambient transaction re-writes the offset
                // (a progress toast re-renders in place on every progress tick / phase text
                // change, which is exactly that), and `.onAppear` never re-fires to
                // restart it. Time-driven, the sweep survives any re-render.
                label
                    .font(font)
                    .foregroundStyle(shimmerColor)
                    .mask(
                        GeometryReader { geometry in
                            TimelineView(.animation) { timeline in
                                // Same travel as the old animation: -1 → 1 + shimmerWidth
                                // (fully off-left, sweep across, fully off-right, repeat).
                                let progress = timeline.date.timeIntervalSinceReferenceDate
                                    .truncatingRemainder(dividingBy: duration) / duration
                                let phase = -1 + (2 + shimmerWidth) * progress
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            stops: [
                                                .init(color: .clear, location: 0),
                                                .init(color: .white, location: 0.3),
                                                .init(color: .white, location: 0.5),
                                                .init(color: .white, location: 0.7),
                                                .init(color: .clear, location: 1)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * shimmerWidth)
                                    .offset(x: geometry.size.width * phase)
                            }
                        }
                    )
            }
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Applies a shimmer effect to text.
    ///
    /// Deprecated: its overlay blend is a no-op on near-white text and its
    /// `repeatForever` animation is cancelled by the next re-render of the view
    /// (see `ShimmerTextOverlay`, which is time-driven and survives them).
    @available(*, deprecated, message: "Use ShimmerTextOverlay: the overlay blend does nothing on light text and the animation doesn't survive a re-render.")
    public func shimmer(
        baseColor: Color = .secondary,
        shimmerColor: Color = .primary,
        duration: Double = ShimmerTextOverlay.defaultDuration
    ) -> some View {
        modifier(ShimmerModifier(
            baseColor: baseColor,
            shimmerColor: shimmerColor,
            duration: duration
        ))
    }
}

private struct ShimmerModifier: ViewModifier {
    var baseColor: Color
    var shimmerColor: Color
    var duration: Double

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: shimmerColor.opacity(0.5), location: 0.4),
                                    .init(color: shimmerColor.opacity(0.8), location: 0.5),
                                    .init(color: shimmerColor.opacity(0.5), location: 0.6),
                                    .init(color: .clear, location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * ShimmerTextOverlay.defaultBandWidth)
                        .offset(x: geometry.size.width * (phase - 0.2))
                        .blendMode(.overlay)
                }
            )
            .mask(content)
            .onAppear {
                guard !prefersReducedMotion else { return }
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.2
                }
            }
    }
}

// MARK: - Previews

#Preview("Shimmer text", traits: .fixedLayout(width: 300, height: 120)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ShimmerTextOverlay(text: "Scanning directory")
        ShimmerTextOverlay("Thinking…", font: Typography.bodyMedium)
        ShimmerTextOverlay(text: "Done", isActive: false)
    }
    .padding(Spacing.xl)
}
