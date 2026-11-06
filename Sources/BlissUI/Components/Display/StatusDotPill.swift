//
//  StatusDotPill.swift
//  BlissUI
//
//  Compact inline status pill: a status dot + same-color label on a soft
//  same-color tint. The shared shape for small run-state / health pills (e.g. a
//  server's "Running" pill, a health summary's overall pill).
//
//  Sibling component — reach for the right one:
//    - `Badge.status(_:color:)` — the larger general status chip (size .large).
//  Use this one for the compact, single-color tinted pill.
//

import SwiftUI

public struct StatusDotPill: View {
    let label: LocalizedStringKey
    let color: Color
    var font: Font = Typography.labelTiny
    var bordered: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    public init(
        label: LocalizedStringKey,
        color: Color,
        font: Font = Typography.labelTiny,
        bordered: Bool = false
    ) {
        self.label = label
        self.color = color
        self.font = font
        self.bordered = bordered
    }

    public var body: some View {
        // The label is the status color, which needs a dark-mode lift to stay
        // readable on its own tint — the fill stays the deep base so the pill
        // keeps its hue. See `Color.legibleOnDark` / `statusTint`.
        let foreground = color.legibleOnDark(colorScheme)
        let tint = color.statusTint
        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(foreground)
                .frame(width: 6, height: 6)
            Text(label)
                .font(font)
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(tint.opacity(0.12))
        }
        .overlay {
            if bordered {
                Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1)
            }
        }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 240, height: 140)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        StatusDotPill(label: "Running", color: Success.success500)
        StatusDotPill(label: "Healthy", color: Success.success500, font: Typography.labelSmall, bordered: true)
        StatusDotPill(label: "Needs attention", color: Warning.warning500, font: Typography.labelSmall, bordered: true)
    }
    .padding()
}
