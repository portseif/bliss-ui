//
//  Sidebar.swift
//  BlissUI
//
//  A window's navigation sidebar: rows of destinations in sections, a pinned
//  footer (Settings), and saved-filter rows marked with a colored dot or their
//  own icon. Generic over the app's selection — each row is tagged with the
//  value it selects, like a `List`'s tags.
//
//  Rows share the neutral `RowTint` fill (selected a step above hover), have no
//  press state, and are Tab stops with the shared ring. Holding ⌘ swaps a row's
//  count for its shortcut (`ShortcutHintService`). Collapsed, the sidebar shows
//  each row's icon alone (its title in a tooltip, a count as a dot) in
//  `Sizing.sidebarCollapsedWidth`; `SidebarToggleButton` flips it.
//

import SwiftUI

// MARK: - Selection plumbing

/// The enclosing `Sidebar`'s selection, as the rows see it.
/// The sidebar's selection, as its rows read it: the selected value, and the
/// writer a row uses to select itself. No closure: the environment compares
/// this field by field, and a fresh closure on every render would read as a
/// change and redraw every row.
struct SidebarSelectionContext {
    let selection: AnyHashable
    let writer: SidebarSelectionWriter
}

/// Writes a row's value into the sidebar's selection binding. The sidebar keeps
/// one for its lifetime, so it compares by identity across renders.
final class SidebarSelectionWriter {
    fileprivate var write: (AnyHashable) -> Void = { _ in }

    func select(_ value: AnyHashable) { write(value) }
}

extension EnvironmentValues {
    @Entry var sidebarSelection: SidebarSelectionContext? = nil
}

extension EnvironmentValues {
    /// Set by a collapsed `Sidebar`: rows draw their icon alone.
    @Entry var sidebarIsCollapsed: Bool = false
}

// MARK: - Sidebar

/// A navigation sidebar bound to a selection. Rows inside select the value they
/// were given; a footer stays pinned to the bottom while the rows scroll.
///
/// ```swift
/// Sidebar(selection: $destination) {
///     SidebarSection {
///         SidebarRow("Inbox", icon: "tray", value: Destination.inbox, count: 4, shortcut: "⌘1")
///         SidebarRow("Today", icon: "sun.max", value: Destination.today, shortcut: "⌘2")
///     }
///     SidebarDivider()
///     SidebarSection("Filters") {
///         SidebarFilterRow("Running", color: Success.success500, value: Destination.running)
///         SidebarRow("New filter", icon: "plus") { isCreatingFilter = true }
///     }
/// } footer: {
///     SidebarRow("Settings", icon: "gearshape", value: Destination.settings, shortcut: "⌘,")
/// }
/// .frame(width: 220)
/// ```
///
/// It has no background of its own: it sits on the window's shell
/// (`Color.appShell`). Size it with `.frame(width:)` — collapsed, with
/// `Sizing.sidebarCollapsedWidth`, and the rows shrink to their icons:
///
/// ```swift
/// Sidebar(selection: $destination, isCollapsed: isCollapsed) { … }
///     .frame(width: isCollapsed ? Sizing.sidebarCollapsedWidth : 220)
/// ```
///
/// Flip `isCollapsed` inside `withAnimation(Animations.pane)` (or with
/// `SidebarToggleButton`) and the width and the rows animate together.
public struct Sidebar<Selection: Hashable, Content: View, Footer: View>: View {
    @Binding private var selection: Selection
    private let isCollapsed: Bool
    private let header: AnyView?
    private let content: Content
    private let footer: Footer
    @State private var selectionWriter = SidebarSelectionWriter()

    /// - Parameters:
    ///   - selection: The selected row's value.
    ///   - isCollapsed: Icons only, titles in tooltips. Size the sidebar to
    ///     `Sizing.sidebarCollapsedWidth` while it's set.
    ///   - content: Sections, rows and dividers, top to bottom.
    ///   - footer: Rows pinned to the bottom (Settings).
    public init(
        selection: Binding<Selection>,
        isCollapsed: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self._selection = selection
        self.isCollapsed = isCollapsed
        self.header = nil
        self.content = content()
        self.footer = footer()
    }

    /// A sidebar with a slot pinned above the scrolling rows — a workspace
    /// switcher, a search field — the mirror of `footer`.
    ///
    /// - Parameters:
    ///   - selection: The selected row's value.
    ///   - isCollapsed: Icons only, titles in tooltips.
    ///   - header: Pinned above the rows; it doesn't scroll with them.
    ///   - content: Sections, rows and dividers, top to bottom.
    ///   - footer: Rows pinned to the bottom (Settings).
    public init<Header: View>(
        selection: Binding<Selection>,
        isCollapsed: Bool = false,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self._selection = selection
        self.isCollapsed = isCollapsed
        self.header = AnyView(header())
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        // Points the writer at the current binding; the writer itself stays the
        // same object, so rows aren't redrawn for it.
        let _ = selectionWriter.write = { [selection = $selection] value in
            if let typed = value.base as? Selection { selection.wrappedValue = typed }
        }
        VStack(spacing: 0) {
            if let header {
                VStack(alignment: .leading, spacing: Spacing.hairline) {
                    header
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xs)
            }

            ScrollViewWithThinIndicator(showFadeMask: true, indicatorTopPadding: Spacing.xs, indicatorBottomPadding: Spacing.xs) {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                // Room for the focus ring, which the scroll would clip.
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.sm)
            }

            VStack(alignment: .leading, spacing: Spacing.hairline) {
                footer
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.sm)
        }
        .environment(\.sidebarSelection, SidebarSelectionContext(selection: AnyHashable(selection), writer: selectionWriter))
        .environment(\.sidebarIsCollapsed, isCollapsed)
    }
}

extension Sidebar where Footer == EmptyView {
    /// A sidebar with no pinned footer.
    public init(selection: Binding<Selection>, isCollapsed: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, isCollapsed: isCollapsed, content: content, footer: { EmptyView() })
    }

    /// A sidebar with a pinned header and no footer.
    public init<Header: View>(
        selection: Binding<Selection>,
        isCollapsed: Bool = false,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(selection: selection, isCollapsed: isCollapsed, header: header, content: content, footer: { EmptyView() })
    }
}

// MARK: - Toggle button

/// The title-bar button that collapses and expands a `Sidebar`.
public struct SidebarToggleButton: View {
    @Binding private var isCollapsed: Bool

    /// - Parameter isCollapsed: The sidebar's collapsed state; a click flips it
    ///   on `Animations.pane`.
    public init(isCollapsed: Binding<Bool>) {
        self._isCollapsed = isCollapsed
    }

    public var body: some View {
        Button {
            withAnimation(Animations.pane) { isCollapsed.toggle() }
        } label: {
            Image(systemName: "sidebar.left")
        }
        .buttonStyle(ToolbarIconButtonStyle())
        // macOS's standard Toggle Sidebar shortcut.
        .keyboardShortcut("s", modifiers: [.control, .command])
        .tooltip(position: .below) {
            HStack(spacing: Spacing.xs) {
                label
                ShortcutKey("⌃⌘S", compact: true)
            }
        }
        .accessibilityLabel(label)
    }

    private var label: Text {
        isCollapsed ? Text("Show Sidebar", bundle: .module) : Text("Hide Sidebar", bundle: .module)
    }
}

// MARK: - Section

/// A group of sidebar rows under an optional small header ("Filters").
public struct SidebarSection<Content: View>: View {
    private let title: LocalizedStringKey?
    private let isExpanded: Binding<Bool>?
    private let trailing: AnyView?
    private let content: Content

    /// - Parameters:
    ///   - title: The header, looked up in your app's strings like `Text("…")`;
    ///     nil for a group without one.
    ///   - isExpanded: Makes the group collapsible: a chevron before the header
    ///     folds the rows away on `Animations.disclosure`. nil keeps it open.
    ///   - content: The rows.
    public init(_ title: LocalizedStringKey? = nil, isExpanded: Binding<Bool>? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.trailing = nil
        self.content = content()
    }

    /// A group whose header carries a control on its trailing edge — a "+" that
    /// adds a filter.
    ///
    /// - Parameters:
    ///   - title: The header.
    ///   - isExpanded: Makes the group collapsible; nil keeps it open.
    ///   - content: The rows.
    ///   - trailing: The header's control, after the title.
    public init<Trailing: View>(
        _ title: LocalizedStringKey,
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.isExpanded = isExpanded
        self.trailing = AnyView(trailing())
        self.content = content()
    }

    @Environment(\.sidebarIsCollapsed) private var isCollapsed

    private var showsRows: Bool { isExpanded?.wrappedValue ?? true }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            // No room for a header beside icons; the rows' tooltips carry the names.
            if let title, !isCollapsed {
                HStack(spacing: Spacing.xxs) {
                    if let isExpanded {
                        SidebarSectionChevron(isExpanded: isExpanded)
                    }
                    Text(title)
                        .font(Typography.labelXSmall)
                        // Secondary, not tertiary: the smaller size already ranks it
                        // under the rows, and tertiary faded out under High Contrast.
                        .foregroundStyle(Color.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    if let trailing {
                        Spacer(minLength: Spacing.xs)
                        trailing
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.xxs)
            }
            // Collapsed to icons, every group shows its rows: the header that
            // would fold them is gone.
            if showsRows || isCollapsed {
                content
                    .transition(.motion(.opacity))
            }
        }
        .animation(Animations.disclosure, value: showsRows)
    }
}

/// The chevron that folds a collapsible section: the outline list's, as a
/// Tab stop.
private struct SidebarSectionChevron: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(Animations.disclosure) { isExpanded.toggle() }
        } label: {
            Image(systemName: "chevron.right")
                .font(Typography.labelTinySemibold)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: Sizing.iconTiny, height: Sizing.iconTiny)
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: Spacing.hairline))
        .accessibilityLabel(isExpanded ? Text("Collapse", bundle: .module) : Text("Expand", bundle: .module))
    }
}

/// How a `SidebarRow`'s count is drawn.
public nonisolated enum SidebarCountStyle: Sendable {
    /// Filled with the accent: an unread count.
    case accent
    /// The neutral grey chip: a plain item count.
    case neutral
}

/// The thin hairline between a sidebar's groups.
public struct SidebarDivider: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(height: 1)
            .padding(.vertical, Spacing.sm)
            .accessibilityHidden(true)
    }
}

// MARK: - Row

/// How a sidebar row acts: it selects a value in the enclosing `Sidebar`, or
/// runs an action ("New filter") and is selected when told.
private enum SidebarRowRole {
    case value(AnyHashable)
    case action(isSelected: Bool, perform: () -> Void)
}

/// A destination in a `Sidebar`: an icon, a title, and a trailing count badge
/// that turns into its shortcut while ⌘ is held.
public struct SidebarRow: View {
    private let title: LocalizedStringKey
    private let icon: SidebarRowIconSource
    private let count: Int
    private let countStyle: SidebarCountStyle
    private let shortcut: String?
    private let role: SidebarRowRole
    /// Shown in place of the count while the pointer is on the row.
    private let trailing: AnyView?

    @Environment(\.sidebarSelection) private var sidebarSelection
    @Environment(\.sidebarIsCollapsed) private var isCollapsed
    // Disabled under a sheet or the command palette, where no hint shows.
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var shortcutHints: ShortcutHintService { .shared }

    /// A row that selects `value` in the enclosing `Sidebar`.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`; pass
    ///     `.verbatim(name)` for a name that isn't.
    ///   - icon: An SF Symbol, or a template asset from your app's catalog
    ///     (`icon-` prefix).
    ///   - value: What the row selects — of the sidebar's selection type.
    ///   - count: A trailing badge (unread, active runs); hidden at 0.
    ///   - countStyle: The accent fill for an unread count, the neutral chip for
    ///     a plain item count.
    ///   - shortcut: Shown in place of the count while ⌘ is held ("⌘1").
    ///     Display only: bind the key in your app's menus.
    public init<Value: Hashable>(
        _ title: LocalizedStringKey,
        icon: String,
        value: Value,
        count: Int = 0,
        countStyle: SidebarCountStyle = .accent,
        shortcut: String? = nil
    ) {
        self.title = title
        self.icon = .named(icon)
        self.count = count
        self.countStyle = countStyle
        self.shortcut = shortcut
        self.role = .value(AnyHashable(value))
        self.trailing = nil
    }

    /// A row that selects `value`, with a control that appears in place of its
    /// count while the pointer is on the row — a "+" or "…" per row.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`.
    ///   - icon: An SF Symbol, or an `icon-` asset.
    ///   - value: What the row selects.
    ///   - count: A trailing badge; hidden at 0 and while `trailing` shows.
    ///   - countStyle: How the count is drawn.
    ///   - shortcut: Shown in place of the count while ⌘ is held.
    ///   - trailing: The hover-revealed control; an icon button, usually.
    public init<Value: Hashable, Trailing: View>(
        _ title: LocalizedStringKey,
        icon: String,
        value: Value,
        count: Int = 0,
        countStyle: SidebarCountStyle = .accent,
        shortcut: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.icon = .named(icon)
        self.count = count
        self.countStyle = countStyle
        self.shortcut = shortcut
        self.role = .value(AnyHashable(value))
        self.trailing = AnyView(trailing())
    }

    /// A row that selects `value`, with an image for its icon — a logo, or
    /// anything else that isn't in your app's catalog.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`.
    ///   - image: Drawn as a template, like the symbol icons: its alpha is the
    ///     shape, in the row's text color.
    ///   - value: What the row selects.
    ///   - count: A trailing badge; hidden at 0.
    ///   - countStyle: How the count is drawn.
    ///   - shortcut: Shown in place of the count while ⌘ is held.
    public init<Value: Hashable>(
        _ title: LocalizedStringKey,
        image: Image,
        value: Value,
        count: Int = 0,
        countStyle: SidebarCountStyle = .accent,
        shortcut: String? = nil
    ) {
        self.title = title
        self.icon = .image(image)
        self.count = count
        self.countStyle = countStyle
        self.shortcut = shortcut
        self.role = .value(AnyHashable(value))
        self.trailing = nil
    }

    /// A row that runs `action` — a "New filter" row, or a destination your app
    /// selects itself.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`.
    ///   - icon: An SF Symbol, or an `icon-` asset.
    ///   - count: A trailing badge; hidden at 0.
    ///   - countStyle: How the count is drawn.
    ///   - shortcut: Shown in place of the count while ⌘ is held.
    ///   - isSelected: Draws the row selected.
    ///   - action: What a click (or Space / Return) does.
    public init(
        _ title: LocalizedStringKey,
        icon: String,
        count: Int = 0,
        countStyle: SidebarCountStyle = .accent,
        shortcut: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = .named(icon)
        self.count = count
        self.countStyle = countStyle
        self.shortcut = shortcut
        self.role = .action(isSelected: isSelected, perform: action)
        self.trailing = nil
    }

    private var isSelected: Bool {
        role.isSelected(in: sidebarSelection)
    }

    /// The hover control takes the count's place while the pointer is on the row.
    private var showsTrailing: Bool {
        trailing != nil && isHovering && !isCollapsed && isEnabled
    }

    public var body: some View {
        SidebarRowButton(isSelected: isSelected, action: { role.perform(in: sidebarSelection) }) {
            HStack(spacing: isCollapsed ? 0 : Spacing.sm) {
                SidebarRowIcon(source: icon)
                    .font(Typography.labelMedium)
                    .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    // Collapsed, a count is a dot on the icon.
                    .overlay(alignment: .topTrailing) {
                        if isCollapsed && count > 0 {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                                .offset(x: Spacing.hairline, y: -Spacing.hairline)
                                .transition(.opacity)
                        }
                    }
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    // Holding ⌘ swaps the count for the row's shortcut. The compact
                    // key is shorter than the row's icon, so the row never grows.
                    if let shortcut, shortcutHints.isShowingHints && isEnabled {
                        ShortcutKey(shortcut, compact: true)
                            .transition(.opacity)
                            .accessibilityHidden(true)
                    } else if let trailing, showsTrailing {
                        // Held to the line's height (the chip overhangs into
                        // the row's padding), so revealing it never makes the
                        // row taller.
                        trailing
                            .frame(height: Sizing.iconDefault)
                            .transition(.opacity)
                    } else if count > 0 {
                        countBadge
                            .transition(.opacity)
                    }
                }
                .sidebarRowText(isCollapsed: isCollapsed)
            }
        }
        .sidebarRowTitle(title, isCollapsed: isCollapsed)
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: showsTrailing)
        .onAppear { if shortcut != nil { shortcutHints.startIfNeeded() } }
    }

    /// The count: on the accent for unread, the neutral chip for a plain count.
    @ViewBuilder
    private var countBadge: some View {
        switch countStyle {
        case .accent:
            Badge(count: count)
                .badgeStyle(.custom(
                    text: AccentHue.contrastForeground,
                    icon: AccentHue.contrastForeground,
                    background: Color.accent,
                    border: nil
                ))
                .badgeSize(.small)
        case .neutral:
            Badge(count: count)
                .badgeStyle(.secondary)
                .badgeSize(.small)
        }
    }
}

// MARK: - Filter row

/// A saved filter (or any secondary destination) in a `Sidebar`: its mark — a
/// colored dot, or its own icon in its color — and a title.
public struct SidebarFilterRow: View {
    private let title: LocalizedStringKey
    private let icon: String
    private let color: Color
    private let role: SidebarRowRole

    @Environment(\.sidebarSelection) private var sidebarSelection
    @Environment(\.sidebarIsCollapsed) private var isCollapsed

    /// A filter row that selects `value` in the enclosing `Sidebar`.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`; pass
    ///     `.verbatim(name)` for a filter the user named.
    ///   - icon: `IconItem.statusDotName` for a dot, an SF Symbol, or an `icon-`
    ///     asset.
    ///   - color: The mark's color.
    ///   - value: What the row selects — of the sidebar's selection type.
    public init<Value: Hashable>(
        _ title: LocalizedStringKey,
        icon: String = IconItem.statusDotName,
        color: Color,
        value: Value
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.role = .value(AnyHashable(value))
    }

    /// A filter row that runs `action` — one that toggles a filter on and off.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`.
    ///   - icon: `IconItem.statusDotName` for a dot, an SF Symbol, or an `icon-` asset.
    ///   - color: The mark's color.
    ///   - isSelected: Draws the row selected.
    ///   - action: What a click (or Space / Return) does.
    public init(
        _ title: LocalizedStringKey,
        icon: String = IconItem.statusDotName,
        color: Color,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.role = .action(isSelected: isSelected, perform: action)
    }

    private var isSelected: Bool {
        role.isSelected(in: sidebarSelection)
    }

    public var body: some View {
        SidebarRowButton(isSelected: isSelected, action: { role.perform(in: sidebarSelection) }) {
            HStack(spacing: isCollapsed ? 0 : Spacing.sm) {
                // The filter's mark (dot / asset / SF Symbol) in its own color,
                // at the label size like the other rows' glyphs.
                IconGlyph(name: icon, color: color, size: FontSize.footnote)
                    .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                    .accessibilityHidden(true)
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .sidebarRowText(isCollapsed: isCollapsed)
            }
        }
        .sidebarRowTitle(title, isCollapsed: isCollapsed)
    }
}

// MARK: - Shared row chrome

extension SidebarRowRole {
    func isSelected(in context: SidebarSelectionContext?) -> Bool {
        switch self {
        case .value(let value): return context?.selection == value
        case .action(let isSelected, _): return isSelected
        }
    }

    func perform(in context: SidebarSelectionContext?) {
        switch self {
        case .value(let value): context?.writer.select(value)
        case .action(_, let perform): perform()
        }
    }
}

extension View {
    /// A row's title and trailing accessory: folded to nothing while the
    /// sidebar is collapsed. The views stay mounted (a structure change would
    /// drop a focused row's focus), so the width animates with the sidebar's.
    fileprivate func sidebarRowText(isCollapsed: Bool) -> some View {
        frame(maxWidth: isCollapsed ? 0 : .infinity)
            .opacity(isCollapsed ? 0 : 1)
            .clipped()
            .accessibilityHidden(isCollapsed)
    }

    /// Collapsed, the title moves into a tooltip and stays the row's
    /// accessibility label.
    fileprivate func sidebarRowTitle(_ title: LocalizedStringKey, isCollapsed: Bool) -> some View {
        tooltip(title, position: .trailing)
            .tooltipsDisabled(!isCollapsed)
            .accessibilityLabel(Text(title))
    }
}

/// What a row's icon is drawn from.
private enum SidebarRowIconSource {
    /// An `icon-` asset from the app's catalog, else an SF Symbol.
    case named(String)
    /// An image the app made or loaded, drawn as a template.
    case image(Image)
}

/// A row's icon, in the row's text color.
private struct SidebarRowIcon: View {
    let source: SidebarRowIconSource

    var body: some View {
        switch source {
        case .named(let name) where name.hasPrefix("icon-"):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        case .named(let name):
            Image(systemName: name)
        case .image(let image):
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }
}

/// The button every sidebar row is: the neutral `RowTint` fill (selected a step
/// above hover), no press state, a Tab stop with the shared ring, and the
/// selection said for VoiceOver. Collapsed to its icon, the row is a square
/// the row's height, centered in the rail.
private struct SidebarRowButton<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    @Environment(\.colorScheme) private var scheme
    @Environment(\.sidebarIsCollapsed) private var isCollapsed
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, isCollapsed ? 0 : Spacing.sm)
                .padding(.vertical, isCollapsed ? 0 : Spacing.navRowPaddingV)
                .frame(width: isCollapsed ? Sizing.controlDefault : nil, height: isCollapsed ? Sizing.controlDefault : nil)
                .frame(maxWidth: isCollapsed ? nil : .infinity, alignment: .leading)
                .background {
                    // Neutral RowTint over the themed shell (not a fixed system
                    // material), so selection and hover read as a tint of the
                    // active theme.
                    RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                        .fill(isSelected ? RowTint.selected(scheme) : (isHovering ? RowTint.hover(scheme) : Color.clear))
                }
                .animation(Animations.hover, value: isHovering)
                .animation(Animations.selection, value: isSelected)
                .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault))
        .onHover { isHovering = $0 }
        .frame(maxWidth: .infinity)
        // Selection is only a fill; say it for VoiceOver.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Resize handle

extension View {
    /// A grip on a sidebar's trailing edge: drag it to make the sidebar wider or
    /// narrower. The same grip as `InspectorSplit`'s — shown on hover, a
    /// column-resize pointer, adjustable with VoiceOver.
    ///
    /// ```swift
    /// @AppStorage("sidebarWidth") private var sidebarWidth: Double = 220
    ///
    /// Sidebar(selection: $destination, isCollapsed: isCollapsed) { … }
    ///     .frame(width: isCollapsed ? Sizing.sidebarCollapsedWidth : sidebarWidth)
    ///     .sidebarResizeHandle(width: $sidebarWidth, in: 180...360, isEnabled: !isCollapsed)
    /// ```
    ///
    /// - Parameters:
    ///   - width: The sidebar's width; keep it in `@AppStorage` to remember it.
    ///   - range: The narrowest and widest the grip goes.
    ///   - isEnabled: Turn it off while the sidebar is collapsed to its icons.
    public func sidebarResizeHandle(width: Binding<Double>, in range: ClosedRange<Double>, isEnabled: Bool = true) -> some View {
        overlay(alignment: .trailing) {
            if isEnabled {
                SidebarResizeGrip(width: width, range: range)
            }
        }
    }
}

/// The strip straddling the sidebar's trailing edge. The drag is measured in
/// the window, not the strip: the strip moves with the edge it drags.
private struct SidebarResizeGrip: View {
    @Binding var width: Double
    let range: ClosedRange<Double>

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isHovering = false
    @State private var dragStartWidth: Double?

    private static var gripWidth: CGFloat { Spacing.sm }
    /// The pill's width and tone while the grip shows.
    private static var pillWidth: CGFloat { Spacing.insetSpacing }
    private static let pillOpacity: Double = 0.25
    /// How far one VoiceOver increment moves the edge.
    private static var keyboardStep: Double { Double(Spacing.xl) }

    /// Right-to-left, the trailing edge is on the left, so dragging left widens.
    private var trailingSign: Double { layoutDirection == .rightToLeft ? -1 : 1 }

    var body: some View {
        Color.clear
            .frame(width: Self.gripWidth)
            .frame(maxHeight: .infinity)
            .overlay {
                Capsule()
                    .fill(Color.primary.opacity(Self.pillOpacity))
                    .frame(width: Self.pillWidth, height: Sizing.controlLarge)
                    .opacity(isHovering || dragStartWidth != nil ? 1 : 0)
                    .animation(Animations.hover, value: isHovering || dragStartWidth != nil)
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = width }
                        width = clamped(start + Double(value.translation.width) * trailingSign)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
            // Straddle the edge.
            .offset(x: Self.gripWidth / 2)
            // In a hidden-title-bar window the grip can reach up into the title
            // bar band, where a press would drag the window instead.
            .windowDragDisabled()
            .accessibilityElement()
            .accessibilityLabel(Text("Sidebar width", bundle: .module))
            .accessibilityValue(Text(verbatim: "\(Int(width))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: width = clamped(width + Self.keyboardStep)
                case .decrement: width = clamped(width - Self.keyboardStep)
                @unknown default: break
                }
            }
    }

    private func clamped(_ proposed: Double) -> Double {
        min(max(proposed, range.lowerBound), range.upperBound).rounded()
    }
}

// MARK: - Preview

private enum SidebarPreviewDestination: Hashable {
    case inbox, today, upcoming, running, review, clients, settings
}

#Preview(traits: .fixedLayout(width: 240, height: 440)) {
    @Previewable @State var destination = SidebarPreviewDestination.today
    Sidebar(selection: $destination) {
        SidebarSection {
            SidebarRow("Inbox", icon: "tray", value: SidebarPreviewDestination.inbox, count: 4, shortcut: "⌘1")
            SidebarRow("Today", icon: "sun.max", value: SidebarPreviewDestination.today, shortcut: "⌘2")
            SidebarRow("Upcoming", icon: "calendar", value: SidebarPreviewDestination.upcoming, shortcut: "⌘3")
        }
        SidebarDivider()
        SidebarSection("Filters") {
            SidebarFilterRow("Running", color: Success.success500, value: SidebarPreviewDestination.running)
            SidebarFilterRow("In review", color: Warning.warning500, value: SidebarPreviewDestination.review)
            SidebarFilterRow("Clients", icon: "star.fill", color: Info.info500, value: SidebarPreviewDestination.clients)
            SidebarRow("New filter", icon: "plus") {}
        }
    } footer: {
        SidebarRow("Settings", icon: "gearshape", value: SidebarPreviewDestination.settings, shortcut: "⌘,")
    }
    .frame(width: Sizing.sidebarMinWidth)
    .background(Color.appShell)
}

#Preview("Collapsed", traits: .fixedLayout(width: 80, height: 300)) {
    @Previewable @State var destination = SidebarPreviewDestination.today
    Sidebar(selection: $destination, isCollapsed: true) {
        SidebarSection {
            SidebarRow("Inbox", icon: "tray", value: SidebarPreviewDestination.inbox, count: 4, shortcut: "⌘1")
            SidebarRow("Today", icon: "sun.max", value: SidebarPreviewDestination.today, shortcut: "⌘2")
            SidebarRow("Upcoming", icon: "calendar", value: SidebarPreviewDestination.upcoming, shortcut: "⌘3")
        }
        SidebarDivider()
        SidebarSection("Filters") {
            SidebarFilterRow("Running", color: Success.success500, value: SidebarPreviewDestination.running)
            SidebarFilterRow("Clients", icon: "star.fill", color: Info.info500, value: SidebarPreviewDestination.clients)
        }
    } footer: {
        SidebarRow("Settings", icon: "gearshape", value: SidebarPreviewDestination.settings, shortcut: "⌘,")
    }
    .frame(width: Sizing.sidebarCollapsedWidth)
    .background(Color.appShell)
}
