import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the parameters the consistency
/// pass added to the navigation, overlay and sheet components, built the way
/// an app would.
@MainActor
@Suite struct NavigationVariantsAPITests {
    private enum Destination: Hashable {
        case inbox, today, settings
    }

    private struct Node: Identifiable {
        let id: String
        var children: [Node]? = nil
    }

    private struct Item: Identifiable {
        let id = UUID()
    }

    @Test func commandPaletteVariantsAreReachable() {
        let commands = [CommandPaletteCommand(id: "a", title: "A") {}]
        _ = CommandPalette(
            commands: [CommandPaletteSection("Go", commands: commands)],
            query: .constant(""),
            compact: true,
            showsLegend: false,
            noResultsText: "No projects match",
            onDismiss: {}
        )
        _ = Text("Page")
            .commandPalette(
                isPresented: .constant(false),
                commands: commands,
                width: Sizing.sheetWidthLarge,
                placement: .center,
                compact: true,
                showsLegend: false,
                noResultsText: "Nothing"
            )
        _ = Text("Page")
            .commandPalette(isPresented: .constant(false), commands: [CommandPaletteSection("Go", commands: commands)], placement: .top)
        #expect(CommandPaletteMetrics.maxResultsHeight > 0)
        #expect(Sizing.commandPaletteWidth == 640)
    }

    @Test func outlineListVariantsAreReachable() {
        let tree = [Node(id: "root", children: [Node(id: "leaf")])]
        var opened: String?
        _ = OutlineList(tree, children: \.children, selection: .constant(nil), expanded: .constant([]), compact: true, onOpen: { opened = $0.id }) { node in
            Text(verbatim: node.id)
        }
        _ = OutlineList(tree, children: \.children, selection: .constant("leaf"), expanded: .constant(["root"])) { node in
            Text(verbatim: node.id)
        } accessory: { node in
            Badge(count: node.children?.count ?? 0).badgeSize(.small)
        }
        #expect(opened == nil)
    }

    @Test func sidebarVariantsAreReachable() {
        _ = Sidebar(selection: .constant(Destination.inbox), header: {
            TextField("Search", text: .constant("")).textFieldStyle(.toolbarSearch)
        }) {
            SidebarSection("Mail", isExpanded: .constant(true)) {
                SidebarRow("Inbox", icon: "tray", value: Destination.inbox, count: 4, countStyle: .neutral)
                SidebarRow("Today", icon: "sun.max", value: Destination.today, count: 2) {
                    Button {} label: { Image(systemName: "plus") }
                }
            } trailing: {
                Button {} label: { Image(systemName: "plus") }
            }
            SidebarRow("New", icon: "plus", countStyle: .accent) {}
        }
        _ = Sidebar(selection: .constant(Destination.inbox), header: { Text("Workspace") }) {
            SidebarRow("Settings", icon: "gearshape", value: Destination.settings, countStyle: .accent)
        } footer: {
            SidebarRow("Settings", icon: "gearshape", value: Destination.settings)
        }
        let style: SidebarCountStyle = .neutral
        #expect(style == .neutral)
    }

    @Test func slideoutPanelVariantsAreReachable() {
        _ = Text("Page")
            .slideoutPanel(
                isPresented: .constant(true),
                title: "Notifications",
                subtitle: "3 unread",
                edge: .leading,
                width: Sizing.slideoutPanelWidth,
                insetsContent: false,
                dimsBackground: true
            ) {
                Text("Rows")
            }
        _ = Text("Page")
            .slideoutPanel(isPresented: .constant(false), title: "Inspector") {
                Text("Rows")
            } actions: {
                Button("Mark all read") {}
            } footer: {
                Button("Clear") {}
            }
    }

    @Test func stepIndicatorVariantsAreReachable() {
        _ = StepIndicator(stepCount: 4, currentIndex: 1, axis: .vertical, style: .segments)
        _ = StepIndicator(stepCount: 5, currentIndex: 2, grows: true)
        _ = StepIndicator(stepCount: 5, currentIndex: 2, axis: .vertical, grows: true)
        _ = StepIndicator(stepCount: 3, currentIndex: 2, labels: ["Account", "Plan", "Done"], onSelect: { _ in })
        let style: StepIndicatorStyle = .dots
        #expect(style == .dots)
    }

    @Test func underlineTabBarVariantsAreReachable() {
        let items = [
            UnderlineTabItem(value: "a", title: "A", icon: "tray", count: 3, isCountProminent: true),
            UnderlineTabItem(value: "b", title: "B", isEnabled: false),
        ]
        #expect(items[0].isCountProminent)
        #expect(!items[1].isEnabled)
        _ = UnderlineTabBar(items: items, selection: .constant("a"), compact: true, showsTitles: false)
    }

    @Test func floatingMenuVariantsAreReachable() {
        _ = Text("Trigger")
            .floatingMenu(isPresented: .constant(false), width: .matchesTrigger, maxHeight: 300) {
                Text("Rows")
            }
        _ = Text("Trigger")
            .floatingMenu(isPresented: .constant(false), itemCount: 1, focusedIndex: .constant(nil), width: .fixed(Sizing.menuMinWidth)) {
                Text("Rows")
            }
        #expect(FloatingMenuWidth.content == .content)
        #expect(FloatingMenuMetrics.maxContentHeight == 420)
    }

    @Test func contextMenuVariantsAreReachable() {
        _ = Text("Row")
            .blissContextMenu(isEnabled: false) {
                MenuSectionHeader("Open with")
                QuickActionMenuItem(title: "Rename", icon: "pencil") {}
            }
        _ = MenuSectionHeader("Document")
    }

    @Test func tooltipVariantsAreReachable() {
        _ = Text("Button").tooltip("Hide Sidebar", shortcut: "⌃⌘S", position: .below)
        _ = Text("File").tooltip("Report.pdf", detail: "2.4 MB", position: .above)
        _ = Text("Copy").tooltip("Copied", isPresented: .constant(false))
        let configuration = TooltipConfiguration(maxWidth: 200, delay: .none)
        #expect(configuration.delay == .none)
        #expect(TooltipConfiguration.default.delay == .standard)
        #expect(TooltipMetrics.maxWidth == 250)
    }

    @Test func appSheetVariantsAreReachable() {
        _ = Text("Page")
            .appSheet(isPresented: .constant(false), size: .small, dismissesOnScrimTap: true, interactiveDismissDisabled: true) {
                Text("Sheet")
            }
        _ = Text("Page")
            .appSheet(item: .constant(Optional<Item>.none), size: .custom(520)) { _ in
                Text("Sheet")
            }
        _ = AppSheetScaffold(showsHairlines: false) {
            SheetHeader(title: "Title")
        } content: {
            Text("Body")
        } footer: {
            Text("Footer")
        }
        #expect(AppSheetSize.regular == .regular)
        #expect(AppSheetMetrics.defaultMaxHeight == 600)
    }

    @Test func sheetHeaderVariantsAreReachable() {
        _ = SheetHeader(title: "New Project", subtitle: "Step 2 of 3", icon: "folder", iconColor: .blue, compact: true, onDismiss: {})
        _ = SheetHeader(title: "New Project", compact: true, onDismiss: {}) {
            StepIndicator(stepCount: 3, currentIndex: 1)
        }
        _ = SheetCloseButton(action: {})
    }

    @Test func windowTitleBarVariantsAreReachable() {
        _ = WindowTitleBar(title: "Inbox", subtitle: "12 unread", centerInset: 220) {
            Button {} label: { Image(systemName: "sidebar.left") }
        } trailing: {
            Button("New") {}
        }
        _ = WindowTitleBar(title: "Settings")
        _ = WindowTitleBarTitle("Inbox", subtitle: "12 unread")
        #expect(WindowTitleBar<EmptyView, EmptyView, EmptyView>.trafficLightClearance == 78)
    }

    @Test func progressOverlayVariantsAreReachable() {
        _ = ProgressOverlay(
            title: "Importing",
            subtitle: "Photos",
            currentItem: "IMG_0001.heic",
            progress: 0.4,
            maximumActiveItems: 2,
            width: Sizing.sheetWidthLarge,
            onCancel: {}
        )
    }

    @Test func thinScrollIndicatorVariantsAreReachable() {
        _ = ScrollViewWithThinIndicator(showsIndicatorAlways: true) {
            Text("Rows")
        }
    }
}
