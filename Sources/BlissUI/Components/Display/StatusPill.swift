//
//  StatusPill.swift
//  BlissUI
//
//  A two-state pill for something that's either on or off (Running /
//  Stopped, Connected / Offline): on, it's a filled dot and label in a status
//  color on that color's wash; off, it goes neutral — a hollow ring dot and a
//  secondary label — so an idle row reads as quiet rather than as a state of
//  its own.
//
//  Sibling components — reach for the right one:
//    - `StatusDotPill` — one status color, any number of states (Healthy,
//      Degraded, Failed …).
//    - `Badge.status(_:color:)` — the general status chip at any `BadgeSize`.
//  Use this one for an on/off state, where "off" isn't a color. All three
//  share `BadgeSize`'s heights and `StatusWash`'s fill and hairline.
//

import SwiftUI

/// An on/off status pill: colored while active, neutral with a hollow dot while not.
///
/// ```swift
/// StatusPill(isRunning ? "Running" : "Stopped", isActive: isRunning)
/// StatusPill("Connected", isActive: true, color: Info.info500, icon: "bolt.fill")
/// ```
public struct StatusPill: View {
    private let label: LocalizedStringKey
    private let isActive: Bool
    private let color: Color
    private let size: BadgeSize
    private let icon: String?
    private let bordered: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - label: The state's name, looked up in your app's strings.
    ///   - isActive: Colored when true; neutral, with a hollow dot, when false.
    ///   - color: The active state's color — a status mark.
    ///   - size: The pill size; `.small` sits in a row, `.regular` heads a pane.
    ///   - icon: An SF Symbol in the dot's place (a bolt for Running, a plug for Connected).
    ///   - bordered: A hairline of the status color (neutral while inactive).
    public init(
        _ label: LocalizedStringKey,
        isActive: Bool,
        color: Color = Success.success500,
        size: BadgeSize = .small,
        icon: String? = nil,
        bordered: Bool = true
    ) {
        self.label = label
        self.isActive = isActive
        self.color = color
        self.size = size
        self.icon = icon
        self.bordered = bordered
    }

    public var body: some View {
        // The active label paints in the status color, which needs the
        // dark-mode lift to clear AA on its own wash (see `Color.legibleOnDark`);
        // the fill and border keep the deep base so the pill keeps its hue.
        let foreground = isActive ? color.legibleOnDark(colorScheme) : Color.textSecondary
        HStack(spacing: size.iconSpacing) {
            if let icon {
                Image(systemName: icon)
                    .font(size.iconFont)
                    .foregroundStyle(foreground)
            } else {
                Circle()
                    .fill(isActive ? foreground : Color.clear)
                    .frame(width: size.dotSize, height: size.dotSize)
                    .overlay {
                        if !isActive { Circle().strokeBorder(Color.textTertiary, lineWidth: 1) }
                    }
            }
            Text(label)
                .font(size.font)
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(height: size.minHeight)
        .background {
            Capsule().fill(isActive ? StatusWash.fill(color, colorScheme) : Color.restingFill)
        }
        .overlay {
            if bordered {
                Capsule().strokeBorder(isActive ? StatusWash.border(color, colorScheme) : Color.menuBorder, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 320, height: 120)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(spacing: Spacing.sm) {
            StatusPill("Running", isActive: true)
            StatusPill("Stopped", isActive: false)
            StatusPill("Connected", isActive: true, color: Info.info500, icon: "bolt.fill")
        }
        HStack(spacing: Spacing.sm) {
            StatusPill("Running", isActive: true, size: .regular)
            StatusPill("Stopped", isActive: false, size: .large, bordered: false)
        }
    }
    .padding(Spacing.xl)
}
