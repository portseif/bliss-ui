import Foundation
import Testing
@testable import BlissUI

/// The logic under the token field, the suggestion lists and the shortcut
/// recorder: how text becomes tokens, how suggestions rank, how the highlight
/// moves, and how a key press records.
@Suite struct TokensTests {
    // MARK: Token parsing

    @Test func typedCommaCommitsTheTextBeforeIt() throws {
        let commit = try #require(TokenParsing.commit(from: "design", to: "design,"))
        #expect(commit.titles == ["design"])
        #expect(commit.draft == "")
    }

    @Test func typedCommaMidTextKeepsTheRestTyping() throws {
        let commit = try #require(TokenParsing.commit(from: "abcd", to: "ab,cd"))
        #expect(commit.titles == ["ab"])
        #expect(commit.draft == "cd")
    }

    @Test func textWithoutSeparatorsCommitsNothing() {
        #expect(TokenParsing.commit(from: "de", to: "des") == nil)
    }

    @Test func pasteCommitsEveryPiece() throws {
        let commit = try #require(TokenParsing.commit(from: "", to: "alpha, beta\ngamma\r\ndelta"))
        #expect(commit.titles == ["alpha", "beta", "gamma", "delta"])
        #expect(commit.draft == "")
    }

    @Test func pasteDropsEmptyPieces() throws {
        let commit = try #require(TokenParsing.commit(from: "", to: " , a,, \n ,b , "))
        #expect(commit.titles == ["a", "b"])
    }

    @Test func returnCommitsTheWholeDraft() {
        #expect(TokenParsing.titles(in: "  release notes ") == ["release notes"])
        #expect(TokenParsing.titles(in: "a,b") == ["a", "b"])
        #expect(TokenParsing.titles(in: "   ").isEmpty)
    }

    @Test func duplicatesCompareCaseInsensitively() {
        #expect(TokenParsing.indexOfDuplicate("DESIGN", in: ["Docs", "Design"]) == 1)
        #expect(TokenParsing.indexOfDuplicate("Designs", in: ["Design"]) == nil)
    }

    @Test func appendingSkipsDuplicatesAndReportsThem() {
        let result = TokenParsing.appending(["docs", "Bug", "bug", "Research"], to: ["Design", "Docs"], title: { $0 })
        #expect(result.tokens == ["Design", "Docs", "Bug", "Research"])
        // "docs" repeats index 1; the second "bug" repeats the "Bug" just added.
        #expect(result.duplicates == [1, 2])
    }

    // MARK: Suggestion ranking

    @Test func rankingPrefersWholeThenPrefixThenWordThenAnywhere() {
        let candidates = ["Carlow", "Lisbon", "Saint Louis", "Los Angeles", "lo"]
        let ranked = SuggestionRanking.rank(candidates, query: "lo", title: { $0 })
        #expect(ranked == ["lo", "Los Angeles", "Saint Louis", "Carlow"])
    }

    @Test func rankingKeepsGivenOrderOnTies() {
        let ranked = SuggestionRanking.rank(["Berlin", "Bern", "Bergen"], query: "ber", title: { $0 })
        #expect(ranked == ["Berlin", "Bern", "Bergen"])
    }

    @Test func rankingIgnoresCaseAndDiacritics() {
        #expect(SuggestionRanking.rank(["São Paulo", "Sapporo"], query: "SAO", title: { $0 }) == ["São Paulo"])
    }

    @Test func emptyQueryKeepsEveryCandidate() {
        #expect(SuggestionRanking.rank(["b", "a"], query: "  ", title: { $0 }) == ["b", "a"])
    }

    @Test func wordStartsCountAfterPunctuation() {
        #expect(SuggestionRanking.score("front-end", query: "end") == 2)
        #expect(SuggestionRanking.score("weekend", query: "end") == 3)
        #expect(SuggestionRanking.score("weekend", query: "xyz") == nil)
    }

    @Test func matchRangeMarksTheTypedText() throws {
        let title = "Saint Louis"
        let range = try #require(SuggestionRanking.matchRange(in: title, query: "lo"))
        #expect(title[range] == "Lo")
        #expect(SuggestionRanking.matchRange(in: title, query: "") == nil)
    }

    // MARK: Suggestion list

    @MainActor
    @Test func listCapsItsRowsAndCountsTheRest() {
        let list = SuggestionListModel<String>()
        list.update(["a1", "a2", "a3", "a4", "b"], query: "a", limit: 3, highlightsFirstMatch: false, title: { $0 })
        #expect(list.matches == ["a1", "a2", "a3"])
        #expect(list.hiddenCount == 1)
        #expect(list.highlightedIndex == nil)
    }

    @MainActor
    @Test func restrictedListLandsOnTheTopMatchWithoutARing() {
        let list = SuggestionListModel<String>()
        list.update(["Go", "Swift"], query: "sw", limit: 8, highlightsFirstMatch: true, title: { $0 })
        #expect(list.highlightedItem == "Swift")
        #expect(!list.highlightMovedByKeyboard)
    }

    @MainActor
    @Test func keysWrapTheHighlightAndRingIt() {
        let list = SuggestionListModel<String>()
        list.update(["a", "b", "c"], query: "", limit: 8, highlightsFirstMatch: false, title: { $0 })
        list.moveHighlight(by: -1)
        #expect(list.highlightedIndex == 2)
        #expect(list.highlightMovedByKeyboard)
        list.moveHighlight(by: 1)
        #expect(list.highlightedIndex == 0)
        list.highlight(1)
        #expect(!list.highlightMovedByKeyboard)
        list.close()
        #expect(!list.isPresented)
        #expect(list.highlightedIndex == nil)
    }

    // MARK: Shortcut display

    @Test func displayStringsFollowMenuOrder() {
        #expect(KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift]).displayString == "⇧⌘K")
        #expect(KeyboardShortcutValue(.character("s"), modifiers: [.command, .control, .option]).displayString == "⌃⌥⌘S")
        #expect(KeyboardShortcutValue(.function(5), modifiers: []).displayString == "F5")
        #expect(KeyboardShortcutValue(.delete, modifiers: .command).displayString == "⌘⌫")
        #expect(KeyboardShortcutValue(.character(","), modifiers: .command).displayString == "⌘,")
        #expect(KeyboardShortcutValue(.upArrow, modifiers: .option).displayString == "⌥↑")
    }

    @Test func keyCodesMapToSpecialKeys() {
        #expect(KeyboardShortcutValue.key(keyCode: 36, characters: "\r") == .return)
        #expect(KeyboardShortcutValue.key(keyCode: 76, characters: "\u{3}") == .return)
        #expect(KeyboardShortcutValue.key(keyCode: 49, characters: " ") == .space)
        #expect(KeyboardShortcutValue.key(keyCode: 96, characters: "\u{F708}") == .function(5))
        #expect(KeyboardShortcutValue.key(keyCode: 40, characters: "K") == .character("k"))
        // A private-use function-key character the table doesn't name isn't a key.
        #expect(KeyboardShortcutValue.key(keyCode: 114, characters: "\u{F746}") == nil)
        #expect(KeyboardShortcutValue.key(keyCode: 0, characters: nil) == nil)
    }

    // MARK: Recording

    @Test func escapeCancelsAndDeleteClears() {
        #expect(ShortcutRecording.outcome(keyCode: 53, modifiers: [], characters: "\u{1B}") == .cancel)
        #expect(ShortcutRecording.outcome(keyCode: 51, modifiers: [], characters: "\u{7F}") == .clear)
        #expect(ShortcutRecording.outcome(keyCode: 117, modifiers: [], characters: "\u{F728}") == .clear)
        #expect(ShortcutRecording.outcome(keyCode: 48, modifiers: .shift, characters: "\t") == .leave)
    }

    @Test func combosNeedACommandOptionOrControl() {
        let commandK = KeyboardShortcutValue(.character("k"), modifiers: .command)
        #expect(ShortcutRecording.outcome(keyCode: 40, modifiers: .command, characters: "k") == .record(commandK))
        let shiftK = KeyboardShortcutValue(.character("k"), modifiers: .shift)
        #expect(ShortcutRecording.outcome(keyCode: 40, modifiers: .shift, characters: "k") == .reject(shiftK))
        let bareK = KeyboardShortcutValue(.character("k"), modifiers: [])
        #expect(ShortcutRecording.outcome(keyCode: 40, modifiers: [], characters: "k") == .reject(bareK))
        // With a modifier, Esc and Delete are combos like any other.
        let commandDelete = KeyboardShortcutValue(.delete, modifiers: .command)
        #expect(ShortcutRecording.outcome(keyCode: 51, modifiers: .command, characters: "\u{7F}") == .record(commandDelete))
    }

    @Test func functionKeysStandAlone() {
        let f5 = KeyboardShortcutValue(.function(5), modifiers: [])
        #expect(ShortcutRecording.outcome(keyCode: 96, modifiers: [], characters: "\u{F708}") == .record(f5))
    }

    @Test func unreadableKeysAreRejected() {
        #expect(ShortcutRecording.outcome(keyCode: 0, modifiers: .command, characters: nil) == .reject(nil))
    }

    @Test func functionKeysHaveNoSwiftUIShortcut() {
        #expect(KeyboardShortcutValue(.function(2), modifiers: .command).keyboardShortcut == nil)
        #expect(KeyboardShortcutValue(.pageDown, modifiers: .command).keyboardShortcut != nil)
    }
}
