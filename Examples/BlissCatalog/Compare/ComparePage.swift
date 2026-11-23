//
//  ComparePage.swift
//  BlissCatalog
//
//  BlissUI's controls beside Presto's, one pair per row, each row with a pick
//  that's remembered. Presto's copies live in PrestoControls.swift.
//

import BlissUI
import SwiftUI

/// Which control a row's pick prefers.
enum ComparePick: String, CaseIterable {
    case undecided = "—"
    case bliss = "Bliss"
    case presto = "Presto"
}

struct ComparePage: View {
    /// Every row's pick, as `id=Pick` pairs, so one key holds them all.
    @AppStorage("compare.picks") private var storedPicks = ""
    @State private var sheetConfirmation = false
    @State private var showsBlissMenu = false
    @State private var showsPrestoMenu = false
    @State private var blissMenuFocus: Int?
    @State private var prestoMenuFocus: Int?
    @State private var showsBlissGroupedMenu = false
    @State private var showsPrestoGroupedMenu = false
    @State private var blissGroupedFocus: Int?
    @State private var prestoGroupedFocus: Int?
    @State private var blissSegment = "Week"
    @State private var prestoSegment = "Week"
    @State private var blissSwitch = true
    @State private var prestoSwitch = true
    @State private var blissName = "Neighborhood Bakery"
    @State private var prestoName = "Neighborhood Bakery"
    @State private var blissSearch = ""
    @State private var prestoSearch = ""
    @State private var blissCopied = false
    @FocusState private var prestoNameFocused: Bool

    private static let rows: [(id: String, title: String)] = [
        ("buttons", "Buttons"),
        ("confirmation", "Confirmation"),
        ("dialogHeader", "Dialog header"),
        ("toasts", "Toasts"),
        ("segmented", "Segmented control"),
        ("switch", "Switch"),
        ("fields", "Text fields"),
        ("search", "Search field"),
        ("pills", "Tags & status"),
        ("keysSpinner", "Shortcut keys & spinner"),
        ("linksCopy", "Links & copy"),
        ("problems", "Problems & waiting"),
        ("menus", "Menus"),
    ]

    private static let segments = ["Day", "Week", "Month"]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            summary
            CompareRow(title: "Buttons", pick: pick("buttons")) {
                HStack(spacing: Spacing.sm) {
                    // Regular, the 32 pt tier Presto's dialog buttons are.
                    Button("Save") {}.buttonStyle(PrimaryButtonStyle())
                    Button("Cancel") {}.buttonStyle(SecondaryButtonStyle())
                    Button("Delete") {}.buttonStyle(DestructiveButtonStyle(prominent: true))
                    Button("Disabled") {}.buttonStyle(SecondaryButtonStyle()).disabled(true)
                }
            } presto: {
                HStack(spacing: 8) {
                    Button("Save") {}.buttonStyle(PrestoButtonStyle(kind: .prominent))
                    Button("Cancel") {}.buttonStyle(PrestoButtonStyle())
                    Button("Delete") {}.buttonStyle(PrestoButtonStyle(kind: .destructive))
                    Button("Disabled") {}.buttonStyle(PrestoButtonStyle()).disabled(true)
                }
            }
            CompareRow(title: "Confirmation", note: "Opens over the window, with the toast that follows.", pick: pick("confirmation")) {
                Button("Delete Project…") { sheetConfirmation = true }
                    .buttonStyle(SecondaryButtonStyle())
            } presto: {
                Button("Delete Project…") {
                    PrestoOverlays.shared.confirmation = PrestoConfirmation(
                        title: "Delete “Neighborhood Bakery”?",
                        detail: "Its chat, site, and assets are deleted from this Mac. You can undo it for a few seconds after.",
                        note: "The someone/bakery-site repository on GitHub, and anything published from it, stay as they are.",
                        confirmTitle: "Delete",
                        doneMessage: "Deleted “Neighborhood Bakery”"
                    )
                }
                .buttonStyle(PrestoButtonStyle())
            }
            CompareRow(title: "Dialog header", pick: pick("dialogHeader")) {
                SheetHeader(title: "URL & SEO", subtitle: "Where the page opens, and how it reads in search results.", onDismiss: {})
                    .background(Color.windowBackground, in: .rect(cornerRadius: Sizing.radiusLarge))
            } presto: {
                HStack(alignment: .top) {
                    PrestoSectionHeader(title: "URL & SEO", detail: "Where the page opens, and how it reads in search results.")
                    Spacer(minLength: 12)
                    PrestoCloseButton {}
                }
                .padding(20)
                .background(PrestoLook.panel, in: .rect(cornerRadius: 16))
            }
            CompareRow(title: "Toasts", note: "The same stack underneath: newest in front, hover to fan them out and hold their timers, a problem stays until closed.", pick: pick("toasts")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ToastNotification(toast: ToastData(
                        title: "Deleted",
                        message: "Neighborhood Bakery",
                        style: .success,
                        actions: [ToastAction(label: "Undo") {}]
                    ))
                    ToastNotification(toast: ToastData(title: "Couldn't rename", message: "The disk is full.", style: .error))
                    HStack(spacing: Spacing.sm) {
                        Button("Show live") {
                            ToastService.shared.showSuccess(
                                title: "Deleted",
                                message: "Neighborhood Bakery",
                                actions: [ToastAction(label: "Undo") {}]
                            )
                        }
                        Button("Show problem") {
                            ToastService.shared.showError(title: "Couldn't rename", message: "The disk is full.")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            } presto: {
                VStack(alignment: .leading, spacing: 10) {
                    PrestoToastView(toast: PrestoToast(message: "Deleted “Neighborhood Bakery”", canUndo: true), onUndo: {}, onClose: {})
                    PrestoToastView(toast: PrestoToast(message: "The project couldn't be renamed: the disk is full.", isProblem: true), onUndo: {}, onClose: {})
                    HStack(spacing: 8) {
                        Button("Show live") {
                            PrestoToasts.shared.show(PrestoToast(message: "Deleted “Neighborhood Bakery”", canUndo: true))
                        }
                        Button("Show problem") {
                            PrestoToasts.shared.show(PrestoToast(message: "The project couldn't be renamed: the disk is full.", isProblem: true))
                        }
                    }
                    .buttonStyle(PrestoButtonStyle())
                }
            }
            CompareRow(title: "Segmented control", pick: pick("segmented")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SegmentedPills(options: Self.segments, selection: $blissSegment, title: { $0 })
                    SegmentedPills(options: Self.segments, selection: $blissSegment, style: .compact, title: { $0 })
                }
            } presto: {
                VStack(alignment: .leading, spacing: 10) {
                    PrestoSegmentedPills(options: Self.segments, selection: $prestoSegment, title: { $0 })
                    PrestoSegmentedPills(options: Self.segments, selection: $prestoSegment, title: { $0 }, isCompact: true)
                        .frame(width: 200)
                }
            }
            CompareRow(title: "Switch", pick: pick("switch")) {
                Toggle("Publish automatically", isOn: $blissSwitch).toggleStyle(.flatSwitch(showsLabel: true))
            } presto: {
                PrestoSwitch(label: "Publish automatically", isOn: $prestoSwitch)
            }
            CompareRow(title: "Text fields", pick: pick("fields")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextField("Name", text: $blissName).textFieldStyle(.largePadded)
                    TextField("Name", text: $blissName).textFieldStyle(.compact)
                }
            } presto: {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name", text: $prestoName)
                        .textFieldStyle(.plain)
                        .font(PrestoLook.ui(13))
                        .focused($prestoNameFocused)
                        .prestoFieldChrome(isFocused: prestoNameFocused)
                    Text(verbatim: "/our story")
                        .font(PrestoLook.mono(12))
                        .foregroundStyle(PrestoLook.faint)
                        .prestoFieldChrome(isInvalid: true)
                    PrestoProblemText(message: "A path can use lowercase letters, numbers, and hyphens.")
                }
            }
            CompareRow(title: "Search field", pick: pick("search")) {
                TextField("Search projects", text: $blissSearch).textFieldStyle(.search)
            } presto: {
                PrestoSearchField(text: $prestoSearch, prompt: "Search projects", shortcut: "⌘K")
            }
            CompareRow(title: "Tags & status", pick: pick("pills")) {
                // One `BadgeSize` for every pill, so they share a height and a font.
                HStack(spacing: Spacing.sm) {
                    Badge("Logo").badgeStyle(.primary).badgeSize(.regular)
                    Badge("new").badgeStyle(.info).badgeSize(.regular)
                    StatusDotPill(label: "Connected", color: Success.success500, size: .regular)
                    StatusDotPill(label: "Waiting", color: Color.accent, size: .regular, isPulsing: true)
                    StatusDotPill(label: "Not connected", color: Danger.danger500, size: .regular)
                }
            } presto: {
                HStack(spacing: 12) {
                    PrestoTagPill(text: "Logo")
                    PrestoTagPill(text: "new", tint: Info.info500)
                    PrestoStatusTag(label: "Connected", color: PrestoLook.success)
                    PrestoStatusTag(label: "Waiting", color: PrestoLook.accent, isPulsing: true)
                    PrestoStatusTag(label: "Not connected", color: PrestoLook.danger)
                }
            }
            CompareRow(title: "Shortcut keys & spinner", pick: pick("keysSpinner")) {
                HStack(spacing: Spacing.sm) {
                    ShortcutKey("⌘K")
                    ShortcutKey("⇧⌘P")
                    ShortcutKey("esc")
                    ThinkingSpinner()
                    ThinkingSpinner(size: .large, color: Color.accent)
                }
            } presto: {
                HStack(spacing: 8) {
                    PrestoShortcutKey("⌘K")
                    PrestoShortcutKey("⇧⌘P")
                    PrestoShortcutKey("Esc")
                    PrestoSpinner().foregroundStyle(PrestoLook.muted)
                    PrestoSpinner(size: 20).foregroundStyle(PrestoLook.accent)
                }
            }
            CompareRow(title: "Links & copy", pick: pick("linksCopy")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextLink("Where to get a key", hoverSymbol: "arrow.up.right") {}
                    HStack(spacing: Spacing.sm) {
                        Text(verbatim: "https://bakery.example/callback")
                            .font(Typography.codeSmall)
                        CopyButton(value: "https://bakery.example/callback", showCopied: $blissCopied)
                    }
                }
            } presto: {
                VStack(alignment: .leading, spacing: 10) {
                    PrestoInlineLink(title: "Where to get a key", url: URL(string: "https://example.com")!)
                    PrestoCopyableValue(value: "https://bakery.example/callback")
                }
            }
            CompareRow(title: "Problems & waiting", pick: pick("problems")) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Banner("GitHub doesn't recognize that client ID.", message: "Check it and try again.", style: .danger)
                    HStack(spacing: Spacing.sm) {
                        ThinkingSpinner(size: .small)
                        Text("Waiting for you to approve on GitHub…")
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            } presto: {
                VStack(alignment: .leading, spacing: 10) {
                    PrestoProblemBanner(title: "GitHub doesn't recognize that client ID.", message: "Check it and try again.")
                    PrestoWaitingLine(text: "Waiting for you to approve on GitHub…")
                }
            }
            // Both are BlissUI's floating menu, with its panel, placement, keys
            // and motion; only the trigger, rows and surface differ.
            CompareRow(title: "Menus", note: "The same menu underneath: ↑ ↓ step through the rows, Return picks, Escape or a click outside closes. Grouped holds each group's rows in a panel of their own.", pick: pick("menus")) {
                HStack(spacing: Spacing.sm) {
                Button {
                    showsBlissMenu.toggle()
                } label: {
                    Label("Project", systemImage: "ellipsis.circle")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .floatingMenu(
                    isPresented: $showsBlissMenu,
                    itemCount: CompareMenuItem.all.count,
                    focusedIndex: $blissMenuFocus,
                    xPosition: .leading,
                    yPosition: .below,
                    onSelect: { _ in showsBlissMenu = false }
                ) {
                    CompareBlissMenu(isPresented: $showsBlissMenu, focusedIndex: $blissMenuFocus)
                }
                Button {
                    showsBlissGroupedMenu.toggle()
                } label: {
                    Label("Grouped", systemImage: "square.stack")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .floatingMenu(
                    isPresented: $showsBlissGroupedMenu,
                    itemCount: CompareMenuGroup.itemCount,
                    focusedIndex: $blissGroupedFocus,
                    xPosition: .leading,
                    yPosition: .below,
                    onSelect: { _ in showsBlissGroupedMenu = false }
                ) {
                    CompareBlissGroupedMenu(isPresented: $showsBlissGroupedMenu, focusedIndex: $blissGroupedFocus)
                }
                }
            } presto: {
                HStack(spacing: 8) {
                Button {
                    showsPrestoMenu.toggle()
                } label: {
                    Label("Project", systemImage: "ellipsis.circle")
                }
                .buttonStyle(PrestoMenuTriggerStyle(isOpen: showsPrestoMenu))
                .floatingMenu(
                    isPresented: $showsPrestoMenu,
                    itemCount: CompareMenuItem.all.count,
                    focusedIndex: $prestoMenuFocus,
                    xPosition: .leading,
                    yPosition: .below,
                    onSelect: { _ in showsPrestoMenu = false }
                ) {
                    ComparePrestoMenu(isPresented: $showsPrestoMenu, focusedIndex: $prestoMenuFocus)
                }
                Button {
                    showsPrestoGroupedMenu.toggle()
                } label: {
                    Label("Grouped", systemImage: "square.stack")
                }
                .buttonStyle(PrestoMenuTriggerStyle(isOpen: showsPrestoGroupedMenu))
                .floatingMenu(
                    isPresented: $showsPrestoGroupedMenu,
                    itemCount: CompareMenuGroup.itemCount,
                    focusedIndex: $prestoGroupedFocus,
                    xPosition: .leading,
                    yPosition: .below,
                    onSelect: { _ in showsPrestoGroupedMenu = false }
                ) {
                    ComparePrestoGroupedMenu(isPresented: $showsPrestoGroupedMenu, focusedIndex: $prestoGroupedFocus)
                }
                }
            }
        }
        .confirmationSheet(
            isPresented: $sheetConfirmation,
            title: "Delete “Neighborhood Bakery”?",
            message: "Its chat, site, and assets are deleted from this Mac. You can undo it for a few seconds after.",
            confirmTitle: "Delete",
            isDestructive: true
        ) {
            ToastService.shared.showSuccess(title: "Deleted", message: "Neighborhood Bakery", actions: [ToastAction(label: "Undo") {}])
        }
    }

    // MARK: - Picks

    private var picks: [String: ComparePick] {
        var picks: [String: ComparePick] = [:]
        for pair in storedPicks.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2, let pick = ComparePick(rawValue: parts[1]) { picks[parts[0]] = pick }
        }
        return picks
    }

    private func pick(_ id: String) -> Binding<ComparePick> {
        Binding(
            get: { picks[id] ?? .undecided },
            set: { newPick in
                var updated = picks
                updated[id] = newPick == .undecided ? nil : newPick
                storedPicks = updated.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.rawValue)" }.joined(separator: ";")
            }
        )
    }

    /// How the picks stand, and the rows that went to Presto, to replace.
    private var summary: some View {
        let current = picks
        let prestoTitles = Self.rows.filter { current[$0.id] == .presto }.map(\.title)
        let blissCount = Self.rows.filter { current[$0.id] == .bliss }.count
        let undecidedCount = Self.rows.count - prestoTitles.count - blissCount
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Each row shows BlissUI's control beside Presto's, ported onto BlissUI's colors so only the shape, sizing and motion differ. Pick the one you'd keep; the picks are remembered.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.sm) {
                Badge("Presto \(prestoTitles.count)").badgeStyle(.primary)
                Badge("Bliss \(blissCount)")
                Badge("Undecided \(undecidedCount)").badgeStyle(.outline)
                if !prestoTitles.isEmpty {
                    Button("Clear picks") { storedPicks = "" }
                        .buttonStyle(GhostButtonStyle(compact: true, hugsLabel: true))
                }
            }
            if !prestoTitles.isEmpty {
                Text("To replace: \(prestoTitles.joined(separator: ", "))")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One pair: the title and the pick over BlissUI's control and Presto's, side
/// by side on the same surface.
private struct CompareRow<Bliss: View, Presto: View>: View {
    let title: LocalizedStringKey
    var note: LocalizedStringKey?
    @Binding var pick: ComparePick
    @ViewBuilder let bliss: () -> Bliss
    @ViewBuilder let presto: () -> Presto

    init(
        title: LocalizedStringKey,
        note: LocalizedStringKey? = nil,
        pick: Binding<ComparePick>,
        @ViewBuilder bliss: @escaping () -> Bliss,
        @ViewBuilder presto: @escaping () -> Presto
    ) {
        self.title = title
        self.note = note
        _pick = pick
        self.bliss = bliss
        self.presto = presto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.headingSmall)
                    if let note {
                        Text(note)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                SegmentedPills(options: ComparePick.allCases, selection: $pick, style: .compact, title: { $0.rawValue })
            }
            HStack(alignment: .top, spacing: Spacing.md) {
                column("BlissUI", isPicked: pick == .bliss, content: bliss)
                column("Presto", isPicked: pick == .presto, content: presto)
            }
        }
    }

    private func column<Content: View>(_ label: LocalizedStringKey, isPicked: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.restingFill, in: .rect(cornerRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(isPicked ? Color.accent : Color.menuBorder, lineWidth: 1)
        }
    }
}

/// The project menu both sides show, in order: the arrow keys step through
/// these, and a divider goes before any marked `startsGroup`.
struct CompareMenuItem {
    let title: String
    let icon: String
    var shortcut: String?
    var detail: String?
    var isChecked = false
    var isDestructive = false
    var startsGroup = false

    static let all: [CompareMenuItem] = [
        CompareMenuItem(title: "Rename", icon: "pencil", shortcut: "⌘R"),
        CompareMenuItem(title: "Branch", icon: "arrow.triangle.branch"),
        CompareMenuItem(title: "Pinned", icon: "pin", isChecked: true),
        CompareMenuItem(title: "Show in Finder", icon: "folder", detail: "No files yet"),
        CompareMenuItem(title: "Delete Project", icon: "trash", isDestructive: true, startsGroup: true),
    ]
}

/// BlissUI's rows. Menu content is a View struct with bindings: the floating
/// menu hosts it in a panel snapshotted at open.
private struct CompareBlissMenu: View {
    @Binding var isPresented: Bool
    @Binding var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuSectionHeader("Project")
            ForEach(Array(CompareMenuItem.all.enumerated()), id: \.offset) { index, item in
                if item.startsGroup { MenuDivider() }
                QuickActionMenuItem(
                    title: LocalizedStringKey(item.title),
                    icon: item.icon,
                    isDestructive: item.isDestructive,
                    isFocused: focusedIndex == index,
                    shortcut: item.shortcut,
                    isChecked: item.isChecked ? true : nil,
                    detail: item.detail.map { LocalizedStringKey($0) }
                ) { isPresented = false }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 280)
    }
}

/// Presto's rows, spacing and solid surface inside the same panel. The
/// highlight follows the pointer and the arrow keys alike, as Presto's does.
private struct ComparePrestoMenu: View {
    @Binding var isPresented: Bool
    @Binding var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            PrestoMenuSectionHeader(title: "Project")
            ForEach(Array(CompareMenuItem.all.enumerated()), id: \.offset) { index, item in
                if item.startsGroup { PrestoMenuDivider() }
                PrestoMenuRow(
                    title: item.title,
                    detail: item.detail,
                    systemImage: item.icon,
                    isSelected: item.isChecked,
                    isDestructive: item.isDestructive,
                    shortcut: item.shortcut,
                    index: index,
                    focusedIndex: $focusedIndex
                ) { isPresented = false }
            }
        }
        .padding(6)
        .fixedSize()
        // Presto's menus are solid; this covers the panel's material.
        .background(PrestoLook.raised)
    }
}

/// The grouped menu both sides show: groups of rows under a heading, then a
/// row of its own after them. Rows are numbered straight through, for the keys.
struct CompareMenuGroup {
    let title: String
    let items: [CompareMenuItem]

    static let all: [CompareMenuGroup] = [
        CompareMenuGroup(title: "Recent", items: [
            CompareMenuItem(title: "Neighborhood Bakery", icon: "storefront", isChecked: true),
            CompareMenuItem(title: "Northlight Observatory", icon: "sparkles"),
            CompareMenuItem(title: "Harbor Coffee", icon: "cup.and.saucer"),
        ]),
        CompareMenuGroup(title: "Project", items: [
            CompareMenuItem(title: "Rename", icon: "pencil", shortcut: "⌘R"),
            CompareMenuItem(title: "Branch", icon: "arrow.triangle.branch"),
            CompareMenuItem(title: "Show in Finder", icon: "folder"),
        ]),
    ]

    /// The row after the groups, which starts something new.
    static let trailing = CompareMenuItem(title: "New Project", icon: "plus", shortcut: "⌘N")

    static var itemCount: Int { all.reduce(0) { $0 + $1.items.count } + 1 }

    /// The index the keys know `group`'s first row by.
    static func firstIndex(of group: Int) -> Int {
        all.prefix(group).reduce(0) { $0 + $1.items.count }
    }
}

/// BlissUI's groups: a `MenuSection` for each, then the row after them.
private struct CompareBlissGroupedMenu: View {
    @Binding var isPresented: Bool
    @Binding var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(Array(CompareMenuGroup.all.enumerated()), id: \.offset) { groupIndex, group in
                MenuSection(LocalizedStringKey(group.title)) {
                    ForEach(Array(group.items.enumerated()), id: \.offset) { offset, item in
                        row(item, index: CompareMenuGroup.firstIndex(of: groupIndex) + offset)
                    }
                }
            }
            row(CompareMenuGroup.trailing, index: CompareMenuGroup.itemCount - 1)
        }
        .padding(Spacing.menuPadding)
        .frame(width: 280)
    }

    private func row(_ item: CompareMenuItem, index: Int) -> some View {
        QuickActionMenuItem(
            title: LocalizedStringKey(item.title),
            icon: item.icon,
            isFocused: focusedIndex == index,
            shortcut: item.shortcut,
            isChecked: item.isChecked ? true : nil
        ) { isPresented = false }
    }
}

/// Presto's groups: each heading over its rows in an inset panel, 5 pt
/// between groups, and the row that starts something new in the accent after
/// them.
private struct ComparePrestoGroupedMenu: View {
    @Binding var isPresented: Bool
    @Binding var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(CompareMenuGroup.all.enumerated()), id: \.offset) { groupIndex, group in
                PrestoMenuSection(title: group.title) {
                    ForEach(Array(group.items.enumerated()), id: \.offset) { offset, item in
                        row(item, index: CompareMenuGroup.firstIndex(of: groupIndex) + offset)
                    }
                }
            }
            row(CompareMenuGroup.trailing, index: CompareMenuGroup.itemCount - 1, isCallToAction: true)
        }
        .padding(6)
        .fixedSize()
        .background(PrestoLook.raised)
    }

    private func row(_ item: CompareMenuItem, index: Int, isCallToAction: Bool = false) -> some View {
        PrestoMenuRow(
            title: item.title,
            systemImage: item.icon,
            isSelected: item.isChecked,
            isCallToAction: isCallToAction,
            shortcut: item.shortcut,
            index: index,
            focusedIndex: $focusedIndex
        ) { isPresented = false }
    }
}
