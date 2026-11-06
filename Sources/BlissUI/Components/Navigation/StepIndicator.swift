//
//  StepIndicator.swift
//  BlissUI
//
//  A row of dots for a wizard: the current step full-strength and a touch
//  larger, completed steps at 0.55, the ones ahead at 0.25.
//

import SwiftUI

/// Horizontal step dots for a multi-step flow.
public struct StepIndicator: View {
    let stepCount: Int
    let currentIndex: Int
    /// The dots' color. Pass `.white` on a fixed dark panel — never the accent's
    /// contrast color, which a light accent turns black.
    var color: Color = .primary

    public init(stepCount: Int, currentIndex: Int, color: Color = .primary) {
        self.stepCount = stepCount
        self.currentIndex = currentIndex
        self.color = color
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<max(stepCount, 0), id: \.self) { index in
                stepDot(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(currentIndex + 1) of \(stepCount)"))
    }

    // MARK: - Step Dot

    private func stepDot(at index: Int) -> some View {
        let isCompleted = index < currentIndex
        let isCurrent = index == currentIndex

        return Circle()
            .fill(color.opacity(isCurrent ? 1 : (isCompleted ? 0.55 : 0.25)))
            .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
            .frame(width: 8, height: 8)
            .animation(Animations.disclosure, value: currentIndex)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 200, height: 30)) {
    StepIndicator(stepCount: 5, currentIndex: 2)
        .padding()
}
