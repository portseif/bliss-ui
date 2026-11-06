//
//  ThinkingSpinner.swift
//  BlissUI
//
//  The single indeterminate "thinking" / loading spinner.
//

import SwiftUI

/// Canonical indeterminate loading spinner. Use this anywhere a task is in flight
/// (update buttons, validating a license, detecting installed tools, syncing, an
/// "investigating" state, loading panes, etc.) instead of bespoke rotating-symbol
/// animations or ad-hoc `ProgressView()` calls, so every spinner looks identical.
///
/// A minimal rotating arc that respects the app's color system.
public struct ThinkingSpinner: View {
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2
    var color: Color = Grey.grey400

    @State private var isAnimating = false

    public init(size: CGFloat = 16, lineWidth: CGFloat = 2, color: Color = Grey.grey400) {
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [color.opacity(0), color]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(252) // 70% of 360
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 0.8).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

#Preview(traits: .fixedLayout(width: 200, height: 200)) {
    VStack(spacing: Spacing.xl) {
        ThinkingSpinner()
        ThinkingSpinner(size: 24, lineWidth: 2.5, color: Color.accent)
        ThinkingSpinner(size: 32, lineWidth: 3, color: Success.success500)
    }
    .padding()
}
