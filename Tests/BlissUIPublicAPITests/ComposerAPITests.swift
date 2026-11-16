import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the message composer and its
/// attachments, built the way an app would build them.
@MainActor
@Suite struct ComposerAPITests {
    @Test func composerIsReachable() {
        _ = MessageComposer("Message", text: .constant(""), onSend: {})
        _ = MessageComposer("Message", text: .constant("Hello"), prompt: Text("Message the team…"), lineLimit: 2...8, isSending: true, onSend: {}, onAttach: {})
        _ = MessageComposer("Message", text: .constant("Hello"), attachments: .constant([ComposerAttachment(name: "Notes.md")]), onSend: {}, onAttach: {}) {
            Button("Emoji") {}
        }
        let name = "Reply"
        _ = MessageComposer("\(name)", text: .constant(""), onSend: {})
    }

    @Test func attachmentsKeepTheirValues() {
        let attachment = ComposerAttachment(name: "Onboarding.png", systemImage: "photo")
        #expect(attachment.name == "Onboarding.png")
        #expect(attachment.systemImage == "photo")
        #expect(ComposerAttachment(name: "Notes.md").systemImage == "doc")
        let fixedID = UUID()
        #expect(ComposerAttachment(id: fixedID, name: "A").id == fixedID)
        #expect(ComposerAttachment(id: fixedID, name: "A") == ComposerAttachment(id: fixedID, name: "A"))
    }
}
