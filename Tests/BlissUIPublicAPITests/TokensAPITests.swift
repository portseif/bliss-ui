import AppKit
import Foundation
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the token field, the combo box
/// and the shortcut recorder, built the way an app would build them.
@MainActor
@Suite struct TokensAPITests {
    private struct Person: Hashable {
        let name: String
    }

    private let team = [Person(name: "Ada"), Person(name: "Grace")]

    /// The shortcut value is plain data, built and compared off the main actor.
    nonisolated private static func makeOffMainActorShortcut() -> KeyboardShortcutValue {
        KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift])
    }

    @Test func tokenFieldsAreReachable() {
        _ = TokenField("Labels", tokens: .constant(["Design"]))
        _ = TokenField("Labels", tokens: .constant([]), suggestions: ["Design", "Docs"], maxSuggestions: 4)
        _ = TokenField("Emails", tokens: .constant(["ada@example.com"]), isValid: { $0.contains("@") })
        _ = TokenField(
            "Assign",
            tokens: .constant([team[0]]),
            suggestions: team,
            title: \.name,
            makeToken: { name in Person(name: name) }
        )
        _ = TokenField(
            "Assign",
            tokens: .constant([Person]()),
            maxSuggestions: 3,
            title: \.name,
            makeToken: { _ in nil },
            isValid: { !$0.name.isEmpty }
        )
    }

    @Test func comboBoxesAreReachable() {
        _ = ComboBox("City", text: .constant(""), suggestions: ["Berlin", "Tokyo"])
        _ = ComboBox("City", text: .constant("Ber"), suggestions: ["Berlin"], maxSuggestions: 5)
        _ = ComboBox("Language", selection: .constant("Swift"), options: ["Go", "Swift"])
        _ = ComboBox("Language", selection: .constant(nil), options: ["Go"], maxSuggestions: 2)
        _ = ComboBox("Assignee", text: .constant(""), options: team, title: \.name)
        _ = ComboBox("Assignee", text: .constant(""), options: team, maxSuggestions: 3, title: \.name, onPick: { _ in })
        _ = ComboBox("Assignee", selection: .constant(team.first), options: team, title: \.name)
        _ = ComboBox("Assignee", selection: .constant(nil), options: team, maxSuggestions: 1, title: \.name)
    }

    @Test func shortcutRecorderIsReachable() {
        _ = ShortcutRecorder(shortcut: .constant(nil))
        _ = ShortcutRecorder(shortcut: .constant(KeyboardShortcutValue(.function(5), modifiers: [])))
    }

    @Test func shortcutValueBuildsOffTheMainActor() {
        let shortcut = Self.makeOffMainActorShortcut()
        #expect(shortcut.displayString == "⇧⌘K")
        #expect(shortcut.key == .character("k"))
        #expect(shortcut.modifiers == [.shift, .command])
    }

    @Test func shortcutValueConvertsToSwiftUI() {
        let shortcut = KeyboardShortcutValue(.character("k"), modifiers: [.command, .option])
        let converted = shortcut.keyboardShortcut
        #expect(converted?.key == KeyEquivalent("k"))
        #expect(converted?.modifiers == [.command, .option])
        #expect(KeyboardShortcutValue(.return, modifiers: .command).keyboardShortcut?.key == .return)
        #expect(KeyboardShortcutValue(.function(3), modifiers: []).keyboardShortcut == nil)
        let modifiers: KeyboardShortcutValue.Modifiers = [.control, .shift]
        #expect(modifiers.eventModifiers == [.control, .shift])
        _ = Button("Run") {}.keyboardShortcut(shortcut.keyboardShortcut)
    }

    @Test func shortcutValueReadsLikeAMenu() {
        let modifiers: KeyboardShortcutValue.Modifiers = [.command, .shift, .option, .control]
        #expect(modifiers.symbols == "⌃⌥⇧⌘")
        #expect(KeyboardShortcutValue.Key.leftArrow.displayName == "←")
        #expect(KeyboardShortcutValue.Key.function(12).displayName == "F12")
        #expect(KeyboardShortcutValue.Key.function(1).isFunctionKey)
        #expect(KeyboardShortcutValue.Key.delete.keyEquivalent == .delete)
        #expect(!KeyboardShortcutValue.Key.space.displayName.isEmpty)
    }

    @Test func shortcutValueRoundTripsThroughCodable() throws {
        let shortcuts = [
            KeyboardShortcutValue(.character(","), modifiers: .command),
            KeyboardShortcutValue(.function(5), modifiers: []),
            KeyboardShortcutValue(.return, modifiers: [.command, .shift]),
        ]
        let data = try JSONEncoder().encode(shortcuts)
        #expect(try JSONDecoder().decode([KeyboardShortcutValue].self, from: data) == shortcuts)
    }

    @Test func shortcutValueReadsAKeyEvent() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ))
        #expect(KeyboardShortcutValue(event: event) == KeyboardShortcutValue(.return, modifiers: [.command, .shift]))
        #expect(KeyboardShortcutValue.Modifiers(flags: [.command, .capsLock, .function]) == .command)
    }
}
