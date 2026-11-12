import Foundation
import Testing
@testable import BlissUI

/// `BlissTableRowLayout`'s widths with `contentWidths` (a table's
/// `autoSizeColumns`), and the sizer that collects them.
@MainActor
@Suite struct BlissTableColumnSizingTests {
    @Test func roomToSpareIsSharedEvenly() {
        let widths = BlissTableRowLayout.fittedWidths(content: [100, 50], minimums: [0, 0], available: 250)
        #expect(widths == [150, 100])
    }

    @Test func tooNarrowCapsTheWidestAndKeepsTheNarrowOnes() {
        // A long name, a badge and a date in 300pt: the badge and date keep
        // their content, the name takes what's left.
        let widths = BlissTableRowLayout.fittedWidths(content: [600, 80, 70], minimums: [0, 0, 0], available: 300)
        #expect(widths == [150, 80, 70])
    }

    @Test func twoWideColumnsShareTheCapEvenly() {
        let widths = BlissTableRowLayout.fittedWidths(content: [600, 400, 60], minimums: [0, 0, 0], available: 300)
        #expect(widths == [120, 120, 60])
    }

    @Test func minimumsHoldWhenSqueezed() {
        let widths = BlissTableRowLayout.fittedWidths(content: [600, 400], minimums: [140, 0], available: 200)
        #expect(widths[0] == 140)
        #expect(widths[1] <= 60)
    }

    @Test func fixedColumnsKeepTheirWidth() {
        let layout = BlissTableRowLayout(columns: [.fixed(40), .flexible(), .flexible()], spacing: 10, contentWidths: [0, 300, 50])
        // 400 - 40 fixed - 20 gaps = 340 for the two flexible columns.
        #expect(layout.widths(for: 400) == [40, 290, 50])
    }

    @Test func withoutContentWidthsFlexibleColumnsSplitEvenly() {
        let layout = BlissTableRowLayout(columns: [.flexible(), .flexible()], spacing: 0)
        #expect(layout.widths(for: 200) == [100, 100])
    }

    @Test func sizerKeepsTheWidestCellAndForgetsRemovedRows() {
        let sizer = BlissTableColumnSizer()
        sizer.record(80, column: 0, from: "a")
        sizer.record(120, column: 0, from: "b")
        sizer.record(30, column: 1, from: "a")
        #expect(sizer.contentWidths == [120, 30])

        sizer.keep(only: ["a"])
        #expect(sizer.contentWidths == [80, 30])

        // The widest cell shrinking finds the next widest.
        sizer.record(20, column: 0, from: "a")
        #expect(sizer.contentWidths == [20, 30])
    }
}
