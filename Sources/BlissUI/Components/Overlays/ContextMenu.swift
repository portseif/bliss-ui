//
//  ContextMenu.swift
//  BlissUI
//
//  `.blissContextMenu { rows }` — the right-click menu. It opens the same popup
//  every other menu uses (`PopupMenuService`), so it matches them instead of
//  the native `.contextMenu`: right-click or control-click opens it at the
//  pointer, ⌃Return / ⇧F10 open it under the view's leading edge while
//  something in the view has focus, the arrow keys walk its rows, and a picked
//  row closes it. Rows are `QuickActionMenuItem`s, submenus are
//  `QuickActionFlyoutRow`s, and `MenuDivider` separates groups.
//

import SwiftUI

// MARK: - Modifier

private struct BlissContextMenuModifier<MenuContent: View>: ViewModifier {
    let menuContent: () -> MenuContent

    func body(content: Content) -> some View {
        content.onSecondaryClick { point in
            PopupMenuService.shared.show(at: point) {
                VStack(alignment: .leading, spacing: 2) {
                    menuContent()
                }
                .padding(Spacing.menuPadding)
            }
        }
    }
}

extension View {
    /// A right-click menu of `QuickActionMenuItem` rows (with
    /// `QuickActionFlyoutRow` submenus and `MenuDivider`s between groups), in
    /// place of the native `.contextMenu`. Right-click, control-click, ⌃Return
    /// or ⇧F10 open it; a picked row closes it.
    ///
    /// ```swift
    /// row.blissContextMenu {
    ///     QuickActionMenuItem(title: "Rename", icon: "pencil") { rename() }
    ///     MenuDivider()
    ///     QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) { delete() }
    /// }
    /// ```
    public func blissContextMenu<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        modifier(BlissContextMenuModifier(menuContent: content))
    }
}

// MARK: - Divider

/// The hairline between groups of menu rows, spaced for a menu.
public struct MenuDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .padding(.vertical, Spacing.xxs)
    }
}

// MARK: - Preview

#Preview("Right-click menu", traits: .fixedLayout(width: 320, height: 160)) {
    Text("Right-click here")
        .font(Typography.bodySmall)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
        }
        .blissContextMenu {
            QuickActionMenuItem(title: "Rename", icon: "pencil") {}
            QuickActionMenuItem(title: "Duplicate", icon: "plus.square.on.square") {}
            MenuDivider()
            QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
        }
        .padding(Spacing.xl)
}
