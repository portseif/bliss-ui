import AppKit
import Foundation
import SwiftUI
import Testing
@testable import BlissUI

/// The arithmetic and text handling behind `NumberField`, `BlissSlider` and `TextArea`.
@Suite struct FieldsTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    // MARK: Clamping

    @Test func clampsToTheRange() {
        let days = SteppedRange(range: 1...365, step: 1, fractionDigits: 0)
        #expect(days.clamped(0) == 1)
        #expect(days.clamped(500) == 365)
        #expect(days.clamped(30) == 30)
        #expect(days.normalized(-12) == 1)
    }

    @Test func normalizingRoundsToTheKeptPrecision() {
        let opacity = SteppedRange(range: 0...1, step: 0.01)
        #expect(opacity.fractionDigits == 2)
        #expect(opacity.normalized(0.333) == 0.33)
        #expect(opacity.normalized(0.1 + 0.2) == 0.3)
        #expect(opacity.normalized(1.004) == 1)
    }

    // MARK: Stepping

    @Test func stepsMoveOneStepAndStopAtTheBounds() {
        let days = SteppedRange(range: 1...365, step: 1, fractionDigits: 0)
        #expect(days.stepped(30, by: 1) == 31)
        #expect(days.stepped(30, by: -1) == 29)
        #expect(days.stepped(365, by: 1) == 365)
        #expect(days.stepped(1, by: -1) == 1)
    }

    @Test func shiftStepsTen() {
        let days = SteppedRange(range: 1...365, step: 1, fractionDigits: 0)
        #expect(SteppedRange.steps(direction: 1, isLarge: true) == 10)
        #expect(SteppedRange.steps(direction: -1, isLarge: true) == -10)
        #expect(SteppedRange.steps(direction: 1, isLarge: false) == 1)
        #expect(days.stepped(30, by: SteppedRange.steps(direction: 1, isLarge: true)) == 40)
        #expect(days.stepped(5, by: SteppedRange.steps(direction: -1, isLarge: true)) == 1)
        #expect(days.stepped(360, by: SteppedRange.steps(direction: 1, isLarge: true)) == 365)
    }

    @Test func stepsLandOnAGridFromTheLowerBound() {
        let weekly = SteppedRange(range: 1...365, step: 7, fractionDigits: 0)
        #expect(weekly.stepped(1, by: 1) == 8)
        // Clamped past the top, then back onto the grid on the way down.
        #expect(weekly.stepped(362, by: 1) == 365)
        #expect(weekly.stepped(365, by: -1) == 358)
    }

    @Test func offGridValuesSnapInTheStepsDirection() {
        let halves = SteppedRange(range: 0...10, step: 0.5)
        #expect(halves.stepped(2.37, by: 1) == 2.5)
        #expect(halves.stepped(2.37, by: -1) == 2.0)
        #expect(halves.stepped(2.5, by: 1) == 3.0)
        #expect(halves.stepped(2.37, by: 10) == 7.0)
    }

    @Test func decimalStepsDontAccumulateError() {
        let tenths = SteppedRange(range: 0...3, step: 0.1)
        var value = 0.0
        for _ in 0..<3 { value = tenths.stepped(value, by: 1) }
        #expect(value == 0.3)
        #expect(tenths.stepped(1.5, by: -1) == 1.4)
    }

    @Test func canStepIsFalseAtTheEnds() {
        let days = SteppedRange(range: 1...365, step: 1, fractionDigits: 0)
        #expect(!days.canStep(from: 365, by: 1))
        #expect(days.canStep(from: 365, by: -1))
        #expect(!days.canStep(from: 1, by: -1))
    }

    @Test func continuousRangesStepByAPercent() {
        let volume = SteppedRange(range: 0...1, step: 0, fractionDigits: 2)
        #expect(volume.isContinuous)
        #expect(volume.stepped(0.5, by: 1) == 0.51)
        #expect(volume.stepped(0.5, by: -10) == 0.4)
        #expect(volume.snapped(0.456) == 0.46)
    }

    @Test func precisionComesFromTheStepAndLowerBound() {
        #expect(SteppedRange(range: 0...1, step: 0.05).fractionDigits == 2)
        #expect(SteppedRange(range: 0...10, step: 0.5).fractionDigits == 1)
        #expect(SteppedRange(range: 0...10, step: 1).fractionDigits == 0)
        #expect(SteppedRange(range: 0.5...10, step: 1).fractionDigits == 1)
        #expect(SteppedRange(range: 0...1, step: 1.0 / 3).fractionDigits == SteppedRange.maximumFractionDigits)
        #expect(SteppedRange(range: 0...1, step: 0.1, fractionDigits: 3).fractionDigits == 3)
    }

    // MARK: Slider geometry

    @Test func dragsSnapToTheNearestStep() {
        let columns = SteppedRange(range: 1...6, step: 1, fractionDigits: 0)
        #expect(columns.snapped(columns.value(atFraction: 0.45)) == 3)
        #expect(columns.snapped(columns.value(atFraction: -0.2)) == 1)
        #expect(columns.snapped(columns.value(atFraction: 1.4)) == 6)
        #expect(columns.fraction(of: 3.5) == 0.5)
    }

    @Test func ticksOnlyForAReadableNumberOfSteps() {
        let columns = SteppedRange(range: 1...6, step: 1, fractionDigits: 0)
        #expect(columns.tickFractions(limit: 60) == [0, 0.2, 0.4, 0.6, 0.8, 1])
        #expect(SteppedRange(range: 0...1, step: 0.001).tickFractions(limit: 60).isEmpty)
        #expect(SteppedRange(range: 0...1, step: 0).tickFractions(limit: 60).isEmpty)
    }

    // MARK: Typed text

    @Test func parsesTheLocalesNumbers() {
        #expect(NumberFieldText.parse("1.5", locale: english) == 1.5)
        #expect(NumberFieldText.parse("1,5", locale: german) == 1.5)
        #expect(NumberFieldText.parse("-3", locale: english) == -3)
        #expect(NumberFieldText.parse("42", locale: german) == 42)
    }

    @Test func rejectsWhatIsntANumber() {
        #expect(NumberFieldText.parse("", locale: english) == nil)
        #expect(NumberFieldText.parse("-", locale: english) == nil)
        #expect(NumberFieldText.parse(".", locale: english) == nil)
        #expect(NumberFieldText.parse("1.2.3", locale: english) == nil)
        #expect(NumberFieldText.parse("abc", locale: english) == nil)
    }

    @Test func filtersCharactersANumberCantHave() {
        #expect(NumberFieldText.filtered("3x0", allowsFraction: false, allowsNegative: false, locale: english) == "30")
        #expect(NumberFieldText.filtered("-1.5", allowsFraction: false, allowsNegative: false, locale: english) == "15")
        #expect(NumberFieldText.filtered("-1.5", allowsFraction: true, allowsNegative: true, locale: english) == "-1.5")
        #expect(NumberFieldText.filtered("1,5", allowsFraction: true, allowsNegative: false, locale: german) == "1,5")
        #expect(NumberFieldText.filtered("1.5", allowsFraction: true, allowsNegative: false, locale: german) == "15")
    }

    @Test func formatsWithTheLocaleAndNoGrouping() {
        #expect(NumberFieldText.format(1.5, fractionDigits: 2, locale: german) == "1,50")
        #expect(NumberFieldText.format(65_535, fractionDigits: 0, locale: english) == "65535")
        #expect(NumberFieldText.format(-0.0, fractionDigits: 1, locale: english) == "0.0")
    }

    @Test func widthTemplateCoversTheWidestBound() {
        #expect(NumberFieldText.widthTemplate(for: ["1", "365"]) == "000")
        #expect(NumberFieldText.widthTemplate(for: ["-10.5", "3"]) == "-00.0")
        #expect(NumberFieldText.widthTemplate(for: ["1"]) == "00")
    }

    // MARK: Text area

    @MainActor
    @Test func textAreaMeasuresWholeLines() {
        let editor = TextAreaEditor(
            text: .constant(""),
            accessibilityLabel: "Notes",
            fontStyle: .body,
            lineLimit: 2...4,
            characterLimit: nil,
            isEnabled: true,
            focusRequest: 0,
            onFocusChange: { _ in },
            onScroll: { _, _ in }
        )
        let coordinator = TextAreaEditor.Coordinator(parent: editor)
        let font = TextAreaFontStyle.body.nsFont
        let oneLine = coordinator.contentHeight(of: "", width: 300, font: font)
        let threeLines = coordinator.contentHeight(of: "one\ntwo\nthree", width: 300, font: font)
        // An empty text is one line tall; a trailing newline adds its empty line.
        #expect(abs(oneLine - coordinator.height(lines: 1, font: font)) <= 1)
        #expect(abs(threeLines - coordinator.height(lines: 3, font: font)) <= 1)
        #expect(coordinator.contentHeight(of: "one\n", width: 300, font: font) > oneLine)
        // A long line wraps at a narrow width.
        let long = String(repeating: "word ", count: 40)
        #expect(coordinator.contentHeight(of: long, width: 120, font: font) > coordinator.contentHeight(of: long, width: 600, font: font))
    }

    @Test func scrollMetricsOverflowOnlyPastTheViewport() {
        #expect(!TextAreaScrollMetrics(offset: 0, contentHeight: 60, viewportHeight: 60).overflows)
        #expect(TextAreaScrollMetrics(offset: 0, contentHeight: 92, viewportHeight: 60).overflows)
        #expect(!TextAreaScrollMetrics().overflows)
    }
}
