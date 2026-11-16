//
//  Sparkline.swift
//  BlissUI
//
//  A word-sized trend line: values evenly spaced across the frame and scaled
//  to fill its height, with an optional area wash and a dot on the newest
//  point. A missing value (nil) breaks the line — the points either side join
//  with a dashed track-colored segment, so a gap in the data is visible,
//  never interpolated over.
//

import SwiftUI

/// A small line chart of a series, normalized to its frame.
///
/// ```swift
/// Sparkline(dailyScores)                                   // [Double]
/// Sparkline(latency, fillsArea: true, color: Warning.warning500)
/// Sparkline([3, 5, nil, 4, 6], range: 0...10)              // a gap, a fixed scale
/// Sparkline(uptime, baseline: 99.9, showsExtremes: true)   // a target rule, the low and high dotted
/// ```
///
/// Give it a frame (`.frame(width: 120, height: 28)`); it fills whatever it's
/// offered. Without a `range`, the lowest value sits on the bottom edge and the
/// highest on the top; a flat series runs through the middle.
public struct Sparkline: View {
    private let values: [Double?]
    private let range: ClosedRange<Double>?
    private let color: Color
    private let lineWidth: CGFloat
    private let fillsArea: Bool
    private let showsLastPoint: Bool
    private let baseline: Double?
    private let showsExtremes: Bool
    private let smooths: Bool
    private let accessibilityLabel: LocalizedStringKey?
    private let valueFormat: (Double) -> String

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - values: The series, oldest first; nil marks a missing reading.
    ///   - range: A fixed scale (values outside it are pinned to its edges);
    ///     nil fits the series' own low and high.
    ///   - color: The line and the newest point — a mark. The area wash uses
    ///     its deep tint.
    ///   - lineWidth: The line's thickness.
    ///   - fillsArea: Washes the area under the line.
    ///   - showsLastPoint: Dots the newest value.
    ///   - baseline: A dashed rule at this value (a target, zero) in the track
    ///     color, so above and below read at a glance. Drawn only when it
    ///     falls inside the scale.
    ///   - showsExtremes: Dots the low and the high.
    ///   - smooths: Curves the line through the points instead of joining
    ///     them with straight segments (the chart's `.monotone` look).
    ///   - accessibilityLabel: What VoiceOver calls the chart ("Trend" when nil).
    ///   - valueFormat: Formats the latest, low and high values VoiceOver reads.
    public init(
        _ values: [Double?],
        range: ClosedRange<Double>? = nil,
        color: Color = Color.accent,
        lineWidth: CGFloat = DataMetrics.lineWidth,
        fillsArea: Bool = false,
        showsLastPoint: Bool = true,
        baseline: Double? = nil,
        showsExtremes: Bool = false,
        smooths: Bool = false,
        accessibilityLabel: LocalizedStringKey? = nil,
        valueFormat: @escaping (Double) -> String = { $0.formatted() }
    ) {
        self.values = values
        self.range = range
        self.color = color
        self.lineWidth = lineWidth
        self.fillsArea = fillsArea
        self.showsLastPoint = showsLastPoint
        self.baseline = baseline
        self.showsExtremes = showsExtremes
        self.smooths = smooths
        self.accessibilityLabel = accessibilityLabel
        self.valueFormat = valueFormat
    }

    private var dotDiameter: CGFloat { lineWidth * 2 + Spacing.hairline }

    /// Keeps the stroke and the dot inside the frame at the extremes.
    private var inset: CGFloat {
        max(lineWidth / 2, showsLastPoint || showsExtremes ? dotDiameter / 2 : 0)
    }

    public var body: some View {
        ZStack {
            if let baseline {
                SparklineShape(values: values, range: range, inset: inset, smooths: false, part: .baseline(baseline))
                    .stroke(DataTrack.color(colorScheme), style: StrokeStyle(lineWidth: 1, dash: [Spacing.xxs]))
            }
            if fillsArea {
                SparklineShape(values: values, range: range, inset: inset, smooths: smooths, part: .area)
                    .fill(LinearGradient(
                        colors: [color.statusTint.opacity(SparklineMetrics.areaWashOpacity(colorScheme)), color.statusTint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            SparklineShape(values: values, range: range, inset: inset, smooths: false, part: .gaps)
                .stroke(DataTrack.color(colorScheme), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [Spacing.xxs]))
            SparklineShape(values: values, range: range, inset: inset, smooths: smooths, part: .line)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            if showsExtremes {
                SparklineShape(values: values, range: range, inset: inset, smooths: false, part: .extremes(diameter: dotDiameter))
                    .fill(color)
            }
            if showsLastPoint {
                SparklineShape(values: values, range: range, inset: inset, smooths: false, part: .lastPoint(diameter: dotDiameter))
                    .fill(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel.map { Text($0) } ?? Text("Trend", bundle: .module))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        let readings = values.compactMap { $0 }.filter(\.isFinite)
        guard let latest = readings.last, let low = readings.min(), let high = readings.max() else {
            return Text("No data", bundle: .module)
        }
        return Text("Latest \(valueFormat(latest)), low \(valueFormat(low)), high \(valueFormat(high))", bundle: .module)
    }
}

/// The sparkline's drawing constants.
enum SparklineMetrics {
    /// The area wash's top opacity: a touch more on dark, where the deep tint
    /// sits close to the surface's own tone.
    static func areaWashOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.36 : 0.26
    }
}

// MARK: - Geometry

/// Where each value lands in the frame, pure so it's tested.
nonisolated enum SparklineGeometry {
    /// One point per value (nil stays nil), evenly spaced from the leading to
    /// the trailing edge and scaled so `range` (or the series' low…high) spans
    /// the height, both inset by `inset`. A single value sits at the trailing
    /// edge; a flat series, or a degenerate range, runs through the middle.
    static func points(for values: [Double?], in size: CGSize, range: ClosedRange<Double>?, inset: CGFloat) -> [CGPoint?] {
        let readings = values.compactMap { $0 }.filter(\.isFinite)
        guard let low = range?.lowerBound ?? readings.min(),
              let high = range?.upperBound ?? readings.max()
        else { return values.map { _ in nil } }
        let plotWidth = max(size.width - inset * 2, 0)
        let plotHeight = max(size.height - inset * 2, 0)
        let span = high - low
        return values.enumerated().map { index, value in
            guard let value, value.isFinite else { return nil }
            let x = values.count > 1
                ? inset + plotWidth * CGFloat(index) / CGFloat(values.count - 1)
                : inset + plotWidth
            let level = span > 0 ? min(max((value - low) / span, 0), 1) : 0.5
            return CGPoint(x: x, y: inset + plotHeight * CGFloat(1 - level))
        }
    }

    /// The y of `value` on the same scale as `points(for:)`, or nil when it
    /// falls outside the scale (a baseline off the chart isn't drawn).
    static func y(of value: Double, for values: [Double?], in size: CGSize, range: ClosedRange<Double>?, inset: CGFloat) -> CGFloat? {
        let readings = values.compactMap { $0 }.filter(\.isFinite)
        guard value.isFinite,
              let low = range?.lowerBound ?? readings.min(),
              let high = range?.upperBound ?? readings.max(),
              high > low, (low...high).contains(value)
        else { return nil }
        let plotHeight = max(size.height - inset * 2, 0)
        return inset + plotHeight * CGFloat(1 - (value - low) / (high - low))
    }

    /// The points split into unbroken runs (consecutive non-nil values).
    static func runs(_ points: [CGPoint?]) -> [[CGPoint]] {
        var runs: [[CGPoint]] = []
        var current: [CGPoint] = []
        for point in points {
            if let point {
                current.append(point)
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    /// The indices of the lowest and highest readings (the first of each on a tie).
    static func extremeIndices(of values: [Double?]) -> (low: Int, high: Int)? {
        let indexed = values.enumerated().compactMap { index, value -> (Int, Double)? in
            guard let value, value.isFinite else { return nil }
            return (index, value)
        }
        guard let low = indexed.min(by: { $0.1 < $1.1 }), let high = indexed.max(by: { $0.1 < $1.1 }) else { return nil }
        return (low.0, high.0)
    }
}

/// One layer of a sparkline, drawn from the same normalized points.
private nonisolated struct SparklineShape: Shape {
    nonisolated enum Part: Sendable {
        /// The unbroken runs.
        case line
        /// Dashed joins across missing values.
        case gaps
        /// Under each run, down to the bottom edge.
        case area
        /// A dot on the newest value.
        case lastPoint(diameter: CGFloat)
        /// Dots on the lowest and highest values.
        case extremes(diameter: CGFloat)
        /// A rule across the frame at a value.
        case baseline(Double)
    }

    let values: [Double?]
    let range: ClosedRange<Double>?
    let inset: CGFloat
    let smooths: Bool
    let part: Part

    func path(in rect: CGRect) -> Path {
        let points = SparklineGeometry.points(for: values, in: rect.size, range: range, inset: inset)
            .map { $0.map { CGPoint(x: $0.x + rect.minX, y: $0.y + rect.minY) } }
        let runs = SparklineGeometry.runs(points)
        var path = Path()
        switch part {
        case .line:
            for run in runs {
                addRun(run, to: &path)
            }
        case .gaps:
            for (before, after) in zip(runs, runs.dropFirst()) {
                if let start = before.last, let end = after.first {
                    path.move(to: start)
                    path.addLine(to: end)
                }
            }
        case .area:
            for run in runs where run.count > 1 {
                guard let first = run.first, let last = run.last else { continue }
                path.move(to: CGPoint(x: first.x, y: rect.maxY))
                path.addLine(to: first)
                addRun(run, to: &path, moving: false)
                path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
                path.closeSubpath()
            }
        case .lastPoint(let diameter):
            if let last = runs.last?.last {
                path.addEllipse(in: dot(at: last, diameter: diameter))
            }
        case .extremes(let diameter):
            if let extremes = SparklineGeometry.extremeIndices(of: values) {
                for index in Set([extremes.low, extremes.high]) {
                    if let point = points[index] {
                        path.addEllipse(in: dot(at: point, diameter: diameter))
                    }
                }
            }
        case .baseline(let value):
            if let y = SparklineGeometry.y(of: value, for: values, in: rect.size, range: range, inset: inset) {
                path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY + y))
                path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + y))
            }
        }
        return path
    }

    private func dot(at point: CGPoint, diameter: CGFloat) -> CGRect {
        CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
    }

    /// Straight segments, or a curve through the points: a Catmull-Rom
    /// spline written as cubic Béziers, which passes through every point and
    /// never overshoots far (the chart's monotone look at sparkline size).
    private func addRun(_ run: [CGPoint], to path: inout Path, moving: Bool = true) {
        guard let first = run.first else { return }
        if moving { path.move(to: first) }
        guard smooths, run.count > 2 else {
            if moving { path.addLines(run) } else { for point in run.dropFirst() { path.addLine(to: point) } }
            return
        }
        for index in 0..<(run.count - 1) {
            let previous = run[max(index - 1, 0)]
            let current = run[index]
            let next = run[index + 1]
            let after = run[min(index + 2, run.count - 1)]
            let control1 = CGPoint(x: current.x + (next.x - previous.x) / 6, y: current.y + (next.y - previous.y) / 6)
            let control2 = CGPoint(x: next.x - (after.x - current.x) / 6, y: next.y - (after.y - current.y) / 6)
            path.addCurve(to: next, control1: control1, control2: control2)
        }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 260, height: 190)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Sparkline([12, 14, 13, 17, 16, 19, 18, 22, 21, 24])
            .frame(width: 140, height: 28)
        Sparkline([0.91, 0.93, 0.9, 0.86, 0.88, 0.94, 0.95], color: Success.success500, fillsArea: true, smooths: true)
            .frame(width: 140, height: 28)
        Sparkline([5, 7, nil, nil, 6, 8, 4, 9], range: 0...10, color: Warning.warning500)
            .frame(width: 140, height: 28)
        Sparkline([99.95, 99.91, 99.97, 99.88, 99.99], baseline: 99.9, showsExtremes: true)
            .frame(width: 140, height: 28)
    }
    .padding(Spacing.xl)
}
