//
//  StatusDotPill.swift
//  BlissUI
//
//  Compact inline status pill: a status dot + same-color label on the
//  status wash. The shared shape for small run-state / health pills (e.g. a
//  server's "Running" pill, a health summary's overall pill).
//
//  Sibling components — reach for the right one:
//    - `StatusPill` — on / off, where "off" is neutral rather than a color.
//    - `Badge.status(_:color:)` — the general status chip at any `BadgeSize`.
//  All three share `BadgeSize`'s heights and `StatusWash`'s fill and hairline.
//

import SwiftUI

public struct StatusDotPill: View {
    let label: LocalizedStringKey
    let color: Color
    var size: BadgeSize = .small
    var icon: String? = nil
    var isActive: Bool = true
    var bordered: Bool = false
    /// A caller's own font, from the older init; nil draws the size's.
    private var fontOverride: Font? = nil

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - label: The state's name, looked up in your app's strings.
    ///   - color: The status color — a status mark.
    ///   - size: The pill size; `.small` sits in a row, `.regular` heads a pane.
    ///   - icon: An SF Symbol in the dot's place.
    ///   - isActive: A hollow dot and secondary text when false — the state is known but idle.
    ///   - bordered: A hairline of the status color.
    public init(
        label: LocalizedStringKey,
        color: Color,
        size: BadgeSize = .small,
        icon: String? = nil,
        isActive: Bool = true,
        bordered: Bool = false
    ) {
        self.label = label
        self.color = color
        self.size = size
        self.icon = icon
        self.isActive = isActive
        self.bordered = bordered
    }

    /// A pill in a font of your own. Prefer `size:`, which keeps the pill at
    /// one of the shared heights.
    public init(
        label: LocalizedStringKey,
        color: Color,
        font: Font,
        bordered: Bool = false
    ) {
        self.label = label
        self.color = color
        self.fontOverride = font
        self.bordered = bordered
    }

    public var body: some View {
        // The label is the status color, which needs a dark-mode lift to stay
        // readable on its own wash — the fill stays the deep base so the pill
        // keeps its hue. See `Color.legibleOnDark` / `statusTint`.
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
                .font(fontOverride ?? size.font)
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

#Preview(traits: .fixedLayout(width: 260, height: 160)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        StatusDotPill(label: "Running", color: Success.success500)
        StatusDotPill(label: "Healthy", color: Success.success500, size: .regular, bordered: true)
        StatusDotPill(label: "Needs attention", color: Warning.warning500, size: .regular, icon: "exclamationmark.triangle.fill", bordered: true)
        StatusDotPill(label: "Idle", color: Grey.grey500, isActive: false)
    }
    .padding()
}
