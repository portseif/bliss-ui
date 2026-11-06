import CoreGraphics
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the number field, slider and
/// text area, built the way an app would build them.
@MainActor
@Suite struct FieldsAPITests {
    @Test func numberFieldTakesIntegersAndDecimals() {
        _ = NumberField("Days to keep", value: .constant(30), in: 1...365)
        _ = NumberField("Days to keep", value: .constant(30), in: 1...365, step: 7, unit: "days")
        _ = NumberField("Port", value: .constant(UInt16(2222)), in: 1...65_535)
        _ = NumberField("Line height", value: .constant(1.5), in: 1...3, step: 0.1)
        _ = NumberField("Opacity", value: .constant(Float(0.8)), in: 0...1, step: 0.05, fractionDigits: 2, unit: "%")
        _ = NumberField("Width", value: .constant(CGFloat(320)), in: 0...2_000, step: 10, unit: "px")
            .controlSize(.small)
    }

    @Test func sliderTakesDecimalsAndIntegers() {
        _ = BlissSlider("Volume", value: .constant(0.5))
        _ = BlissSlider("Volume", value: .constant(0.5), in: 0...1, step: 0.1, showsTicks: true)
        _ = BlissSlider("Zoom", value: .constant(CGFloat(1)), in: 0.5...4, valueLabel: { Text($0, format: .number) })
        _ = BlissSlider("Gain", value: .constant(Float(0)), in: -12...12, step: 1, onEditingChanged: { isEditing in _ = isEditing })
        _ = BlissSlider("Columns", value: .constant(3), in: 1...6)
        _ = BlissSlider("Columns", value: .constant(3), in: 1...6, step: 1, showsTicks: true, valueLabel: { Text($0, format: .number) }, onEditingChanged: { _ in })
    }

    @Test func textAreaIsReachable() {
        _ = TextArea("Notes", text: .constant(""))
        _ = TextArea("Notes", text: .constant(""), prompt: Text("Add a note…"))
        _ = TextArea("Bio", text: .constant("Hello"), lineLimit: 2...5, characterLimit: 160)
        _ = TextArea("Summary", text: .constant(""), showsCharacterCount: true)
        _ = TextArea("Ignore file", text: .constant("/node_modules"), prompt: Text("/dist"), lineLimit: 4...12, monospaced: true)
        let name = "Notes"
        _ = TextArea("\(name)", text: .constant(""))
    }
}
