//
//  FormsPage.swift
//  BlissCatalog
//
//  The "Forms & Feedback" page: settings rows and the table-of-contents form,
//  option cards, wizard rows, banners, disclosure sections, the confirmation
//  sheet and skeleton loading.
//

import BlissUI
import SwiftUI

struct FormsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            FormsSettingsRowsDemo()
            FormsTableOfContentsDemo()
            FormsOptionCardsDemo()
            FormsWizardRowsDemo()
            FormsBannersDemo()
            FormsDisclosureDemo()
            FormsConfirmationDemo()
            FormsSkeletonDemo()
        }
    }
}

// MARK: - Settings rows

private struct FormsSettingsRowsDemo: View {
    @State private var launchAtLogin = true
    @State private var playSounds = false
    @State private var language = "English"
    @State private var isConfirmingReset = false

    var body: some View {
        DemoBlock(title: "Settings rows") {
            RoundedSection("General", divided: true) {
                SettingsToggleRow("Launch at login", detail: "Opens in the menu bar when you log in.", isOn: $launchAtLogin)
                SettingsToggleRow("Play sounds", isOn: $playSounds)
                SettingsRow("Language", detail: "Used for menus and messages.") {
                    FloatingMenuPicker(
                        "Language",
                        selection: $language,
                        options: ["English", "Deutsch", "Français", "日本語"],
                        optionTitle: { $0 },
                        showsTitle: false
                    )
                }
                SettingsRow("Updates", detail: "Checked once a day.") {
                    Button("Check Now") {
                        ToastService.shared.showInfo(title: "You're up to date", message: "Version 1.0 is the latest.")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
                SettingsActionRow("Login Items", detail: "Choose what opens at login in System Settings.", systemImage: "arrow.up.right") {
                    ToastService.shared.showInfo(title: "Login Items", message: "An app would open System Settings here.")
                }
                SettingsActionRow("Reset All Settings…", isDestructive: true) {
                    isConfirmingReset = true
                }
            }
            .frame(maxWidth: 560)
        }
        .confirmationSheet(
            isPresented: $isConfirmingReset,
            title: "Reset All Settings?",
            message: "Every setting goes back to its default. Your documents aren't touched.",
            confirmTitle: "Reset",
            isDestructive: true
        ) {
            launchAtLogin = true
            playSounds = false
            language = "English"
            ToastService.shared.showSuccess(title: "Settings reset", message: "Everything is back to its default.")
        }
    }
}

// MARK: - Table of contents

private enum CatalogSettingsPane: String, CaseIterable, Hashable {
    case general = "General"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case privacy = "Privacy"
    case advanced = "Advanced"
}

private struct FormsTableOfContentsDemo: View {
    @State private var activeSection: CatalogSettingsPane?
    @State private var toggles: [String: Bool] = [:]

    private var sections: [SettingsTableOfContentsItem<CatalogSettingsPane>] {
        CatalogSettingsPane.allCases.map { SettingsTableOfContentsItem($0, title: LocalizedStringKey($0.rawValue)) }
    }

    var body: some View {
        DemoBlock(title: "Settings with a table of contents") {
            SettingsScrollView(sections: sections, activeSection: $activeSection) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(CatalogSettingsPane.allCases, id: \.self) { pane in
                        RoundedSection(LocalizedStringKey(pane.rawValue), divided: true) {
                            ForEach(Self.rows(for: pane), id: \.self) { row in
                                SettingsToggleRow(LocalizedStringKey(row), detail: "Applies right away.", isOn: binding(for: row))
                            }
                        }
                        .settingsSection(pane)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .frame(height: 320)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
            Text("In view: \(activeSection?.rawValue ?? "—")")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    private static func rows(for pane: CatalogSettingsPane) -> [String] {
        switch pane {
        case .general: ["Open at login", "Show in menu bar", "Check for updates"]
        case .appearance: ["Use compact rows", "Show icons in the sidebar"]
        case .notifications: ["Banners", "Sounds", "Badge the app icon"]
        case .privacy: ["Share analytics", "Send crash reports"]
        case .advanced: ["Verbose logging", "Developer menu"]
        }
    }

    private func binding(for row: String) -> Binding<Bool> {
        Binding(get: { toggles[row] ?? true }, set: { toggles[row] = $0 })
    }
}

// MARK: - Option cards

private enum CatalogTaskKind: String, CaseIterable, Hashable {
    case review = "Review", refactor = "Refactor", tests = "Write tests", explain = "Explain"

    var icon: String {
        switch self {
        case .review: "doc.text.magnifyingglass"
        case .refactor: "wand.and.rays"
        case .tests: "checkmark.seal"
        case .explain: "text.bubble"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .review: "Reads the code and reports what it finds."
        case .refactor: "Tidies the code without changing what it does."
        case .tests: "Adds tests for what isn't covered yet."
        case .explain: "Walks through how a part of the code works."
        }
    }
}

private enum CatalogPlan: String, CaseIterable, Hashable {
    case monthly = "Monthly", yearly = "Yearly", lifetime = "Lifetime"

    var price: LocalizedStringKey {
        switch self {
        case .monthly: "$8 a month"
        case .yearly: "$80 a year"
        case .lifetime: "$199 once"
        }
    }
}

private struct FormsOptionCardsDemo: View {
    @State private var kind = CatalogTaskKind.review
    @State private var plan = CatalogPlan.yearly
    @State private var contents: Set<String> = ["Database", "Files"]

    var body: some View {
        DemoBlock(title: "Option cards") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                OptionCardGrid(
                    CatalogTaskKind.allCases,
                    selection: $kind,
                    title: { LocalizedStringKey($0.rawValue) },
                    detail: { $0.detail },
                    icon: { $0.icon },
                    badge: { $0 == .explain ? Badge("Soon") : nil },
                    isOptionEnabled: { $0 != .explain }
                )
                OptionCardGrid(
                    CatalogPlan.allCases,
                    selection: $plan,
                    columns: 3,
                    axis: .vertical,
                    title: { LocalizedStringKey($0.rawValue) },
                    detail: { $0.price },
                    icon: { $0 == .lifetime ? "infinity" : "calendar" },
                    badge: { $0 == .yearly ? Badge("Save 17%").badgeStyle(.success) : nil }
                )
                OptionCardGrid(
                    ["Database", "Files", "Settings"],
                    selection: $contents,
                    columns: 3,
                    title: { LocalizedStringKey($0) },
                    detail: { $0 == "Database" ? "1.2 GB" : ($0 == "Files" ? "18,206 files" : "12 KB") },
                    icon: { $0 == "Database" ? "cylinder" : ($0 == "Files" ? "folder" : "gearshape") }
                )
            }
            .frame(maxWidth: 640)
        }
    }
}

// MARK: - Wizard rows

private struct FormsWizardRowsDemo: View {
    @State private var source = 0
    @State private var stepStates: [WizardStepState] = [.done, .running, .pending, .pending]
    @State private var isRunning = false

    private let steps: [(title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("Download files", "128 files · 4.2 MB"),
        ("Check signatures", "Every file is signed."),
        ("Install", "Copied to Applications."),
        ("Clean up", "Removed the download."),
    ]

    var body: some View {
        DemoBlock(title: "Wizard rows") {
            HStack(alignment: .top, spacing: Spacing.xl) {
                VStack(spacing: Spacing.xxs) {
                    WizardRadioRow("From a template", subtitle: "Start from a ready-made layout", icon: "square.stack.3d.up", isSelected: source == 0) { source = 0 }
                    WizardRadioRow("Import a file", subtitle: "Bring in an existing document", icon: "arrow.down.doc", isSelected: source == 1) { source = 1 }
                    WizardRadioRow("Blank", subtitle: "An empty document", icon: "doc", isSelected: source == 2) { source = 2 }
                }
                .frame(maxWidth: 340)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(steps.indices, id: \.self) { index in
                        let state = stepStates[index]
                        WizardStepRow(
                            steps[index].title,
                            detail: state == .done ? steps[index].detail : (state == .failed ? "The disk is full." : nil),
                            number: index + 1,
                            state: state
                        )
                    }
                    HStack(spacing: Spacing.sm) {
                        Button("Run") { run(failing: false) }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                        Button("Run and Fail") { run(failing: true) }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                    .disabled(isRunning)
                    .padding(.top, Spacing.xs)
                }
                .frame(maxWidth: 300, alignment: .leading)
            }
        }
    }

    /// Walks the steps through running → done, one every 0.8s; `failing`
    /// stops at the third.
    private func run(failing: Bool) {
        isRunning = true
        stepStates = Array(repeating: .pending, count: steps.count)
        Task { @MainActor in
            for index in steps.indices {
                stepStates[index] = .running
                try? await Task.sleep(for: .milliseconds(800))
                if failing && index == 2 {
                    stepStates[index] = .failed
                    break
                }
                stepStates[index] = .done
            }
            isRunning = false
        }
    }
}

// MARK: - Banners

private struct FormsBannersDemo: View {
    @State private var dismissed: Set<BannerStyle> = []

    var body: some View {
        DemoBlock(title: "Banners") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !dismissed.contains(.info) {
                    Banner("A new version is available", message: "Version 2.1 adds the Low Glare theme.", actionTitle: "Update", action: {}, onDismiss: { dismiss(.info) })
                }
                if !dismissed.contains(.success) {
                    Banner("Backup complete", message: "Saved 1.2 GB to the external drive.", style: .success, onDismiss: { dismiss(.success) })
                }
                if !dismissed.contains(.warning) {
                    Banner("This folder no longer exists", message: "~/Projects/site", style: .warning, actionTitle: "Locate…", action: {})
                }
                if !dismissed.contains(.danger) {
                    Banner("Couldn't connect", message: "The server didn't answer. Check your connection and try again.", style: .danger, actionTitle: "Retry", action: {}, onDismiss: { dismiss(.danger) })
                }
                if !dismissed.isEmpty {
                    Button("Show All") { withAnimation(Animations.disclosure) { dismissed = [] } }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    private func dismiss(_ style: BannerStyle) {
        _ = withAnimation(Animations.disclosure) { dismissed.insert(style) }
    }
}

// MARK: - Disclosure

private struct FormsDisclosureDemo: View {
    @State private var isAdvancedOpen = true
    @State private var verbose = true
    @State private var beta = false

    var body: some View {
        DemoBlock(title: "Disclosure sections") {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                DisclosureSection("Advanced", isExpanded: $isAdvancedOpen) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SettingsToggleRow("Verbose logging", detail: "Writes every request to the log.", isOn: $verbose)
                        SettingsToggleRow("Use beta features", isOn: $beta)
                    }
                }
                DisclosureSection("Network") {
                    Text("Requests go through the system proxy. Set one in System Settings → Network.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                DisclosureSection {
                    Text("Keyboard: Space or Return toggles a header, → opens it and ← closes it.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("About this section", systemImage: "keyboard")
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
    }
}

// MARK: - Confirmation

private struct FormsConfirmationDemo: View {
    @State private var isConfirmingDelete = false
    @State private var isConfirmingSignOut = false

    var body: some View {
        DemoBlock(title: "Confirmation sheet") {
            HStack(spacing: Spacing.sm) {
                Button("Delete 3 Items…") { isConfirmingDelete = true }
                    .buttonStyle(DestructiveButtonStyle(compact: true))
                Button("Sign Out…") { isConfirmingSignOut = true }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
            Text("Return confirms, Esc cancels.")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
        .confirmationSheet(
            isPresented: $isConfirmingDelete,
            title: "Delete 3 Items?",
            message: "They're removed from every device. This can't be undone.",
            confirmTitle: "Delete",
            isDestructive: true
        ) {
            ToastService.shared.showSuccess(title: "Deleted", message: "3 items are gone.")
        }
        .confirmationSheet(
            isPresented: $isConfirmingSignOut,
            title: "Sign Out?",
            message: "You'll need your password to sign back in.",
            confirmTitle: "Sign Out"
        ) {
            ToastService.shared.showInfo(title: "Signed out", message: "See you soon.")
        }
        // `-demo confirmation` opens the delete confirmation, for screenshots.
        .onAppear {
            if CatalogDemo.state == "confirmation" { isConfirmingDelete = true }
        }
    }
}

// MARK: - Skeleton

private struct FormsSkeletonDemo: View {
    @State private var isLoading = true
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        DemoBlock(title: "Skeleton loading") {
            HStack(alignment: .top, spacing: Spacing.xl) {
                RoundedSection {
                    ForEach(CatalogPerson.samples) { person in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(Typography.displaySmall)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                                Text(verbatim: person.name).font(Typography.bodySmallSemibold)
                                Text(verbatim: person.role).font(Typography.captionSmall).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Badge(LocalizedStringKey(person.status))
                                .badgeStyle(person.status == "Away" ? .warning : .success)
                                .badgeSize(.small)
                        }
                    }
                }
                .skeleton(isLoading: isLoading)
                .frame(maxWidth: 360)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: Spacing.sm) {
                            SkeletonBlock(.circle, width: 28)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                SkeletonBlock.line(width: 150)
                                SkeletonBlock.line(width: 96, height: 8)
                            }
                            Spacer()
                            SkeletonBlock(.capsule, width: 52, height: 16)
                        }
                    }
                    SkeletonBlock(.rectangle(cornerRadius: Sizing.radiusMedium), height: 56)
                }
                .frame(maxWidth: 300)
                .accessibilityElement()
                .accessibilityLabel(Text("Loading"))
            }
            HStack(spacing: Spacing.sm) {
                Toggle("Loading", isOn: $isLoading).toggleStyle(.flatSwitch(showsLabel: true))
                Button("Reload") { reload() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
        }
    }

    private func reload() {
        reloadTask?.cancel()
        isLoading = true
        reloadTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }
}

private struct CatalogPerson: Identifiable {
    let id: Int
    let name: String
    let role: String
    let status: String

    static let samples = [
        CatalogPerson(id: 1, name: "Ada Lovelace", role: "Analytical Engine", status: "Active"),
        CatalogPerson(id: 2, name: "Grace Hopper", role: "Compilers", status: "Active"),
        CatalogPerson(id: 3, name: "Alan Turing", role: "Computability", status: "Away"),
    ]
}
