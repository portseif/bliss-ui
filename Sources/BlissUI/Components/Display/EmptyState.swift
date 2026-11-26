//
//  EmptyState.swift
//  BlissUI
//
//  The one empty state: a glyph, a title, a line under it, and the actions
//  that fill the space.
//

import SwiftUI

// MARK: - Empty State

/// Single canonical empty-state component for the entire app. There is one
/// look everywhere, and it always fills its container vertically and
/// horizontally so callers don't need their own `.frame(maxHeight: .infinity)`.
///
/// It never shrinks below `minHeight`, so in a height-hugging host (an
/// auto-height sheet) it still reads as a proper empty state. Inside a
/// `ScrollViewWithThinIndicator`, the scroll must pass `fillsViewport: true`
/// for the empty state to take the remaining visible height (a scroll view
/// otherwise proposes no height and the state collapses to `minHeight`).
///
/// `compact: true` is the small version for an inspector pane, a table body
/// or a popover: a 24pt glyph, a semibold body title and a caption, half the
/// floor. Optional `actions` builder lets callers slot buttons / menus / links
/// below the subtitle without recreating the layout. When omitted, the
/// `EmptyView` overload is used and no extra spacing is added.
public struct EmptyState<Actions: View>: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var compact: Bool
    var iconColor: Color?
    var minHeight: CGFloat
    let actions: Actions

    /// Floor for hosts that hug their content (sheets, scroll content).
    public static var minimumHeight: CGFloat { 240 }

    /// The compact version's floor.
    public static var compactMinimumHeight: CGFloat { 120 }

    /// The dashed outline of `contained()`: `primary` at this opacity, not
    /// `Color.menuBorder` — a dash only inks half its length, and the menu
    /// hairline dashed all but disappeared.
    static var outlineOpacity: Double { 0.16 }

    /// - Parameters:
    ///   - icon: The SF Symbol.
    ///   - title: What's missing. Looked up in your app's strings.
    ///   - subtitle: What to do about it.
    ///   - compact: The small version, for a pane or a table body.
    ///   - iconColor: The glyph's color; nil is tertiary. `Danger.danger500`
    ///     for an error state, `Color.accent` for a first run.
    ///   - minHeight: The floor; the regular or compact default when nil.
    ///   - actions: Buttons, menus or links under the subtitle.
    public init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        compact: Bool = false,
        iconColor: Color? = nil,
        minHeight: CGFloat? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.compact = compact
        self.iconColor = iconColor
        self.minHeight = minHeight ?? (compact ? Self.compactMinimumHeight : Self.minimumHeight)
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: compact ? Spacing.sm : Spacing.lg) {
            BlissSymbol(icon)
                .font(compact ? Typography.headingLarge : Typography.displayLargeLight)
                .foregroundStyle(iconColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tertiary))

            VStack(spacing: compact ? Spacing.xxs : Spacing.xs) {
                Text(title)
                    .font(compact ? Typography.bodySmallSemibold : Typography.headingMedium)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(compact ? Typography.captionSmall : Typography.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Render the actions slot. EmptyView (the no-actions overload)
            // produces no visible chrome, so the padding-top below adds a
            // visible gap only when real action views are present — we gate
            // it on a runtime type check against `EmptyView` to avoid a
            // stray ~8pt gap underneath the subtitle when there are none.
            if Actions.self != EmptyView.self {
                actions
                    .padding(.top, compact ? Spacing.xxs : Spacing.sm)
            } else {
                actions
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Actionless Convenience Init

extension EmptyState where Actions == EmptyView {
    public init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        compact: Bool = false,
        iconColor: Color? = nil,
        minHeight: CGFloat? = nil
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle, compact: compact, iconColor: iconColor, minHeight: minHeight, actions: { EmptyView() })
    }
}

// MARK: - Section-level (contained)

extension EmptyState {
    /// An empty state that's one section of a page with other content on it —
    /// a detail page's tabs. It hugs its natural height (`minHeight`)
    /// so it sits right under its heading or controls instead of floating in
    /// the middle of whatever viewport is left, inside a dashed placeholder
    /// outline that marks the spot the content will fill. Same icon, title
    /// and subtitle as every other empty state; only the container differs.
    ///
    /// A whole-pane empty (a destination with nothing in it, a sheet) stays
    /// borderless: the pane is already the container.
    public func contained() -> some View {
        fixedSize(horizontal: false, vertical: true)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(Self.outlineOpacity),
                        style: StrokeStyle(lineWidth: 1, dash: [Spacing.xxs, Spacing.xxs])
                    )
            }
    }
}

// MARK: - Previews

// Preview text is `verbatim`: Xcode's catalog sync was adding these strings as
// untranslated keys, and nothing outside a preview shows them.

#Preview("No actions", traits: .fixedLayout(width: 600, height: 400)) {
    EmptyState(
        icon: "sidebar.left",
        title: .verbatim("No Item Selected"),
        subtitle: .verbatim("Select an item from the sidebar to view details")
    )
    .background(Color.windowBackground)
}

#Preview("Contained (a section of a page)", traits: .fixedLayout(width: 600, height: 400)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        Text(verbatim: "Recent activity")
            .font(Typography.headingMedium)
        EmptyState(
            icon: "clock",
            title: "No activity yet",
            subtitle: "Actions you take will show up here."
        )
        .contained()
        Spacer(minLength: 0)
    }
    .padding(Spacing.xl)
    .background(Color.windowBackground)
}

#Preview("Compact and error", traits: .fixedLayout(width: 600, height: 300)) {
    HStack(spacing: Spacing.lg) {
        EmptyState(icon: "tray", title: .verbatim("No results"), subtitle: .verbatim("Try another search."), compact: true)
            .contained()
        EmptyState(icon: "wifi.exclamationmark", title: .verbatim("Couldn't load"), subtitle: .verbatim("Check your connection."), compact: true, iconColor: Danger.danger500)
            .contained()
    }
    .padding(Spacing.xl)
    .background(Color.windowBackground)
}

#Preview("With actions", traits: .fixedLayout(width: 600, height: 400)) {
    EmptyState(
        icon: "doc.on.doc",
        title: .verbatim("No Templates"),
        subtitle: .verbatim("Create a template to reuse whenever you start something new")
    ) {
        Button {
            // create
        } label: {
            Label(.verbatim("Create Template"), systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
    .background(Color.windowBackground)
}
