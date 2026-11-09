//
//  FormsGallery.swift
//  BlissCatalog
//
//  The "Forms & Feedback" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let forms: [GalleryEntry] = [
        // Settings
        GalleryEntry("settings-rows", height: 312) {
            RoundedSection("General", divided: true) {
                SettingsToggleRow("Launch at login", detail: "Opens in the menu bar when you log in.", isOn: .constant(true))
                SettingsToggleRow("Play sounds", isOn: .constant(false))
                SettingsRow("Language", detail: "Used for menus and messages.") {
                    FloatingMenuPicker("Language", selection: .constant("English"), options: ["English", "Deutsch"], optionTitle: { $0 }, showsTitle: false)
                }
                SettingsActionRow("Login Items", detail: "Choose what opens at login in System Settings.", systemImage: "arrow.up.right") {}
                SettingsActionRow("Reset All Settings…", isDestructive: true) {}
            }
        },
        GalleryEntry("settings-table-of-contents", width: 640, height: 300) {
            GallerySettingsScrollView()
        },
        GalleryEntry("form-field", width: 420, height: 196) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                FormField("Name", hint: "Shown on your receipts.", isRequired: true) {
                    TextField("Name", text: .constant("Ada Lovelace")).textFieldStyle(.largePadded)
                }
                FormField("Email", error: "Enter a full address, like ada@example.com", isRequired: true) {
                    TextField("Email", text: .constant("ada@example")).textFieldStyle(.largePadded)
                }
            }
        },

        // Option cards
        GalleryEntry("option-cards", height: 196) {
            OptionCardGrid(
                ["Review", "Refactor", "Write tests", "Explain"],
                selection: .constant("Review"),
                title: { LocalizedStringKey($0) },
                detail: { GalleryTaskKind.detail(for: $0) },
                icon: { GalleryTaskKind.icon(for: $0) },
                badge: { $0 == "Explain" ? Badge("Soon") : nil },
                isOptionEnabled: { $0 != "Explain" }
            )
        },
        GalleryEntry("option-cards-plans", height: 176) {
            OptionCardGrid(
                ["Monthly", "Yearly", "Lifetime"],
                selection: .constant("Yearly"),
                columns: 3,
                axis: .vertical,
                title: { LocalizedStringKey($0) },
                detail: { GalleryPlan.detail(for: $0) },
                icon: { GalleryPlan.icon(for: $0) },
                badge: { GalleryPlan.badge(for: $0) }
            )
        },
        GalleryEntry("option-cards-multiple", height: 110) {
            OptionCardGrid(
                ["Database", "Files", "Settings"],
                selection: .constant(["Database", "Files"]),
                columns: 3,
                title: { LocalizedStringKey($0) },
                detail: { GalleryBackupContent.detail(for: $0) },
                icon: { GalleryBackupContent.icon(for: $0) }
            )
        },

        // Wizard rows
        GalleryEntry("wizard-radio-rows", width: 440, height: 212) {
            VStack(spacing: Spacing.xxs) {
                WizardRadioRow("From a template", subtitle: "Start from a ready-made layout", icon: "square.stack.3d.up", isSelected: true) {}
                WizardRadioRow("Import a file", subtitle: "Bring in an existing document", icon: "arrow.down.doc", isSelected: false) {}
                WizardRadioRow("Blank", subtitle: "An empty document", icon: "doc", isSelected: false) {}
            }
        },
        GalleryEntry("wizard-step-rows", width: 400, height: 226) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                WizardStepRow("Download files", detail: "128 files · 4.2 MB", number: 1, state: .done)
                WizardStepRow("Check signatures", number: 2, state: .running)
                WizardStepRow("Install", detail: "The disk is full.", number: 3, state: .failed)
                WizardStepRow("Choose a location", number: 4, state: .current)
                WizardStepRow("Finish", number: 5, state: .pending)
            }
        },

        // Feedback
        GalleryEntry("banners", height: 284) {
            VStack(spacing: Spacing.sm) {
                Banner("A new version is available", message: "Version 2.1 adds the Low Glare theme.", actionTitle: "Update", action: {}, onDismiss: {})
                Banner("Backup complete", message: "Saved 1.2 GB to the external drive.", style: .success, onDismiss: {})
                Banner("This folder no longer exists", message: "~/Projects/site", style: .warning, actionTitle: "Locate…", action: {})
                Banner("Couldn't connect", message: "The server didn't answer.", style: .danger, actionTitle: "Retry", action: {})
            }
        },
        GalleryEntry("disclosure-section", height: 178) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                DisclosureSection("Advanced", initiallyExpanded: true) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SettingsToggleRow("Verbose logging", detail: "Writes every request to the log.", isOn: .constant(true))
                        SettingsToggleRow("Use beta features", isOn: .constant(false))
                    }
                }
                DisclosureSection("Network") { EmptyView() }
            }
        },
        GalleryEntry("confirmation-sheet", width: 448, height: 172) {
            GalleryConfirmationCard()
        },
        GalleryEntry("skeleton", height: 212) {
            GallerySkeleton()
        },
    ]
}

// MARK: - Composite samples

private enum GalleryTaskKind {
    static func detail(for kind: String) -> LocalizedStringKey {
        switch kind {
        case "Review": "Reads the code and reports what it finds."
        case "Refactor": "Tidies the code without changing what it does."
        case "Write tests": "Adds tests for what isn't covered yet."
        default: "Walks through how a part of the code works."
        }
    }

    static func icon(for kind: String) -> String {
        switch kind {
        case "Review": "doc.text.magnifyingglass"
        case "Refactor": "wand.and.rays"
        case "Write tests": "checkmark.seal"
        default: "text.bubble"
        }
    }
}

// Typed lookups rather than nested ternaries in the closures: Swift 6.3 gives
// up type-checking those ("unable to type-check this expression in
// reasonable time") even though 6.4 manages.
private enum GalleryPlan {
    static func detail(for plan: String) -> LocalizedStringKey {
        switch plan {
        case "Monthly": "$8 a month"
        case "Yearly": "$80 a year"
        default: "$199 once"
        }
    }

    static func icon(for plan: String) -> String {
        plan == "Lifetime" ? "infinity" : "calendar"
    }

    static func badge(for plan: String) -> Badge? {
        plan == "Yearly" ? Badge("Save 17%").badgeStyle(.success) : nil
    }
}

private enum GalleryBackupContent {
    static func detail(for content: String) -> LocalizedStringKey {
        switch content {
        case "Database": "1.2 GB"
        case "Files": "18,206 files"
        default: "12 KB"
        }
    }

    static func icon(for content: String) -> String {
        switch content {
        case "Database": "cylinder"
        case "Files": "folder"
        default: "gearshape"
        }
    }
}

private struct GallerySettingsScrollView: View {
    private let panes = ["General", "Appearance", "Notifications", "Privacy"]

    var body: some View {
        SettingsScrollView(sections: panes.map { SettingsTableOfContentsItem($0, title: LocalizedStringKey($0), isEnabled: $0 != "Privacy") }) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(panes, id: \.self) { pane in
                    RoundedSection(LocalizedStringKey(pane), divided: true) {
                        SettingsToggleRow("Show in menu bar", detail: "Keeps the app a click away.", isOn: .constant(true))
                        SettingsToggleRow("Play sounds", isOn: .constant(false))
                    }
                    .settingsSection(pane)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

/// The confirmation's card, drawn inline: the real one is presented over a
/// window by `.confirmationSheet`, so the index shows it on the same surface.
private struct GalleryConfirmationCard: View {
    var body: some View {
        ConfirmationSheet(
            title: "Delete 3 Items?",
            message: "They're removed from every device. This can't be undone.",
            confirmTitle: "Delete",
            isDestructive: true,
            onConfirm: {}
        )
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.windowBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

private struct GallerySkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            RoundedSection {
                ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing"], id: \.self) { name in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(Typography.displaySmall)
                        VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                            Text(verbatim: name).font(Typography.bodySmallSemibold)
                            Text(verbatim: "Engineering").font(Typography.captionSmall).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .skeleton(isLoading: true)

            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: Spacing.sm) {
                        SkeletonBlock(.circle, width: 28)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            SkeletonBlock.line(width: 120)
                            SkeletonBlock.line(width: 80, height: 8)
                        }
                        Spacer()
                        SkeletonBlock(.capsule, width: 44, height: 16)
                    }
                }
                SkeletonBlock(.rectangle(cornerRadius: Sizing.radiusMedium), height: 40)
            }
        }
    }
}
