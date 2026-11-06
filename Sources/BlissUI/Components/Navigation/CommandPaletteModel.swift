//
//  CommandPaletteModel.swift
//  BlissUI
//
//  What a `CommandPalette` lists and how it searches: the app's commands in
//  sections, the matcher that ranks them against the query, the scope prefixes
//  (`>` for commands, `@` for people…) and the recent picks.
//
//  Plain data and pure functions, plus a small `UserDefaults`-backed recents
//  store, so the ranking, the keyboard moves and the recents are tested
//  without a window.
//

import SwiftUI

// MARK: - Commands

/// One row in a `CommandPalette`: what it shows, what it's found by, and what
/// it runs.
///
/// `title`, `subtitle`, `tag` and `keywords` are shown as they are and searched
/// as typed, so pass them already localized (`String(localized: "New Project")`)
/// — the palette matches what the user reads.
public struct CommandPaletteCommand: Identifiable {
    /// Stable across launches: recents are stored by it.
    public let id: String
    public var title: String
    public var subtitle: String?
    /// An SF Symbol, a template asset from the app's catalog (`icon-` prefix), or
    /// `IconItem.statusDotName` for a colored dot (a run state, a label color).
    public var icon: String?
    /// The icon's color; the secondary tone when nil.
    public var iconColor: Color?
    /// The key shortcut that does the same thing ("⌘N"), shown on the row so the
    /// palette teaches it. Display only — bind the key in your app's menus.
    public var shortcut: String?
    /// Small trailing type tag ("Go", "Open") for a row without a shortcut.
    public var tag: String?
    /// Other words it's found by ("create", "add" for New Project).
    public var keywords: [String]
    /// Running it puts it under Recent. Off for rows that shouldn't come back
    /// (an upgrade prompt, a one-off).
    public var recordsRecent: Bool
    public let action: () -> Void

    /// - Parameters:
    ///   - id: Stable across launches; recents are stored by it.
    ///   - title: Shown and searched as is.
    ///   - subtitle: A second line (a path, the project it acts on), also searched.
    ///   - icon: SF Symbol, `icon-` asset, or `IconItem.statusDotName`.
    ///   - iconColor: The icon's color; secondary when nil.
    ///   - shortcut: The key that does the same thing ("⌘N"), display only.
    ///   - tag: Trailing type tag ("Go", "Open") for a row without a shortcut.
    ///   - keywords: Other words it's found by.
    ///   - recordsRecent: Running it lists it under Recent.
    ///   - action: What it does. The palette closes first.
    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        shortcut: String? = nil,
        tag: String? = nil,
        keywords: [String] = [],
        recordsRecent: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.shortcut = shortcut
        self.tag = tag
        self.keywords = keywords
        self.recordsRecent = recordsRecent
        self.action = action
    }
}

/// A titled group of commands. Sections keep the order you give them; within
/// one, the best matches come first.
public struct CommandPaletteSection {
    /// Shown as is over the section's rows, and in the scope legend. Empty hides
    /// the header.
    public var title: String
    public var commands: [CommandPaletteCommand]
    /// Typed first ("@", "#", ">"), it narrows the palette to the sections with
    /// this prefix; the legend at the bottom lists each one and lights the active
    /// prefix. nil for a section that's only searched.
    public var prefix: String?
    /// Listed before anything is typed. Off for a long list (every project) that
    /// should only come up when searched or scoped to.
    public var showsWithoutQuery: Bool
    /// The most matches it shows while searching; nil for all of them. A prefix
    /// scope shows every row.
    public var maxResults: Int?

    /// - Parameters:
    ///   - title: Shown as is over the rows and in the scope legend; empty hides it.
    ///   - prefix: Typed first, narrows the palette to this section.
    ///   - showsWithoutQuery: Listed before anything is typed.
    ///   - maxResults: The most matches shown while searching; nil for all.
    ///   - commands: The rows, in their resting order.
    public init(
        _ title: String,
        prefix: String? = nil,
        showsWithoutQuery: Bool = true,
        maxResults: Int? = nil,
        commands: [CommandPaletteCommand]
    ) {
        self.title = title
        self.commands = commands
        self.prefix = prefix
        self.showsWithoutQuery = showsWithoutQuery
        self.maxResults = maxResults
    }
}

// MARK: - Results

/// One section as listed for the current query: its header and the rows that
/// matched, ranked.
struct CommandPaletteResultSection: Identifiable {
    let id: String
    let title: String
    let commands: [CommandPaletteCommand]
}

/// A row of the flattened list the palette renders: a section header, or a
/// command with its position among the commands (the keyboard's index).
enum CommandPaletteDisplayRow: Identifiable {
    case header(id: String, title: String)
    case command(CommandPaletteCommand, index: Int)

    var id: String {
        switch self {
        case .header(let id, _): return "header-\(id)"
        case .command(let command, _): return "command-\(command.id)"
        }
    }
}

// MARK: - Search

/// The palette's search: scope prefixes, matching and ranking, and the keyboard's
/// selection moves.
enum CommandPaletteSearch {
    /// The scope a query's leading prefix selects, and the query without it.
    struct Scope: Equatable {
        /// The prefix typed first, or nil when the query searches everything.
        let prefix: String?
        /// The query with the prefix stripped, trimmed.
        let query: String
    }

    /// Reads the query's leading prefix, when one of the sections declares it.
    static func scope(of query: String, prefixes: [String]) -> Scope {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        // The longest first, so "@@" can't be read as "@".
        for prefix in prefixes.sorted(by: { $0.count > $1.count }) where !prefix.isEmpty && trimmed.hasPrefix(prefix) {
            let rest = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return Scope(prefix: prefix, query: rest)
        }
        return Scope(prefix: nil, query: trimmed)
    }

    /// The sections to list for `query`.
    ///
    /// - Nothing typed: Recent (the recent IDs that still resolve), then every
    ///   section that `showsWithoutQuery`, without the rows already under Recent.
    /// - A prefix: only the sections with that prefix, every row ranked against
    ///   the rest of the query (all of them when it's empty).
    /// - Otherwise: each section's matches, best first, capped at `maxResults`.
    ///
    /// A command ID listed twice is shown once (its first place), since rows are
    /// identified by it.
    static func results(
        for query: String,
        in sections: [CommandPaletteSection],
        recentIDs: [String],
        recentTitle: String
    ) -> [CommandPaletteResultSection] {
        let prefixes = sections.compactMap(\.prefix)
        let scope = scope(of: query, prefixes: prefixes)
        var listedIDs = Set<String>()
        var results: [CommandPaletteResultSection] = []

        func append(id: String, title: String, commands: [CommandPaletteCommand]) {
            let unlisted = commands.filter { listedIDs.insert($0.id).inserted }
            if !unlisted.isEmpty {
                results.append(CommandPaletteResultSection(id: id, title: title, commands: unlisted))
            }
        }

        if let prefix = scope.prefix {
            for (offset, section) in sections.enumerated() where section.prefix == prefix {
                append(id: "\(offset)", title: section.title, commands: ranked(section.commands, query: scope.query))
            }
            return results
        }

        if scope.query.isEmpty {
            let everyCommand = sections.flatMap(\.commands)
            let recents = recentIDs.compactMap { id in everyCommand.first { $0.id == id && $0.recordsRecent } }
            append(id: "recent", title: recentTitle, commands: recents)
            for (offset, section) in sections.enumerated() where section.showsWithoutQuery {
                append(id: "\(offset)", title: section.title, commands: section.commands)
            }
            return results
        }

        for (offset, section) in sections.enumerated() {
            let matches = ranked(section.commands, query: scope.query)
            append(id: "\(offset)", title: section.title, commands: section.maxResults.map { Array(matches.prefix($0)) } ?? matches)
        }
        return results
    }

    /// The commands that match `query`, best first; ties keep their order. An
    /// empty query matches everything, in order.
    static func ranked(_ commands: [CommandPaletteCommand], query: String) -> [CommandPaletteCommand] {
        guard !query.isEmpty else { return commands }
        return commands.enumerated()
            .compactMap { offset, command in
                score(command, query: query).map { (command: command, score: $0, offset: offset) }
            }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .map(\.command)
    }

    /// How well `command` matches `query`, higher is better; nil when it doesn't.
    ///
    /// The whole query against the title ranks first — equal, then a prefix, then
    /// the start of a later word, then anywhere in it. Past that every word of the
    /// query has to match somewhere (the title, a keyword, the subtitle, or the
    /// title's letters in order: "nwprj" finds "New project"), and the command
    /// scores the average of its words.
    static func score(_ command: CommandPaletteCommand, query: String) -> Int? {
        let words = normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return 0 }
        let whole = words.joined(separator: " ")
        let title = normalized(command.title)

        if title == whole { return 1_000 }
        if title.hasPrefix(whole) { return 900 }
        if startsAWord(whole, in: title) { return 800 }
        if title.contains(whole) { return 700 }

        let keywords = command.keywords.map(normalized)
        let subtitle = command.subtitle.map(normalized)
        var total = 0
        for word in words {
            guard let wordScore = score(word: word, title: title, keywords: keywords, subtitle: subtitle) else { return nil }
            total += wordScore
        }
        return total / words.count
    }

    /// One word of the query against one command.
    private static func score(word: String, title: String, keywords: [String], subtitle: String?) -> Int? {
        if startsAWord(word, in: title) { return 600 }
        if title.contains(word) { return 500 }
        if keywords.contains(where: { startsAWord(word, in: $0) }) { return 450 }
        if keywords.contains(where: { $0.contains(word) }) { return 350 }
        if let subtitle {
            if startsAWord(word, in: subtitle) { return 300 }
            if subtitle.contains(word) { return 250 }
        }
        return lettersInOrderScore(word, in: title)
    }

    /// Case-, diacritic- and width-insensitive, so "cafe" finds "Café".
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Whether `needle` appears in `text` at the start of a word.
    private static func startsAWord(_ needle: String, in text: String) -> Bool {
        guard !needle.isEmpty else { return false }
        for range in text.ranges(of: needle) {
            if range.lowerBound == text.startIndex { return true }
            let previous = text[text.index(before: range.lowerBound)]
            if !previous.isLetter && !previous.isNumber { return true }
        }
        return false
    }

    /// The fuzzy fallback: every letter of `word` in `text`, in order. Runs of
    /// adjacent letters and letters that start a word score higher, gaps lower.
    /// Always under the substring matches (1–199).
    private static func lettersInOrderScore(_ word: String, in text: String) -> Int? {
        guard word.count > 1 else { return nil }
        let letters = Array(text)
        var searchFrom = 0
        var previousMatch: Int?
        var score = 100
        for character in word {
            guard let match = letters[searchFrom...].firstIndex(of: character) else { return nil }
            if let previousMatch {
                score += match == previousMatch + 1 ? 10 : -min(match - previousMatch - 1, 10)
            }
            if match == 0 || !(letters[match - 1].isLetter || letters[match - 1].isNumber) {
                score += 15
            }
            previousMatch = match
            searchFrom = match + 1
        }
        return min(max(score, 1), 199)
    }

    /// The flattened rows for `sections`: each header, then its commands with
    /// their keyboard index.
    static func displayRows(for sections: [CommandPaletteResultSection]) -> [CommandPaletteDisplayRow] {
        var rows: [CommandPaletteDisplayRow] = []
        var index = 0
        for section in sections {
            if !section.title.isEmpty {
                rows.append(.header(id: section.id, title: section.title))
            }
            for command in section.commands {
                rows.append(.command(command, index: index))
                index += 1
            }
        }
        return rows
    }

    /// The selection after ↑ / ↓ (or Tab / Shift-Tab): `delta` rows on, wrapping
    /// around either end. nil when there's nothing to select.
    static func movedSelection(from index: Int, by delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let start = min(max(index, 0), count - 1)
        return ((start + delta) % count + count) % count
    }
}

// MARK: - Recents

/// The commands last run from a palette, newest first, by ID — so each resolves
/// against the live commands and silently drops once its command is gone.
/// Stored in `UserDefaults` under the palette's recents key.
@Observable
final class CommandPaletteRecents {
    /// How many it keeps.
    static let limit = 6

    let storageKey: String
    private let defaults: UserDefaults
    private(set) var commandIDs: [String]

    /// One store per key, so every palette that shares a key shares its recents.
    private static var stores: [String: CommandPaletteRecents] = [:]

    static func store(for storageKey: String) -> CommandPaletteRecents {
        if let store = stores[storageKey] { return store }
        let store = CommandPaletteRecents(storageKey: storageKey)
        stores[storageKey] = store
        return store
    }

    init(storageKey: String, defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.defaults = defaults
        commandIDs = defaults.stringArray(forKey: storageKey) ?? []
    }

    func record(_ commandID: String) {
        commandIDs = Self.recording(commandID, in: commandIDs, limit: Self.limit)
        defaults.set(commandIDs, forKey: storageKey)
    }

    /// `ids` with `commandID` moved (or added) to the front, at most `limit` long.
    nonisolated static func recording(_ commandID: String, in ids: [String], limit: Int) -> [String] {
        Array(([commandID] + ids.filter { $0 != commandID }).prefix(limit))
    }
}
