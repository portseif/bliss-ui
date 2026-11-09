import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the settings rows and table of
/// contents, option cards, wizard rows, banners, disclosure sections, the
/// confirmation sheet and skeleton loading, built the way an app would build
/// them. Nothing here presents a sheet.
@MainActor
@Suite struct FormsAPITests {
    private enum Pane: Hashable, CaseIterable {
        case general, appearance
    }

    @Test func settingsRowsAreReachable() {
        _ = SettingsRow("Language") { Text("English") }
        _ = SettingsRow("Updates", detail: "Checked once a day.") {
            Button("Check Now") {}.buttonStyle(SecondaryButtonStyle(compact: true))
        }
        _ = SettingsToggleRow("Launch at login", isOn: .constant(true))
        _ = SettingsToggleRow("Launch at login", detail: "Opens when you log in.", isOn: .constant(false))
        _ = SettingsActionRow("Login Items") {}
        _ = SettingsActionRow("Reset", detail: "Back to the defaults.", systemImage: "arrow.counterclockwise", isDestructive: true) {}
    }

    @Test func tableOfContentsIsReachable() {
        let items = [
            SettingsTableOfContentsItem(Pane.general, title: "General"),
            SettingsTableOfContentsItem(Pane.appearance, title: "Appearance", isEnabled: false),
        ]
        #expect(items[0].id == .general)
        #expect(items[1].isEnabled == false)
        _ = SettingsTableOfContents(items, activeID: Pane.general) { _ in }
        _ = SettingsScrollView(sections: items) {
            Text("General").settingsSection(Pane.general)
            Text("Appearance").settingsSection(Pane.appearance)
        }
        _ = SettingsScrollView(
            sections: items,
            activeSection: .constant(Pane.general),
            scrollTarget: .constant(nil),
            railWidth: 200
        ) {
            Text("Settings")
        } content: {
            Text("General").settingsSection(Pane.general)
        }
    }

    @Test func optionCardsAreReachable() {
        _ = OptionCard("Monthly", isSelected: true) {}
        _ = OptionCard(
            "Yearly",
            detail: "$80 a year",
            icon: "calendar",
            badge: Badge("Save 17%").badgeStyle(.success),
            isSelected: false,
            selection: .multiple,
            axis: .vertical
        ) {}
        let modes: [OptionCardSelection] = [.single, .multiple]
        #expect(modes.count == 2)

        _ = OptionCardGrid(["A", "B"], selection: .constant("A"), title: { LocalizedStringKey($0) })
        _ = OptionCardGrid(
            ["A", "B", "C"],
            selection: .constant("B"),
            columns: 3,
            axis: .vertical,
            title: { LocalizedStringKey($0) },
            detail: { _ in "Detail" },
            icon: { _ in "star" },
            badge: { $0 == "C" ? Badge("Soon") : nil },
            isOptionEnabled: { $0 != "C" }
        )
        _ = OptionCardGrid(["A", "B"], selection: .constant(Set(["A"])), columns: 1, title: { LocalizedStringKey($0) })
        _ = RadioGlyph(isOn: true)
        _ = RadioGlyph(isOn: false, size: 18)
    }

    @Test func wizardRowsAreReachable() {
        _ = WizardRadioRow("Blank", isSelected: true) {}
        _ = WizardRadioRow("From a template", subtitle: "Start from a layout", icon: "square.stack.3d.up", isSelected: false) {}
        let states: [WizardStepState] = [.pending, .current, .running, .done, .failed]
        for state in states {
            _ = WizardStepRow("Install", state: state)
        }
        _ = WizardStepRow("Install", detail: "The disk is full.", number: 3, state: .failed)
    }

    @Test func bannersAreReachable() {
        #expect(BannerStyle.allCases == [.info, .success, .warning, .danger])
        _ = Banner("Saved")
        _ = Banner(
            "This folder no longer exists",
            message: "~/Projects/site",
            style: .warning,
            icon: "folder.badge.questionmark",
            actionTitle: "Locate…",
            action: {},
            onDismiss: {}
        )
    }

    @Test func disclosureSectionsAreReachable() {
        _ = DisclosureSection("Advanced") { Text("Content") }
        _ = DisclosureSection("Advanced", isExpanded: .constant(true)) { Text("Content") }
        _ = DisclosureSection("Advanced", initiallyExpanded: true) { Text("Content") }
        _ = DisclosureSection(isExpanded: .constant(false)) {
            Text("Content")
        } label: {
            Label("Advanced", systemImage: "gearshape")
        }
    }

    @Test func confirmationSheetIsReachable() {
        _ = ConfirmationSheet(title: "Delete?", confirmTitle: "Delete") {}
        _ = ConfirmationSheet(
            title: "Delete 3 Items?",
            message: "This can't be undone.",
            confirmTitle: "Delete",
            isDestructive: true,
            onCancel: {},
            onConfirm: {}
        )
        _ = Text("Page").confirmationSheet(
            isPresented: .constant(false),
            title: "Sign Out?",
            message: "You'll need your password to sign back in.",
            confirmTitle: "Sign Out"
        ) {}
        _ = Text("Page").confirmationSheet(isPresented: .constant(false), title: "Delete?", confirmTitle: "Delete", isDestructive: true) {}
    }

    @Test func skeletonsAreReachable() {
        let shapes: [SkeletonShape] = [.rectangle(cornerRadius: Sizing.radiusMedium), .capsule, .circle]
        #expect(shapes.count == 3)
        _ = SkeletonBlock()
        _ = SkeletonBlock(.circle, width: 32)
        _ = SkeletonBlock(.capsule, width: 56, height: 18)
        _ = SkeletonBlock.line()
        _ = SkeletonBlock.line(width: 120, height: 8)
        _ = Text("Ada Lovelace").skeleton(isLoading: true)
        _ = Text("Ada Lovelace").skeleton(isLoading: false)
    }

    @Test func formFieldsAreReachable() {
        _ = FormField("Name") { TextField("Name", text: .constant("")).textFieldStyle(.largePadded) }
        _ = FormField("Email", hint: "We only use it for receipts.", isRequired: true) {
            TextField("Email", text: .constant("")).textFieldStyle(.compact)
        }
        _ = FormField("Email", hint: "We only use it for receipts.", error: "Enter a full address") {
            TextField("Email", text: .constant("ada@")).textFieldStyle(.largePadded)
        }
        _ = FormField("Port", error: "Out of range") {
            NumberField("Port", value: .constant(70_000), in: 1...65_535)
        }
        var environment = EnvironmentValues()
        #expect(!environment.formFieldIsInvalid)
        environment.formFieldIsInvalid = true
        #expect(environment.formFieldIsInvalid)
    }
}
