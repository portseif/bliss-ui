import Charts
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the themed charts, built the
/// way an app would build them.
@MainActor
@Suite struct ChartsAPITests {
    private var samples: [ChartSample] {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        return (0..<6).flatMap { day -> [ChartSample] in
            let date = start.addingTimeInterval(Double(day) * 86_400)
            return [
                ChartSample(date: date, value: Double(day * 3), series: "Web"),
                ChartSample(date: date, value: Double(day * 2), series: "App"),
            ]
        }
    }

    private var bars: [ChartBar] {
        [
            ChartBar(category: "Jan", value: 40, series: "Mac"),
            ChartBar(category: "Jan", value: 20, series: "iPad"),
            ChartBar(category: "Feb", value: 55, series: "Mac"),
            ChartBar(category: "Feb", value: 30, series: "iPad"),
        ]
    }

    @Test func dataTypesKeepTheirValues() {
        let sample = ChartSample(date: Date(timeIntervalSince1970: 0), value: 4.5, series: "Web")
        #expect(sample.value == 4.5)
        #expect(sample.series == "Web")
        let single = ChartSample(date: Date(), value: 1)
        #expect(single.series.isEmpty)
        let bar = ChartBar(category: "Jan", value: 40)
        #expect(bar.category == "Jan")
        #expect(bar.series.isEmpty)
        let kinds: [TimeSeriesChartKind] = [.line, .area]
        #expect(kinds.count == 2)
    }

    @Test func timeSeriesChartsAreReachable() {
        _ = TimeSeriesChart(samples: samples)
        _ = TimeSeriesChart(.area, samples: samples, showsLegend: false)
        _ = TimeSeriesChart(.line, samples: samples, valueFormat: .number.precision(.fractionLength(1)))
        _ = TimeSeriesChart(samples: [])
    }

    @Test func barChartsAreReachable() {
        _ = BarChart(bars: bars)
        _ = BarChart(bars: bars, stacked: true, showsLegend: false)
        _ = BarChart(bars: bars, valueFormat: .number.precision(.fractionLength(0)))
        _ = BarChart(bars: [])
    }

    @Test func legendAndPaletteAreReachable() {
        _ = ChartLegend(series: ["Web", "App"])
        #expect(ChartPalette.series.count >= 6)
    }

    @Test func styleAppliesToAnyChart() {
        _ = Chart {
            LineMark(x: .value("Day", 1), y: .value("Value", 2))
        }
        .blissChartStyle()
    }
}
