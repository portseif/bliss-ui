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
    let isEnabled: Bool
    let menuContent: () -> MenuContent

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.onSecondaryClick { point in
                PopupMenuService.shared.show(at: point) {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        menuContent()
                    }
                    .padding(Spacing.menuPadding)
                }
            }
        } else {
            content
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
    ///
    /// - Parameters:
    ///   - isEnabled: Off while the row has no actions (loading, read-only):
    ///     a right-click then does nothing.
    ///   - content: The rows.
    public func blissContextMenu<Content: View>(isEnabled: Bool = true, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        modifier(BlissContextMenuModifier(isEnabled: isEnabled, menuContent: content))
    }
}

// MARK: - Divider

/// The hairline between groups of menu rows, spaced for a menu.
public struct MenuDivider: View {
    public init() {}

    public var body: some View {
        Color.menuBorder
            .frame(height: 1)
            .padding(.vertical, Spacing.xxs)
            .padding(.horizontal, Spacing.xxs)
    }
}

// MARK: - Section header

/// A small heading over a group of menu rows ("Open with", the item's name):
/// tiny capitals, widely spaced, in the tertiary tone, at the menu rows' inset.
public struct MenuSectionHeader: View {
    private let title: LocalizedStringKey
    private let leadingInset: CGFloat

    /// - Parameter title: Looked up in your app's strings like `Text("…")`;
    ///   pass `.verbatim(name)` for a name that isn't.
    public init(_ title: LocalizedStringKey) {
        self.init(title, leadingInset: Spacing.menuRowPaddingH)
    }

    /// A heading lined up with something other than the rows' text: a
    /// `MenuSection`'s inset panel.
    init(_ title: LocalizedStringKey, leadingInset: CGFloat) {
        self.title = title
        self.leadingInset = leadingInset
    }

    public var body: some View {
        Text(title)
            .font(Typography.labelXTiny)
            .textCase(.uppercase)
            .tracking(MenuSectionMetrics.headerTracking)
            .foregroundStyle(Color.textTertiary)
            .lineLimit(1)
            .padding(.leading, leadingInset)
            .padding(.trailing, Spacing.menuRowPaddingH)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.hairline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Section

enum MenuSectionMetrics {
    /// The heading's letter spacing: tiny capitals need room to read.
    static let headerTracking: CGFloat = 1.6
    /// The group's inset panel: a step darker than the menu around it.
    static func groupFill(_ scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .dark ? 0.25 : 0.025)
    }
}

/// A group of menu rows under a heading, held together in an inset panel a
/// step darker than the menu: a project switcher's Recent projects, a model
/// picker's providers. Stack sections with `Spacing.xxs` between them.
///
/// ```swift
/// MenuSection("Recent") {
///     QuickActionMenuItem(title: "Bakery", icon: "storefront", isChecked: true) {}
///     QuickActionMenuItem(title: "Observatory", icon: "sparkles") {}
/// }
/// ```
public struct MenuSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - title: The heading, looked up in your app's strings.
    ///   - content: The group's rows.
    public init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            MenuSectionHeader(title, leadingInset: Spacing.insetSpacing)
            VStack(alignment: .leading, spacing: MenuRowMetrics.rowSpacing) {
                content
            }
            .padding(Spacing.insetSpacing)
            .background(MenuSectionMetrics.groupFill(colorScheme), in: shape)
            .overlay { shape.strokeBorder(Color.menuBorder, lineWidth: 1) }
        }
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
            MenuSectionHeader("Document")
            QuickActionMenuItem(title: "Rename", icon: "pencil") {}
            QuickActionMenuItem(title: "Duplicate", icon: "plus.square.on.square") {}
            MenuDivider()
            QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
        }
        .padding(Spacing.xl)
}

#Preview("Menu sections", traits: .fixedLayout(width: 280, height: 300)) {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
        MenuSection("Recent") {
            QuickActionMenuItem(title: "Neighborhood Bakery", icon: "storefront", isChecked: true) {}
            QuickActionMenuItem(title: "Northlight Observatory", icon: "sparkles", isChecked: false) {}
        }
        MenuSection("Project") {
            QuickActionMenuItem(title: "Rename", icon: "pencil", shortcut: "⌘R") {}
            QuickActionMenuItem(title: "Show in Finder", icon: "folder", detail: "No files yet") {}
        }
        QuickActionMenuItem(title: "New Project", icon: "plus", shortcut: "⌘N") {}
    }
    .padding(Spacing.menuPadding)
    .background(Color.controlBackground)
}
