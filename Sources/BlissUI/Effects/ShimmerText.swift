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
    let text: String
    var font: Font = .body
    var baseColor: Color = .secondary
    var shimmerColor: Color = .primary
    var duration: Double = 5.0
    var shimmerWidth: CGFloat = 0.3

    /// - Parameters:
    ///   - text: The text to draw.
    ///   - font: The text's font.
    ///   - baseColor: The text's resting color.
    ///   - shimmerColor: The color of the band that sweeps across it.
    ///   - duration: Seconds for one sweep.
    ///   - shimmerWidth: The band's width, as a fraction of the text's width.
    public init(
        text: String,
        font: Font = .body,
        baseColor: Color = .secondary,
        shimmerColor: Color = .primary,
        duration: Double = 5.0,
        shimmerWidth: CGFloat = 0.3
    ) {
        self.text = text
        self.font = font
        self.baseColor = baseColor
        self.shimmerColor = shimmerColor
        self.duration = duration
        self.shimmerWidth = shimmerWidth
    }

    public var body: some View {
        ZStack {
            // Base text layer
            Text(text)
                .font(font)
                .foregroundStyle(baseColor)

            // Reduce Motion: just the base text, no sweeping band.
            if !prefersReducedMotion {
                // Shimmer overlay. The band position is derived from the clock via
                // TimelineView rather than a repeatForever withAnimation — a state-driven
                // sweep gets cancelled when any ambient transaction re-writes the offset
                // (a progress toast re-renders in place on every progress tick / phase text
                // change, which is exactly that), and `.onAppear` never re-fires to
                // restart it. Time-driven, the sweep survives any re-render.
                Text(text)
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
    /// Applies a shimmer effect to text
    public func shimmer(
        baseColor: Color = .secondary,
        shimmerColor: Color = .primary,
        duration: Double = 5.0
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
                        .frame(width: geometry.size.width * 0.4)
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

#Preview("Light Mode") {
    VStack(spacing: 24) {
        ShimmerTextOverlay(
            text: "Scanning directory",
            font: .subheadline,
            baseColor: Grey.grey300,
            shimmerColor: Grey.grey600,
            duration: 1.5
        )
    }
    .padding(40)
    .background(Color.white)
    .preferredColorScheme(.light)
}
