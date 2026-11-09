//
//  Gallery.swift
//  BlissCatalog
//
//  `BlissCatalog -gallery <folder>` renders every component on its own, one
//  after another, in a window sized to it, and captures each as
//  `<folder>/<id>.png`. The README's component index is built from these.
//  Pass `-bliss.colorScheme Dark` (or `Light`) to pick the appearance.
//

import AppKit
import BlissUI
import SwiftUI
import UniformTypeIdentifiers

/// One component in the index.
struct GalleryEntry: Identifiable {
    let id: String
    let size: CGSize
    let content: () -> AnyView

    init<Content: View>(_ id: String, width: CGFloat = 560, height: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.size = CGSize(width: width, height: height)
        self.content = { AnyView(content()) }
    }
}

enum Gallery {
    static var outputDirectory: URL? {
        UserDefaults.standard.string(forKey: "gallery").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Each catalog area's entries, in README order.
    static var areas: [(name: String, entries: [GalleryEntry])] {
        [("filters", filters), ("calendar", calendar), ("commandSidebar", commandSidebar), ("forms", forms), ("data", data), ("fields", fields), ("tokens", tokens), ("layout", layout)]
    }

    /// Everything to capture: `-galleryArea <name>` limits it to one area
    /// (`core` for the original set).
    static var entries: [GalleryEntry] {
        let all = [("core", core)] + areas
        guard let only = UserDefaults.standard.string(forKey: "galleryArea") else { return all.flatMap(\.entries) }
        return all.first { $0.name == only }?.entries ?? []
    }

    // MARK: - Entries

    static let core: [GalleryEntry] = [
        // Buttons & styles
        GalleryEntry("buttons", height: 76) {
            HStack(spacing: Spacing.sm) {
                Button("Primary") {}.buttonStyle(PrimaryButtonStyle())
                Button("Secondary") {}.buttonStyle(SecondaryButtonStyle())
                Button("Outline") {}.buttonStyle(OutlineButtonStyle())
                Button("Ghost") {}.buttonStyle(GhostButtonStyle())
                Button("Delete") {}.buttonStyle(DestructiveButtonStyle())
            }
        },
        GalleryEntry("compact-buttons", height: 68) {
            HStack(spacing: Spacing.sm) {
                Button("Cancel") {}.buttonStyle(SecondaryButtonStyle(compact: true))
                Button("Continue") {}.buttonStyle(SecondaryButtonStyle(compact: true, accent: true))
                Button("Save") {}.buttonStyle(PrimaryButtonStyle(compact: true))
                Button("Remove") {}.buttonStyle(DestructiveButtonStyle(compact: true))
            }
        },
        GalleryEntry("loading-buttons", height: 76) {
            HStack(spacing: Spacing.sm) {
                Button("Save") {}.buttonStyle(PrimaryButtonStyle()).buttonLoading(true)
                Button("Checking…") {}.buttonStyle(SecondaryButtonStyle()).buttonLoading(true)
                Button("Publishing") {}.buttonStyle(OutlineButtonStyle(compact: true)).buttonLoading(true)
                Button("Deleting") {}.buttonStyle(DestructiveButtonStyle(compact: true, prominent: true)).buttonLoading(true)
            }
        },
        GalleryEntry("gradient-button", height: 76) {
            HStack(spacing: Spacing.sm) {
                Button {} label: { Label("Generate", systemImage: "sparkles") }
                    .buttonStyle(AnimatedGradientBorderButtonStyle())
                Button {} label: { Label("Generate", systemImage: "sparkles") }
                    .buttonStyle(AnimatedGradientBorderButtonStyle(compact: true))
                Button("Upgrade") {}.buttonStyle(SmallPillButtonStyle(color: Color.accent))
            }
        },
        GalleryEntry("icon-buttons", height: 68) {
            HStack(spacing: Spacing.md) {
                Button {} label: { Image(systemName: "gearshape") }
                    .buttonStyle(ToolbarIconButtonStyle(isActive: true))
                Button {} label: { Image(systemName: "sidebar.left") }
                    .buttonStyle(ToolbarIconButtonStyle())
                HoverIconButton(systemImage: "doc.on.doc", help: "Copy") {}
                Button {} label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(InlineIconButtonStyle())
            }
        },
        GalleryEntry("text-link", height: 60) {
            TextLink("bliss-ui.dev/docs", hoverSymbol: "arrow.up.right") {}
        },

        // Inputs
        GalleryEntry("text-fields", height: 120) {
            VStack(spacing: Spacing.md) {
                TextField("Project name", text: .constant("Bliss")).textFieldStyle(.largePadded)
                TextField("Search", text: .constant("")).textFieldStyle(.search)
            }
        },
        GalleryEntry("secret-field", width: 420, height: 108) {
            VStack(spacing: Spacing.md) {
                SecretField("API key", text: .constant("sk-live-4f8a2c9e1b7d6a3f"))
                SecretField("Password", text: .constant(""), prompt: Text("Required"), isCopyable: false)
            }
        },
        GalleryEntry("drop-zone", width: 480, height: 200) {
            DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", systemImage: "photo.on.rectangle", allowedContentTypes: [.png, .jpeg]) { _ in }
        },
        GalleryEntry("flat-switch", height: 84) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Toggle("Notifications", isOn: .constant(true)).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Sync over cellular", isOn: .constant(false)).toggleStyle(.flatSwitch(showsLabel: true))
            }
        },
        GalleryEntry("checkbox", height: 60) {
            HStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.sm) { CheckboxGlyph(isOn: true); Text("Selected") }
                HStack(spacing: Spacing.sm) { CheckboxGlyph(isOn: false); Text("Not selected") }
            }
            .font(Typography.bodySmall)
        },
        GalleryEntry("segmented-pills", height: 104) {
            VStack(spacing: Spacing.md) {
                SegmentedPills(options: ["Day", "Week", "Month"], selection: .constant("Week"), title: { $0 })
                SegmentedPills(options: ["List", "Grid"], selection: .constant("List"), style: .compact, title: { $0 }, icon: { $0 == "List" ? "list.bullet" : "square.grid.2x2" })
            }
        },
        GalleryEntry("floating-menu-picker", height: 64) {
            FloatingMenuPicker(
                "Size",
                selection: .constant("Medium"),
                options: ["Small", "Medium", "Large"],
                optionTitle: { $0 },
                optionIcon: { _ in "textformat.size" }
            )
        },
        GalleryEntry("pickers", height: 64) {
            HStack(spacing: Spacing.md) {
                ColorPickerButton(red: .constant(0.04), green: .constant(0.52), blue: .constant(1))
                IconPickerButton(selectedIcon: .constant("star.fill"))
                Spacer()
            }
        },
        GalleryEntry("browse-input", height: 64) {
            BrowseInput(path: "/Users/me/Documents/Reports", onBrowse: {})
        },

        // Display
        GalleryEntry("badges", height: 96) {
            FlowLayout(spacing: Spacing.sm) {
                Badge("Default")
                Badge("Primary").badgeStyle(.primary)
                Badge("Success", icon: "checkmark").badgeStyle(.success)
                Badge("Warning", icon: "exclamationmark.triangle").badgeStyle(.warning)
                Badge("Error", icon: "xmark").badgeStyle(.error)
                Badge("Info", icon: "info.circle").badgeStyle(.info)
                Badge(count: 12)
                Badge.status("Healthy", color: Success.success500)
                Badge.pro()
                Badge.lifetime()
            }
        },
        GalleryEntry("status-dot-pill", height: 60) {
            HStack(spacing: Spacing.sm) {
                StatusDotPill(label: "Running", color: Success.success500)
                StatusDotPill(label: "Degraded", color: Warning.warning500, bordered: true)
                StatusDotPill(label: "Stopped", color: Danger.danger500)
            }
        },
        GalleryEntry("spinner-shimmer", height: 60) {
            HStack(spacing: Spacing.lg) {
                ThinkingSpinner()
                ThinkingSpinner(size: 20, lineWidth: 2, color: Color.accent)
                ShimmerTextOverlay(text: "Thinking…")
            }
        },
        GalleryEntry("numbers-keys-time", height: 64) {
            HStack(spacing: Spacing.lg) {
                SlidingNumber(value: 128, font: Typography.displaySmall)
                ShortcutKey("⌘K")
                ShortcutKey("⇧⌘P")
                TimeAgoLabel(date: Date().addingTimeInterval(-3_600))
                    .foregroundStyle(.secondary)
                InfoButton(text: "Explains a setting.")
            }
        },
        GalleryEntry("path-hover-chip", height: 84) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PathHoverChip(path: "/Users/me/Developer/BlissUI/Sources")
                PathHoverChip.code("swift run BlissCatalog")
            }
        },
        GalleryEntry("terminal-output", height: 180) {
            TerminalOutputView(lines: [
                TerminalOutputLine("$ swift build", type: .system),
                TerminalOutputLine("Compiling BlissUI (62 sources)"),
                TerminalOutputLine("warning: unused variable 'count'", type: .stderr),
                TerminalOutputLine("Build complete!"),
            ], title: "Build", maxHeight: 140)
        },
        GalleryEntry("empty-state", height: 300) {
            EmptyState(icon: "tray", title: "Nothing here yet", subtitle: "Items you add show up here.") {
                Button("Add Item") {}.buttonStyle(PrimaryButtonStyle(compact: true))
            }
            .contained()
        },

        // Sections
        GalleryEntry("rounded-section", height: 190) {
            RoundedSection("General", divided: true) {
                Toggle("Save automatically", isOn: .constant(true)).toggleStyle(.flatSwitch(showsLabel: true))
                DetailRow(label: "Version", value: "1.0.0", copyable: true)
                DetailRow(label: "Location", value: "~/Library/Application Support/Bliss", isPath: true)
            }
        },
        GalleryEntry("section-header", height: 64) {
            SectionHeader("Members", count: 4, caption: "Updated just now") {
                Button("Invite") {}.buttonStyle(SecondaryButtonStyle(compact: true))
            }
        },
        GalleryEntry("info-rows", height: 140) {
            RoundedSection("Connection", borderTint: Success.tint.opacity(0.3)) {
                InfoRow.labeled("Host", value: "api.example.com")
                InfoRow.status("Connected", icon: "checkmark.circle.fill", style: .success)
                InfoRow.branch("main")
            }
        },

        // Navigation
        GalleryEntry("underline-tab-bar", height: 64) {
            UnderlineTabBar(
                items: [
                    UnderlineTabItem(value: 0, title: "Overview"),
                    UnderlineTabItem(value: 1, title: "Activity", count: 3),
                    UnderlineTabItem(value: 2, title: "Settings"),
                ],
                selection: .constant(0)
            )
        },
        GalleryEntry("step-indicator", height: 52) {
            StepIndicator(stepCount: 5, currentIndex: 2)
        },

        // Tables & grids
        GalleryEntry("bliss-table", width: 640, height: 230) {
            GalleryTable()
        },
        GalleryEntry("reorderable-list", width: 360, height: 220) {
            ReorderableList(.constant(GalleryStep.pipeline), divided: true) { step in
                Label {
                    Text(verbatim: step.title).font(Typography.bodySmall)
                } icon: {
                    Image(systemName: step.icon)
                        .foregroundStyle(.secondary)
                        .frame(width: Sizing.iconDefault)
                }
            }
        },
        GalleryEntry("selection-bar", width: 520, height: 92) {
            SelectionBar(count: 3, onClear: {}) {
                SelectionBarButton("Open", systemImage: "arrow.up.forward.app") {}
                SelectionBarButton("Archive", systemImage: "archivebox") {}
                SelectionBarButton("Actions", systemImage: "ellipsis.circle", showsChevron: true) {}
            }
        },
        GalleryEntry("divided-list", height: 150) {
            DividedForEach(["Design review", "Ship 1.0", "Write release notes"], id: \.self) { item in
                HStack {
                    Image(systemName: "circle").foregroundStyle(.tertiary)
                    Text(verbatim: item).font(Typography.bodySmall)
                    Spacer()
                    TimeAgoLabel(date: Date().addingTimeInterval(-7_200)).foregroundStyle(.secondary)
                }
                .rowHover()
            }
        },
        GalleryEntry("flow-layout", height: 96) {
            FlowLayout(spacing: Spacing.sm) {
                ForEach(["SwiftUI", "macOS", "Themes", "Accessibility", "Motion", "Tokens", "Window chrome", "Open source"], id: \.self) { tag in
                    Badge(LocalizedStringKey(tag))
                }
            }
        },

        // Sheets & actions
        GalleryEntry("sheet", width: 480, height: 310) {
            GallerySheetCard()
                .environment(\.appSheetMaxHeight, 600)
        },
        GalleryEntry("action-bar", width: 480, height: 76) {
            ActionBar(confirmTitle: "Create", showBackground: false, onCancel: {}, onConfirm: {})
        },

        // Menus, toasts & overlays
        GalleryEntry("menu-rows", width: 320, height: 200) {
            GalleryMenuCard()
        },
        GalleryEntry("toasts", height: 190) {
            VStack(spacing: Spacing.sm) {
                ToastNotification(toast: .success(title: "Saved", message: "Your changes are in."))
                    .fixedSize()
                ToastNotification(toast: .error(title: "Upload failed", message: "The server didn't answer."))
                    .fixedSize()
                ToastNotification(toast: ToastData(title: "Exporting", message: "Writing files…", style: .progress(0.6)))
                    .fixedSize()
            }
        },
        GalleryEntry("progress-overlay", width: 460, height: 230) {
            ProgressOverlay(
                title: "Importing Library",
                subtitle: "Photos",
                systemImage: "photo.on.rectangle",
                currentItem: "IMG_2041.HEIC",
                counters: [
                    ProgressOverlay.Counter(systemImage: "photo", value: 1_284),
                    ProgressOverlay.Counter(systemImage: "checkmark.circle", value: 1_120, highlightsWhenNonzero: true),
                ]
            )
        },

        // Themes
        GalleryEntry("theme-cards", width: 520, height: 120) {
            HStack(spacing: Spacing.sm) {
                ForEach(BlissTheme.builtIn) { theme in
                    ThemeCard(theme: theme, isSelected: theme == .system, onSelect: {})
                }
            }
        },
        GalleryEntry("appearance-settings", width: 520, height: 340) {
            AppearanceSettings()
                .environment(\.settingsFormPlain, true)
        },
    ]
}

// MARK: - Composite samples

private struct GalleryTask: Identifiable {
    let id: Int
    let title: String
    let owner: String
    let priority: Int
}

private struct GalleryTable: View {
    private let tasks = [
        GalleryTask(id: 1, title: "Ship the Low Glare theme", owner: "Grace", priority: 1),
        GalleryTask(id: 2, title: "Audit focus rings", owner: "Katherine", priority: 1),
        GalleryTask(id: 3, title: "Polish the onboarding card", owner: "Ada", priority: 2),
        GalleryTask(id: 4, title: "Tune the sheet spring", owner: "Alan", priority: 3),
    ]

    var body: some View {
        BlissTable(
            tasks,
            columns: [
                BlissTableColumn("Task", sortedBy: \GalleryTask.title),
                BlissTableColumn("Owner", width: .fixed(100), sortedBy: \GalleryTask.owner),
                BlissTableColumn("Priority", width: .fixed(80), sortedBy: \GalleryTask.priority),
            ],
            selection: .constant([2]),
            initialSort: BlissTableSort(columnID: "Priority"),
            contentInset: 0
        ) { task in
            Text(verbatim: task.title).font(Typography.bodySmall)
            Text(verbatim: task.owner).font(Typography.bodySmall).foregroundStyle(.secondary)
            Badge("P\(task.priority)").badgeStyle(task.priority == 1 ? .error : .secondary).badgeSize(.small)
        }
    }
}

/// The sheet's look, drawn inline: the real `appSheet` card is presented over
/// a window, so the index shows its scaffold on the same surface.
private struct GallerySheetCard: View {
    var body: some View {
        AppSheetScaffold {
            SheetHeader(title: "New Item", subtitle: "Give it a name to get started.", onDismiss: {})
        } content: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Title", text: .constant("Quarterly report")).textFieldStyle(.largePadded)
                Toggle("Notify me when it's done", isOn: .constant(true)).toggleStyle(.flatSwitch(showsLabel: true))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        } footer: {
            ActionBar(confirmTitle: "Create", showBackground: false, onCancel: {}, onConfirm: {})
        }
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusXLarge, style: .continuous)
                .fill(Color.controlBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusXLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

/// Menu rows on the menu surface — `floatingMenu` and `PopupMenuService`
/// panels are separate windows, so the index draws the rows inline.
private struct GalleryMenuCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickActionMenuItem(title: "Rename", icon: "pencil", isFocused: true) {}
            QuickActionMenuItem(title: "Duplicate", icon: "plus.square.on.square") {}
            QuickActionMenuItem(title: "Share", icon: "square.and.arrow.up") {}
            QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
        }
        .padding(Spacing.menuPadding)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.controlBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

// MARK: - Exporter

/// Shows each entry in turn, sizes the window to it, and captures the window.
struct GalleryExportView: View {
    let outputDirectory: URL

    @State private var current: GalleryEntry?
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            Color.contentAreaBackground
            if let current {
                current.content()
                    .padding(Spacing.xl)
                    .frame(width: current.size.width, height: current.size.height)
                    // The pointer may sit over the window; no hover states in a capture.
                    .allowsHitTesting(false)
                    .id(current.id)
            }
        }
        .ignoresSafeArea()
        .onWindow { hostWindow in
            guard window !== hostWindow else { return }
            window = hostWindow
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                hostWindow.standardWindowButton(button)?.isHidden = true
            }
        }
        .task { await export() }
    }

    private func export() async {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        // Give the window a moment to land.
        try? await Task.sleep(for: .milliseconds(800))
        for entry in Gallery.entries {
            current = entry
            if let window {
                window.setContentSize(entry.size)
            }
            // Past every entrance animation.
            try? await Task.sleep(for: .milliseconds(700))
            guard let window else { continue }
            capture(window: window, to: outputDirectory.appendingPathComponent("\(entry.id).png"))
        }
        NSApplication.shared.terminate(nil)
    }

    private func capture(window: NSWindow, to file: URL) {
        WindowCapture.capture(window, to: file)
    }
}

// MARK: - Window capture

/// Captures a window with `screencapture` (no shadow, transparent corners).
enum WindowCapture {
    /// `-capture <file.png>`: the catalog captures its own window once it has
    /// settled, then quits.
    static var requestedFile: URL? {
        UserDefaults.standard.string(forKey: "capture").map { URL(fileURLWithPath: $0) }
    }

    static func capture(_ window: NSWindow, to file: URL) {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", "\(window.windowNumber)", file.path]
        try? process.run()
        process.waitUntilExit()
    }
}

/// A pipeline step for the reorderable list.
private struct GalleryStep: Identifiable {
    let id: Int
    let title: String
    let icon: String

    static let pipeline = [
        GalleryStep(id: 1, title: "Install dependencies", icon: "shippingbox"),
        GalleryStep(id: 2, title: "Run migrations", icon: "cylinder.split.1x2"),
        GalleryStep(id: 3, title: "Build", icon: "hammer"),
        GalleryStep(id: 4, title: "Run tests", icon: "checkmark.seal"),
        GalleryStep(id: 5, title: "Deploy", icon: "paperplane"),
    ]
}
