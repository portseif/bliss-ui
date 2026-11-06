import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the data and progress views,
/// built the way an app would build them.
@MainActor
@Suite struct DataAPITests {
    @Test func progressBarsAreReachable() {
        _ = ProgressBar(value: 0.4)
        _ = ProgressBar(value: 3, total: 8, label: "Uploading", showsPercentage: true)
        _ = ProgressBar(value: nil, label: "Preparing…")
        _ = ProgressBar(value: 0.9, tint: Success.success500, height: 4)
        let optionalProgress: Double? = nil
        _ = ProgressBar(value: optionalProgress)
    }

    @Test func progressRingsAreReachable() {
        _ = ProgressRing(value: 0.25)
        _ = ProgressRing(value: 2, total: 5, center: .percentage, size: 48)
        _ = ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Warning.warning500, size: 56, lineWidth: 4)
        _ = ProgressRing(value: 1, center: .none, font: Typography.caption, accessibilityLabel: "Sync")
        let label: ProgressRing.CenterLabel = .text(.verbatim("12"))
        _ = ProgressRing(value: 0.5, center: label)
    }

    @Test func usageBarsAreReachable() {
        let segments = [
            UsageBar.Segment("Apps", value: 48, color: .accent),
            UsageBar.Segment(.verbatim("Photos"), value: 31, color: Info.info500),
        ]
        _ = UsageBar(segments)
        _ = UsageBar(segments, capacity: 256, title: "Storage", showsTotal: true, showsLegend: true) { "\($0.formatted()) GB" }
        _ = UsageBar(segments, height: 8, spacing: 1)
        _ = UsageBar(value: 412, capacity: 500)
        _ = UsageBar(value: 412, capacity: 500, title: "Entries", showsTotal: true, height: 4) { $0.formatted() }
        var segment = segments[0]
        segment.value = 50
        segment.color = Danger.danger500
        segment.label = "Mail"
        #expect(segment.value == 50)
    }

    @Test func tickStripsAreReachable() {
        let ticks = [
            TickStrip.Tick(color: Success.success500, label: "Mar 1 · Healthy"),
            TickStrip.Tick(color: nil, label: "Mar 2 · No reading"),
        ]
        #expect(ticks[0] != ticks[1])
        _ = TickStrip(ticks)
        _ = TickStrip(ticks, tickWidth: 3, spacing: 2, height: 16, isRefreshing: true, accessibilityLabel: "Health")
        var tick = ticks[1]
        tick.color = Warning.warning500
        tick.label = "Mar 2 · Degraded"
        #expect(tick.color != nil)
    }

    @Test func changeBlocksAreReachable() {
        _ = ChangeBlocks(additions: 529, deletions: 12)
        _ = ChangeBlocks(additions: 0, deletions: 0, showsCounts: false)
        _ = ChangeBlocks(additions: 20, deletions: 4, blockCount: 8, unitsPerBlock: 10)
    }

    @Test func sparklinesAreReachable() {
        let series: [Double] = [3, 5, 4, 6]
        _ = Sparkline(series)
        _ = Sparkline([3, nil, 4, 6], range: 0...10, color: Success.success500, lineWidth: 2, fillsArea: true, showsLastPoint: false)
        _ = Sparkline(series, accessibilityLabel: "Latency") { "\($0.formatted()) ms" }
    }

    @Test func pillsAreReachable() {
        _ = StatusPill("Running", isActive: true)
        _ = StatusPill("Stopped", isActive: false, color: Info.info500)
        _ = KeyHintPill("esc")
        _ = KeyHintPill("⌘↩")
    }
}
