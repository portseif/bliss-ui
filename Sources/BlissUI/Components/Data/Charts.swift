//
//  Charts.swift
//  BlissUI
//
//  Time-series and bar charts on Swift Charts, dressed like the rest of the
//  library: series in the theme's accent and status marks, `menuBorder` grid
//  lines, caption axis labels, the library's own legend, and a hover cursor
//  with a callout card of the values under the pointer. The shared pieces
//  (palette, style, legend, hover layer) are in ChartStyle.swift.
//
//  The other data views are hand-drawn and dependency-free; these import
//  Charts on purpose — it's a system framework (macOS 13+), and axes, scales
//  and date ticks are its job. `.blissChartStyle()` gives any `Chart` an app
//  builds itself the same look.
//

import Charts
import SwiftUI

// MARK: - Data

/// One sample of a time series.
public nonisolated struct ChartSample: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var value: Double
    /// The legend name; "" for a chart with one series.
    public var series: String

    public init(id: UUID = UUID(), date: Date, value: Double, series: String = "") {
        self.id = id
        self.date = date
        self.value = value
        self.series = series
    }
}

/// One bar of a bar chart.
public nonisolated struct ChartBar: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// The x label, shown as given.
    public var category: String
    public var value: Double
    /// The legend name; "" for a chart with one series.
    public var series: String

    public init(id: UUID = UUID(), category: String, value: Double, series: String = "") {
        self.id = id
        self.category = category
        self.value = value
        self.series = series
    }
}

/// How a time series is drawn: a line, or a line over a wash of its color.
public nonisolated enum TimeSeriesChartKind: Sendable {
    case line
    case area
}

// MARK: - Series grouping

/// The samples of one series, with its color.
private struct SampleSeries: Identifiable {
    let name: String
    let color: Color
    let samples: [ChartSample]
    var id: String { name }
}

/// The bars of one series, with its color.
private struct BarSeries: Identifiable {
    let name: String
    let color: Color
    let bars: [ChartBar]
    var id: String { name }
}

/// Series names in order of first appearance.
private func orderedSeriesNames(_ names: [String]) -> [String] {
    var seen = Set<String>()
    return names.filter { seen.insert($0).inserted }
}

// MARK: - Time series chart

/// A line or area chart of dated samples, one line per series.
///
/// ```swift
/// TimeSeriesChart(.area, samples: dailyVisits)
/// ```
///
/// Hovering shows a cursor at the nearest date and a card with each series'
/// value there. The legend appears under the chart when two or more series are
/// named.
public struct TimeSeriesChart: View {
    private let kind: TimeSeriesChartKind
    private let samples: [ChartSample]
    private let showsLegend: Bool
    private let valueFormat: FloatingPointFormatStyle<Double>

    @State private var hoveredDate: Date?

    /// - Parameters:
    ///   - kind: A line, or a line over a wash.
    ///   - samples: The data; the series name groups them into lines.
    ///   - showsLegend: Draws a `ChartLegend` under the chart when there are
    ///     two or more named series.
    ///   - valueFormat: How values read in the hover card and for VoiceOver.
    public init(
        _ kind: TimeSeriesChartKind = .line,
        samples: [ChartSample],
        showsLegend: Bool = true,
        valueFormat: FloatingPointFormatStyle<Double> = .number
    ) {
        self.kind = kind
        self.samples = samples
        self.showsLegend = showsLegend
        self.valueFormat = valueFormat
    }

    private var seriesNames: [String] {
        orderedSeriesNames(samples.map(\.series))
    }

    private var groups: [SampleSeries] {
        seriesNames.enumerated().map { index, name in
            SampleSeries(
                name: name,
                color: ChartPalette.color(forSeriesAt: index),
                samples: samples.filter { $0.series == name }.sorted { $0.date < $1.date }
            )
        }
    }

    private var namedSeries: [String] {
        seriesNames.filter { !$0.isEmpty }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if samples.isEmpty {
                ChartEmptyState()
            } else {
                Chart {
                    hoverRule
                    ForEach(groups) { group in
                        seriesMarks(for: group)
                    }
                    hoverPoints
                }
                .blissChartStyle()
                .chartOverlay { proxy in
                    TimeSeriesHoverOverlay(
                        proxy: proxy,
                        hoveredDate: $hoveredDate,
                        snap: nearestDate(to:),
                        values: hoveredValues,
                        valueFormat: valueFormat
                    )
                }
                .frame(minHeight: 160)
            }
            if showsLegend && namedSeries.count >= 2 {
                ChartLegend(series: namedSeries)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Marks

    @ChartContentBuilder
    private func seriesMarks(for group: SampleSeries) -> some ChartContent {
        if kind == .area {
            ForEach(group.samples) { sample in
                areaMark(sample, in: group)
            }
        }
        ForEach(group.samples) { sample in
            lineMark(sample, in: group)
        }
    }

    private func areaMark(_ sample: ChartSample, in group: SampleSeries) -> some ChartContent {
        AreaMark(
            x: .value("Date", sample.date),
            y: .value("Value", sample.value),
            series: .value("Series", group.name),
            stacking: .unstacked
        )
        .foregroundStyle(group.color.opacity(0.15))
        .interpolationMethod(.monotone)
        .accessibilityHidden(true)
    }

    private func lineMark(_ sample: ChartSample, in group: SampleSeries) -> some ChartContent {
        LineMark(
            x: .value("Date", sample.date),
            y: .value("Value", sample.value),
            series: .value("Series", group.name)
        )
        .foregroundStyle(group.color)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .interpolationMethod(.monotone)
        .accessibilityLabel(Text(verbatim: group.name))
        .accessibilityValue(Text(sample.value, format: valueFormat))
    }

    @ChartContentBuilder
    private var hoverRule: some ChartContent {
        if let hoveredDate {
            RuleMark(x: .value("Date", hoveredDate))
                .foregroundStyle(Color.menuBorder)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    @ChartContentBuilder
    private var hoverPoints: some ChartContent {
        if let hoveredDate {
            ForEach(hoveredValues) { value in
                PointMark(x: .value("Date", hoveredDate), y: .value("Value", value.value))
                    .foregroundStyle(value.color)
                    .symbolSize(40)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Hover

    /// The sample date nearest to where the pointer is.
    private func nearestDate(to date: Date) -> Date? {
        samples.map(\.date).min { abs($0.timeIntervalSince(date)) < abs($1.timeIntervalSince(date)) }
    }

    /// Each series' value at the hovered date (its nearest sample).
    private var hoveredValues: [HoveredValue] {
        guard let hoveredDate else { return [] }
        return groups.compactMap { group in
            let nearest = group.samples.min { abs($0.date.timeIntervalSince(hoveredDate)) < abs($1.date.timeIntervalSince(hoveredDate)) }
            guard let nearest else { return nil }
            return HoveredValue(name: group.name, color: group.color, value: nearest.value)
        }
    }
}

/// The hover layer over a time-series plot: tracks the pointer, snaps to a
/// sample date, and places the callout beside the cursor.
private struct TimeSeriesHoverOverlay: View {
    let proxy: ChartProxy
    @Binding var hoveredDate: Date?
    let snap: (Date) -> Date?
    let values: [HoveredValue]
    let valueFormat: FloatingPointFormatStyle<Double>

    var body: some View {
        GeometryReader { geometry in
            let plotFrame = proxy.plotFrame.map { geometry[$0] } ?? .zero
            ChartHoverLayer(
                plotFrame: plotFrame,
                markX: hoveredDate.flatMap { proxy.position(forX: $0) },
                callout: callout,
                onHover: { location in
                    guard let location else { return hoveredDate = nil }
                    let pointerDate: Date? = proxy.value(atX: location.x - plotFrame.minX)
                    hoveredDate = pointerDate.flatMap(snap)
                }
            )
        }
    }

    @ViewBuilder
    private var callout: some View {
        if let hoveredDate {
            ChartCallout(title: Text(hoveredDate, format: .dateTime.month().day()), values: values, valueFormat: valueFormat)
        }
    }
}

// MARK: - Bar chart

/// A bar chart of categories, with the series side by side or stacked.
///
/// ```swift
/// BarChart(bars: downloadsByMonth)
/// BarChart(bars: revenueByRegion, stacked: true)
/// ```
///
/// Hovering a category shows a card with each series' value in it.
public struct BarChart: View {
    private let bars: [ChartBar]
    private let stacked: Bool
    private let showsLegend: Bool
    private let valueFormat: FloatingPointFormatStyle<Double>

    @State private var hoveredCategory: String?

    /// - Parameters:
    ///   - bars: The data; the series name groups them, the category places them.
    ///   - stacked: Stack the series in one bar per category instead of side by side.
    ///   - showsLegend: Draws a `ChartLegend` under the chart when there are
    ///     two or more named series.
    ///   - valueFormat: How values read in the hover card and for VoiceOver.
    public init(
        bars: [ChartBar],
        stacked: Bool = false,
        showsLegend: Bool = true,
        valueFormat: FloatingPointFormatStyle<Double> = .number
    ) {
        self.bars = bars
        self.stacked = stacked
        self.showsLegend = showsLegend
        self.valueFormat = valueFormat
    }

    private var seriesNames: [String] {
        orderedSeriesNames(bars.map(\.series))
    }

    private var namedSeries: [String] {
        seriesNames.filter { !$0.isEmpty }
    }

    private var groups: [BarSeries] {
        seriesNames.enumerated().map { index, name in
            BarSeries(name: name, color: ChartPalette.color(forSeriesAt: index), bars: bars.filter { $0.series == name })
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if bars.isEmpty {
                ChartEmptyState()
            } else {
                Chart {
                    hoverRule
                    ForEach(groups) { group in
                        ForEach(group.bars) { bar in
                            barMark(bar, in: group)
                        }
                    }
                }
                .blissChartStyle()
                .chartOverlay { proxy in
                    BarHoverOverlay(
                        proxy: proxy,
                        hoveredCategory: $hoveredCategory,
                        values: hoveredValues,
                        valueFormat: valueFormat
                    )
                }
                .frame(minHeight: 160)
            }
            if showsLegend && namedSeries.count >= 2 {
                ChartLegend(series: namedSeries)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Marks

    private func barMark(_ bar: ChartBar, in group: BarSeries) -> some ChartContent {
        let mark = BarMark(x: .value("Category", bar.category), y: .value("Value", bar.value))
            .foregroundStyle(group.color)
            .cornerRadius(Sizing.radiusSmall)
            .accessibilityLabel(Text(verbatim: group.name.isEmpty ? bar.category : "\(bar.category), \(group.name)"))
            .accessibilityValue(Text(bar.value, format: valueFormat))
        return groupedIfNeeded(mark, series: group.name)
    }

    /// Side by side unless stacked; a lone series needs no grouping either way.
    @ChartContentBuilder
    private func groupedIfNeeded(_ mark: some ChartContent, series: String) -> some ChartContent {
        if stacked || seriesNames.count < 2 {
            mark
        } else {
            mark.position(by: .value("Series", series))
        }
    }

    @ChartContentBuilder
    private var hoverRule: some ChartContent {
        if let hoveredCategory {
            RuleMark(x: .value("Category", hoveredCategory))
                .foregroundStyle(Color.menuBorder)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    // MARK: Hover

    private var hoveredValues: [HoveredValue] {
        guard let hoveredCategory else { return [] }
        return groups.compactMap { group in
            guard let bar = group.bars.first(where: { $0.category == hoveredCategory }) else { return nil }
            return HoveredValue(name: group.name, color: group.color, value: bar.value)
        }
    }
}

/// The hover layer over a bar plot: the category under the pointer, and the
/// callout beside it.
private struct BarHoverOverlay: View {
    let proxy: ChartProxy
    @Binding var hoveredCategory: String?
    let values: [HoveredValue]
    let valueFormat: FloatingPointFormatStyle<Double>

    var body: some View {
        GeometryReader { geometry in
            let plotFrame = proxy.plotFrame.map { geometry[$0] } ?? .zero
            ChartHoverLayer(
                plotFrame: plotFrame,
                markX: hoveredCategory.flatMap { proxy.position(forX: $0) },
                callout: callout,
                onHover: { location in
                    guard let location else { return hoveredCategory = nil }
                    hoveredCategory = proxy.value(atX: location.x - plotFrame.minX)
                }
            )
        }
    }

    @ViewBuilder
    private var callout: some View {
        if let hoveredCategory {
            ChartCallout(title: Text(verbatim: hoveredCategory), values: values, valueFormat: valueFormat)
        }
    }
}

// MARK: - Previews

private enum ChartPreviewData {
    static let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

    static let visits: [ChartSample] = (0..<12).flatMap { day -> [ChartSample] in
        let date = Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
        return [
            ChartSample(date: date, value: 120 + Double((day * 37) % 80), series: "Web"),
            ChartSample(date: date, value: 60 + Double((day * 53) % 70), series: "App"),
        ]
    }

    static let downloads: [ChartBar] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].enumerated().flatMap { index, month in
        [
            ChartBar(category: month, value: Double(40 + (index * 23) % 50), series: "Mac"),
            ChartBar(category: month, value: Double(20 + (index * 31) % 40), series: "iPad"),
        ]
    }
}

#Preview("Line chart", traits: .fixedLayout(width: 520, height: 300)) {
    TimeSeriesChart(samples: ChartPreviewData.visits)
        .padding(Spacing.xl)
}

#Preview("Area chart", traits: .fixedLayout(width: 520, height: 300)) {
    TimeSeriesChart(.area, samples: ChartPreviewData.visits)
        .padding(Spacing.xl)
}

#Preview("Bar chart", traits: .fixedLayout(width: 520, height: 300)) {
    VStack(spacing: Spacing.lg) {
        BarChart(bars: ChartPreviewData.downloads)
        BarChart(bars: ChartPreviewData.downloads, stacked: true, showsLegend: false)
    }
    .padding(Spacing.xl)
}
