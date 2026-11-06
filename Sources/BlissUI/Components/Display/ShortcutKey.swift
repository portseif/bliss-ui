//
//  ShortcutKey.swift
//  BlissUI
//
//  Reusable pill-style keyboard shortcut indicator (e.g., "⌘K", "⌘N", "⇧⌘P"),
//  the same pill a search field or command palette trigger shows.
//

import SwiftUI

/// A small pill displaying a keyboard shortcut, styled like a search field's shortcut hint.
///
/// Use this to advertise a keyboard shortcut next to a menu item, button, or search field.
///
/// ```swift
/// ShortcutKey("⌘N")
/// ShortcutKey("⇧⌘P")
/// ```
public struct ShortcutKey: View {
    let keys: String
    /// On an opaque surface with a hairline and a soft shadow, for a pill that
    /// floats over other content (the held-modifier hints, `.shortcutHint`).
    var floating = false
    /// The held-⌘ hints' size: shorter than a sidebar row's icon, so swapping
    /// a row's count for its shortcut never makes the row grow.
    var compact = false

    @Environment(\.colorScheme) private var colorScheme

    public init(_ keys: String, floating: Bool = false, compact: Bool = false) {
        self.keys = keys
        self.floating = floating
        self.compact = compact
    }

    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.85) : Grey.grey600
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
    }

    public var body: some View {
        Text(verbatim: keys)
            .font(compact ? Typography.codeXTiny : Typography.codeTiny)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? Spacing.xs - 1 : Spacing.xs)
            .padding(.vertical, compact ? 1 : Spacing.insetSpacing)
            .background {
                if floating {
                    // The tint over an opaque base, so text under the pill
                    // can't show through.
                    shape.fill(backgroundColor).background(shape.fill(Color.controlBackground))
                } else {
                    shape.fill(backgroundColor)
                }
            }
            .overlay {
                if floating { shape.strokeBorder(Color.menuBorder, lineWidth: 1) }
            }
            .shadow(color: .black.opacity(floating ? (colorScheme == .dark ? 0.4 : 0.1) : 0), radius: 3, y: 1)
    }
}

// MARK: - Previews

#Preview("Single Key") {
    ShortcutKey("⌘N")
        .padding()
}

#Preview("Modifier Combos") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ShortcutKey("⌘K")
        ShortcutKey("⌘N")
        ShortcutKey("⌘,")
        ShortcutKey("⇧⌘P")
        ShortcutKey("⌃⌥⌘R")
        ShortcutKey("Esc")
    }
    .padding()
}

#Preview("Floating") {
    ShortcutKey("⌘N", floating: true)
        .padding()
}

#Preview("Compact") {
    HStack(spacing: Spacing.sm) {
        ShortcutKey("⌘1", compact: true)
        ShortcutKey("⌘[", floating: true, compact: true)
    }
    .padding()
}

#Preview("In Context") {
    HStack(spacing: Spacing.sm) {
        Image(systemName: "magnifyingglass")
            .font(.system(size: Sizing.iconDefault, weight: .regular))
        Text("Search...")
            .font(Typography.labelMedium)
        ShortcutKey("⌘K")
    }
    .padding()
    .background(Color.black.opacity(0.05))
    .padding()
}
