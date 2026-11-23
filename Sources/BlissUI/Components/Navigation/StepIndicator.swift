//
//  StepIndicator.swift
//  BlissUI
//
//  A row of dots for a wizard: the current step full-strength and a touch
//  larger, completed steps at 0.55, the ones ahead at 0.25. Or a bar of equal
//  segments (`.segments`), the onboarding / stories idiom. With `grows`, the
//  current dot stretches into a short line instead. Either runs along
//  an `axis`, can carry a label per step, and can let a completed step be
//  clicked to go back.
//

import SwiftUI

/// How a `StepIndicator` draws its steps.
public nonisolated enum StepIndicatorStyle: Sendable {
    /// A dot per step, the current one larger.
    case dots
    /// Equal capsule segments that fill the width — the onboarding bar.
    case segments
}

/// Step dots (or segments) for a multi-step flow.
public struct StepIndicator: View {
    let stepCount: Int
    let currentIndex: Int
    /// The dots' color. Pass `.white` on a fixed dark panel — never the accent's
    /// contrast color, which a light accent turns black.
    var color: Color = .primary
    let axis: Axis
    let style: StepIndicatorStyle
    /// The current dot stretches into a short line along the axis.
    let grows: Bool
    let labels: [LocalizedStringKey]?
    let onSelect: ((Int) -> Void)?

    /// A completed step's and a pending step's tone.
    private static let completedOpacity: Double = 0.55
    private static let pendingOpacity: Double = 0.25
    /// How long the current dot grows with `grows`.
    private static let grownLength: CGFloat = Sizing.iconMedium

    /// - Parameters:
    ///   - stepCount: How many steps.
    ///   - currentIndex: The step the user is on, from 0.
    ///   - color: The marks' color.
    ///   - axis: Across (the default) or down, beside a vertical list of steps.
    ///   - style: Dots, or equal segments that fill the width.
    ///   - grows: With dots, the current one stretches into a short line,
    ///     sliding as the step changes.
    ///   - labels: One caption per step, drawn beside its mark.
    ///   - onSelect: Makes completed steps clickable (go back); the current and
    ///     pending ones stay inert.
    public init(
        stepCount: Int,
        currentIndex: Int,
        color: Color = .primary,
        axis: Axis = .horizontal,
        style: StepIndicatorStyle = .dots,
        grows: Bool = false,
        labels: [LocalizedStringKey]? = nil,
        onSelect: ((Int) -> Void)? = nil
    ) {
        self.stepCount = stepCount
        self.currentIndex = currentIndex
        self.color = color
        self.axis = axis
        self.style = style
        self.grows = grows
        self.labels = labels
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if axis == .horizontal {
                HStack(alignment: .top, spacing: Spacing.sm) { steps }
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) { steps }
            }
        }
        .accessibilityElement(children: onSelect == nil ? .ignore : .contain)
        .accessibilityLabel(Text("Step \(currentIndex + 1) of \(stepCount)", bundle: .module))
    }

    private var steps: some View {
        ForEach(0..<max(stepCount, 0), id: \.self) { index in
            step(at: index)
        }
    }

    // MARK: - Step

    @ViewBuilder
    private func step(at index: Int) -> some View {
        let isCompleted = index < currentIndex
        if let onSelect, isCompleted {
            Button { onSelect(index) } label: { stepLabel(at: index) }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull, outset: Spacing.ringOutset))
                .accessibilityLabel(Text("Step \(index + 1)", bundle: .module))
        } else {
            stepLabel(at: index)
        }
    }

    /// The mark with its caption, if any: beside it across, under it down.
    @ViewBuilder
    private func stepLabel(at index: Int) -> some View {
        if let label = labels?[safe: index] {
            if axis == .horizontal {
                VStack(spacing: Spacing.xxs) {
                    mark(at: index)
                    Text(label)
                        .font(Typography.captionSmall)
                        .foregroundStyle(index == currentIndex ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    mark(at: index)
                    Text(label)
                        .font(Typography.captionSmall)
                        .foregroundStyle(index == currentIndex ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
        } else {
            mark(at: index)
        }
    }

    private func opacity(at index: Int) -> Double {
        if index == currentIndex { return 1 }
        return index < currentIndex ? Self.completedOpacity : Self.pendingOpacity
    }

    @ViewBuilder
    private func mark(at index: Int) -> some View {
        let isCurrent = index == currentIndex
        switch style {
        case .dots where grows:
            // The current dot stretches along the axis into a short line; the
            // others stay dots, so the line seems to travel between them.
            let length = isCurrent ? Self.grownLength : Sizing.statusCircle
            Capsule()
                .fill(color.opacity(opacity(at: index)))
                .frame(
                    width: axis == .horizontal ? length : Sizing.statusCircle,
                    height: axis == .horizontal ? Sizing.statusCircle : length
                )
                .animation(Animations.selection, value: currentIndex)
        case .dots:
            // The current dot a step larger, in a box the larger size so the
            // row never shifts.
            Circle()
                .fill(color.opacity(opacity(at: index)))
                .frame(width: isCurrent ? Spacing.sm : Sizing.statusCircle, height: isCurrent ? Spacing.sm : Sizing.statusCircle)
                .frame(width: Spacing.sm, height: Spacing.sm)
                .animation(Animations.selection, value: currentIndex)
        case .segments:
            RoundedRectangle(cornerRadius: Sizing.radiusFull)
                .fill(color.opacity(opacity(at: index)))
                .frame(
                    maxWidth: axis == .horizontal ? .infinity : Sizing.statusCircle,
                    maxHeight: axis == .horizontal ? Sizing.statusCircle : .infinity
                )
                .frame(minWidth: Sizing.statusCircle, minHeight: Sizing.statusCircle)
                .animation(Animations.selection, value: currentIndex)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 260, height: 160)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        StepIndicator(stepCount: 5, currentIndex: 2)
        StepIndicator(stepCount: 5, currentIndex: 2, grows: true)
        StepIndicator(stepCount: 5, currentIndex: 2, style: .segments)
            .frame(width: 200)
        StepIndicator(stepCount: 3, currentIndex: 1, labels: ["Account", "Plan", "Done"], onSelect: { _ in })
    }
    .padding(Spacing.lg)
}
