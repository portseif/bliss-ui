//
//  CommandSidebarPage.swift
//  BlissCatalog
//
//  The "Command & Sidebar" page: the ⌘K command palette, the navigation
//  sidebar and the slideout panel, each inside a small mock window so it can
//  take over the window the way it would in an app.
//
//  `-demo palette` opens the palette and `-demo slideout` the panel, for
//  screenshots.
//

import BlissUI
import SwiftUI

struct CommandSidebarPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Command palette") {
                CommandPaletteDemo()
            }
            DemoBlock(title: "Sidebar") {
                SidebarDemo()
            }
            DemoBlock(title: "Slideout panel") {
                SlideoutPanelDemo()
            }
        }
    }
}

// MARK: - Sample data

/// The destinations the demos navigate between.
enum CatalogDestination: Hashable {
    case inbox, today, upcoming, projects, settings
    case running, inReview, recent
    case savedFilter(Int)
}

/// A saved filter the sidebar demo lists (and the New filter row adds).
struct CatalogSavedFilter: Identifiable, Hashable {
    let id: Int
    let name: String
    let icon: String
    let color: Color
}

enum CommandSidebarSamples {
    private static let projects: [(name: String, path: String, isRunning: Bool)] = [
        ("Apollo", "~/Developer/apollo", true),
        ("Borealis", "~/Developer/borealis", false),
        ("Cascade", "~/Developer/cascade", true),
        ("Dune", "~/Developer/dune", false),
        ("Prospect", "~/Developer/prospect", false),
        ("Fjord", "~/Clients/fjord", true),
        ("Glacier", "~/Clients/glacier", false),
        ("Horizon", "~/Clients/horizon", false),
    ]

    /// The palette's sections: destinations under `#`, projects under `@` (only
    /// when searched or scoped to), actions under `>`. Each command reports its
    /// title to `onRun`.
    static func paletteSections(onRun: @escaping (String) -> Void) -> [CommandPaletteSection] {
        func command(
            _ id: String,
            _ title: String,
            subtitle: String? = nil,
            icon: String,
            iconColor: Color? = nil,
            shortcut: String? = nil,
            tag: String? = nil,
            keywords: [String] = []
        ) -> CommandPaletteCommand {
            CommandPaletteCommand(
                id: id,
                title: title,
                subtitle: subtitle,
                icon: icon,
                iconColor: iconColor,
                shortcut: shortcut,
                tag: tag,
                keywords: keywords
            ) { onRun(title) }
        }

        return [
            CommandPaletteSection("Go to", prefix: "#", commands: [
                command("go-inbox", "Inbox", icon: "tray", shortcut: "⌘1"),
                command("go-today", "Today", icon: "sun.max", shortcut: "⌘2"),
                command("go-upcoming", "Upcoming", icon: "calendar", shortcut: "⌘3"),
                command("go-projects", "Projects", icon: "folder", shortcut: "⌘4"),
                command("go-settings", "Settings", icon: "gearshape", shortcut: "⌘,", keywords: ["preferences"]),
            ]),
            CommandPaletteSection("Projects", prefix: "@", showsWithoutQuery: false, maxResults: 5, commands: projects.map { project in
                command(
                    "project-\(project.name)",
                    project.name,
                    subtitle: project.path,
                    icon: IconItem.statusDotName,
                    iconColor: project.isRunning ? Success.success500 : Grey.grey400,
                    tag: "Open"
                )
            }),
            CommandPaletteSection("Actions", prefix: ">", commands: [
                command("new-project", "New project", subtitle: "Start from a template", icon: "plus.circle", shortcut: "⌘N", keywords: ["create", "add"]),
                command("new-filter", "New filter", subtitle: "A saved view of your projects", icon: "line.3.horizontal.decrease", tag: "New"),
                command("invite", "Invite teammate", subtitle: "Share this workspace", icon: "person.badge.plus", tag: "New", keywords: ["share"]),
                command("export", "Export as CSV", subtitle: "Every project, with its status", icon: "square.and.arrow.up", tag: "Run", keywords: ["download"]),
            ]),
        ]
    }

    static let savedFilters: [CatalogSavedFilter] = [
        CatalogSavedFilter(id: 1, name: "Client work", icon: "bookmark.fill", color: Info.info500),
        CatalogSavedFilter(id: 2, name: "Side projects", icon: IconItem.statusDotName, color: Purple.purple400),
    ]

    /// The marks a new saved filter cycles through.
    static let filterMarks: [(icon: String, color: Color)] = [
        ("star.fill", Warning.warning500),
        ("flag.fill", Danger.danger500),
        (IconItem.statusDotName, Success.success500),
    ]
}

// MARK: - Mock window

/// A small window inside the page: the shell surface with a hairline border,
/// so a palette or a panel can take it over.
private struct DemoWindow<Content: View>: View {
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Color.appShell)
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
    }
}

/// Placeholder rows standing in for a page.
private struct DemoPageRows: View {
    let titles: [String]

    var body: some View {
        DividedForEach(titles, id: \.self) { title in
            HStack(spacing: Spacing.sm) {
                Image(systemName: "circle")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Text(verbatim: title)
                    .font(Typography.bodySmall)
                Spacer()
                TimeAgoLabel(date: Date().addingTimeInterval(-7_200))
                    .foregroundStyle(.secondary)
            }
            .rowHover()
        }
    }
}

// MARK: - Command palette

private struct CommandPaletteDemo: View {
    @State private var isPresented = CatalogDemo.state == "palette"
    @State private var lastRun: String?
    @State private var isHoveringTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Press ⌘K or click the search field. Typing ranks the commands; # / @ / > narrow them to a section. ↑ ↓ or Tab move, Return runs, Esc clears and then closes.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DemoWindow(height: 460) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack {
                        Spacer()
                        searchTrigger
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Today")
                            .font(Typography.headingMedium)
                        if let lastRun {
                            Text("Ran “\(lastRun)”")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DemoPageRows(titles: ["Review the Q3 roadmap", "Ship the Low Glare theme", "Reply to Ada", "Tune the sheet spring"])
                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.contentAreaBackground)
                .commandPalette(
                    isPresented: $isPresented,
                    commands: CommandSidebarSamples.paletteSections { lastRun = $0 },
                    recentsKey: "blissCatalog.commandPalette.recents"
                )
            }
        }
    }

    /// The resting search field: a button that toggles the palette.
    private var searchTrigger: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.labelSmall)
                    .foregroundStyle(.secondary)
                Text("Search or jump to…")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Spacing.lg)
                ShortcutKey("⌘K")
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(width: 320)
            .inputBox(isFocused: false, cornerRadius: Sizing.radiusMedium)
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium))
    }
}

// MARK: - Sidebar

private struct SidebarDemo: View {
    @State private var selection = CatalogDestination.today
    @State private var savedFilters = CommandSidebarSamples.savedFilters

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Click a row, or Tab to it and press Space. Hold ⌘ to see each row's shortcut. Right-click a saved filter to remove it; New filter adds one.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DemoWindow(height: 440) {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 220)
                    detail
                }
            }
        }
    }

    private var sidebar: some View {
        Sidebar(selection: $selection) {
            SidebarSection {
                SidebarRow("Inbox", icon: "tray", value: CatalogDestination.inbox, count: 4, shortcut: "⌘1")
                SidebarRow("Today", icon: "sun.max", value: CatalogDestination.today, shortcut: "⌘2")
                SidebarRow("Upcoming", icon: "calendar", value: CatalogDestination.upcoming, shortcut: "⌘3")
                SidebarRow("Projects", icon: "folder", value: CatalogDestination.projects, count: 12, shortcut: "⌘4")
            }
            SidebarDivider()
            SidebarSection("Filters") {
                SidebarFilterRow("Running", color: Success.success500, value: CatalogDestination.running)
                SidebarFilterRow("In review", color: Warning.warning500, value: CatalogDestination.inReview)
                SidebarFilterRow("Recent", color: Info.info500, value: CatalogDestination.recent)
                ForEach(savedFilters) { filter in
                    SidebarFilterRow(.verbatim(filter.name), icon: filter.icon, color: filter.color, value: CatalogDestination.savedFilter(filter.id))
                        .accessibilityAction(named: Text("Remove Filter")) { remove(filter) }
                        .onSecondaryClick { screenPoint in
                            PopupMenuService.shared.show(at: screenPoint) {
                                QuickActionMenuItem(title: "Remove “\(filter.name)”", icon: "trash", isDestructive: true) {
                                    remove(filter)
                                    PopupMenuService.shared.hide()
                                }
                                .padding(Spacing.menuPadding)
                                .fixedSize()
                            }
                        }
                }
                SidebarRow("New filter", icon: "plus") { addFilter() }
            }
        } footer: {
            SidebarRow("Settings", icon: "gearshape", value: CatalogDestination.settings, shortcut: "⌘,")
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(verbatim: title(for: selection))
                .font(Typography.headingMedium)
            DemoPageRows(titles: ["Design review", "Write release notes", "Audit focus rings"])
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.contentAreaBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .padding(.top, Spacing.sm)
    }

    private func title(for destination: CatalogDestination) -> String {
        switch destination {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .projects: return "Projects"
        case .settings: return "Settings"
        case .running: return "Running"
        case .inReview: return "In review"
        case .recent: return "Recent"
        case .savedFilter(let id): return savedFilters.first { $0.id == id }?.name ?? "Filter"
        }
    }

    private func addFilter() {
        let id = (savedFilters.map(\.id).max() ?? 0) + 1
        let mark = CommandSidebarSamples.filterMarks[id % CommandSidebarSamples.filterMarks.count]
        let filter = CatalogSavedFilter(id: id, name: "Saved filter \(id)", icon: mark.icon, color: mark.color)
        savedFilters.append(filter)
        selection = .savedFilter(id)
    }

    private func remove(_ filter: CatalogSavedFilter) {
        if selection == .savedFilter(filter.id) { selection = .today }
        savedFilters.removeAll { $0.id == filter.id }
    }
}

// MARK: - Slideout panel

private struct SlideoutPanelDemo: View {
    @State private var isPresented = CatalogDemo.state == "slideout"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("The bell slides the panel in over the window's trailing edge. Esc, its ✕ or a click outside closes it.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DemoWindow(height: 400) {
                SlideoutPageSample(isPresented: $isPresented)
                    .slideoutPanel(isPresented: $isPresented, title: "Notifications") {
                        NotificationsSample()
                    } actions: {
                        Button("Mark all read") {}
                            .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 3))
                            .font(Typography.labelSmall)
                            .foregroundStyle(Color.accent)
                    }
            }
        }
    }
}

/// The page under the panel: a heading, a bell that toggles it, and rows.
struct SlideoutPageSample: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Projects")
                    .font(Typography.headingMedium)
                Spacer()
                Button { isPresented.toggle() } label: {
                    Image(systemName: "bell")
                }
                .buttonStyle(ToolbarIconButtonStyle(isActive: isPresented))
                .accessibilityLabel(Text("Notifications"))
                .tooltip("Notifications", position: .below)
            }
            DemoPageRows(titles: ["Apollo", "Borealis", "Cascade", "Dune", "Everest"])
            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.contentAreaBackground)
    }
}

/// A notifications feed for the panel: rows that each name what happened.
struct NotificationsSample: View {
    private let notifications: [(icon: String, tint: Color, title: String, detail: String, minutesAgo: Double)] = [
        ("exclamationmark.triangle", Warning.warning500, "Build failed", "Borealis · main", 4),
        ("checkmark.circle", Success.success500, "Deploy finished", "Apollo · production", 26),
        ("externaldrive", Info.info500, "Backup completed", "Cascade · 1.2 GB", 95),
        ("person.badge.plus", Purple.purple400, "Invite accepted", "Grace joined the workspace", 240),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent activity")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.xs)
            DividedForEach(notifications, id: \.title) { notification in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: notification.icon)
                        .font(Typography.bodySmall)
                        .foregroundStyle(notification.tint)
                        .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: notification.title)
                            .font(Typography.bodySmall)
                            .lineLimit(1)
                        Text(verbatim: notification.detail)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Spacing.sm)
                    TimeAgoLabel(date: Date().addingTimeInterval(-notification.minutesAgo * 60))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .rowHover()
            }
        }
    }
}
