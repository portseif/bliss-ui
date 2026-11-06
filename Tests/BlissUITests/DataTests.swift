import CoreGraphics
import Foundation
import Testing
@testable import BlissUI

/// The data views' geometry: whole-point segment widths that sum exactly,
/// clamped fractions, block splits and sparkline normalization.
@Suite struct DataTests {
    // MARK: - Fractions

    @Test(arguments: [
        (0.5, 1.0, 0.5),
        (-3.0, 10.0, 0.0),
        (15.0, 10.0, 1.0),
        (5.0, 0.0, 0.0),
        (5.0, -2.0, 0.0),
        (Double.nan, 10.0, 0.0),
        (Double.infinity, 10.0, 0.0),
        (3.0, Double.infinity, 0.0),
    ])
    func fractionClampsToTheTrack(value: Double, total: Double, expected: Double) {
        #expect(DataMetrics.fraction(value, of: total) == expected)
    }

    @Test func percentRoundsDown() {
        let locale = Locale(identifier: "en_US")
        #expect(0.996.formatted(DataMetrics.percentFormat.locale(locale)) == "99%")
        #expect(1.0.formatted(DataMetrics.percentFormat.locale(locale)) == "100%")
        #expect(0.625.formatted(DataMetrics.percentFormat.locale(locale)) == "62%")
    }

    // MARK: - Whole shares

    @Test func wholeSharesSumExactly() {
        let shares = DataMetrics.wholeShares(of: 100, weights: [1, 1, 1])
        #expect(shares.reduce(0, +) == 100)
        // The leftover point goes to the earliest of the tied remainders.
        #expect(shares == [34, 33, 33])
        #expect(DataMetrics.wholeShares(of: 0, weights: [1, 2]) == [0, 0])
        #expect(DataMetrics.wholeShares(of: 10, weights: [0, 0]) == [0, 0])
        #expect(DataMetrics.wholeShares(of: 10, weights: [-4, 1, .nan]) == [0, 10, 0])
    }

    // MARK: - Usage bar

    /// Drawn segments plus the gaps between them, which must land exactly on
    /// the filled width.
    private func occupiedWidth(_ widths: [CGFloat], spacing: CGFloat) -> CGFloat {
        let drawn = widths.filter { $0 > 0 }
        return drawn.reduce(0, +) + spacing * CGFloat(max(drawn.count - 1, 0))
    }

    @Test(arguments: [237.6, 240, 101, 333.3, 1_000])
    func segmentWidthsSumToTheFilledWidth(barWidth: CGFloat) {
        let values = [48.0, 31, 9, 18, 2.5]
        let widths = UsageBarLayout.segmentWidths(values: values, capacity: 256, barWidth: barWidth, spacing: 2)
        #expect(widths.allSatisfy { $0 == $0.rounded() })
        let expectedFill = (barWidth.rounded(.down) * values.reduce(0, +) / 256).rounded()
        #expect(occupiedWidth(widths, spacing: 2) == expectedFill)
    }

    @Test func aBreakdownFillsTheWholeBar() {
        let widths = UsageBarLayout.segmentWidths(values: [1, 1, 1], capacity: nil, barWidth: 200.7, spacing: 2)
        #expect(occupiedWidth(widths, spacing: 2) == 200)
        #expect(widths == [66, 65, 65])
    }

    @Test func overCapacityClampsToFull() {
        let widths = UsageBarLayout.segmentWidths(values: [300, 200], capacity: 256, barWidth: 120, spacing: 0)
        #expect(widths.reduce(0, +) == 120)
    }

    @Test func emptyAndInvalidValuesDrawNothing() {
        #expect(UsageBarLayout.segmentWidths(values: [], capacity: 10, barWidth: 100, spacing: 2) == [])
        #expect(UsageBarLayout.segmentWidths(values: [0, 0], capacity: nil, barWidth: 100, spacing: 2) == [0, 0])
        #expect(UsageBarLayout.segmentWidths(values: [-5, .nan], capacity: 10, barWidth: 100, spacing: 2) == [0, 0])
        #expect(UsageBarLayout.segmentWidths(values: [5], capacity: 0, barWidth: 100, spacing: 2) == [0])
    }

    @Test func aSegmentTooSmallForAPointIsDroppedWithItsGap() {
        // 0.1 of 100 on a 100pt bar earns no whole point: the other two split
        // the run with a single gap between them.
        let widths = UsageBarLayout.segmentWidths(values: [50, 0.1, 49.9], capacity: 100, barWidth: 100, spacing: 2)
        #expect(widths[1] == 0)
        #expect(occupiedWidth(widths, spacing: 2) == 100)
    }

    @Test func aRunTooNarrowForItsGapsGoesToTheLargestSegment() {
        let widths = UsageBarLayout.segmentWidths(values: [1, 3, 2], capacity: 600, barWidth: 100, spacing: 2)
        #expect(widths == [0, 1, 0])
    }

    @Test(arguments: [(0.5, UsageBarLayout.MeterLevel.normal), (0.75, .normal), (0.76, .warning), (0.9, .warning), (0.91, .critical), (1.0, .critical)])
    func meterLevelThresholds(fraction: Double, level: UsageBarLayout.MeterLevel) {
        #expect(UsageBarLayout.MeterLevel(fraction: fraction) == level)
    }

    // MARK: - Tick strip

    @Test func tickStripIsWholePoints() {
        #expect(TickStrip.width(tickCount: 20, tickWidth: 2, spacing: 2) == 78)
        #expect(TickStrip.width(tickCount: 1, tickWidth: 2, spacing: 2) == 2)
        #expect(TickStrip.width(tickCount: 0, tickWidth: 2, spacing: 2) == 0)
    }

    // MARK: - Change blocks

    @Test func changeBlocksScaleWithSize() {
        typealias Kind = ChangeBlocks.BlockKind
        #expect(ChangeBlocks.blockKinds(additions: 0, deletions: 0, blockCount: 5, unitsPerBlock: 150) == Array(repeating: Kind.neutral, count: 5))
        #expect(ChangeBlocks.blockKinds(additions: 10, deletions: 0, blockCount: 5, unitsPerBlock: 150) == [.addition, .neutral, .neutral, .neutral, .neutral])
        #expect(ChangeBlocks.blockKinds(additions: 400, deletions: 200, blockCount: 5, unitsPerBlock: 150) == [.addition, .addition, .addition, .deletion, .neutral])
        #expect(ChangeBlocks.blockKinds(additions: 90_000, deletions: 1, blockCount: 5, unitsPerBlock: 150) == [.addition, .addition, .addition, .addition, .deletion])
    }

    @Test func eachSideWithChangesKeepsABlock() {
        // A tiny change on both sides lights two blocks, not one shared one.
        let kinds = ChangeBlocks.blockKinds(additions: 3, deletions: 1, blockCount: 5, unitsPerBlock: 150)
        #expect(kinds.contains(.addition))
        #expect(kinds.contains(.deletion))
        #expect(kinds.count == 5)
    }

    // MARK: - Sparkline

    @Test func sparklineSpansTheInsetFrame() throws {
        let size = CGSize(width: 104, height: 34)
        let points = SparklineGeometry.points(for: [2, 8, 5], in: size, range: nil, inset: 2)
        let first = try #require(points[0])
        let high = try #require(points[1])
        let last = try #require(points[2])
        // Evenly spaced from inset to inset, the low on the bottom, the high on top.
        #expect(first == CGPoint(x: 2, y: 32))
        #expect(high == CGPoint(x: 52, y: 2))
        #expect(last == CGPoint(x: 102, y: 17))
    }

    @Test func sparklineKeepsGapsAndRuns() {
        let points = SparklineGeometry.points(for: [1, nil, 3, 4, nil], in: CGSize(width: 50, height: 10), range: nil, inset: 0)
        #expect(points[1] == nil)
        #expect(points[4] == nil)
        let runs = SparklineGeometry.runs(points)
        #expect(runs.map(\.count) == [1, 2])
    }

    @Test func sparklineFlatSeriesRunsThroughTheMiddle() {
        let points = SparklineGeometry.points(for: [4, 4, 4], in: CGSize(width: 20, height: 10), range: nil, inset: 1)
        #expect(points.allSatisfy { $0?.y == 5 })
    }

    @Test func sparklineFixedRangePinsOutliers() {
        let points = SparklineGeometry.points(for: [-5, 5, 50], in: CGSize(width: 20, height: 10), range: 0...10, inset: 0)
        #expect(points.map { $0?.y } == [10, 5, 0])
    }

    @Test func sparklineSingleValueSitsAtTheTrailingEdge() {
        let points = SparklineGeometry.points(for: [7], in: CGSize(width: 40, height: 10), range: nil, inset: 2)
        #expect(points == [CGPoint(x: 38, y: 5)])
        #expect(SparklineGeometry.points(for: [nil, nil], in: CGSize(width: 40, height: 10), range: nil, inset: 2) == [nil, nil])
    }
}
