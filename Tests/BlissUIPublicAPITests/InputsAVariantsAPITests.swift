import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the variant parameters the
/// consistency pass added to the inputs, built the way an app would build them.
@MainActor
@Suite struct InputsAVariantsAPITests {
    @Test func sliderVariantsAreReachable() {
        let ramp = LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
        _ = BlissSlider("Volume", value: .constant(0.5), color: Success.success500)
        _ = BlissSlider("Lightness", value: .constant(0.5), trackGradient: ramp)
        _ = BlissSlider("Volume", value: .constant(0.5), minimumValueLabel: Text("0%"), maximumValueLabel: Text("100%"))
        _ = BlissSlider("Columns", value: .constant(3), in: 1...6, color: Color.accent, trackGradient: ramp, minimumValueLabel: Text("1"), maximumValueLabel: Text("6")) { Text($0, format: .number) }
    }

    @Test func browseInputIsClearable() {
        _ = BrowseInput(path: .constant("/tmp"), isClearable: true)
        _ = BrowseInput(path: .constant(""), placeholder: "Pick a file", icon: "doc", isClearable: true, canChooseFiles: true, canChooseDirectories: false)
    }

    @Test func glyphVariantsAreReachable() {
        _ = CheckboxGlyph(isOn: false, isMixed: true)
        _ = CheckboxGlyph(isOn: true, color: Danger.danger500)
        _ = CheckboxGlyph(isOn: true, size: Sizing.iconDefault)
        _ = RadioGlyph(isOn: true, tint: Warning.warning500)
        _ = RadioGlyph(isOn: false, size: Sizing.iconDefault)
    }

    @Test func comboBoxVariantsAreReachable() {
        _ = ComboBox("City", text: .constant(""), suggestions: ["Berlin"], systemImage: "mappin", isClearable: true)
        _ = ComboBox("Language", selection: .constant(nil), options: ["Swift"], systemImage: "chevron.left.slash.chevron.right", isClearable: true)
        _ = ComboBox("City", text: .constant(""), options: [1, 2], systemImage: "number", isClearable: true, title: { "\($0)" }, optionIcon: { _ in "circle" }, onPick: { _ in })
        _ = ComboBox("Pick", selection: .constant(Optional<Int>.none), options: [1, 2], isClearable: true, title: { "\($0)" }, optionIcon: { _ in "circle" })
    }

    @Test func colorPickerVariantsAreReachable() {
        _ = ColorPickerButton(red: .constant(0.2), green: .constant(0.4), blue: .constant(0.6), compact: true)
        _ = ColorPickerButton(red: .constant(0.2), green: .constant(0.4), blue: .constant(0.6), label: .hexChip, compact: true)
        _ = ColorPickerPopover(red: .constant(0.2), green: .constant(0.4), blue: .constant(0.6), showsPresets: false, onApply: {}, onUseDefault: {}, onCancel: {})
    }

    @Test func dropZoneVariantsAreReachable() {
        _ = DropZone("Attach files", hint: "Up to 25 MB", compact: true) { _ in }
        _ = DropZone("Importing", isLoading: true) { _ in }
        _ = DropZone("Drop", compact: true, isLoading: true) { _ in }
    }

    @Test func floatingMenuPickerVariantsAreReachable() {
        _ = FloatingMenuPicker("Sort", selection: .constant(""), options: ["Name"], optionTitle: { $0 }, compact: true, showsBorder: false, placeholder: "Sort by", iconOnly: true)
        _ = FloatingMenuPicker("View", selection: .constant("Grid"), options: ["Grid"], optionTitle: { $0 }, optionIconView: { _, size in Image(systemName: "square.grid.2x2").frame(width: size) }, compact: true, showsBorder: false, placeholder: "View", iconOnly: true)
    }

    @Test func iconPickerVariantsAreReachable() {
        _ = IconPickerButton(selectedIcon: .constant("star"), compact: true)
        _ = IconPickerButton(selectedIcon: .constant("star"), red: .constant(0), green: .constant(0), blue: .constant(0), compact: true)
        _ = GroupIconPicker(selectedIcon: .constant("star"), showsSearch: false)
        _ = IconGlyph(name: "folder", size: Sizing.iconSmall)
    }

    @Test func inputFieldVariantsAreReachable() {
        _ = InputField("Endpoint", text: .constant("https://example.com"), isReadOnly: true)
        _ = InputField("Domain", text: .constant("bliss"), isReadOnly: true) {
            Text(".dev")
        }
        _ = InputField("Site", text: .constant("bliss")) {
            Text("https://")
        } trailing: {
            Text(".dev")
        }
    }

    @Test func numberFieldVariantsAreReachable() {
        _ = NumberField("Port", value: .constant(8080), in: 1...65_535, showsSteppers: false, fillsWidth: true)
        _ = NumberField("Price", value: .constant(12), in: 0...999, unit: "$", unitPlacement: .leading)
        _ = NumberField("Opacity", value: .constant(0.5), in: 0...1, step: 0.05, unit: "%", unitPlacement: .trailing, showsSteppers: false, fillsWidth: true)
    }

    @Test func oneTimeCodeVariantsAreReachable() {
        _ = OneTimeCodeField("PIN", code: .constant(""), length: 4, groupSize: nil, compact: true, isSecure: true)
        _ = OneTimeCodeField(code: .constant("12"), compact: true)
    }

    @Test func ratingVariantsAreReachable() {
        _ = Rating("Average", value: .constant(4), isReadOnly: true, valueLabel: Text("4.2"))
        _ = Rating("Small", value: .constant(2), size: .small)
        _ = Rating("Large", value: .constant(5), size: .large)
        let sizes: [RatingSize] = [.small, .regular, .large]
        #expect(sizes.count == 3)
    }
}
