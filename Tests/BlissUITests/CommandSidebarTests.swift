import Foundation
import Testing
@testable import BlissUI

/// The command palette's search — ranking, scope prefixes, the sections it
/// lists — its keyboard moves, and its recents.
@MainActor
@Suite struct CommandSidebarTests {
    private func command(
        _ title: String,
        id: String? = nil,
        subtitle: String? = nil,
        keywords: [String] = [],
        recordsRecent: Bool = true
    ) -> CommandPaletteCommand {
        CommandPaletteCommand(id: id ?? title, title: title, subtitle: subtitle, keywords: keywords, recordsRecent: recordsRecent) {}
    }

    private func titles(_ commands: [CommandPaletteCommand]) -> [String] {
        commands.map(\.title)
    }

    // MARK: Ranking

    @Test func prefixesOutrankWordStartsWhichOutrankSubstrings() {
        let commands = [command("New project"), command("Approve"), command("Projects"), command("Prose")]
        // Title prefixes keep their order, then a later word's start, then anywhere.
        #expect(titles(CommandPaletteSearch.ranked(commands, query: "pro")) == ["Projects", "Prose", "New project", "Approve"])
    }

    @Test func anExactTitleRanksFirst() {
        let commands = [command("Inbox zero"), command("Inbox")]
        #expect(titles(CommandPaletteSearch.ranked(commands, query: "inbox")) == ["Inbox", "Inbox zero"])
    }

    @Test func titleMatchesOutrankKeywordsWhichOutrankSubtitles() {
        let commands = [
            command("Export", subtitle: "Writes a new file"),
            command("Add project", keywords: ["new"]),
            command("New window"),
        ]
        #expect(titles(CommandPaletteSearch.ranked(commands, query: "new")) == ["New window", "Add project", "Export"])
    }

    @Test func lettersInOrderFindAnAbbreviation() {
        let commands = [command("Settings"), command("New project")]
        #expect(titles(CommandPaletteSearch.ranked(commands, query: "nwprj")) == ["New project"])
        // Scattered letters still match, below a run of them.
        let scattered = CommandPaletteSearch.score(command("New project"), query: "npt")
        let run = CommandPaletteSearch.score(command("New project"), query: "nwp")
        #expect(scattered != nil && run != nil)
        #expect(run! > scattered!)
    }

    @Test func everyWordOfTheQueryHasToMatch() {
        let newFilter = command("New filter", subtitle: "A saved view")
        #expect(CommandPaletteSearch.score(newFilter, query: "new filt") == 900)
        #expect(CommandPaletteSearch.score(newFilter, query: "filter new") != nil)
        #expect(CommandPaletteSearch.score(newFilter, query: "new saved") != nil)
        #expect(CommandPaletteSearch.score(newFilter, query: "new zebra") == nil)
    }

    @Test func matchingIgnoresCaseAndDiacritics() {
        #expect(CommandPaletteSearch.score(command("Café Menu"), query: "CAFE") == 900)
        #expect(CommandPaletteSearch.score(command("Résumé"), query: "resume") == 1_000)
    }

    @Test func anEmptyQueryMatchesEverythingInOrder() {
        let commands = [command("B"), command("A")]
        #expect(titles(CommandPaletteSearch.ranked(commands, query: "")) == ["B", "A"])
        #expect(CommandPaletteSearch.score(command("A"), query: "   ") == 0)
    }

    // MARK: Scope

    @Test func aLeadingPrefixScopesTheQuery() {
        let prefixes = [">", "@", "#"]
        #expect(CommandPaletteSearch.scope(of: ">new", prefixes: prefixes) == .init(prefix: ">", query: "new"))
        #expect(CommandPaletteSearch.scope(of: "  @  apollo ", prefixes: prefixes) == .init(prefix: "@", query: "apollo"))
        #expect(CommandPaletteSearch.scope(of: "#", prefixes: prefixes) == .init(prefix: "#", query: ""))
        #expect(CommandPaletteSearch.scope(of: "a>b", prefixes: prefixes) == .init(prefix: nil, query: "a>b"))
        #expect(CommandPaletteSearch.scope(of: "%x", prefixes: prefixes) == .init(prefix: nil, query: "%x"))
    }

    // MARK: Listed sections

    private var sections: [CommandPaletteSection] {
        [
            CommandPaletteSection("Go to", prefix: "#", commands: [command("Inbox"), command("Settings")]),
            CommandPaletteSection("Projects", prefix: "@", showsWithoutQuery: false, maxResults: 2, commands: [
                command("Apollo"), command("Atlas"), command("Aurora"), command("Borealis"),
            ]),
            CommandPaletteSection("Actions", prefix: ">", commands: [
                command("New project"), command("Upgrade", recordsRecent: false),
            ]),
        ]
    }

    @Test func atRestRecentComesFirstAndIsntListedTwice() {
        let results = CommandPaletteSearch.results(
            for: "",
            in: sections,
            recentIDs: ["New project", "Gone", "Upgrade", "Atlas"],
            recentTitle: "Recent"
        )
        #expect(results.map(\.title) == ["Recent", "Go to", "Actions"])
        // A recent whose command is gone is dropped, and one that opted out never shows.
        #expect(titles(results[0].commands) == ["New project", "Atlas"])
        #expect(titles(results[2].commands) == ["Upgrade"])
    }

    @Test func aPrefixListsItsWholeSection() {
        let results = CommandPaletteSearch.results(for: "@", in: sections, recentIDs: [], recentTitle: "Recent")
        #expect(results.map(\.title) == ["Projects"])
        // A scope ignores `maxResults` and `showsWithoutQuery`.
        #expect(results[0].commands.count == 4)

        let narrowed = CommandPaletteSearch.results(for: "@ bor", in: sections, recentIDs: [], recentTitle: "Recent")
        #expect(titles(narrowed.flatMap(\.commands)) == ["Borealis"])
    }

    @Test func searchingCapsSectionsAndDropsEmptyOnes() {
        let results = CommandPaletteSearch.results(for: "a", in: sections, recentIDs: ["Inbox"], recentTitle: "Recent")
        // No Recent while searching; Projects capped at two.
        #expect(!results.map(\.title).contains("Recent"))
        #expect(titles(results.first { $0.title == "Projects" }?.commands ?? []) == ["Apollo", "Atlas"])
        #expect(CommandPaletteSearch.results(for: "zzz", in: sections, recentIDs: [], recentTitle: "Recent").isEmpty)
    }

    @Test func aCommandInTwoSectionsIsListedOnce() {
        let shared = [
            CommandPaletteSection("One", commands: [command("Open", id: "open")]),
            CommandPaletteSection("Two", commands: [command("Open", id: "open"), command("Other")]),
        ]
        let results = CommandPaletteSearch.results(for: "o", in: shared, recentIDs: [], recentTitle: "Recent")
        #expect(results.flatMap(\.commands).map(\.id) == ["open", "Other"])
    }

    @Test func displayRowsNumberTheCommandsAcrossSections() {
        let results = [
            CommandPaletteResultSection(id: "a", title: "First", commands: [command("A"), command("B")]),
            CommandPaletteResultSection(id: "b", title: "", commands: [command("C")]),
        ]
        let rows = CommandPaletteSearch.displayRows(for: results)
        #expect(rows.count == 4)
        let indices = rows.compactMap { row -> Int? in
            if case .command(_, let index) = row { return index }
            return nil
        }
        #expect(indices == [0, 1, 2])
        // An untitled section has no header.
        if case .header(_, let title) = rows[0] { #expect(title == "First") } else { Issue.record("Expected a header first") }
        if case .command(let last, _) = rows[3] { #expect(last.title == "C") } else { Issue.record("Expected a command last") }
    }

    // MARK: Keyboard

    @Test func selectionWrapsAroundBothEnds() {
        #expect(CommandPaletteSearch.movedSelection(from: 0, by: 1, count: 3) == 1)
        #expect(CommandPaletteSearch.movedSelection(from: 2, by: 1, count: 3) == 0)
        #expect(CommandPaletteSearch.movedSelection(from: 0, by: -1, count: 3) == 2)
        // A selection left past the end by a shorter list starts from the last row.
        #expect(CommandPaletteSearch.movedSelection(from: 7, by: -1, count: 3) == 1)
        #expect(CommandPaletteSearch.movedSelection(from: 0, by: 1, count: 0) == nil)
    }

    // MARK: Recents

    @Test func recordingMovesToTheFrontAndKeepsTheLimit() {
        #expect(CommandPaletteRecents.recording("b", in: ["a", "b", "c"], limit: 6) == ["b", "a", "c"])
        #expect(CommandPaletteRecents.recording("d", in: ["a", "b", "c"], limit: 3) == ["d", "a", "b"])
        #expect(CommandPaletteRecents.recording("a", in: [], limit: 6) == ["a"])
    }

    @Test func recentsPersistUnderTheirKey() throws {
        let suiteName = "CommandSidebarTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let recents = CommandPaletteRecents(storageKey: "palette.recents", defaults: defaults)
        #expect(recents.commandIDs.isEmpty)
        for id in ["a", "b", "c", "d", "e", "f", "g", "a"] { recents.record(id) }
        #expect(recents.commandIDs == ["a", "g", "f", "e", "d", "c"])
        #expect(recents.commandIDs.count == CommandPaletteRecents.limit)

        let reloaded = CommandPaletteRecents(storageKey: "palette.recents", defaults: defaults)
        #expect(reloaded.commandIDs == recents.commandIDs)
        #expect(CommandPaletteRecents(storageKey: "other.key", defaults: defaults).commandIDs.isEmpty)
    }
}
