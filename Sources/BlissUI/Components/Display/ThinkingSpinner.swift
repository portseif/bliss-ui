//
//  ThinkingSpinner.swift
//  BlissUI
//
//  The single indeterminate "thinking" / loading spinner.
//

import SwiftUI

/// The spinner's sizes: the arc's diameter and stroke.
public enum SpinnerSize: Hashable, Sendable {
    /// 14pt — inside a field or a compact button.
    case small
    /// 16pt — the default, beside a row's text.
    case regular
    /// 24pt — a pane or a card that's loading.
    case large

    var diameter: CGFloat {
        switch self {
        case .small: Sizing.iconSmall
        case .regular: Sizing.iconDefault
        case .large: Sizing.iconLarge
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .small: 1.5
        case .regular: 2
        case .large: 2.5
        }
    }
}

/// Canonical indeterminate loading spinner. Use this anywhere a task is in flight
/// (update buttons, validating a license, detecting installed tools, syncing, an
/// "investigating" state, loading panes, etc.) instead of bespoke rotating-symbol
/// animations or ad-hoc `ProgressView()` calls, so every spinner looks identical.
///
/// A minimal rotating arc that respects the app's color system. Under Reduce
/// Motion the arc holds still. VoiceOver reads `label` ("Loading").
public struct ThinkingSpinner: View {
    var size: CGFloat = Sizing.iconDefault
    var lineWidth: CGFloat = 2
    var color: Color = Grey.grey400
    var label: Text? = Text("Loading", bundle: .blissUI)

    /// The arc at any diameter and stroke.
    public init(size: CGFloat = Sizing.iconDefault, lineWidth: CGFloat = 2, color: Color = Grey.grey400, label: Text? = Text("Loading", bundle: .blissUI)) {
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.label = label
    }

    /// The arc at one of the shared sizes.
    public init(size: SpinnerSize, color: Color = Grey.grey400, label: Text? = Text("Loading", bundle: .blissUI)) {
        self.init(size: size.diameter, lineWidth: size.lineWidth, color: color, label: label)
    }

    /// 70% of the circle, so the gradient's clear end meets its solid end.
    private static let arcFraction: Double = 0.7
    /// One turn takes this long.
    private static let period: TimeInterval = 0.8

    // It turns by the clock rather than by a repeating animation started on
    // appear: that animation took along whatever else changed as the spinner
    // arrived, so a spinner that appeared while its row was laid out again
    // slid back and forth between the two places forever.
    public var body: some View {
        TimelineView(.animation(paused: prefersReducedMotion)) { timeline in
            let turn = prefersReducedMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
            Circle()
                .trim(from: 0, to: Self.arcFraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0), color]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * Self.arcFraction)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // Keeps the stroke's outer half inside the frame.
                .padding(lineWidth / 2)
                .rotationEffect(.degrees(turn * 360))
        }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? Text(verbatim: ""))
            .accessibilityHidden(label == nil)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview(traits: .fixedLayout(width: 200, height: 200)) {
    VStack(spacing: Spacing.xl) {
        ThinkingSpinner()
        ThinkingSpinner(size: .large, color: Color.accent)
        ThinkingSpinner(size: Sizing.iconXLarge, lineWidth: 3, color: Success.success500)
    }
    .padding()
}
