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
        GalleryEntry("control-shapes", width: 620, height: 168) {
            ControlShapesDemo()
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
        GalleryEntry("rating", width: 360, height: 100) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Rating("Quality", value: .constant(4))
                Rating("Priority", value: .constant(2), maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
            }
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
                Badge("v6.2").badgeStyle(.outline)
            }
        },
        GalleryEntry("status-dot-pill", height: 60) {
            HStack(spacing: Spacing.sm) {
                StatusDotPill(label: "Running", color: Success.success500)
                StatusDotPill(label: "Degraded", color: Warning.warning500, bordered: true)
                StatusDotPill(label: "Stopped", color: Danger.danger500)
                StatusDotPill(label: "Synced", color: Info.info500, size: .regular, icon: "arrow.triangle.2.circlepath")
                StatusDotPill(label: "Offline", color: Grey.grey500, isActive: false)
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
                ShortcutKey("esc", outlined: true)
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
        GalleryEntry("markdown-view", width: 520, height: 360) {
            MarkdownView(CatalogMarkdown.releaseNotes)
        },
        GalleryEntry("carousel", width: 520, height: 300) {
            Carousel(GalleryTourPage.pages, selection: .constant(1), showsArrows: false) { page in
                VStack(spacing: Spacing.sm) {
                    Image(systemName: page.systemImage)
                        .font(Typography.displaySmall)
                        .foregroundStyle(.secondary)
                    Text(verbatim: page.title)
                        .font(Typography.headingMedium)
                    Text(verbatim: page.detail)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(page.wash)
            }
            .frame(height: 220)
        },
        GalleryEntry("timeline", width: 420, height: 240) {
            Timeline(GalleryEvent.feed) { event in
                TimelineItem(mark: event.mark, time: Text(verbatim: event.time)) {
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(verbatim: event.title)
                        if let detail = event.detail {
                            Text(verbatim: detail)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
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
        GalleryEntry("labeled-divider", width: 420, height: 100) {
            VStack(spacing: Spacing.lg) {
                LabeledDivider("or")
                LabeledDivider("Yesterday", alignment: .leading)
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
        GalleryEntry("step-indicator", width: 420, height: 104) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                StepIndicator(stepCount: 5, currentIndex: 2)
                StepIndicator(stepCount: 4, currentIndex: 1, style: .segments)
                    .frame(width: 200)
                StepIndicator(stepCount: 3, currentIndex: 1, labels: ["Account", "Plan", "Done"])
            }
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
        GalleryEntry("pagination", width: 420, height: 76) {
            Pagination(page: .constant(6), pageCount: 24)
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
///
/// The loop lives in `GalleryExporter`, not in this view's `.task`:
/// `.blissTheme()` re-IDs the tree when a forced Light or Dark differs from the
/// Mac's appearance, which would recreate this view, cancel its task and drop
/// its window reference, so a Light run on a dark Mac captured nothing.
struct GalleryExportView: View {
    let outputDirectory: URL

    private let exporter = GalleryExporter.shared

    var body: some View {
        ZStack {
            Color.contentAreaBackground
            if let current = exporter.current {
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
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                hostWindow.standardWindowButton(button)?.isHidden = true
            }
        }
        .onAppear { exporter.startIfNeeded(outputDirectory: outputDirectory) }
    }
}

/// Walks the entries once, whatever happens to the view showing them.
@MainActor
@Observable
final class GalleryExporter {
    static let shared = GalleryExporter()

    private(set) var current: GalleryEntry?
    @ObservationIgnored private var hasStarted = false

    private init() {}

    func startIfNeeded(outputDirectory: URL) {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await export(to: outputDirectory) }
    }

    private func export(to outputDirectory: URL) async {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        // Give the window a moment to land.
        try? await Task.sleep(for: .milliseconds(800))
        for entry in Gallery.entries {
            current = entry
            WindowCapture.catalogWindow?.setContentSize(entry.size)
            // Past every entrance animation.
            try? await Task.sleep(for: .milliseconds(700))
            guard let window = WindowCapture.catalogWindow else { continue }
            WindowCapture.capture(window, to: outputDirectory.appendingPathComponent("\(entry.id).png"))
        }
        NSApplication.shared.terminate(nil)
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

    /// The catalog's window (not a menu or tooltip panel), found through AppKit
    /// so a capture doesn't depend on a view that may have been re-created.
    static var catalogWindow: NSWindow? {
        NSApplication.shared.windows.first { $0.isVisible && !($0 is NSPanel) }
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

/// An event in the timeline picture.
private struct GalleryEvent: Identifiable {
    let id: Int
    let title: String
    let detail: String?
    let mark: TimelineMark
    let time: String

    static let feed = [
        GalleryEvent(id: 1, title: "Deploy finished", detail: "Build 412 is live on production.", mark: .icon("checkmark", Success.success500), time: "4m ago"),
        GalleryEvent(id: 2, title: "Tests passed", detail: nil, mark: .dot(Success.success500), time: "9m ago"),
        GalleryEvent(id: 3, title: "Build started", detail: "Triggered by a push to main.", mark: .dot(.secondary), time: "12m ago"),
        GalleryEvent(id: 4, title: "Migration warning", detail: "Two columns were dropped without a backup.", mark: .icon("exclamationmark.triangle", Warning.warning500), time: "30m ago"),
    ]
}

/// The pages of the carousel picture.
private struct GalleryTourPage: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let systemImage: String
    let wash: Color

    static var pages: [GalleryTourPage] {
        [
            GalleryTourPage(id: 1, title: "Welcome", detail: "A tour of what's new in this release.", systemImage: "sparkles", wash: Success.tint.opacity(0.15)),
            GalleryTourPage(id: 2, title: "Sync", detail: "Your projects follow you to every Mac.", systemImage: "arrow.triangle.2.circlepath", wash: Info.tint.opacity(0.15)),
            GalleryTourPage(id: 3, title: "Shortcuts", detail: "Hold ⌘ to see every row's key.", systemImage: "command", wash: Warning.tint.opacity(0.15)),
            GalleryTourPage(id: 4, title: "Themes", detail: "Four built in, and room for your own.", systemImage: "paintpalette", wash: Danger.tint.opacity(0.15)),
        ]
    }
}
