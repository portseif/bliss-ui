import Foundation
import Testing
@testable import BlissUI

/// `CommitGraphLayout`: which lane each commit takes, which lanes end, pass
/// by or open at it, and that a lane keeps its color.
@Suite struct CommitGraphTests {
    private func commit(_ id: String, _ parents: [String]) -> CommitGraphCommit {
        CommitGraphCommit(id: id, parentIDs: parents, title: id, authorName: "Ada Lovelace", date: .distantPast)
    }

    @Test func linearHistoryStaysInOneLane() {
        let rows = CommitGraphLayout.rows(for: [commit("c", ["b"]), commit("b", ["a"]), commit("a", [])])
        #expect(rows.map(\.column) == [0, 0, 0])
        #expect(rows.map(\.color) == [0, 0, 0])
        #expect(rows.map(\.hasLineAbove) == [false, true, true])
        #expect(rows.last?.parents.isEmpty == true)
        #expect(rows.allSatisfy { $0.incoming.isEmpty && $0.passThrough.isEmpty })
    }

    @Test func mergeOpensASecondLaneThatRejoinsAtTheForkPoint() {
        // m merges b2 into main; b2 and a1 both come from a0.
        let rows = CommitGraphLayout.rows(for: [
            commit("m", ["a1", "b2"]),
            commit("b2", ["a0"]),
            commit("a1", ["a0"]),
            commit("a0", []),
        ])

        // The merge keeps lane 0 for its first parent and opens lane 1, in a new color, for the second.
        #expect(rows[0].column == 0)
        #expect(rows[0].parents == [CommitGraphLane(column: 0, color: 0), CommitGraphLane(column: 1, color: 1)])

        // The branch commit sits in lane 1 while lane 0 passes by.
        #expect(rows[1].column == 1)
        #expect(rows[1].color == 1)
        #expect(rows[1].passThrough == [CommitGraphLane(column: 0, color: 0)])

        // a1 continues lane 0; lane 1 (now waiting for a0) passes by.
        #expect(rows[2].column == 0)
        #expect(rows[2].passThrough == [CommitGraphLane(column: 1, color: 1)])

        // Both lanes wait for a0: it takes the leftmost, and lane 1 ends into it.
        #expect(rows[3].column == 0)
        #expect(rows[3].incoming == [CommitGraphLane(column: 1, color: 1)])
        #expect(rows[3].maxColumn == 1)
    }

    @Test func tipsSharingAParentConvergeAtIt() {
        // The second tip keeps its own lane down to base, then curves into lane 0.
        let rows = CommitGraphLayout.rows(for: [commit("tip1", ["base"]), commit("tip2", ["base"]), commit("base", [])])
        #expect(rows[1].column == 1)
        #expect(rows[1].hasLineAbove == false)
        #expect(rows[1].parents == [CommitGraphLane(column: 1, color: 1)])
        #expect(rows[2].column == 0)
        #expect(rows[2].incoming == [CommitGraphLane(column: 1, color: 1)])
    }

    @Test func mergedParentAlreadyWaitingJoinsThatLane() {
        // m's second parent is a lane's next commit already: no third lane opens.
        let rows = CommitGraphLayout.rows(for: [
            commit("side", ["b"]),
            commit("m", ["a", "b"]),
            commit("b", ["a"]),
            commit("a", []),
        ])
        #expect(rows[1].column == 1)
        #expect(rows[1].parents == [CommitGraphLane(column: 1, color: 1), CommitGraphLane(column: 0, color: 1)])
        #expect(rows.map(\.maxColumn).max() == 1)
    }

    @Test func freedLaneIsReusedWithANewColor() {
        // a merge closes lane 1 (from x) and reopens it for its second parent y.
        let rows = CommitGraphLayout.rows(for: [
            commit("main", ["merge"]),
            commit("x", ["merge"]),
            commit("merge", ["older", "y"]),
            commit("y", ["older"]),
            commit("older", []),
        ])
        #expect(rows[2].incoming == [CommitGraphLane(column: 1, color: 1)])
        #expect(rows[2].parents == [CommitGraphLane(column: 0, color: 0), CommitGraphLane(column: 1, color: 2)])
        #expect(rows[3].column == 1)
        #expect(rows[3].color == 2)
    }

    @Test func missingParentKeepsItsLaneOpen() {
        let rows = CommitGraphLayout.rows(for: [commit("c", ["not-shown"])])
        #expect(rows[0].parents == [CommitGraphLane(column: 0, color: 0)])
    }

    @Test func shortHashDefaultsToSevenCharacters() {
        #expect(commit("0123456789abcdef", []).shortHash == "0123456")
    }
}
