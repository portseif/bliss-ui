import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the data and layout variants
/// added in the consistency pass, built the way an app would build them.
@MainActor
@Suite struct DataLayoutVariantsAPITests {
    private struct Member {
        let name: String
        let isOnline: Bool
    }

    private struct Task: Identifiable {
        let id: Int
        let title: String
    }

    @Test func barThicknessAndReadoutsAreReachable() {
        for thickness in BarThickness.allCases {
            _ = ProgressBar(value: 0.5, thickness: thickness)
            #expect(thickness.height > 0)
        }
        #expect(BarThickness.thin.height < BarThickness.regular.height)
        #expect(BarThickness.regular.height < BarThickness.thick.height)
        _ = ProgressBar(value: 4, total: 12, label: "Steps", readout: .text("4 of 12"), inline: true)
        _ = ProgressBar(value: 0.3, readout: .percentage)
        let readout: ProgressReadout = .none
        _ = ProgressBar(value: 0.3, readout: readout)
    }

    @Test func progressRingVariantsAreReachable() {
        _ = ProgressRing(value: 0.4, label: "Synced")
        _ = ProgressRing(value: 0.4, size: 72)
        _ = ProgressRing(value: 0.4, size: 72, lineWidth: 5)
        let center: ProgressRing.CenterLabel = .percentage
        _ = ProgressRing(value: 0.4, center: center)
    }

    @Test func sparklineVariantsAreReachable() {
        _ = Sparkline([1, 2, 3], baseline: 2, showsExtremes: true, smooths: true)
        _ = Sparkline([1, nil, 3], range: 0...10, baseline: 50)
    }

    @Test func chartVariantsAreReachable() {
        let samples = [ChartSample(date: Date(), value: 1, series: "Web"), ChartSample(date: Date(), value: 2, series: "App")]
        _ = TimeSeriesChart(samples: samples, compact: true, range: 0...100, seriesColors: ["Web": Success.success500], isInteractive: false)
        let bars = [ChartBar(category: "Jan", value: 40, series: "Mac"), ChartBar(category: "Feb", value: 20, series: "iPad")]
        _ = BarChart(bars: bars, compact: true, seriesColors: ["Mac": Info.info500], isInteractive: false, orientation: .horizontal)
        let orientations: [BarChartOrientation] = [.vertical, .horizontal]
        #expect(orientations.count == 2)
        _ = ChartLegend(series: ["Web", "App"], colors: [Success.success500, Info.info500])
        _ = Text("Chart").blissChartStyle(showsAxes: false, showsGrid: false)
    }

    @Test func statCardVariantsAreReachable() {
        _ = StatCard("Builds", value: "48", compact: true)
        _ = StatCard("Errors", value: "3", sparkline: [1, 2, 3], sparklineColor: Danger.danger500, isLoading: true)
        _ = StatCard("Revenue", value: "$4,120", onOpen: {})
    }

    @Test func tickStripVariantsAreReachable() {
        let ticks = [TickStrip.Tick(color: Success.success500, label: "Mon"), TickStrip.Tick(color: nil, label: "Tue")]
        _ = TickStrip(ticks, highlightedIndex: 0, fillsWidth: true, onSelect: { _ in })
        #expect(TickStripMetrics.tickWidth > 0)
        #expect(TickStripMetrics.height > TickStripMetrics.spacing)
    }

    @Test func changeBlocksVariantsAreReachable() {
        _ = ChangeBlocks(additions: 12_400, deletions: 3_100, showsBlocks: false, countStyle: .exact, accessibilityLabel: "Diff size")
        let styles: [ChangeCountStyle] = [.compact, .exact]
        #expect(styles.count == 2)
    }

    @Test func usageBarVariantsAreReachable() {
        let thresholds = UsageThresholds(warning: 0.5, critical: 0.95)
        #expect(thresholds.warning == 0.5)
        #expect(UsageThresholds.default.critical == 0.9)
        _ = UsageBar(value: 412, capacity: 500, title: "Entries", showsTotal: true, showsPercentage: true, thresholds: thresholds, thickness: .thick)
        let segments = [UsageBar.Segment("Apps", value: 48, color: Color.accent)]
        _ = UsageBar(segments, capacity: 256, showsLegend: true, showsShares: true, thickness: .thin)
    }

    @Test func commitGraphVariantsAreReachable() {
        let commits = [CommitGraphCommit(id: "abc1234", parentIDs: [], title: "Initial", authorName: "Ada", date: Date())]
        _ = CommitGraph(commits, selection: .constant("abc1234"), compact: true, showsAuthor: false)
        _ = CommitGraph(commits, laneWidth: CommitGraphMetrics.laneWidth) { _, _ in EmptyView() }
    }

    @Test func avatarVariantsAreReachable() {
        _ = Avatar(name: "Ada Lovelace", size: .xlarge)
        _ = Avatar(name: "Release bot", tint: Grey.grey500, symbol: "gearshape.fill", showsBorder: true)
        #expect(AvatarSize.large.diameter < AvatarSize.xlarge.diameter)
        let members = [Member(name: "Ada", isOnline: true), Member(name: "Grace", isOnline: false)]
        _ = AvatarStack(members, name: \.name, status: { $0.isOnline ? .online : .offline }, onOverflowSelect: {})
        _ = AvatarStack(names: ["Ada", "Grace"], onOverflowSelect: {})
    }

    @Test func personRowVariantsAreReachable() {
        _ = PersonRow(name: "Design Team", detail: "4 members", image: Image(systemName: "person.3"), size: .large, shape: .rounded)
        _ = PersonRow(name: "Ada", image: nil, shape: .circle) { Text("Owner") }
    }

    @Test func breadcrumbVariantsAreReachable() {
        _ = Breadcrumbs(["Projects", "BlissUI", "Sources"], title: { $0 }, separator: .slash, maximumSegments: 2) { _ in }
        let separators: [BreadcrumbSeparator] = [.chevron, .slash]
        #expect(separators.count == 2)
    }

    @Test func codeVariantsAreReachable() {
        _ = CodeBlock("let x = 1", highlighter: .swift, font: Typography.code, wraps: true, title: "main.swift", maxHeight: 200, highlightedLines: [1])
        _ = CodeBlock("{\"a\": 1}", highlighter: .json)
        _ = CodeField(text: .constant("ls"), highlighter: .shell, layout: .editor(height: 120), showsLineNumbers: true, compact: true)
        _ = CodeField(text: .constant("ls"), highlighter: .shell) {
            Button("Run") {}
        }
        _ = CodeField(code: "git status", highlighter: .shell, font: Typography.codeSmall, maxHeight: 120)
        let tokens = CodeHighlighter.json.tokens(in: "{\"name\": true}")
        #expect(tokens.contains { $0.kind == .key })
        #expect(tokens.contains { $0.kind == .literal })
        let swift = CodeHighlighter.swift.tokens(in: "let x = 1 // one")
        #expect(swift.contains { $0.kind == .keyword })
        #expect(swift.contains { $0.kind == .comment })
    }

    @Test func splitVariantsAreReachable() {
        _ = InspectorSplit(isPresented: .constant(true), edge: .leading) { Text("Content") } inspector: { Text("Inspector") }
        _ = InspectorSplit(isPresented: .constant(true), idealWidth: 240, in: 200...400, persistenceKey: "test.inspector") { Text("Content") } inspector: { Text("Inspector") }
        #expect(InspectorSplitMetrics.minimumWidth < InspectorSplitMetrics.idealWidth)
        _ = ResizableSplit(width: .constant(220), isCollapsed: .constant(false), showsDivider: false) { Text("Leading") } trailing: { Text("Trailing") }
    }

    @Test func kanbanVariantsAreReachable() {
        let columns = [KanbanColumn(id: "todo", title: "To do", cards: [Task(id: 1, title: "Write")], limit: 1)]
        #expect(columns[0].isAtLimit)
        _ = KanbanBoard(columns: .constant(columns), onOpen: { _ in }, canMove: { _, _, _ in true }) { task in
            Text(verbatim: task.title)
        }
        _ = KanbanBoard(columns: .constant(columns), columnWidth: KanbanMetrics.columnWidth) { task in
            Text(verbatim: task.title)
        } columnFooter: { _ in
            Text("Add")
        } columnAccessory: { _ in
            Image(systemName: "ellipsis")
        }
    }
}
