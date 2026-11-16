import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the rich text editor, built
/// the way an app would build it.
@MainActor
@Suite struct RichTextAPITests {
    @Test func richTextEditorIsReachable() {
        _ = RichTextEditor("Description", text: .constant(AttributedString()))
        _ = RichTextEditor("Description", text: .constant(AttributedString("Hello")), prompt: Text("Describe the change…"))
        _ = RichTextEditor("Notes", text: .constant(AttributedString("Hello")), minimumHeight: 240, showsToolbar: false)
        let title = "Release notes"
        _ = RichTextEditor("\(title)", text: .constant(AttributedString()))
    }
}
