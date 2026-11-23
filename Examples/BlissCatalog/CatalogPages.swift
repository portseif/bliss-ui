//
//  CatalogPages.swift
//  BlissCatalog
//
//  One page per component area. Each shows the components the way an app
//  would use them.
//

import BlissUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared

/// `-demo <state>` opens a page in a state that otherwise takes a click —
/// used to capture the README screenshots (`selection`, `sheet`, `toasts`).
enum CatalogDemo {
    static var state: String? { UserDefaults.standard.string(forKey: "demo") }
}

/// A titled demo block on a page. Shared by every catalog page.
struct DemoBlock<Content: View>: View {
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
            DemoBlock(title: "Mode picker with labels") {
                AppearanceModePicker(
                    selection: Binding(get: { BlissAppearance.colorScheme }, set: { BlissAppearance.colorScheme = $0 }),
                    showsLabels: true
                )
            }
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
    @State private var isSaving = false

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
            DemoBlock(title: "Icon-only and full-width") {
                HStack(spacing: Spacing.sm) {
                    Button {} label: { Image(systemName: "plus") }
                        .buttonStyle(PrimaryButtonStyle(iconOnly: true))
                        .accessibilityLabel(Text("Add"))
                    Button {} label: { Image(systemName: "square.and.arrow.up") }
                        .buttonStyle(SecondaryButtonStyle(iconOnly: true))
                        .accessibilityLabel(Text("Share"))
                    Button {} label: { Image(systemName: "pencil") }
                        .buttonStyle(OutlineButtonStyle(compact: true, iconOnly: true))
                        .accessibilityLabel(Text("Edit"))
                    Button {} label: { Image(systemName: "ellipsis") }
                        .buttonStyle(GhostButtonStyle(compact: true, iconOnly: true))
                        .accessibilityLabel(Text("More"))
                    Button {} label: { Image(systemName: "trash") }
                        .buttonStyle(DestructiveButtonStyle(compact: true, iconOnly: true))
                        .accessibilityLabel(Text("Delete"))
                    Button {} label: { Image(systemName: "stop.fill") }
                        .buttonStyle(ToolbarIconButtonStyle(tint: Danger.danger500))
                        .accessibilityLabel(Text("Stop"))
                    Button("Bugs") {}.buttonStyle(SmallPillButtonStyle(color: Danger.danger500, isSelected: true))
                    Button("Docs") {}.buttonStyle(SmallPillButtonStyle(color: Info.info500, compact: true))
                }
                Button("Continue") {}
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    .frame(width: 240)
            }
            DemoBlock(title: "Loading") {
                HStack(spacing: Spacing.sm) {
                    Button("Save") {
                        isSaving = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            isSaving = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .buttonLoading(isSaving)
                    Button("Checking…") {}.buttonStyle(SecondaryButtonStyle()).buttonLoading(true)
                    Button("Publishing") {}.buttonStyle(OutlineButtonStyle(compact: true)).buttonLoading(true)
                    Button("Deleting") {}.buttonStyle(DestructiveButtonStyle(compact: true, prominent: true)).buttonLoading(true)
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

private enum CatalogLayout: CaseIterable, Hashable {
    case list, grid

    var title: String { self == .list ? "List" : "Grid" }
    var icon: String { self == .list ? "list.bullet" : "square.grid.2x2" }
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
    @State private var tintedChecked = true
    @State private var apiKey = "sk-live-4f8a2c9e1b7d6a3f"
    @State private var droppedFiles: [String] = []
    @State private var stars = 3
    @State private var priority = 2
    @State private var compactName = ""
    @State private var passphrase = "correct horse battery staple"
    @State private var wifiOn = true
    @State private var layout = CatalogLayout.list

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Text fields") {
                TextField("Name", text: $name).textFieldStyle(.largePadded)
                TextField("Search", text: $search).textFieldStyle(.search)
                TextField("Compact", text: $compactName, prompt: Text("Compact, for a toolbar or a dense form"))
                    .textFieldStyle(.compact)
                    .frame(maxWidth: 320)
            }
            DemoBlock(title: "Secret field") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SecretField("API key", text: $apiKey, prompt: Text("sk-…"))
                    SecretField("Passphrase", text: $passphrase, isRevealable: false, monospaced: false)
                }
                .frame(maxWidth: 420)
            }
            DemoBlock(title: "Drop zone") {
                DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", systemImage: "photo.on.rectangle", allowedContentTypes: [.png, .jpeg]) { urls in
                    droppedFiles = urls.map(\.lastPathComponent)
                }
                .frame(maxWidth: 480)
                DropZone("Attach a file", hint: "Any type", systemImage: "paperclip", compact: true) { urls in
                    droppedFiles = urls.map(\.lastPathComponent)
                }
                .frame(maxWidth: 480)
                if !droppedFiles.isEmpty {
                    Text(verbatim: droppedFiles.joined(separator: ", "))
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            DemoBlock(title: "Switch and checkbox") {
                Toggle("Notifications", isOn: $notificationsOn).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Wi-Fi", isOn: $wifiOn).toggleStyle(.flatSwitch(showsLabel: true, tint: Success.success500, labelPlacement: .trailing))
                Toggle("I agree", isOn: $agreed).toggleStyle(.flatCheckbox)
                Toggle("Tinted", isOn: $tintedChecked).toggleStyle(.flatCheckbox(tint: Success.success500))
                HStack(spacing: Spacing.sm) {
                    CheckboxGlyph(isOn: true, isMixed: true)
                    Text("Some selected (the mixed glyph, for a select-all box)")
                }
            }
            DemoBlock(title: "Rating") {
                Text("Hover to preview, click to set, click the same star to clear. Tab to it and use ← / →, Home / End, or ↓ to clear.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Rating("Quality", value: $stars)
                    Rating("Priority", value: $priority, maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
                    Rating("Average", value: .constant(4), size: .small, isReadOnly: true, valueLabel: Text(verbatim: "4.0"))
                    Rating("Review", value: $stars, size: .large)
                }
            }
            DemoBlock(title: "Segmented pills") {
                SegmentedPills(options: CatalogPeriod.allCases, selection: $period, title: { $0.rawValue })
                HStack(spacing: Spacing.md) {
                    SegmentedPills(options: CatalogPeriod.allCases, selection: $period, style: .compact, title: { $0.rawValue })
                    SegmentedPills(options: CatalogLayout.allCases, selection: $layout, style: .compact, labelStyle: .iconOnly, title: { $0.title }, icon: { $0.icon })
                    SegmentedPills(options: CatalogPeriod.allCases, selection: $period, fillsWidth: false, title: { $0.rawValue })
                }
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
                HStack(spacing: Spacing.md) {
                    FloatingMenuPicker("Size", selection: $size, options: ["Small", "Medium", "Large"], optionTitle: { $0 }, showsTitle: false, compact: true)
                    FloatingMenuPicker("Size", selection: $size, options: ["Small", "Medium", "Large"], optionTitle: { $0 }, showsTitle: false, showsBorder: false)
                    FloatingMenuPicker("Size", selection: $size, options: ["Small", "Medium", "Large"], optionTitle: { $0 }, optionIcon: { _ in "textformat.size" }, showsTitle: false, iconOnly: true)
                }
            }
            DemoBlock(title: "Pickers") {
                HStack(spacing: Spacing.md) {
                    ColorPickerButton(red: $red, green: $green, blue: $blue)
                    IconPickerButton(selectedIcon: $icon)
                    ColorPickerButton(red: $red, green: $green, blue: $blue, label: .hexChip, compact: true)
                    IconPickerButton(selectedIcon: $icon, compact: true)
                }
                BrowseInput(path: $folder, placeholder: "Choose a folder", isClearable: true)
                    .frame(maxWidth: 420)
            }
        }
    }
}

// MARK: - Display

/// The pages of the carousel demo.
private struct CatalogTourPage: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let systemImage: String
    let wash: Color

    static var pages: [CatalogTourPage] {
        [
            CatalogTourPage(id: 1, title: "Welcome", detail: "A tour of what's new in this release.", systemImage: "sparkles", wash: Success.tint.opacity(0.15)),
            CatalogTourPage(id: 2, title: "Sync", detail: "Your projects follow you to every Mac.", systemImage: "arrow.triangle.2.circlepath", wash: Info.tint.opacity(0.15)),
            CatalogTourPage(id: 3, title: "Shortcuts", detail: "Hold ⌘ to see every row's key.", systemImage: "command", wash: Warning.tint.opacity(0.15)),
            CatalogTourPage(id: 4, title: "Themes", detail: "Four built in, and room for your own.", systemImage: "paintpalette", wash: Danger.tint.opacity(0.15)),
        ]
    }
}

/// One tour page: an icon, a title and a line on a colored wash.
private struct CatalogTourPageView: View {
    let page: CatalogTourPage

    var body: some View {
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
}

/// An event in the timeline demo.
private struct CatalogEvent: Identifiable {
    let id: Int
    let title: String
    let detail: String?
    let mark: TimelineMark
    let date: Date

    static let feed = [
        CatalogEvent(id: 1, title: "Deploy finished", detail: "Build 412 is live on production.", mark: .icon("checkmark", Success.success500), date: .now.addingTimeInterval(-240)),
        CatalogEvent(id: 2, title: "Tests passed", detail: nil, mark: .dot(Success.success500), date: .now.addingTimeInterval(-540)),
        CatalogEvent(id: 3, title: "Build started", detail: "Triggered by a push to main.", mark: .dot(.secondary), date: .now.addingTimeInterval(-720)),
        CatalogEvent(id: 4, title: "Migration warning", detail: "Two columns were dropped without a backup.", mark: .icon("exclamationmark.triangle", Warning.warning500), date: .now.addingTimeInterval(-1_800)),
    ]

    /// Who did what: avatar marks for a comment feed.
    static let activity = [
        CatalogEvent(id: 1, title: "Ada approved the release", detail: nil, mark: .avatar(name: "Ada Lovelace"), date: .now.addingTimeInterval(-300)),
        CatalogEvent(id: 2, title: "Grace requested changes", detail: nil, mark: .avatar(name: "Grace Hopper"), date: .now.addingTimeInterval(-2_400)),
        CatalogEvent(id: 3, title: "Alan opened the pull request", detail: nil, mark: .avatar(name: "Alan Turing"), date: .now.addingTimeInterval(-7_200)),
    ]
}

struct DisplayPage: View {
    @State private var count = 7
    @State private var isRevealed = false
    @State private var tourPage = 1
    @State private var tourAutoplays = false
    @State private var terminalExpanded = true
    @State private var markdownSize: MarkdownSize = .small

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Badges") {
                FlowLayout(spacing: Spacing.sm) {
                    Badge("Default")
                    Badge("Primary").badgeStyle(.primary)
                    Badge("Beta", icon: "flask").badgeStyle(.info)
                    Badge(count: 12)
                    Badge.status("Healthy", color: Success.success500)
                    Badge.pro()
                    Badge("Live").badgeStyle(.success).dot(Success.success500)
                }
                FlowLayout(spacing: Spacing.sm, alignment: .center) {
                    Badge("v6.2").badgeStyle(.outline)
                    Badge(count: 1_200, maximum: 999)
                    Badge.status("Paused", color: Warning.warning500)
                    Badge("Starred", icon: "star").badgeStyle(.primary)
                }
                .frame(maxWidth: 320)
            }
            DemoBlock(title: "Status and progress") {
                HStack(spacing: Spacing.lg) {
                    StatusDotPill(label: "Running", color: Success.success500)
                    StatusDotPill(label: "Degraded", color: Warning.warning500, bordered: true)
                    ThinkingSpinner()
                    ShimmerTextOverlay(text: "Thinking…")
                }
                HStack(spacing: Spacing.lg) {
                    StatusDotPill(label: "Synced", color: Info.info500, icon: "arrow.triangle.2.circlepath")
                    StatusDotPill(label: "Offline", color: Grey.grey500, isActive: false)
                    StatusPill("Connected", isActive: true, color: Info.info500, icon: "bolt.fill")
                    ThinkingSpinner(size: .small)
                    ThinkingSpinner(size: .large, color: Color.accent)
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
                HStack(spacing: Spacing.lg) {
                    SlidingNumber(value: count * 12, size: .small, prefix: "$")
                    SlidingNumber(value: min(count * 7, 100), size: .regular, suffix: "%")
                    ShortcutKey("esc", outlined: true)
                    ShortcutKey("⌘S", tint: Color.accent)
                    TimeAgoLabel(date: Date().addingTimeInterval(-3_600), style: .full)
                    TimeAgoLabel(date: Date().addingTimeInterval(-90), showsIcon: false)
                        .foregroundStyle(.secondary)
                }
            }
            DemoBlock(title: "Paths") {
                PathHoverChip(path: "/Users/me/Developer/BlissUI/Sources")
                PathHoverChip.code("swift run BlissCatalog")
                PathHoverChip(path: "~/Library/Application Support/Bliss", compact: true, showsCopy: false)
            }
            DemoBlock(title: "Terminal output") {
                TerminalOutputView(lines: [
                    TerminalOutputLine("$ swift build", type: .system),
                    TerminalOutputLine("Compiling BlissUI (62 sources)"),
                    TerminalOutputLine("warning: unused variable 'count'", type: .stderr),
                    TerminalOutputLine("Build complete!"),
                ], title: "Build", maxHeight: 140)
                Text("Caller-owned collapse, no wrapping (scroll sideways) and a header accessory.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                TerminalOutputView(lines: [
                    TerminalOutputLine("$ swift run BlissCatalog -gallery /tmp/shots -bliss.colorScheme Dark -bliss.theme system -galleryArea core", type: .system),
                    TerminalOutputLine("Captured 48 components in 34 s"),
                ], title: "Deploy", maxHeight: 120, isExpanded: $terminalExpanded, wrapsLines: false) {
                    HoverIconButton(systemImage: "trash", help: "Clear") {}
                }
                Button(terminalExpanded ? "Collapse" : "Expand") { terminalExpanded.toggle() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
            DemoBlock(title: "Markdown view") {
                Text("A whole document: headings, lists, quotes, links and fenced code. Text alone renders inline markdown only.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                SegmentedPills(options: [MarkdownSize.small, .regular], selection: $markdownSize, style: .compact, title: { $0 == .small ? "Small" : "Regular" })
                MarkdownView(CatalogMarkdown.releaseNotes, size: markdownSize)
                    .frame(maxWidth: 560)
            }
            DemoBlock(title: "Carousel") {
                Text("Swipe, click the arrows that appear on hover, or focus it and press ← / → (Home / End jump). The dots are a Tab stop too. Autoplay pauses under the pointer and never runs with Reduce Motion on.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Autoplay every 4 seconds", isOn: $tourAutoplays)
                    .toggleStyle(.flatSwitch(showsLabel: true))
                Carousel(CatalogTourPage.pages, selection: $tourPage, autoplayInterval: tourAutoplays ? 4 : nil, loops: true, pageSpacing: Spacing.sm) { page in
                    CatalogTourPageView(page: page)
                }
                .frame(maxWidth: 560)
                .frame(height: 240)
            }
            DemoBlock(title: "Timeline") {
                Timeline(CatalogEvent.feed) { event in
                    TimelineItem(mark: event.mark, time: Text(event.date, style: .relative)) {
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
                .frame(maxWidth: 480)
                Text("Compact, time leading, avatar marks.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Timeline(CatalogEvent.activity, compact: true, timePlacement: .leading) { event in
                    TimelineItem(mark: event.mark, time: Text(event.date, style: .relative)) {
                        Text(verbatim: event.title)
                    }
                }
                .frame(maxWidth: 480)
            }
            DemoBlock(title: "Empty state") {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    EmptyState(icon: "tray", title: "Nothing here yet", subtitle: "Items you add show up here.") {
                        Button("Add Item") {}.buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                    .contained()
                    EmptyState(icon: "exclamationmark.triangle", title: "Couldn't load", subtitle: "The server didn't answer.", compact: true, iconColor: Danger.danger500) {
                        Button("Retry") {}.buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                    .contained()
                    .frame(maxWidth: 280)
                }
            }
        }
    }
}

// MARK: - Sections

struct SectionsPage: View {
    @State private var tab = 0
    @State private var iconTab = 0
    @State private var autoSave = true
    @State private var step = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Labeled divider") {
                VStack(spacing: Spacing.lg) {
                    LabeledDivider("or")
                    LabeledDivider("Yesterday", alignment: .leading)
                    LabeledDivider(alignment: .trailing) {
                        Text("3 more").font(Typography.captionSmallSemibold)
                    }
                    LabeledDivider("Details", alignment: .leading, prominent: true, verticalPadding: Spacing.xs)
                }
                .frame(maxWidth: 420)
            }
            DemoBlock(title: "Underline tabs") {
                UnderlineTabBar(
                    items: [
                        UnderlineTabItem(value: 0, title: "Overview"),
                        UnderlineTabItem(value: 1, title: "Activity", count: 3, isCountProminent: true),
                        UnderlineTabItem(value: 2, title: "Settings"),
                        UnderlineTabItem(value: 3, title: "Logs", isEnabled: false),
                    ],
                    selection: $tab
                )
                Text("Compact, icons only (the title is the tooltip), a disabled tab.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                UnderlineTabBar(
                    items: [
                        UnderlineTabItem(value: 0, title: "Overview", icon: "square.grid.2x2"),
                        UnderlineTabItem(value: 1, title: "Activity", icon: "clock", count: 3),
                        UnderlineTabItem(value: 2, title: "Settings", icon: "gearshape"),
                        UnderlineTabItem(value: 3, title: "Logs", icon: "doc.text", isEnabled: false),
                    ],
                    selection: $iconTab,
                    compact: true,
                    showsTitles: false
                )
            }
            SettingsForm {
                RoundedSection("General", divided: true) {
                    Toggle("Save automatically", isOn: $autoSave).toggleStyle(.flatSwitch(showsLabel: true))
                    DetailRow(label: "Version", value: "1.0.0", copyable: true)
                    DetailRow(label: "Location", value: "/Users/me/Library/Application Support/Bliss", isPath: true)
                    DetailRow(label: "API key", value: "sk-live-4f8a2c9e1b7d6a3f", monospace: true, copyable: true, isSecret: true)
                    DetailRow(label: "Last modified", value: "Today at 9:41", labelWidth: 120)
                } footer: {
                    Text("Changes apply on relaunch.")
                }
                .headerTrailing {
                    Button("Edit") {}.buttonStyle(GhostButtonStyle(compact: true, hugsLabel: true))
                }
                RoundedSection("Connection", borderTint: Success.tint.opacity(0.3)) {
                    ForEach(rows) { row in row }
                }
            }
            .environment(\.settingsFormPlain, true)
            SectionHeader("Members", count: 4, caption: "Updated just now")
            SectionHeader("Pinned", count: 2, size: .small, hugsContent: true, topPadding: 0)
            DemoBlock(title: "Step indicator") {
                StepIndicator(stepCount: 5, currentIndex: 2)
                StepIndicator(stepCount: 5, currentIndex: step, grows: true)
                Text("A dot that grows into a line, segments, labels with clickable completed steps, and a vertical rail.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                StepIndicator(stepCount: 4, currentIndex: step, style: .segments, onSelect: { step = $0 })
                    .frame(maxWidth: 240)
                StepIndicator(stepCount: 3, currentIndex: min(step, 2), labels: ["Account", "Plan", "Done"], onSelect: { step = $0 })
                StepIndicator(stepCount: 3, currentIndex: min(step, 2), axis: .vertical)
                Button("Next step") { step = (step + 1) % 4 }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
        }
    }

    private var rows: [InfoRow] {
        [
            InfoRow.labeled("Host", value: "api.example.com"),
            InfoRow.status("Connected", icon: "checkmark.circle.fill", style: .success, detail: "Last checked 2 minutes ago"),
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

/// A pipeline step the reorderable list demo drags around.
private struct CatalogStep: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

struct TablePage: View {
    @State private var selection: Set<UUID> = []
    @State private var page = 6
    @State private var pageSize = 25
    @State private var isCompact = false
    @State private var isStriped = false
    @State private var showsRows = true
    @State private var barIsAttached = false
    @State private var steps = [
        CatalogStep(id: 1, title: "Install dependencies", icon: "shippingbox"),
        CatalogStep(id: 2, title: "Run migrations", icon: "cylinder.split.1x2"),
        CatalogStep(id: 3, title: "Build", icon: "hammer"),
        CatalogStep(id: 4, title: "Run tests", icon: "checkmark.seal"),
        CatalogStep(id: 5, title: "Deploy", icon: "paperplane"),
    ]
    /// Static, so the rows keep their IDs across renders (a selection holds IDs).
    private static let tasks = [
        CatalogTask(title: "Polish the onboarding card", owner: "Ada", priority: 2, updated: .now.addingTimeInterval(-600)),
        CatalogTask(title: "Ship the Low Glare theme", owner: "Grace", priority: 1, updated: .now.addingTimeInterval(-7_200)),
        CatalogTask(title: "Tune the sheet spring", owner: "Alan", priority: 3, updated: .now.addingTimeInterval(-86_400)),
        CatalogTask(title: "Audit focus rings", owner: "Katherine", priority: 1, updated: .now.addingTimeInterval(-172_800)),
        CatalogTask(title: "Write the catalog", owner: "Ada", priority: 2, updated: .now.addingTimeInterval(-30)),
    ]

    private var tasks: [CatalogTask] { Self.tasks }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack(spacing: Spacing.md) {
                Toggle("Compact", isOn: $isCompact).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Striped", isOn: $isStriped).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Rows", isOn: $showsRows).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Attached selection bar", isOn: $barIsAttached).toggleStyle(.flatSwitch(showsLabel: true))
            }
            table
            DemoBlock(title: "Reorderable list") {
                Text("Drag a row by its grip, or Tab to the grip and press ⌥↑ / ⌥↓. Deploy stays last: `canMove` pins it.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                ReorderableList($steps, divided: true, canMove: { $0.id != 5 }) { step in
                    Label {
                        Text(verbatim: step.title).font(Typography.bodySmall)
                    } icon: {
                        Image(systemName: step.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: Sizing.iconDefault)
                    }
                }
                .frame(maxWidth: 420)
                Text("Compact rows.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                ReorderableList($steps, compact: true) { step in
                    Text(verbatim: step.title).font(Typography.bodySmall)
                }
                .frame(maxWidth: 420)
            }
            DemoBlock(title: "Pagination") {
                Text("The first and last page always show; skipped runs fold into an ellipsis. Previous and next disable at the ends.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Pagination(page: $page, pageCount: 24)
                Pagination(page: $page, pageCount: 24, siblingCount: 2)
                Text("A total, a page-size picker and first / last buttons.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Pagination(page: $page, pageCount: 24, totalItems: 583, pageSize: $pageSize, showsFirstLast: true)
            }
        }
    }

    private var table: some View {
        BlissTable(
            showsRows ? tasks : [],
            columns: [
                BlissTableColumn("Task", sortedBy: \CatalogTask.title),
                BlissTableColumn("Owner", width: .fixed(110), sortedBy: \CatalogTask.owner),
                BlissTableColumn("Priority", width: .fixed(80), sortedBy: \CatalogTask.priority),
                BlissTableColumn("Updated", width: .fixed(110), alignment: .trailing, sortedBy: \CatalogTask.updated),
            ],
            selection: $selection,
            initialSort: BlissTableSort(columnID: "Priority"),
            contentInset: 0,
            compact: isCompact,
            striped: isStriped,
            onOpen: { task in
                ToastService.shared.showInfo(title: "Opened", message: task.title)
            },
            emptyState: {
                EmptyState(icon: "tray", title: "No tasks", subtitle: "Turn the rows back on.", compact: true)
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
        // Tall enough that the selection bar floats below the rows.
        .frame(minHeight: 540, alignment: .top)
        .selectionBar(
            count: selection.count,
            total: tasks.count,
            placement: barIsAttached ? .attached : .floating,
            onClear: { selection.removeAll() },
            onSelectAll: { selection = Set(tasks.map(\.id)) }
        ) {
            SelectionBarButton("Archive", systemImage: "archivebox") { selection.removeAll() }
            SelectionBarButton("Assign", systemImage: "person.crop.circle") {}
        }
        .onAppear {
            if CatalogDemo.state == "selection" {
                selection = Set(tasks.filter { $0.priority == 1 }.map(\.id))
            }
        }
    }
}

// MARK: - Overlays

struct OverlaysPage: View {
    @State private var showingMenu = false
    @State private var showingGroupedMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Tooltips") {
                HStack(spacing: Spacing.md) {
                    Button("Above") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows above", position: .above)
                    Button("Below") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows below", position: .below)
                    Button("Trailing") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Shows trailing", position: .trailing)
                    InfoButton(text: "Click for a hint that stays open to be read.")
                }
                HStack(spacing: Spacing.md) {
                    Button("Save") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Save", shortcut: "⌘S", position: .below)
                    Button("Build 412") {}.buttonStyle(SecondaryButtonStyle()).tooltip("Build 412", detail: "Finished 4 minutes ago on main", position: .below)
                    InfoButton(text: "Projects sync whenever this Mac is online.", title: "Sync", size: .regular, systemImage: "questionmark.circle")
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
            DemoBlock(title: "Grouped menu") {
                Button {
                    showingGroupedMenu.toggle()
                } label: {
                    Label("Switch project", systemImage: "square.stack")
                }
                .buttonStyle(SecondaryButtonStyle())
                .floatingMenu(isPresented: $showingGroupedMenu, xPosition: .leading, yPosition: .below) {
                    CatalogGroupedMenu(isPresented: $showingGroupedMenu)
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
                    .blissContextMenu {
                        MenuSectionHeader("Card")
                        QuickActionMenuItem(title: "Open", icon: "arrow.up.forward.app", shortcut: "⌘O") {}
                        QuickActionMenuItem(title: "Rename", icon: "pencil") {}
                        QuickActionMenuItem(title: "Duplicate", icon: "plus.square.on.square") {}
                        QuickActionMenuItem(title: "Pinned", icon: "pin", isChecked: true) {}
                        QuickActionMenuItem(title: "Export", icon: "square.and.arrow.up", isEnabled: false, detail: "Needs a selection") {}
                        MenuDivider()
                        QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
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

/// Rows held in `MenuSection`s, with a loose row after them.
private struct CatalogGroupedMenu: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            MenuSection("Recent") {
                QuickActionMenuItem(title: "Neighborhood Bakery", icon: "storefront", isChecked: true) { isPresented = false }
                QuickActionMenuItem(title: "Northlight Observatory", icon: "sparkles", isChecked: false) { isPresented = false }
                QuickActionMenuItem(title: "Harbor Coffee", icon: "cup.and.saucer", isChecked: false) { isPresented = false }
            }
            MenuSection("Project") {
                QuickActionMenuItem(title: "Rename", icon: "pencil", shortcut: "⌘R") { isPresented = false }
                QuickActionMenuItem(title: "Show in Finder", icon: "folder", detail: "No files yet") { isPresented = false }
            }
            QuickActionMenuItem(title: "New Project", icon: "plus", shortcut: "⌘N") { isPresented = false }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 280)
    }
}

// MARK: - Sheets & Toasts

struct SheetsPage: View {
    @State private var showingSheet = false
    @State private var showingLargeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "App sheet") {
                HStack(spacing: Spacing.sm) {
                    Button("Open Sheet") { showingSheet = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Large Sheet") { showingLargeSheet = true }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Text("The large one has an icon in its header, a header action, a secondary footer action, and closes on a click outside.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
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
                HStack(spacing: Spacing.sm) {
                    Button("Warning") {
                        ToastService.shared.showWarning(title: "Low disk space", message: "4 GB left on Macintosh HD.")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Prominent action") {
                        ToastService.shared.showInfo(
                            title: "Update ready",
                            message: "Version 2.4 downloaded.",
                            actions: [ToastAction(label: "Install", icon: "arrow.down.circle", isProminent: true) {}]
                        )
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("Stacked") {
                        ToastService.shared.show(ToastData(title: "Backup complete", message: "Saved 1.2 GB to the external drive, 8 minutes.", style: .success, layout: .stacked))
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        }
        // A fixed-width sheet is content-sized.
        .appSheet(isPresented: $showingSheet, contentSized: true) {
            CatalogSheet()
        }
        .appSheet(isPresented: $showingLargeSheet, size: .large, dismissesOnScrimTap: true) {
            CatalogLargeSheet()
        }
        .onAppear(perform: showDemoState)
    }

    private func showDemoState() {
        switch CatalogDemo.state {
        case "sheet":
            showingSheet = true
        case "toasts":
            ToastService.shared.show(.success(title: "Saved", message: "Your changes are in."), autoDismiss: false)
            ToastService.shared.show(.info(title: "Update available", message: "Version 1.1 is ready."), autoDismiss: false)
            ToastService.shared.show(ToastData(title: "Exporting", message: "Writing files…", style: .progress(0.6)))
        default:
            break
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

/// The large sheet: an icon in the header, a header action, a loading confirm
/// and a secondary footer action.
private struct CatalogLargeSheet: View {
    @Environment(\.appSheetDismiss) private var dismiss
    @State private var title = "Quarterly report"
    @State private var isCreating = false

    var body: some View {
        AppSheetScaffold {
            SheetHeader(title: "New Report", subtitle: "From the Q3 template.", icon: "doc.badge.plus", iconColor: Color.accent, onDismiss: { dismiss() }) {
                Button("Help") {}.buttonStyle(GhostButtonStyle(compact: true))
            }
        } content: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Title", text: $title).textFieldStyle(.largePadded)
                Text("A large sheet is as wide as the window allows, up to the preset.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        } footer: {
            ActionBar(
                confirmTitle: "Create",
                isConfirmDisabled: title.isEmpty,
                isConfirmLoading: isCreating,
                secondaryTitle: "Save Draft",
                onSecondary: { dismiss() },
                onCancel: { dismiss() }
            ) {
                isCreating = true
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    isCreating = false
                    dismiss()
                }
            }
        }
    }
}

private struct CatalogSheet: View {
    @Environment(\.appSheetDismiss) private var dismiss
    @State private var title = ""
    @State private var notify = true

    var body: some View {
        AppSheetScaffold {
            SheetHeader(title: "New Item", subtitle: "Give it a name to get started.", onDismiss: { dismiss() })
        } content: {
            VStack(alignment: .leading, spacing: Spacing.md) {
                TextField("Title", text: $title).textFieldStyle(.largePadded)
                Toggle("Notify me when it's done", isOn: $notify).toggleStyle(.flatSwitch(showsLabel: true))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        } footer: {
            ActionBar(confirmTitle: "Create", isConfirmDisabled: title.isEmpty, onCancel: { dismiss() }) {
                dismiss()
                ToastService.shared.showSuccess(title: "Created", message: title)
            }
        }
        .frame(width: 440)
    }
}
