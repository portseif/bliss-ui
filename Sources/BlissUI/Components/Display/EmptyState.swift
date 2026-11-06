//
//  EmptyState.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/8/25.
//

import SwiftUI

// MARK: - Empty State

/// Single canonical empty-state component for the entire app. There is one
/// look everywhere, and it always fills its container vertically and
/// horizontally so callers don't need their own `.frame(maxHeight: .infinity)`.
///
/// It never shrinks below `minimumHeight`, so in a height-hugging host (an
/// auto-height sheet) it still reads as a proper empty state. Inside a
/// `ScrollViewWithThinIndicator`, the scroll must pass `fillsViewport: true`
/// for the empty state to take the remaining visible height (a scroll view
/// otherwise proposes no height and the state collapses to `minimumHeight`).
///
/// Optional `actions` builder lets callers slot buttons / menus / links
/// below the subtitle without recreating the layout. When omitted, the
/// `EmptyView` overload is used and no extra spacing is added.
public struct EmptyState<Actions: View>: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let actions: Actions

    /// Floor for hosts that hug their content (sheets, scroll content).
    public static var minimumHeight: CGFloat { 240 }

    public init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: Sizing.iconXLarge, weight: .light))
                .foregroundStyle(.tertiary)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.headingMedium)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.tertiary)
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
                    .padding(.top, Spacing.sm)
            } else {
                actions
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.minimumHeight, maxHeight: .infinity)
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Actionless Convenience Init

extension EmptyState where Actions == EmptyView {
    public init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle, actions: { EmptyView() })
    }
}

// MARK: - Section-level (contained)

extension EmptyState {
    /// An empty state that's one section of a page with other content on it —
    /// a detail page's tabs. It hugs its natural height (`minimumHeight`)
    /// so it sits right under its heading or controls instead of floating in
    /// the middle of whatever viewport is left, inside a dashed placeholder
    /// outline that marks the spot the content will fill. Same icon, title
    /// and subtitle as every other empty state; only the container differs.
    ///
    /// A whole-pane empty (a destination with nothing in it, a sheet) stays
    /// borderless: the pane is already the container.
    ///
    /// The outline is `primary` at 0.16, not `Color.menuBorder`: a dash only
    /// inks half its length, and the menu hairline dashed all but disappeared.
    public func contained() -> some View {
        fixedSize(horizontal: false, vertical: true)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
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
