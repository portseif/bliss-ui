//
//  CatalogPages.swift
//  BlissCatalog
//
//  One page per component area. Each shows the components the way an app
//  would use them.
//

import BlissUI
import SwiftUI

// MARK: - Shared

/// A titled demo block on a page.
private struct DemoBlock<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(Typography.headingSmall)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Themes

struct ThemesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Every surface, accent and status color follows the theme. Pick one and the whole window re-themes.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
            AppearanceSettings()
                .environment(\.settingsFormPlain, true)
            DemoBlock(title: "Status colors") {
                HStack(spacing: Spacing.sm) {
                    Badge("Success", icon: "checkmark").badgeStyle(.success)
                    Badge("Warning", icon: "exclamationmark.triangle").badgeStyle(.warning)
                    Badge("Error", icon: "xmark").badgeStyle(.error)
                    Badge("Info", icon: "info.circle").badgeStyle(.info)
                }
            }
        }
    }
}

// MARK: - Buttons

struct ButtonsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Text buttons") {
                HStack(spacing: Spacing.sm) {
                    Button("Primary") {}.buttonStyle(PrimaryButtonStyle())
                    Button("Secondary") {}.buttonStyle(SecondaryButtonStyle())
                    Button("Outline") {}.buttonStyle(OutlineButtonStyle())
                    Button("Ghost") {}.buttonStyle(GhostButtonStyle())
                    Button("Delete") {}.buttonStyle(DestructiveButtonStyle())
                }
            }
            DemoBlock(title: "Compact (sheets)") {
                HStack(spacing: Spacing.sm) {
                    Button("Cancel") {}.buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Continue") {}.buttonStyle(SecondaryButtonStyle(compact: true, accent: true))
                    Button("Save") {}.buttonStyle(PrimaryButtonStyle(compact: true))
                    Button("Remove") {}.buttonStyle(DestructiveButtonStyle(compact: true))
                }
            }
            DemoBlock(title: "Signature") {
                HStack(spacing: Spacing.sm) {
                    Button {} label: { Label("Generate", systemImage: "sparkles") }
                        .buttonStyle(AnimatedGradientBorderButtonStyle())
                    Button {} label: { Label("Generate", systemImage: "sparkles") }
                        .buttonStyle(AnimatedGradientBorderButtonStyle(compact: true))
                    Button("Upgrade") {}.buttonStyle(SmallPillButtonStyle(color: Color.accent))
                }
            }
            DemoBlock(title: "Icons") {
                HStack(spacing: Spacing.sm) {
                    Button {} label: { Image(systemName: "gearshape") }
                        .buttonStyle(ToolbarIconButtonStyle())
                        .accessibilityLabel(Text("Settings"))
                        .tooltip("Settings", position: .below)
                    HoverIconButton(systemImage: "doc.on.doc", help: "Copy") {}
                    Button {} label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(InlineIconButtonStyle())
                        .accessibilityLabel(Text("Refresh"))
                }
            }
            DemoBlock(title: "Links") {
                TextLink("bliss-ui.dev/docs", hoverSymbol: "arrow.up.right") {}
            }
        }
    }
}

// MARK: - Inputs

private enum CatalogPeriod: String, CaseIterable, Hashable {
    case day = "Day", week = "Week", month = "Month"
}

struct InputsPage: View {
    @State private var name = ""
    @State private var search = ""
    @State private var notificationsOn = true
    @State private var period: CatalogPeriod = .week
    @State private var size = "Medium"
    @State private var folder = ""
    @State private var icon = "star"
    @State private var red = 0.04
    @State private var green = 0.52
    @State private var blue = 1.0
    @State private var agreed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Text fields") {
                TextField("Name", text: $name).textFieldStyle(.largePadded)
                TextField("Search", text: $search).textFieldStyle(.search)
            }
            DemoBlock(title: "Switch and checkbox") {
                Toggle("Notifications", isOn: $notificationsOn).toggleStyle(.flatSwitch(showsLabel: true))
                Button { agreed.toggle() } label: {
                    HStack(spacing: Spacing.sm) {
                        CheckboxGlyph(isOn: agreed)
                        Text("I agree")
                    }
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 3))
            }
            DemoBlock(title: "Segmented pills") {
                SegmentedPills(options: CatalogPeriod.allCases, selection: $period, title: { $0.rawValue })
                SegmentedPills(options: CatalogPeriod.allCases, selection: $period, style: .compact, title: { $0.rawValue })
            }
            DemoBlock(title: "Dropdown") {
                FloatingMenuPicker(
                    "Size",
                    selection: $size,
                    options: ["Small", "Medium", "Large"],
                    optionTitle: { $0 },
                    optionIcon: { _ in "textformat.size" }
                )
                .frame(maxWidth: 320)
            }
            DemoBlock(title: "Pickers") {
                HStack(spacing: Spacing.md) {
                    ColorPickerButton(red: $red, green: $green, blue: $blue)
                    IconPickerButton(selectedIcon: $icon)
                }
                BrowseInput(path: $folder, placeholder: "Choose a folder")
                    .frame(maxWidth: 420)
            }
        }
    }
}

// MARK: - Display

struct DisplayPage: View {
    @State private var count = 7
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Badges") {
                FlowLayout(spacing: Spacing.sm) {
                    Badge("Default")
                    Badge("Primary").badgeStyle(.primary)
                    Badge("Beta", icon: "flask").badgeStyle(.info).badgeSize(.small)
                    Badge(count: 12)
                    Badge.status("Healthy", color: Success.success500)
                    Badge.pro()
                    Badge("Live").badgeStyle(.success).dot(Success.success500)
                }
            }
            DemoBlock(title: "Status and progress") {
                HStack(spacing: Spacing.lg) {
                    StatusDotPill(label: "Running", color: Success.success500)
                    StatusDotPill(label: "Degraded", color: Warning.warning500, bordered: true)
                    ThinkingSpinner()
                    ShimmerTextOverlay(text: "Thinking…")
                }
            }
            DemoBlock(title: "Numbers, keys and time") {
                HStack(spacing: Spacing.lg) {
                    SlidingNumber(value: count, font: Typography.displaySmall)
                    Button("+1") { count += 1 }.buttonStyle(SecondaryButtonStyle(compact: true))
                    ShortcutKey("⌘K")
                    TimeAgoLabel(date: Date().addingTimeInterval(-3_600))
                    Button { withAnimation(Animations.selection) { isRevealed.toggle() } } label: {
                        RevealToggleIcon(isRevealed: isRevealed)
                    }
                    .buttonStyle(InlineIconButtonStyle())
                    .accessibilityLabel(Text(isRevealed ? "Hide" : "Reveal"))
                }
            }
            DemoBlock(title: "Paths") {
                PathHoverChip(path: "/Users/me/Developer/BlissUI/Sources")
                PathHoverChip.code("swift run BlissCatalog")
            }
            DemoBlock(title: "Terminal output") {
                TerminalOutputView(lines: [
                    TerminalOutputLine("$ swift build", type: .system),
                    TerminalOutputLine("Compiling BlissUI (62 sources)"),
                    TerminalOutputLine("warning: unused variable 'count'", type: .stderr),
                    TerminalOutputLine("Build complete!"),
                ], title: "Build", maxHeight: 140)
            }
            DemoBlock(title: "Empty state") {
                EmptyState(icon: "tray", title: "Nothing here yet", subtitle: "Items you add show up here.") {
                    Button("Add Item") {}.buttonStyle(PrimaryButtonStyle(compact: true))
                }
                .contained()
            }
        }
    }
}

// MARK: - Sections

struct SectionsPage: View {
    @State private var tab = 0
    @State private var autoSave = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            UnderlineTabBar(
                items: [
                    UnderlineTabItem(value: 0, title: "Overview"),
                    UnderlineTabItem(value: 1, title: "Activity", count: 3),
                    UnderlineTabItem(value: 2, title: "Settings"),
                ],
                selection: $tab
            )
            SettingsForm {
                RoundedSection("General", divided: true) {
                    Toggle("Save automatically", isOn: $autoSave).toggleStyle(.flatSwitch(showsLabel: true))
                    DetailRow(label: "Version", value: "1.0.0", copyable: true)
                    DetailRow(label: "Location", value: "/Users/me/Library/Application Support/Bliss", isPath: true)
                }
                RoundedSection("Connection", borderTint: Success.tint.opacity(0.3)) {
                    ForEach(rows) { row in row }
                }
            }
            .environment(\.settingsFormPlain, true)
            SectionHeader("Members", count: 4, caption: "Updated just now")
            StepIndicator(stepCount: 5, currentIndex: 2)
        }
    }

    private var rows: [InfoRow] {
        [
            InfoRow.labeled("Host", value: "api.example.com"),
            InfoRow.status("Connected", icon: "checkmark.circle.fill", style: .success),
            InfoRow.branch("main"),
        ]
    }
}

// MARK: - Table

private struct CatalogTask: Identifiable {
    let id = UUID()
    let title: String
    let owner: String
    let priority: Int
    let updated: Date
}

struct TablePage: View {
    @State private var selection: Set<UUID> = []
    private let tasks = [
        CatalogTask(title: "Polish the onboarding card", owner: "Ada", priority: 2, updated: .now.addingTimeInterval(-600)),
        CatalogTask(title: "Ship the Low Glare theme", owner: "Grace", priority: 1, updated: .now.addingTimeInterval(-7_200)),
        CatalogTask(title: "Tune the sheet spring", owner: "Alan", priority: 3, updated: .now.addingTimeInterval(-86_400)),
        CatalogTask(title: "Audit focus rings", owner: "Katherine", priority: 1, updated: .now.addingTimeInterval(-172_800)),
        CatalogTask(title: "Write the catalog", owner: "Ada", priority: 2, updated: .now.addingTimeInterval(-30)),
    ]

    var body: some View {
        BlissTable(
            tasks,
            columns: [
                BlissTableColumn("Task", sortedBy: \CatalogTask.title),
                BlissTableColumn("Owner", width: .fixed(110), sortedBy: \CatalogTask.owner),
                BlissTableColumn("Priority", width: .fixed(80), sortedBy: \CatalogTask.priority),
                BlissTableColumn("Updated", width: .fixed(110), alignment: .trailing, sortedBy: \CatalogTask.updated),
            ],
            selection: $selection,
            initialSort: BlissTableSort(columnID: "Priority"),
            contentInset: 0,
            onOpen: { task in
                ToastService.shared.showInfo(title: "Opened", message: task.title)
            }
        ) { task in
            Text(verbatim: task.title)
                .font(Typography.bodySmall)
                .lineLimit(1)
            Text(verbatim: task.owner)
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
            Badge("P\(task.priority)").badgeStyle(task.priority == 1 ? .error : .secondary).badgeSize(.small)
            TimeAgoLabel(date: task.updated)
                .foregroundStyle(.secondary)
        }
        .selectionBar(count: selection.count, onClear: { selection.removeAll() }) {
            SelectionBarButton("Archive", systemImage: "archivebox") { selection.removeAll() }
            SelectionBarButton("Assign", systemImage: "person.crop.circle") {}
        }
        .frame(minHeight: 360, alignment: .top)
    }
}

// MARK: - Overlays

struct OverlaysPage: View {
    @State private var showingMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Tooltips") {
                HStack(spacing: Spacing.md) {
                    Button("Above") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows above", position: .above)
                    Button("Below") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows below", position: .below)
                    Button("Trailing") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows trailing", position: .trailing)
                    InfoButton(text: "Click for a hint that stays open to be read.")
                }
            }
            DemoBlock(title: "Floating menu") {
                Button {
                    showingMenu.toggle()
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .buttonStyle(SecondaryButtonStyle())
                .floatingMenu(isPresented: $showingMenu, xPosition: .leading, yPosition: .below) {
                    CatalogMenu(isPresented: $showingMenu)
                }
            }
            DemoBlock(title: "Right-click") {
                Text("Right-click this card")
                    .font(Typography.bodySmall)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .strokeBorder(Color.menuBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                    .onSecondaryClick { point in
                        PopupMenuService.shared.show(at: point) {
                            VStack(alignment: .leading, spacing: 0) {
                                QuickActionMenuItem(title: "Rename", icon: "pencil") { PopupMenuService.shared.hide() }
                                QuickActionMenuItem(title: "Duplicate", icon: "plus.square.on.square") { PopupMenuService.shared.hide() }
                                QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) { PopupMenuService.shared.hide() }
                            }
                            .padding(Spacing.menuPadding)
                        }
                    }
            }
        }
    }
}

/// Menu content is a View struct with bindings: the floating menu hosts it in
/// a panel snapshotted at open.
private struct CatalogMenu: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickActionMenuItem(title: "Rename", icon: "pencil") { isPresented = false }
            QuickActionMenuItem(title: "Share", icon: "square.and.arrow.up") { isPresented = false }
            QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) { isPresented = false }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 200)
    }
}

// MARK: - Sheets & Toasts

struct SheetsPage: View {
    @State private var showingSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "App sheet") {
                Button("Open Sheet") { showingSheet = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            DemoBlock(title: "Toasts") {
                HStack(spacing: Spacing.sm) {
                    Button("Success") {
                        ToastService.shared.showSuccess(title: "Saved", message: "Your changes are in.")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Info") {
                        ToastService.shared.showInfo(title: "Update available", message: "Version 1.1 is ready.")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Error") {
                        ToastService.shared.showError(
                            title: "Upload failed",
                            message: "The server didn't answer.",
                            fullMessage: "POST /upload timed out after 30 seconds.\nCheck your connection and try again."
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Progress") { runProgressToast() }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        }
        .appSheet(isPresented: $showingSheet) {
            CatalogSheet()
        }
    }

    /// A progress toast is the caller's to take down: its result is a
    /// separate toast.
    private func runProgressToast() {
        Task { @MainActor in
            // Showing a toast whose id is already up updates it in place.
            let toastID = UUID()
            @MainActor func tick(_ fraction: Double) {
                ToastService.shared.show(ToastData(
                    id: toastID, title: "Exporting", message: "Writing files…", style: .progress(fraction)
                ))
            }
            tick(0)
            defer { ToastService.shared.dismiss(id: toastID) }
            for step in 1...10 {
                try? await Task.sleep(for: .milliseconds(200))
                tick(Double(step) / 10)
            }
            ToastService.shared.showSuccess(title: "Exported", message: "12 files")
        }
    }
}

private struct CatalogSheet: View {
    @Environment(\.appSheetDismiss) private var dismiss
    @State private var title = ""
    @State private var notify = true

    var body: some View {
        AppSheetScaffold {
            SheetHeader(title: "New Item", subtitle: "Give it a name to get started.", onDismiss: dismiss)
        } content: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Title", text: $title).textFieldStyle(.largePadded)
                Toggle("Notify me when it's done", isOn: $notify).toggleStyle(.flatSwitch(showsLabel: true))
            }
            .padding(.horizontal, Spacing.lg)
        } footer: {
            ActionBar(confirmTitle: "Create", isConfirmDisabled: title.isEmpty, onCancel: dismiss) {
                dismiss()
                ToastService.shared.showSuccess(title: "Created", message: title)
            }
        }
        .frame(width: 440)
    }
}
