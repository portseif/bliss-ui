import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the command palette, the
/// sidebar and the slideout panel, built the way an app would.
@MainActor
@Suite struct CommandSidebarAPITests {
    private enum Destination: Hashable {
        case inbox, today, running, settings
    }

    @Test func commandPaletteIsReachable() {
        var ranCommand = false
        let command = CommandPaletteCommand(
            id: "new-project",
            title: "New Project",
            subtitle: "Start from a template",
            icon: "plus.circle",
            iconColor: .secondary,
            shortcut: "⌘N",
            tag: "New",
            keywords: ["create"],
            recordsRecent: false
        ) { ranCommand = true }
        let section = CommandPaletteSection(
            "Actions",
            prefix: ">",
            showsWithoutQuery: false,
            maxResults: 5,
            commands: [command, CommandPaletteCommand(id: "minimal", title: "Minimal") {}]
        )

        #expect(command.id == "new-project")
        #expect(command.title == "New Project")
        #expect(command.subtitle == "Start from a template")
        #expect(command.shortcut == "⌘N")
        #expect(command.keywords == ["create"])
        #expect(!command.recordsRecent)
        command.action()
        #expect(ranCommand)

        #expect(section.title == "Actions")
        #expect(section.prefix == ">")
        #expect(!section.showsWithoutQuery)
        #expect(section.maxResults == 5)
        #expect(section.commands.count == 2)

        let defaults = CommandPaletteSection("Go to", commands: [])
        #expect(defaults.prefix == nil && defaults.showsWithoutQuery && defaults.maxResults == nil)

        _ = CommandPalette(commands: [section], query: .constant(""), onDismiss: {})
        _ = CommandPalette(
            commands: [section],
            query: .constant("new"),
            placeholder: "Search",
            recentsKey: nil,
            focusesFieldOnAppear: false,
            onDismiss: {}
        )

        _ = Text("Window").commandPalette(isPresented: .constant(false), commands: [section])
        _ = Text("Window").commandPalette(
            isPresented: .constant(false),
            commands: [section],
            shortcut: KeyboardShortcut("p", modifiers: [.command, .shift]),
            placeholder: "Type a command",
            recentsKey: "app.palette.recents"
        )
        _ = Text("Window").commandPalette(isPresented: .constant(false), commands: [command], shortcut: nil, recentsKey: nil)
    }

    @Test func sidebarIsReachable() {
        _ = Sidebar(selection: .constant(Destination.today)) {
            SidebarSection {
                SidebarRow("Inbox", icon: "tray", value: Destination.inbox, count: 3, shortcut: "⌘1")
                SidebarRow("Today", icon: "sun.max", value: Destination.today)
            }
            SidebarDivider()
            SidebarSection("Filters") {
                SidebarFilterRow("Running", color: .green, value: Destination.running)
                SidebarFilterRow(.verbatim("Saved"), icon: "star.fill", color: .orange, value: Destination.running)
                SidebarFilterRow("Toggled", color: .blue, isSelected: true) {}
                SidebarRow("New filter", icon: "plus") {}
                SidebarRow("Picked", icon: "folder", count: 2, shortcut: "⌘2", isSelected: true) {}
            }
        } footer: {
            SidebarRow("Settings", icon: "gearshape", value: Destination.settings, shortcut: "⌘,")
        }

        _ = Sidebar(selection: .constant(Optional<Destination>.none)) {
            SidebarRow("Inbox", icon: "tray", value: Optional(Destination.inbox))
        }
    }

    @Test func slideoutPanelIsReachable() {
        _ = Text("Page").slideoutPanel(isPresented: .constant(false), title: "Notifications") {
            Text("Row")
        }
        _ = Text("Page").slideoutPanel(isPresented: .constant(true), title: "Inspector", edge: .leading, width: 280) {
            Text("Row")
        } actions: {
            Button("Mark all read") {}
        }
    }

    @Test func sidebarCollapses() {
        _ = Sidebar(selection: .constant(1), isCollapsed: true) {
            SidebarRow("Inbox", icon: "tray", value: 1, count: 3)
            SidebarFilterRow("Running", color: Success.success500, value: 2)
        }
        .frame(width: Sizing.sidebarCollapsedWidth)
        _ = Sidebar(selection: .constant(1), isCollapsed: false, content: { SidebarRow("Inbox", icon: "tray", value: 1) }, footer: { SidebarRow("Settings", icon: "gearshape", value: 9) })
        _ = SidebarToggleButton(isCollapsed: .constant(false))
    }

    @Test func outlineListIsReachable() {
        struct Node: Identifiable {
            let id: Int
            var children: [Node]? = nil
        }
        let tree = [Node(id: 1, children: [Node(id: 2)]), Node(id: 3)]
        _ = OutlineList(tree, children: \.children, selection: .constant(nil), expanded: .constant([1])) { node in
            Text(verbatim: "\(node.id)")
        }
        _ = OutlineList(tree, children: \.children, selection: .constant(2), expanded: .constant([]), indent: 20) { _ in
            Text("Row")
        }
    }
}
