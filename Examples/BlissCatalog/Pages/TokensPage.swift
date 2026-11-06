//
//  TokensPage.swift
//  BlissCatalog
//
//  The "Tokens & Autocomplete" page: tag inputs, combo boxes (free text and
//  restricted, over strings and over a model type), and shortcut recorders
//  whose shortcuts drive a real button.
//

import BlissUI
import SwiftUI

struct TokensPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Token field") {
                TokenFieldDemo()
            }
            DemoBlock(title: "Combo box") {
                ComboBoxDemo()
            }
            DemoBlock(title: "Shortcut recorder") {
                ShortcutRecorderDemo()
            }
        }
    }
}

// MARK: - Sample data

/// A teammate, to show the components over an app's own type.
private struct TokensDemoPerson: Hashable {
    let name: String
    let role: String

    static let team = [
        TokensDemoPerson(name: "Ada Lovelace", role: "Engineer"),
        TokensDemoPerson(name: "Alan Turing", role: "Research"),
        TokensDemoPerson(name: "Grace Hopper", role: "Lead"),
        TokensDemoPerson(name: "Katherine Johnson", role: "Analyst"),
        TokensDemoPerson(name: "Margaret Hamilton", role: "Engineer"),
    ]

    /// The teammate with this name, any case; nil for anyone else.
    static func named(_ name: String) -> TokensDemoPerson? {
        team.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
    }
}

private let labelSuggestions = ["Bug", "Design", "Docs", "Engineering", "Feature", "Marketing", "Research", "Support"]

/// A rough email check, enough to show an invalid token.
private func looksLikeEmail(_ text: String) -> Bool {
    let parts = text.split(separator: "@")
    return parts.count == 2 && parts[1].contains(".") && !parts[0].isEmpty
}

private struct DemoCaption: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Token field

private struct TokenFieldDemo: View {
    @State private var labels = ["Design", "Engineering"]
    @State private var emails = ["ada@example.com", "grace@"]
    @State private var assignees = [TokensDemoPerson.team[2]]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TokenField("Add a label", tokens: $labels, suggestions: labelSuggestions)
            DemoCaption(text: "Return or a comma adds a label, and a pasted list adds them all. Backspace in the empty field selects the last label and removes it on the second press; ← → move between labels. ↓ shows the suggestions.")

            TokenField("Invite by email", tokens: $emails, isValid: looksLikeEmail)
            DemoCaption(text: "An address that doesn't look valid stays, tinted as an error.")

            TokenField(
                "Assign teammates",
                tokens: $assignees,
                suggestions: TokensDemoPerson.team,
                title: \.name,
                makeToken: TokensDemoPerson.named
            )
            DemoCaption(text: "Over a model type: only teammates are taken. Assigned: \(assignees.map(\.name).joined(separator: ", "))")
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}

// MARK: - Combo box

private struct ComboBoxDemo: View {
    @State private var city = ""
    @State private var assignee: TokensDemoPerson? = TokensDemoPerson.team[0]
    @State private var timeZone: String? = TimeZone.current.identifier

    private let cities = [
        "Amsterdam", "Berlin", "Buenos Aires", "Cape Town", "Lisbon", "London", "Los Angeles",
        "Mexico City", "New York", "Paris", "San Francisco", "São Paulo", "Seoul", "Tokyo",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ComboBox("City", text: $city, suggestions: cities)
            DemoCaption(text: "Free text: suggestions rank as you type (\"sa\" puts San Francisco and São Paulo first). ↑ ↓ or Tab move, Return picks, Esc closes the list and then clears. City: \(city.isEmpty ? "none" : city)")

            ComboBox("Assignee", selection: $assignee, options: TokensDemoPerson.team, title: \.name)
            DemoCaption(text: "Restricted to the team: Return takes the top match, and text that matches no one goes back on leaving. Assignee: \(assignee?.name ?? "none")")

            ComboBox("Time zone", selection: $timeZone, options: TimeZone.knownTimeZoneIdentifiers)
            DemoCaption(text: "Hundreds of options: the list shows the best eight and counts the rest.")
        }
        .frame(maxWidth: 360, alignment: .leading)
    }
}

// MARK: - Shortcut recorder

private struct ShortcutRecorderDemo: View {
    @State private var quickSearch: KeyboardShortcutValue? = KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift])
    @State private var toggleSidebar: KeyboardShortcutValue? = KeyboardShortcutValue(.character("s"), modifiers: [.control, .command])
    @State private var newNote: KeyboardShortcutValue?
    @State private var searchRuns = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(spacing: Spacing.sm) {
                recorderRow("Quick search", shortcut: $quickSearch)
                recorderRow("Toggle sidebar", shortcut: $toggleSidebar)
                recorderRow("New note", shortcut: $newNote)
            }

            HStack(spacing: Spacing.sm) {
                Button("Quick Search") { searchRuns += 1 }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    .keyboardShortcut(quickSearch?.keyboardShortcut)
                Text("Ran \(searchRuns) times — press \(quickSearch?.displayString ?? "its shortcut")")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            DemoCaption(text: "Click a recorder (or Space) and press a combo with ⌘, ⌥ or ⌃ — function keys need none. Esc cancels, Delete clears. The button above takes the Quick search shortcut through `keyboardShortcut`.")
        }
        .frame(maxWidth: 480, alignment: .leading)
    }

    private func recorderRow(_ title: LocalizedStringKey, shortcut: Binding<KeyboardShortcutValue?>) -> some View {
        HStack {
            Text(title)
                .font(Typography.bodySmall)
            Spacer()
            ShortcutRecorder(shortcut: shortcut)
        }
    }
}
