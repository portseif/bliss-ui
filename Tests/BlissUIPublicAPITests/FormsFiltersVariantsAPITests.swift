import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the calendar, filter and form
/// variants added in the consistency pass, built the way an app would build
/// them.
@MainActor
@Suite struct FormsFiltersVariantsAPITests {
    private let day = Date()

    // MARK: Calendar

    @Test func monthCalendarVariantsAreReachable() {
        _ = MonthCalendar(
            selection: .constant(day),
            isDateEnabled: { _ in true },
            displayedMonth: .constant(day),
            showsHeader: false,
            showsOutOfMonthDays: false
        )
        _ = MonthCalendar(selection: .constant(nil as Date?), isDateEnabled: { _ in false }, showsHeader: true)
        _ = MonthCalendar(selection: .constant(day), displayedMonth: .constant(day)) { _ in Text(verbatim: "Detail") }
    }

    @Test func datePickerFieldVariantsAreReachable() {
        _ = DatePickerField("Due", selection: .constant(day), isDateEnabled: { _ in true }, showsTitle: false, dateStyle: .numeric)
        _ = DatePickerField("Ends", selection: .constant(nil as Date?), placeholder: "Never", isDateEnabled: { _ in true }, showsTitle: false, dateStyle: .long)
        _ = DatePickerField("Reminder", selection: .constant(day), showsTime: true)
    }

    @Test func dateRangePickerFieldVariantsAreReachable() {
        let range = day...day
        _ = DateRangePickerField("Period", selection: .constant(range), isDateEnabled: { _ in true }, showsTitle: false, dateStyle: .numeric)
        _ = DateRangePickerField("Trip", selection: .constant(nil as ClosedRange<Date>?), placeholder: "Any", isDateEnabled: { _ in true }, showsTitle: true, dateStyle: .abbreviated)
    }

    @Test func dateRangeCalendarVariantsAreReachable() {
        let range = day...day
        _ = DateRangeCalendar(selection: .constant(range), presets: DateRangePreset.standard, isDateEnabled: { _ in true }, maximumLength: 30, presetPlacement: .above, showsFooter: false)
        _ = DateRangeCalendar(selection: .constant(nil as ClosedRange<Date>?), maximumLength: 7, presetPlacement: .beside, showsFooter: true)
        let placement: DateRangePresetPlacement = .above
        #expect(placement == .above)
    }

    @Test func timeFieldIsReachable() {
        _ = TimeField("Quiet hours start", selection: .constant(nil as Date?))
        _ = TimeField("Daily at", selection: .constant(day), minuteInterval: 15, showsSeconds: true)
    }

    // MARK: Filters

    @Test func filterBarVariantsAreReachable() {
        let fields = [FilterField(id: "status", title: "Status", kind: .options([FilterOption(title: "Open")]))]
        let locked = FilterCondition(fieldID: "status", operator: .is, values: ["Open"], isLocked: true)
        #expect(locked.isLocked)
        #expect(!FilterCondition(field: fields[0]).isLocked)
        _ = FilterBar(
            conditions: .constant([locked]),
            fields: fields,
            matchMode: .constant(.any),
            showsClearButton: false,
            alwaysShowsAddTitle: true
        )
    }

    @Test func filterConditionDecodesWithoutLock() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","fieldID":"status","operator":"is","values":["Open"]}"#
        let condition = try JSONDecoder().decode(FilterCondition.self, from: Data(json.utf8))
        #expect(!condition.isLocked)
        let encoded = try JSONEncoder().encode(FilterCondition(fieldID: "status", operator: .is, isLocked: true))
        let decoded = try JSONDecoder().decode(FilterCondition.self, from: encoded)
        #expect(decoded.isLocked)
    }

    @Test func filterMenuButtonVariantsAreReachable() {
        _ = FilterMenuButton(count: 2, compact: true, showsTitle: false, showsChevron: true) {}
        _ = FilterMenuButton("Display", systemImage: "slider.horizontal.3", isActive: true, compact: false, showsTitle: true, showsChevron: true) {}
    }

    @Test func filterMenuRowsVariantsAreReachable() {
        _ = FilterMenuSectionHeader("Status")
        _ = FilterMenuSectionHeader("Status") { Text(verbatim: "3") }
        _ = FilterCheckRow("Open", detail: "Not yet done", count: 3, isOn: true, isFocused: true, color: Success.success500, systemImage: "circle") {}
        _ = DisplayRadioRow("Title", detail: "A to Z", isOn: true, systemImage: "textformat", keyHint: "⌘1") {}
        _ = FilterMenuRow("Remove filter", isFocused: false, isDestructive: true) {}
        _ = FilterMenuRow("Open", detail: "3 rows", isFocused: true, isSelected: true, action: {}, trailing: { Image(systemName: "checkmark") })
        _ = FilterMenuRow("Open", isFocused: false, action: {}, leading: { Image(systemName: "circle") }, trailing: { Text(verbatim: "3") })
        _ = FilterMenuSearchHeader(query: "do", placeholder: "Status", showsNoMatches: false, resultCount: 2, showsIcon: false)
    }

    // MARK: Forms

    @Test func formFieldVariantsAreReachable() {
        _ = FormField("Name", hint: "Shown on receipts.", showsOptionalMark: true, labelPlacement: .leading, characterCount: (12, 80)) {
            TextField("Name", text: .constant("")).textFieldStyle(.largePadded)
        }
        _ = FormField("Email", error: "Enter an address.", isRequired: true) {
            TextField("Email", text: .constant("")).textFieldStyle(.largePadded)
        } titleAccessory: {
            InfoButton(text: "We only use it for receipts.")
        }
        let placement: FormFieldLabelPlacement = .leading
        #expect(placement == .leading)
    }

    @Test func optionCardVariantsAreReachable() {
        _ = OptionCard("Pro", detail: "Billed yearly", value: "$80 / yr", icon: "star", badge: Badge("Save 20%"), isSelected: true, selection: .single, axis: .vertical, compact: true, showsMark: false, action: {})
        _ = OptionCard("Theme", value: "Free", isSelected: false, action: {}) {
            Circle().fill(Color.accent).frame(width: 20, height: 20)
        }
        _ = OptionCardGrid(["A", "B", "C"], selection: .constant("A"), minimumCardWidth: 160, title: { LocalizedStringKey($0) })
        _ = OptionCardGrid(["A", "B"], selection: .constant(Set(["A"])), columns: 2, minimumCardWidth: nil, title: { LocalizedStringKey($0) })
    }

    @Test func settingsRowVariantsAreReachable() {
        _ = SettingsRow("Port", detail: "1 to 65535", systemImage: "network", badge: Badge("Beta"), error: "Port must be 1 to 65535", alignsControlToTitle: false) {
            NumberField("Port", value: .constant(22), in: 1...65_535)
        }
        _ = SettingsToggleRow("Launch at login", detail: "Opens at login.", systemImage: "power", badge: Badge("Pro"), isOn: .constant(true))
        _ = SettingsActionRow("Language", detail: "Menus and messages.", value: "English", systemImage: "chevron.right", leadingSystemImage: "globe", badge: Badge("Beta"), isDestructive: false, isLoading: true) {}
    }

    @Test func settingsTableOfContentsVariantsAreReachable() {
        let items = [
            SettingsTableOfContentsItem("general", title: "General", systemImage: "gearshape"),
            SettingsTableOfContentsItem("privacy", title: "Privacy", isEnabled: false),
        ]
        #expect(items[0].systemImage == "gearshape")
        _ = SettingsTableOfContents(items, activeID: "general", activeStyle: .bar) { _ in }
        _ = SettingsScrollView(sections: items, railPlacement: .trailing) {
            Text(verbatim: "Form").settingsSection("general")
        }
        _ = SettingsScrollView(sections: items, activeSection: .constant("general"), railWidth: 200, railPlacement: .leading) {
            Text(verbatim: "Header")
        } content: {
            Text(verbatim: "Form")
        }
    }

    @Test func wizardRowVariantsAreReachable() {
        _ = WizardRadioRow("From a template", detail: "Start from a layout", icon: "doc", badge: Badge("Recommended"), isSelected: true, showsBorder: true, compact: true) {}
        _ = WizardRadioRow("Blank", isSelected: false, action: {}) { Text(verbatim: "Free") }
        _ = WizardRadioRow("Import", subtitle: "Bring in a document", icon: "arrow.down.doc", isSelected: false) {}
        _ = WizardStepRow("Download", detail: "128 files", number: 1, state: .running, progress: 0.4, compact: true)
        _ = WizardStepRow("Install", number: 2, state: .failed) {
            Button("Retry") {}.buttonStyle(GhostButtonStyle(compact: true))
        }
    }
}
