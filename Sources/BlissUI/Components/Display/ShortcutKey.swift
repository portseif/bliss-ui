//
//  ShortcutKey.swift
//  BlissUI
//
//  The key cap: a keyboard shortcut in the code face on a small pill, the
//  same one a search field, a menu row and a command palette show. Filled by
//  default; `outlined` draws only a hairline, for a key cap set in running
//  caption text ("esc to cancel"); `floating` sits it on an opaque surface
//  with a lift, for the held-⌘ hints over a control.
//
//  Its sizes are `BadgeSize`'s: compact is the small pill (16pt), regular the
//  regular one (20pt), so a key beside a badge sits at the same cap height.
//

import SwiftUI

/// A small pill displaying a keyboard shortcut.
///
/// ```swift
/// ShortcutKey("⌘N")
/// ShortcutKey("esc", outlined: true)
/// ```
public struct ShortcutKey: View {
    let keys: String
    /// On an opaque surface with a hairline and a lift, for a pill that
    /// floats over other content (the held-modifier hints, `.shortcutHint`).
    var floating = false
    /// The held-⌘ hints' size: shorter than a sidebar row's icon, so swapping
    /// a row's count for its shortcut never makes the row grow.
    var compact = false
    /// A hairline and no fill: a key cap inline in caption text.
    var outlined = false
    /// The text color in place of the secondary text tone — the contrast
    /// foreground on an accent-filled button.
    var tint: Color? = nil

    /// - Parameters:
    ///   - keys: The key or chord, shown as-is ("⌘K", "esc", "⌘↩").
    ///   - floating: An opaque surface with a lift, over other content.
    ///   - compact: The small pill (16pt) instead of the regular one (20pt).
    ///   - outlined: A hairline instead of a fill.
    ///   - tint: The text color, in place of the secondary tone.
    public init(_ keys: String, floating: Bool = false, compact: Bool = false, outlined: Bool = false, tint: Color? = nil) {
        self.keys = keys
        self.floating = floating
        self.compact = compact
        self.outlined = outlined
        self.tint = tint
    }

    private var size: BadgeSize { compact ? .small : .regular }

    private var font: Font { compact ? Typography.codeXTiny : Typography.codeTiny }

    /// The key cap: a faint wash of the text color inside a hairline of it,
    /// both translucent so the cap reads on a sidebar, a raised button and a
    /// menu alike.
    private static let fillOpacity: Double = 0.06
    private static let hairlineOpacity: Double = 0.12

    private var fill: Color {
        if outlined { return .clear }
        return Color.primary.opacity(Self.fillOpacity)
    }

    private var hairline: Color {
        floating || outlined ? Color.menuBorder : Color.primary.opacity(Self.hairlineOpacity)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
    }

    public var body: some View {
        let pill = Text(verbatim: keys)
            .font(font)
            .foregroundStyle(tint ?? Color.textSecondary)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            // A lone key is at least as wide as it is tall, so "K" reads as a cap.
            .frame(minWidth: size.minHeight, minHeight: size.minHeight, maxHeight: size.minHeight)
            .background {
                if floating {
                    // The tint over an opaque base, so text under the pill
                    // can't show through.
                    shape.fill(fill).background(shape.fill(Color.controlBackground))
                } else {
                    shape.fill(fill)
                }
            }
            .overlay {
                shape.strokeBorder(hairline, lineWidth: 1)
            }
        if floating {
            pill.elevation(.lift)
        } else {
            pill
        }
    }
}

// MARK: - Previews

#Preview("Key caps", traits: .fixedLayout(width: 300, height: 220)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        HStack(spacing: Spacing.sm) {
            ShortcutKey("⌘K")
            ShortcutKey("⇧⌘P")
            ShortcutKey("⌃⌥⌘R")
            ShortcutKey("Esc")
        }
        HStack(spacing: Spacing.sm) {
            ShortcutKey("⌘1", compact: true)
            ShortcutKey("⌘[", floating: true, compact: true)
            ShortcutKey("⌘N", floating: true)
        }
        HStack(spacing: Spacing.xs) {
            ShortcutKey("esc", outlined: true)
            Text(verbatim: "to cancel").font(Typography.captionTiny).foregroundStyle(.tertiary)
            ShortcutKey("⌘↩", outlined: true)
            Text(verbatim: "to save").font(Typography.captionTiny).foregroundStyle(.tertiary)
        }
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Typography.labelMedium)
            Text(verbatim: "Search…")
                .font(Typography.labelMedium)
            ShortcutKey("⌘K")
        }
        .padding(Spacing.sm)
        .background(Color.restingFill)
    }
    .padding(Spacing.xl)
}
