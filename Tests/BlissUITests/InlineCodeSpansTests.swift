import Foundation
import SwiftUI
import Testing
@testable import BlissUI

/// `LocalizedStringKey.verbatimWithCode(_:)`'s parsing: backticked spans
/// become code, everything else stays literal.
@Suite struct InlineCodeSpansTests {
    private func codeRuns(_ text: String) -> [String] {
        let attributed = AttributedString.inlineCodeSpans(in: text)
        return attributed.runs.compactMap { run in
            run.inlinePresentationIntent == .code ? String(attributed[run.range].characters) : nil
        }
    }

    @Test func backtickedSpansBecomeCodeWithoutTheBackticks() {
        let text = "Runs `skills remove` and `npx skills update`."
        #expect(codeRuns(text) == ["skills remove", "npx skills update"])
        #expect(String(AttributedString.inlineCodeSpans(in: text).characters) == "Runs skills remove and npx skills update.")
    }

    @Test func otherMarkdownStaysLiteral() {
        let text = "my_skill and *stars*"
        #expect(codeRuns(text).isEmpty)
        #expect(String(AttributedString.inlineCodeSpans(in: text).characters) == text)
    }

    @Test func anUnpairedBacktickStays() {
        let text = "a ` lone backtick"
        #expect(codeRuns(text).isEmpty)
        #expect(String(AttributedString.inlineCodeSpans(in: text).characters) == text)
    }
}
