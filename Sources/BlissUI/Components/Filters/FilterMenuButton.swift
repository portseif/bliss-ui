//
//  FilterMenuButton.swift
//  BlissUI
//
//  The compact trigger for a Filter or Display menu over a list: an icon and a
//  title in a hairline pill, filled while its menu is open or a filter
//  applies, with an accent count of the active filters. Attach the menu with
//  `.floatingMenu`; the button highlights itself while it's open.
//

import SwiftUI

/// A compact menu trigger for a list's header row — "Filter" (with how many
/// filters apply) or "Display".
///
/// ```swift
/// FilterMenuButton(count: activeFacets.count) { showingFilters.toggle() }
///     .floatingMenu(
///         isPresented: $showingFilters,
///         itemCount: facets.count,
///         focusedIndex: $focusedFacet,
///         xPosition: .leading,
///         yPosition: .below,
///         onActivate: { index in toggle(facets[index]); return .keepOpen }
///     ) {
///         FacetMenu(selected: $activeFacets, focusedIndex: $focusedFacet)
///     }
/// ```
///
/// A menu's trigger must toggle its `isPresented` binding, not set it `true`:
/// the menu's click-away monitor closes it on a click on the trigger and
/// expects the button to flip the state back.
public struct FilterMenuButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let isActive: Bool
    let count: Int
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    /// Set by the `.floatingMenu` attached to this button while it's open.
    @Environment(\.floatingMenuActive) private var isMenuOpen
    @State private var isHovering = false

    /// A trigger with your own title and icon ("Display").
    /// - Parameters:
    ///   - title: Looked up in your app's strings, like `Text("…")`.
    ///   - systemImage: An SF Symbol before the title.
    ///   - isActive: Fills the button. It also fills while its `.floatingMenu`
    ///     is open and whenever `count` is above zero.
    ///   - count: Active filters, shown as an accent count; 0 hides it.
    ///   - action: Toggles the menu.
    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        isActive: Bool = false,
        count: Int = 0,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isActive = isActive
        self.count = count
        self.action = action
    }

    /// The "Filter" trigger, titled in the library's own strings.
    /// - Parameters:
    ///   - isActive: Fills the button. It also fills while its `.floatingMenu`
    ///     is open and whenever `count` is above zero.
    ///   - count: Active filters, shown as an accent count; 0 hides it.
    ///   - action: Toggles the menu.
    public init(isActive: Bool = false, count: Int = 0, action: @escaping () -> Void) {
        self.init(
            .verbatim(String(localized: "Filter", bundle: .module)),
            systemImage: "line.3.horizontal.decrease",
            isActive: isActive,
            count: count,
            action: action
        )
    }

    private var isHighlighted: Bool { isActive || isMenuOpen || count > 0 }

    private var fill: Color {
        if isHighlighted { return RowTint.selected(scheme) }
        return isHovering ? RowTint.hover(scheme) : .clear
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(Typography.captionSmall)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.labelMedium)
                if count > 0 {
                    Badge(count: count)
                        .badgeStyle(.custom(
                            text: AccentHue.contrastForeground,
                            icon: AccentHue.contrastForeground,
                            background: Color.accent,
                            border: nil
                        ))
                        .badgeSize(.small)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isHighlighted || isHovering ? Color.primary : Color.secondary)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs)
            .background {
                shape
                    .fill(fill)
                    .overlay { shape.strokeBorder(Color.menuBorder, lineWidth: 1) }
            }
            // Make the whole padded pill tappable, not just the icon + text.
            .contentShape(shape)
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault))
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        // The open fill follows the menu: in on its ease-out, out faster.
        .animation(isMenuOpen ? Animations.menuOpen : Animations.menuClose, value: isMenuOpen)
        .accessibilityValue(count > 0 ? Text("\(count) active", bundle: .module) : Text(verbatim: ""))
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 320, height: 80)) {
    HStack(spacing: Spacing.sm) {
        FilterMenuButton {}
        FilterMenuButton(count: 2) {}
        FilterMenuButton("Display", systemImage: "slider.horizontal.3") {}
    }
    .padding(Spacing.lg)
}
