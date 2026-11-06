//
//  StatusPill.swift
//  BlissUI
//
//  A two-state pill for something that's either on or off (Running /
//  Stopped, Connected / Offline): on, it's a filled dot and label in a status
//  color on that color's tint; off, it goes neutral — a hollow ring dot and a
//  secondary label — so an idle row reads as quiet rather than as a state of
//  its own.
//
//  Sibling components — reach for the right one:
//    - `StatusDotPill` — one status color, any number of states (Healthy,
//      Degraded, Failed …). Capsule, border optional.
//    - `Badge.status(_:color:)` — the larger general status chip.
//  Use this one for an on/off state, where "off" isn't a color.
//

import SwiftUI

/// An on/off status pill: colored while active, neutral with a hollow dot while not.
///
/// ```swift
/// StatusPill(isRunning ? "Running" : "Stopped", isActive: isRunning)
/// StatusPill("Connected", isActive: true, color: Info.info500)
/// ```
public struct StatusPill: View {
    private let label: LocalizedStringKey
    private let isActive: Bool
    private let color: Color

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - label: The state's name, looked up in your app's strings.
    ///   - isActive: Colored when true; neutral, with a hollow dot, when false.
    ///   - color: The active state's color — a status mark.
    public init(_ label: LocalizedStringKey, isActive: Bool, color: Color = Success.success500) {
        self.label = label
        self.isActive = isActive
        self.color = color
    }

    public var body: some View {
        // The active label paints in the status color, which needs the
        // dark-mode lift to clear AA on its own tint (see `Color.legibleOnDark`);
        // the fill and border keep the deep base so the pill keeps its hue.
        let foreground = color.legibleOnDark(colorScheme)
        let shape = RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isActive ? foreground : Color.clear)
                .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                .overlay {
                    if !isActive { Circle().strokeBorder(Grey.grey400, lineWidth: 1) }
                }
            Text(label)
                .font(Typography.labelTiny)
                .foregroundStyle(isActive ? foreground : Color.secondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background {
            shape.fill(isActive ? color.statusTint.opacity(0.12) : Color.primary.opacity(0.05))
        }
        .overlay {
            shape.strokeBorder(
                (isActive ? color.statusTint : Color.primary).opacity(prefersIncreasedContrast ? 0.5 : 0.3),
                lineWidth: 1
            )
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 260, height: 90)) {
    HStack(spacing: Spacing.sm) {
        StatusPill("Running", isActive: true)
        StatusPill("Stopped", isActive: false)
        StatusPill("Connected", isActive: true, color: Info.info500)
    }
    .padding(Spacing.xl)
}
