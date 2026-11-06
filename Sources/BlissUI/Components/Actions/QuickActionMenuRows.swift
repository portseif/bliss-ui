//
//  QuickActionMenuRows.swift
//  BlissUI
//
//  Shared menu rows for a `floatingMenu` or a right-click popup
//  (`PopupMenuService`): a plain action row and a row that flies out a nested
//  submenu. Both answer the popup's arrow keys and draw the shared hover fill.
//

import SwiftUI

// MARK: - Quick Action Fly-out Row

/// Root-menu row that opens a nested submenu (`floatingMenu`) to the trailing
/// side on hover. Leading icon + title + trailing chevron, matching
/// `QuickActionMenuItem` chrome. The submenu content is supplied by the caller.
/// `isCustomIcon` draws `icon` as a template asset from the app's catalog.
public struct QuickActionFlyoutRow<Items: View>: View {
    let title: LocalizedStringKey
    let icon: String
    var isCustomIcon: Bool = false
    /// The menu's arrow-key highlight.
    var isFocused: Bool = false
    @Binding var isPresented: Bool
    let onHoverEnter: () -> Void
    @ViewBuilder let items: () -> Items

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    /// Set inside a right-click popup: the keys reach this row through it.
    @Environment(PopupMenuNavigator.self) private var navigator: PopupMenuNavigator?
    @State private var rowID = UUID()
    /// The submenu's own keys, inside a popup.
    @State private var submenuNavigator = PopupMenuNavigator()

    public init(
        title: LocalizedStringKey,
        icon: String,
        isCustomIcon: Bool = false,
        isFocused: Bool = false,
        isPresented: Binding<Bool>,
        onHoverEnter: @escaping () -> Void,
        @ViewBuilder items: @escaping () -> Items
    ) {
        self.title = title
        self.icon = icon
        self.isCustomIcon = isCustomIcon
        self.isFocused = isFocused
        self._isPresented = isPresented
        self.onHoverEnter = onHoverEnter
        self.items = items
    }

    private var isKeyboardFocused: Bool { isFocused || navigator?.focusedRowID == rowID }

    public var body: some View {
        HStack(spacing: 10) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(Typography.caption)
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: 16)

            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // Full-width so the chevron right-aligns whether the parent menu is a
        // fixed width or auto-sizing (`.fixedSize`).
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered || isPresented || isKeyboardFocused ? RowTint.hover(colorScheme) : Color.clear)
        )
        // The row the keys are on (arrows / Tab) carries the focus ring.
        .focusRing(isFocused: isKeyboardFocused, cornerRadius: 6)
        .contentShape(Rectangle())
        // Hover opens the submenu (and switches away from any sibling). We
        // only set on enter — leaving the row toward its own submenu must NOT
        // close it, so there's no clear-on-exit here.
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                navigator?.notePointerHover(rowID)
                onHoverEnter()
            }
        }
        .onAppear {
            let presented = $isPresented
            let submenuNavigator = submenuNavigator
            submenuNavigator.parent = navigator
            submenuNavigator.parentRowID = rowID
            navigator?.register(rowID, row: PopupMenuNavigator.Row(
                activate: {},
                openSubmenu: {
                    presented.wrappedValue = true
                    return submenuNavigator
                },
                closeSubmenu: { presented.wrappedValue = false }
            ))
        }
        .onDisappear { navigator?.unregister(rowID) }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { minY in
            navigator?.updatePosition(rowID, minY: minY)
        }
        // Closed by its own Esc or the pointer: the popup's keys come back here.
        .onChange(of: isPresented) { _, presented in
            if !presented { navigator?.submenuDidClose(rowID) }
        }
        // Nested submenu panel, flown out to the trailing side. Offsets push
        // it just past the row's right edge, roughly top-aligned.
        .floatingMenu(
            isPresented: $isPresented,
            xPosition: .afterTrailing,
            yPosition: .below,
            menuGap: 0,
            xOffset: 0,
            yOffset: 34
        ) {
            VStack(alignment: .leading, spacing: 2) {
                items()
            }
            // Inside a popup the submenu's rows answer the keys too.
            .environment(navigator == nil ? nil : submenuNavigator)
            .padding(6)
            // Auto-width to the longest submenu row (was a fixed 210). `.afterTrailing`
            // anchors the panel's left edge to the parent row's right edge, so the
            // width no longer needs to be known for positioning.
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

/// A menu action row: leading icon + title, an optional Pro badge, and a red
/// destructive variant. `isCustomIcon` draws `icon` as a template asset from the
/// app's catalog; `iconView` takes any view instead.
public struct QuickActionMenuItem: View {
    let title: LocalizedStringKey
    let iconName: String?
    let isCustomIcon: Bool
    let customIconView: AnyView?
    let isDestructive: Bool
    let showProBadge: Bool
    /// The menu's arrow-key highlight; drawn like the hover.
    let isFocused: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    /// Set inside a right-click popup: the keys reach this row through it.
    @Environment(PopupMenuNavigator.self) private var navigator: PopupMenuNavigator?
    @State private var rowID = UUID()

    private var isKeyboardFocused: Bool { isFocused || navigator?.focusedRowID == rowID }

    /// A destructive row stays the red mark; hovered it takes the subtle
    /// destructive button's red wash (`DestructiveButtonStyle`).
    private var destructiveColor: Color { Danger.danger500 }

    public init(
        title: LocalizedStringKey,
        icon: String,
        isCustomIcon: Bool = false,
        isDestructive: Bool = false,
        showProBadge: Bool = false,
        isFocused: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = icon
        self.isCustomIcon = isCustomIcon
        self.customIconView = nil
        self.isDestructive = isDestructive
        self.showProBadge = showProBadge
        self.isFocused = isFocused
        self.action = action
    }

    public init(
        title: LocalizedStringKey,
        iconView: AnyView,
        isDestructive: Bool = false,
        showProBadge: Bool = false,
        isFocused: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = nil
        self.isCustomIcon = false
        self.customIconView = iconView
        self.isDestructive = isDestructive
        self.showProBadge = showProBadge
        self.isFocused = isFocused
        self.action = action
    }

    private var isHighlighted: Bool { isHovered || isKeyboardFocused }

    private var textColor: Color {
        isDestructive ? destructiveColor : .primary
    }

    private var iconColor: Color {
        isDestructive ? destructiveColor : .secondary
    }

    /// Hovered rows fill with the shared neutral gray; destructive rows with the
    /// red wash the subtle destructive button uses on hover.
    private var hoverBackgroundColor: Color {
        isDestructive ? Danger.tint.opacity(colorScheme == .dark ? 0.14 : 0.06) : RowTint.hover(colorScheme)
    }

    @ViewBuilder
    private var iconContent: some View {
        if let iconName {
            if isCustomIcon {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(iconColor)
            } else {
                Image(systemName: iconName)
                    .font(Typography.caption)
                    .foregroundStyle(iconColor)
            }
        } else if let customIconView {
            customIconView
        }
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                iconContent
                    .frame(width: 16)

                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(textColor)

                Spacer()

                if showProBadge {
                    Badge.pro(size: .small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            // Full-width so trailing content right-aligns whether the parent menu
            // is fixed width or auto-sizing (`.fixedSize`).
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHighlighted ? hoverBackgroundColor : Color.clear)
            )
            // The row the keys are on (arrows / Tab) carries the focus ring.
            .focusRing(isFocused: isKeyboardFocused, cornerRadius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { navigator?.notePointerHover(rowID) }
        }
        .onAppear { navigator?.register(rowID, row: PopupMenuNavigator.Row(activate: action)) }
        .onDisappear { navigator?.unregister(rowID) }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { minY in
            navigator?.updatePosition(rowID, minY: minY)
        }
    }
}

// MARK: - Previews

private struct QuickActionMenuRowsPreview: View {
    @State private var isFlyoutOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            QuickActionFlyoutRow(title: "Open in", icon: "arrow.up.forward.app", isPresented: $isFlyoutOpen, onHoverEnter: { isFlyoutOpen = true }) {
                QuickActionMenuItem(title: "Browser", icon: "safari") {}
                QuickActionMenuItem(title: "Finder", icon: "folder") {}
            }
            Divider().padding(.vertical, 4)
            QuickActionMenuItem(title: "Summarize", icon: "sparkles", showProBadge: true) {}
            QuickActionMenuItem(title: "Refresh", icon: "arrow.clockwise") {}
            Divider().padding(.vertical, 4)
            QuickActionMenuItem(title: "Remove", icon: "trash", isDestructive: true) {}
        }
        .padding(Spacing.menuPadding)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview("Menu rows", traits: .fixedLayout(width: 260, height: 220)) {
    QuickActionMenuRowsPreview()
}
