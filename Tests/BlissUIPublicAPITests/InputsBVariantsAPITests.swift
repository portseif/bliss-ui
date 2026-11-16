import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the variant parameters the
/// consistency pass added to the composer, the pick-many picker, the rich
/// text editor, the secret field, the segmented pills, the shortcut recorder,
/// the text area and the token field.
@MainActor
@Suite struct InputsBVariantsAPITests {
    @Test func messageComposerVariantsAreReachable() {
        _ = MessageComposer("Comment", text: .constant(""), characterLimit: 280, monospaced: true, sendsOnReturn: false, onSend: {})
        _ = MessageComposer("Comment", text: .constant(""), sendsOnReturn: false, onSend: {}) {
            Button {} label: { Image(systemName: "face.smiling") }
                .buttonStyle(ToolbarIconButtonStyle())
        }
    }

    @Test func multiSelectPickerVariantsAreReachable() {
        _ = MultiSelectPicker("Labels", selection: .constant(Set(["Bug"])), options: ["Bug", "Docs"], optionTitle: { $0 }, summary: .count, showsSelectAll: true)
        _ = MultiSelectPicker("Labels", selection: .constant(Set<String>()), options: ["Bug", "Docs"], optionTitle: { $0 }, summary: .titles)
        let summaries: [MultiSelectSummary] = [.chips, .count, .titles]
        #expect(summaries.count == 3)
    }

    @Test func richTextEditorVariantsAreReachable() {
        _ = RichTextEditor("Comment", text: .constant(AttributedString()), minimumHeight: 60, maximumHeight: 240, tools: [.inlineStyles, .link])
        _ = RichTextEditor("Notes", text: .constant(AttributedString()), tools: .all)
        #expect(RichTextTools.all.contains(.quote))
        #expect(!RichTextTools.inlineStyles.contains(.headings))
    }

    @Test func secretFieldVariantsAreReachable() {
        _ = SecretField("Confirm password", text: .constant(""), isCopyable: false, isRevealable: false, monospaced: false)
        _ = SecretField("API key", text: .constant("sk-1"), isRevealable: true)
    }

    @Test func segmentedPillsVariantsAreReachable() {
        _ = SegmentedPills(options: ["List", "Grid"], selection: .constant("List"), style: .compact, labelStyle: .iconOnly, title: { $0 }, icon: { _ in "list.bullet" })
        _ = SegmentedPills(options: ["Day", "Week"], selection: .constant("Day"), fillsWidth: false, title: { $0 })
        let styles: [SegmentedPillsLabelStyle] = [.titleAndIcon, .iconOnly]
        #expect(styles.count == 2)
    }

    @Test func shortcutRecorderVariantsAreReachable() {
        _ = ShortcutRecorder(shortcut: .constant(nil), placeholder: "None")
        _ = ShortcutRecorder(shortcut: .constant(KeyboardShortcutValue(.character("k"), modifiers: [.command])), isClearable: false)
    }

    @Test func textAreaVariantsAreReachable() {
        _ = TextArea("Notes", text: .constant(""), isBordered: false)
        _ = TextArea("Notes", text: .constant(""), onCommandReturn: {})
    }

    @Test func tokenFieldVariantsAreReachable() {
        _ = TokenField("Tags", tokens: .constant(["a"]), suggestions: ["a", "b"], maximumTokens: 5, allowsCustomTokens: false, tokenIcon: { _ in "tag" })
        _ = TokenField("People", tokens: .constant([1, 2]), suggestions: [3], maximumTokens: 1, title: { "#\($0)" }, tokenIcon: { _ in nil }, makeToken: { Int($0) })
    }
}
