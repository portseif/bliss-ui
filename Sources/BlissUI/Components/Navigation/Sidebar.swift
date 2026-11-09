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
struct SidebarSelectionContext {
    let selection: AnyHashable
    let select: (AnyHashable) -> Void
}

private struct SidebarSelectionKey: EnvironmentKey {
    static let defaultValue: SidebarSelectionContext? = nil
}

extension EnvironmentValues {
    var sidebarSelection: SidebarSelectionContext? {
        get { self[SidebarSelectionKey.self] }
        set { self[SidebarSelectionKey.self] = newValue }
    }
}

private struct SidebarIsCollapsedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Set by a collapsed `Sidebar`: rows draw their icon alone.
    var sidebarIsCollapsed: Bool {
        get { self[SidebarIsCollapsedKey.self] }
        set { self[SidebarIsCollapsedKey.self] = newValue }
    }
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
    private let content: Content
    private let footer: Footer

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
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewWithThinIndicator(showFadeMask: true, indicatorTopPadding: Spacing.xs, indicatorBottomPadding: Spacing.xs) {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                // Room for the focus ring, which the scroll would clip.
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.sm)
            }

            VStack(alignment: .leading, spacing: 1) {
                footer
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.sm)
        }
        .environment(\.sidebarSelection, SidebarSelectionContext(
            selection: AnyHashable(selection),
            select: { value in
                if let typed = value.base as? Selection { selection = typed }
            }
        ))
        .environment(\.sidebarIsCollapsed, isCollapsed)
    }
}

extension Sidebar where Footer == EmptyView {
    /// A sidebar with no pinned footer.
    public init(selection: Binding<Selection>, isCollapsed: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, isCollapsed: isCollapsed, content: content, footer: { EmptyView() })
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
        .tooltip(position: .below) { label.font(Typography.labelSmall) }
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
    private let content: Content

    /// - Parameters:
    ///   - title: The header, looked up in your app's strings like `Text("…")`;
    ///     nil for a group without one.
    ///   - content: The rows.
    public init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    @Environment(\.sidebarIsCollapsed) private var isCollapsed

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // No room for a header beside icons; the rows' tooltips carry the names.
            if let title, !isCollapsed {
                Text(title)
                    .font(Typography.labelXSmall)
                    // Secondary, not tertiary: the smaller size already ranks it
                    // under the rows, and tertiary faded out under High Contrast.
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xxs)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
    }
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
    private let icon: String
    private let count: Int
    private let shortcut: String?
    private let role: SidebarRowRole

    @Environment(\.sidebarSelection) private var sidebarSelection
    @Environment(\.sidebarIsCollapsed) private var isCollapsed
    // Disabled under a sheet or the command palette, where no hint shows.
    @Environment(\.isEnabled) private var isEnabled

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
    ///   - shortcut: Shown in place of the count while ⌘ is held ("⌘1").
    ///     Display only: bind the key in your app's menus.
    public init<Value: Hashable>(
        _ title: LocalizedStringKey,
        icon: String,
        value: Value,
        count: Int = 0,
        shortcut: String? = nil
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.shortcut = shortcut
        self.role = .value(AnyHashable(value))
    }

    /// A row that runs `action` — a "New filter" row, or a destination your app
    /// selects itself.
    ///
    /// - Parameters:
    ///   - title: Looked up in your app's strings like `Text("…")`.
    ///   - icon: An SF Symbol, or an `icon-` asset.
    ///   - count: A trailing badge; hidden at 0.
    ///   - shortcut: Shown in place of the count while ⌘ is held.
    ///   - isSelected: Draws the row selected.
    ///   - action: What a click (or Space / Return) does.
    public init(
        _ title: LocalizedStringKey,
        icon: String,
        count: Int = 0,
        shortcut: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.shortcut = shortcut
        self.role = .action(isSelected: isSelected, perform: action)
    }

    private var isSelected: Bool {
        role.isSelected(in: sidebarSelection)
    }

    public var body: some View {
        SidebarRowButton(isSelected: isSelected, action: { role.perform(in: sidebarSelection) }) {
            HStack(spacing: isCollapsed ? 0 : Spacing.sm) {
                SidebarRowIcon(name: icon)
                    .font(Typography.labelMedium)
                    .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    // Collapsed, a count is a dot on the icon.
                    .overlay(alignment: .topTrailing) {
                        if isCollapsed && count > 0 {
                            Circle()
                                .fill(Color.accent)
                                .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                                .offset(x: 2, y: -2)
                                .transition(.opacity)
                        }
                    }
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    // Holding ⌘ swaps the count for the row's shortcut. The compact
                    // key is shorter than the row's icon, so the row never grows.
                    if let shortcut, shortcutHints.isShowingHints && isEnabled {
                        ShortcutKey(shortcut, compact: true)
                            .transition(.opacity)
                            .accessibilityHidden(true)
                    } else if count > 0 {
                        Badge(count: count)
                            .badgeStyle(.custom(
                                text: AccentHue.contrastForeground,
                                icon: AccentHue.contrastForeground,
                                background: Color.accent,
                                border: nil
                            ))
                            .badgeSize(.small)
                            .transition(.opacity)
                    }
                }
                .sidebarRowText(isCollapsed: isCollapsed)
            }
        }
        .sidebarRowTitle(title, isCollapsed: isCollapsed)
        .onAppear { if shortcut != nil { shortcutHints.startIfNeeded() } }
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
                // The filter's mark (dot / asset / SF Symbol) in its own color.
                IconGlyph(name: icon, color: color, size: 15)
                    .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                    .accessibilityHidden(true)
                HStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
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
        case .value(let value): context?.select(value)
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

/// A row's icon: an `icon-` asset from the app's catalog, else an SF Symbol.
private struct SidebarRowIcon: View {
    let name: String

    var body: some View {
        if name.hasPrefix("icon-") {
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: name)
        }
    }
}

/// The button every sidebar row is: the neutral `RowTint` fill (selected a step
/// above hover), no press state, a Tab stop with the shared ring, and the
/// selection said for VoiceOver.
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
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs + 1)
                .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
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
        // Selection is only a fill; say it for VoiceOver.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
    .frame(width: 220)
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
