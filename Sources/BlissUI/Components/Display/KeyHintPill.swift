//
//  KeyHintPill.swift
//  BlissUI
//
//  A small outlined key cap for keyboard hints in running text — a sheet
//  footer's "esc to cancel · ↩ to save". The hairline sibling of
//  `ShortcutKey`: that one is a filled pill that accessorizes a control (a
//  search field's ⌘K); this one sits inline in caption text without adding a
//  block of fill to it.
//

import SwiftUI

/// An outlined key cap for inline keyboard hints ("esc", "⌘↩").
///
/// ```swift
/// HStack(spacing: Spacing.xs) {
///     KeyHintPill("esc")
///     Text("to cancel").font(Typography.captionTiny).foregroundStyle(.tertiary)
/// }
/// ```
public struct KeyHintPill: View {
    private let keys: String

    /// - Parameter keys: The key or chord, shown as-is ("esc", "↩", "⌘↩").
    public init(_ keys: String) {
        self.keys = keys
    }

    public var body: some View {
        Text(verbatim: keys)
            .font(Typography.codeTiny)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs - 1)
            .padding(.vertical, 1)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .strokeBorder(Color.primary.opacity(prefersIncreasedContrast ? 0.3 : 0.15), lineWidth: 1)
            }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 280, height: 70)) {
    HStack(spacing: Spacing.xs) {
        KeyHintPill("esc")
        Text(verbatim: "to cancel").font(Typography.captionTiny).foregroundStyle(.tertiary)
        Text(verbatim: "·").font(Typography.captionTiny).foregroundStyle(.quaternary)
        KeyHintPill("⌘↩")
        Text(verbatim: "to restore").font(Typography.captionTiny).foregroundStyle(.tertiary)
    }
    .padding(Spacing.xl)
}
