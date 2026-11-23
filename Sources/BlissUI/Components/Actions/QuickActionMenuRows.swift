//
//  QuickActionMenuRows.swift
//  BlissUI
//
//  Shared menu rows for a `floatingMenu` or a right-click popup
//  (`PopupMenuService`): a plain action row and a row that flies out a nested
//  submenu. Both answer the popup's arrow keys and draw the shared hover fill.
//

import SwiftUI

// MARK: - Metrics

/// The menu row's geometry, shared by the quick-action rows, the filter rows
/// and a picker's rows.
enum MenuRowMetrics {
    /// The row's inset.
    static let horizontalPadding: CGFloat = Spacing.menuRowPaddingH
    static let verticalPadding: CGFloat = Spacing.menuRowPaddingV
    /// Between the icon slot and the title.
    static let iconSpacing: CGFloat = Spacing.sm
    /// The leading icon slot.
    static let iconSlot: CGFloat = Sizing.iconDefault
    /// A custom (asset) icon's size.
    static let customIconSize: CGFloat = Sizing.iconTiny
    /// The hover fill's corners.
    static let cornerRadius: CGFloat = Sizing.radiusDefault
    /// Between rows.
    static let rowSpacing: CGFloat = Spacing.hairline
    /// How far down a fly-out submenu opens from its row's top.
    static let flyoutYOffset: CGFloat = 34
}

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
        HStack(spacing: MenuRowMetrics.iconSpacing) {
            Group {
                if isCustomIcon {
                    Image(icon)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: MenuRowMetrics.customIconSize, height: MenuRowMetrics.customIconSize)
                } else {
                    Image(systemName: icon)
                        .font(Typography.caption)
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: MenuRowMetrics.iconSlot)

            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, MenuRowMetrics.horizontalPadding)
        .padding(.vertical, MenuRowMetrics.verticalPadding)
        // Full-width so the chevron right-aligns whether the parent menu is a
        // fixed width or auto-sizing (`.fixedSize`).
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MenuRowMetrics.cornerRadius, style: .continuous)
                .fill(isHovered || isPresented || isKeyboardFocused ? RowTint.hover(colorScheme) : Color.clear)
        )
        // The row the keys are on (arrows / Tab) carries the focus ring.
        .focusRing(isFocused: isKeyboardFocused, cornerRadius: MenuRowMetrics.cornerRadius)
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
            yOffset: MenuRowMetrics.flyoutYOffset
        ) {
            VStack(alignment: .leading, spacing: MenuRowMetrics.rowSpacing) {
                items()
            }
            // Inside a popup the submenu's rows answer the keys too.
            .environment(navigator == nil ? nil : submenuNavigator)
            .padding(Spacing.menuPadding)
            // Auto-width to the longest submenu row (was a fixed 210). `.afterTrailing`
            // anchors the panel's left edge to the parent row's right edge, so the
            // width no longer needs to be known for positioning.
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

/// A menu action row: leading icon + title, an optional detail line, a
/// trailing shortcut or Pro badge, a checkmark for a toggle item, and a red
/// destructive variant. `isCustomIcon` draws `icon` as a template asset from the
/// app's catalog; `iconView` takes any view instead. A disabled row greys out
/// and ignores clicks and the keys.
public struct QuickActionMenuItem: View {
    let title: LocalizedStringKey
    let iconName: String?
    let isCustomIcon: Bool
    let customIconView: AnyView?
    let isDestructive: Bool
    let showProBadge: Bool
    /// The menu's arrow-key highlight; drawn like the hover.
    let isFocused: Bool
    var shortcut: String? = nil
    var isEnabled: Bool = true
    var isChecked: Bool? = nil
    var detail: LocalizedStringKey? = nil
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

    /// - Parameters:
    ///   - title: The row's label.
    ///   - icon: The leading SF Symbol (or asset, with `isCustomIcon`).
    ///   - isCustomIcon: `icon` is a template asset from the app's catalog.
    ///   - isDestructive: The red mark and the red wash on hover.
    ///   - showProBadge: A Pro badge trailing the title.
    ///   - isFocused: The menu's arrow-key highlight.
    ///   - shortcut: A trailing key cap ("⌘D").
    ///   - isEnabled: A greyed row that ignores clicks and the keys.
    ///   - isChecked: A checkmark at the row's end for a toggle item; nil for an action.
    ///   - detail: A quieter note after the title ("Opens in Safari").
    ///   - action: What the row does.
    public init(
        title: LocalizedStringKey,
        icon: String,
        isCustomIcon: Bool = false,
        isDestructive: Bool = false,
        showProBadge: Bool = false,
        isFocused: Bool = false,
        shortcut: String? = nil,
        isEnabled: Bool = true,
        isChecked: Bool? = nil,
        detail: LocalizedStringKey? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = icon
        self.isCustomIcon = isCustomIcon
        self.customIconView = nil
        self.isDestructive = isDestructive
        self.showProBadge = showProBadge
        self.isFocused = isFocused
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.detail = detail
        self.action = action
    }

    public init(
        title: LocalizedStringKey,
        iconView: AnyView,
        isDestructive: Bool = false,
        showProBadge: Bool = false,
        isFocused: Bool = false,
        shortcut: String? = nil,
        isEnabled: Bool = true,
        isChecked: Bool? = nil,
        detail: LocalizedStringKey? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconName = nil
        self.isCustomIcon = false
        self.customIconView = iconView
        self.isDestructive = isDestructive
        self.showProBadge = showProBadge
        self.isFocused = isFocused
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.detail = detail
        self.action = action
    }

    private var isHighlighted: Bool { isEnabled && (isHovered || isKeyboardFocused) }

    private var textColor: Color {
        isDestructive ? destructiveColor : .primary
    }

    private var iconColor: Color {
        isDestructive ? destructiveColor : .secondary
    }

    /// Hovered rows fill with the shared neutral gray; destructive rows with
    /// the status wash.
    private var hoverBackgroundColor: Color {
        isDestructive ? StatusWash.fill(Danger.danger500, colorScheme) : RowTint.hover(colorScheme)
    }

    @ViewBuilder
    private var iconContent: some View {
        if let iconName {
            if isCustomIcon {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: MenuRowMetrics.customIconSize, height: MenuRowMetrics.customIconSize)
                    .foregroundStyle(iconColor)
            } else {
                Image(systemName: iconName)
                    .font(Typography.labelXSmall)
                    .foregroundStyle(iconColor)
            }
        } else if let customIconView {
            customIconView
        }
    }

    /// Inside a right-click popup a picked row is the end of the menu, so the
    /// popup closes after the action. A floating menu's trigger owns its
    /// `isPresented`, so there the action closes it (or leaves it open).
    private func activate() {
        guard isEnabled else { return }
        action()
        if navigator != nil { PopupMenuService.shared.hide() }
    }

    public var body: some View {
        Button(action: activate) {
            HStack(spacing: MenuRowMetrics.iconSpacing) {
                iconContent
                    .frame(width: MenuRowMetrics.iconSlot)

                // The detail follows the title on its line, quieter, and gives
                // way first when the row is short of room.
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(textColor)
                    .layoutPriority(1)
                if let detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer(minLength: Spacing.lg)

                if showProBadge {
                    Badge.pro(size: .small)
                }

                if let shortcut {
                    ShortcutKey(shortcut, compact: true)
                }

                // A toggle item's check trails the row, with a slot kept
                // while it's off so the shortcuts above and below line up.
                if let isChecked {
                    Image(systemName: "checkmark")
                        .font(Typography.labelXSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(iconColor)
                        .opacity(isChecked ? 1 : 0)
                        .frame(width: MenuRowMetrics.iconSlot)
                        .accessibilityHidden(true)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, MenuRowMetrics.horizontalPadding)
            .padding(.vertical, MenuRowMetrics.verticalPadding)
            // Full-width so trailing content right-aligns whether the parent menu
            // is fixed width or auto-sizing (`.fixedSize`).
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MenuRowMetrics.cornerRadius, style: .continuous)
                    .fill(isHighlighted ? hoverBackgroundColor : Color.clear)
            )
            // The row the keys are on (arrows / Tab) carries the focus ring.
            .focusRing(isFocused: isKeyboardFocused && isEnabled, cornerRadius: MenuRowMetrics.cornerRadius)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .interactiveCursor()
        .onHover { hovering in
            isHovered = hovering
            if hovering, isEnabled { navigator?.notePointerHover(rowID) }
        }
        .accessibilityValue(isChecked.map { $0 ? Text("Checked", bundle: .module) : Text("Unchecked", bundle: .module) } ?? Text(verbatim: ""))
        .onAppear { navigator?.register(rowID, row: PopupMenuNavigator.Row(activate: activate)) }
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
        VStack(alignment: .leading, spacing: MenuRowMetrics.rowSpacing) {
            QuickActionFlyoutRow(title: "Open in", icon: "arrow.up.forward.app", isPresented: $isFlyoutOpen, onHoverEnter: { isFlyoutOpen = true }) {
                QuickActionMenuItem(title: "Browser", icon: "safari") {}
                QuickActionMenuItem(title: "Finder", icon: "folder") {}
            }
            MenuDivider()
            QuickActionMenuItem(title: "Summarize", icon: "sparkles", showProBadge: true) {}
            QuickActionMenuItem(title: "Refresh", icon: "arrow.clockwise", shortcut: "⌘R", detail: "Reloads from the server") {}
            QuickActionMenuItem(title: "Show hidden", icon: "eye", isChecked: true) {}
            QuickActionMenuItem(title: "Archive", icon: "archivebox", isEnabled: false) {}
            MenuDivider()
            QuickActionMenuItem(title: "Remove", icon: "trash", isDestructive: true) {}
        }
        .padding(Spacing.menuPadding)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview("Menu rows", traits: .fixedLayout(width: 260, height: 220)) {
    QuickActionMenuRowsPreview()
}
