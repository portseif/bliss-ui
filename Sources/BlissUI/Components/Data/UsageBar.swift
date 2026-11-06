//
//  UsageBar.swift
//  BlissUI
//
//  A capacity bar: stacked colored segments (what's using the space) over a
//  faint track (what's left), with an optional title + total above it and a
//  legend below. Or a single meter that warns as it fills — amber past 75%,
//  red past 90%.
//
//  Segment widths are whole points that sum exactly to the filled width: a row
//  of fractional widths anti-aliases its edges unevenly, so neighbouring
//  segments look like they have different gaps.
//

import SwiftUI

/// A stacked usage bar, or a single meter.
///
/// ```swift
/// UsageBar([
///     UsageBar.Segment("Apps", value: 48, color: Color.accent),
///     UsageBar.Segment("Photos", value: 31, color: Info.info500),
///     UsageBar.Segment("System", value: 18, color: Grey.grey400),
/// ], capacity: 256, title: "Storage", showsTotal: true, showsLegend: true) { "\($0.formatted()) GB" }
///
/// UsageBar(value: entries, capacity: maxEntries)   // accent, then amber, then red
/// ```
public struct UsageBar: View {
    /// One stacked segment: a part of the total in its own color.
    public struct Segment {
        public var label: LocalizedStringKey
        public var value: Double
        public var color: Color

        /// - Parameters:
        ///   - label: The legend's name for it, looked up in your app's strings.
        ///   - value: How much it uses, in the same unit as the bar's capacity.
        ///   - color: Its fill and legend dot — a mark (a status `*500`, the
        ///     accent, a `Grey`), not a `tint`.
        public init(_ label: LocalizedStringKey, value: Double, color: Color) {
            self.label = label
            self.value = value
            self.color = color
        }
    }

    private let segments: [Segment]
    private let capacity: Double?
    private let title: LocalizedStringKey?
    private let showsTotal: Bool
    private let showsLegend: Bool
    private let height: CGFloat
    private let spacing: CGFloat
    private let valueFormat: (Double) -> String
    /// Set by the meter initializer: one segment whose color follows its level.
    private let isMeter: Bool

    @Environment(\.colorScheme) private var colorScheme

    /// A stacked bar.
    /// - Parameters:
    ///   - segments: The parts, leading to trailing.
    ///   - capacity: The value of a full bar; nil scales the segments to fill it
    ///     (a pure breakdown). Segments past the capacity are clipped.
    ///   - title: A title above the bar, looked up in your app's strings. Also
    ///     what VoiceOver calls the bar ("Usage" when nil).
    ///   - showsTotal: Shows "used of capacity" (or the total) above the bar's
    ///     trailing end.
    ///   - showsLegend: Lists each segment's dot, label and value under the bar.
    ///   - height: The bar's thickness.
    ///   - spacing: The gap between segments, in whole points.
    ///   - valueFormat: Formats a value for the legend, the total and VoiceOver
    ///     (add your unit here: `{ "\($0.formatted()) GB" }`).
    public init(
        _ segments: [Segment],
        capacity: Double? = nil,
        title: LocalizedStringKey? = nil,
        showsTotal: Bool = false,
        showsLegend: Bool = false,
        height: CGFloat = 6,
        spacing: CGFloat = 2,
        valueFormat: @escaping (Double) -> String = { $0.formatted() }
    ) {
        self.segments = segments
        self.capacity = capacity
        self.title = title
        self.showsTotal = showsTotal
        self.showsLegend = showsLegend
        self.height = height
        self.spacing = spacing
        self.valueFormat = valueFormat
        self.isMeter = false
    }

    /// A single meter (entries of a limit, bytes of a quota). Accent while
    /// there's room, amber past 75%, red past 90%.
    /// - Parameters:
    ///   - value: How much is used.
    ///   - capacity: The limit.
    ///   - title: A title above the bar, looked up in your app's strings.
    ///   - showsTotal: Shows "value of capacity" above the bar's trailing end.
    ///   - height: The bar's thickness.
    ///   - valueFormat: Formats the total's numbers.
    public init(
        value: Double,
        capacity: Double,
        title: LocalizedStringKey? = nil,
        showsTotal: Bool = false,
        height: CGFloat = 6,
        valueFormat: @escaping (Double) -> String = { $0.formatted() }
    ) {
        let level = UsageBarLayout.MeterLevel(fraction: DataMetrics.fraction(value, of: capacity))
        // The label only feeds a legend, which a meter never shows.
        self.segments = [Segment(title ?? .verbatim(""), value: value, color: level.color)]
        self.capacity = capacity
        self.title = title
        self.showsTotal = showsTotal
        self.showsLegend = false
        self.height = height
        self.spacing = 0
        self.valueFormat = valueFormat
        self.isMeter = true
    }

    private var usedTotal: Double {
        segments.reduce(0) { $0 + max($1.value, 0) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if title != nil || showsTotal {
                DataHeaderRow(title: title) {
                    if showsTotal { totalText }
                }
            }
            bar
            if showsLegend && !segments.isEmpty {
                legend
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title.map { Text($0) } ?? Text("Usage", bundle: .module))
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Bar

    private var bar: some View {
        GeometryReader { proxy in
            // Whole points only — the bar is at most a point short of its
            // container, which nobody sees; uneven segment edges they do.
            let barWidth = proxy.size.width.rounded(.down)
            let widths = UsageBarLayout.segmentWidths(
                values: segments.map(\.value),
                capacity: capacity,
                barWidth: barWidth,
                spacing: spacing
            )
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DataTrack.color(colorScheme))
                HStack(spacing: spacing) {
                    ForEach(segments.indices, id: \.self) { index in
                        if widths[index] > 0 {
                            Rectangle()
                                .fill(segments[index].color)
                                .frame(width: widths[index])
                        }
                    }
                }
                // Only the run's two ends round; joins stay square.
                .clipShape(Capsule(style: .continuous))
                .animation(prefersReducedMotion ? nil : Animations.disclosure, value: widths)
            }
            .frame(width: barWidth, alignment: .leading)
        }
        .frame(height: height)
    }

    // MARK: - Total

    @ViewBuilder
    private var totalText: some View {
        let used = valueFormat(usedTotal)
        if let capacity {
            Text("\(used) of \(valueFormat(capacity))", bundle: .module)
        } else {
            Text("\(used) total", bundle: .module)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                    Text(segment.label)
                        .foregroundStyle(.secondary)
                    Text(verbatim: valueFormat(segment.value))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .font(Typography.captionSmall)
                .lineLimit(1)
                // A wider gap between items than between lines.
                .padding(.trailing, Spacing.xs)
            }
        }
    }

    // MARK: - Accessibility

    /// "62% used, Apps: 48 GB, Photos: 31 GB" — or the breakdown alone when
    /// there's no capacity to be a share of.
    private var accessibilityValue: Text {
        var parts: [Text] = []
        if let capacity {
            let fraction = DataMetrics.fraction(usedTotal, of: capacity)
            parts.append(Text("\(fraction, format: DataMetrics.percentFormat) used", bundle: .module))
        }
        if !isMeter {
            parts += segments.map { segment in
                Text("\(Text(segment.label)): \(valueFormat(segment.value))", bundle: .module)
            }
        }
        guard var joined = parts.first else { return Text("No data", bundle: .module) }
        for part in parts.dropFirst() {
            joined = Text("\(joined), \(part)", bundle: .module)
        }
        return joined
    }
}

// MARK: - Layout

/// The usage bar's width math and meter thresholds, pure so they're tested.
nonisolated enum UsageBarLayout {
    /// Whole-point widths for each value, in input order. The drawn segments
    /// plus the gaps between them sum exactly to the filled width
    /// (`barWidth × used / capacity`, rounded); a value too small to earn a
    /// whole point gets 0 and isn't drawn (it stays in the legend).
    static func segmentWidths(values: [Double], capacity: Double?, barWidth: CGFloat, spacing: CGFloat) -> [CGFloat] {
        let cleaned = values.map { $0.isFinite ? max($0, 0) : 0 }
        let usedTotal = cleaned.reduce(0, +)
        let scale = capacity ?? usedTotal
        let wholeWidth = Int(max(barWidth, 0).rounded(.down))
        let filledWidth = Int((Double(wholeWidth) * DataMetrics.fraction(usedTotal, of: scale)).rounded())
        let gap = Int(max(spacing, 0).rounded())

        // Each pass drops any segment that earned no width, which frees its gap
        // for the rest; settles in at most one pass per segment.
        var drawn = cleaned.indices.filter { cleaned[$0] > 0 }
        while !drawn.isEmpty {
            let available = filledWidth - gap * (drawn.count - 1)
            let shares = DataMetrics.wholeShares(of: max(available, 0), weights: drawn.map { cleaned[$0] })
            let kept = zip(drawn, shares).filter { $0.1 > 0 }
            if kept.count == drawn.count {
                var widths = Array(repeating: CGFloat(0), count: values.count)
                for (index, share) in kept { widths[index] = CGFloat(share) }
                return widths
            }
            if kept.isEmpty {
                // Too narrow for even one gap: the largest segment takes the run.
                guard filledWidth > 0, let largest = drawn.max(by: { cleaned[$0] < cleaned[$1] }) else { break }
                drawn = [largest]
            } else {
                drawn = kept.map(\.0)
            }
        }
        return Array(repeating: 0, count: values.count)
    }

    /// How full a meter is, for its color.
    nonisolated enum MeterLevel: Equatable, Sendable {
        case normal, warning, critical

        init(fraction: Double) {
            if fraction > 0.9 {
                self = .critical
            } else if fraction > 0.75 {
                self = .warning
            } else {
                self = .normal
            }
        }

        @MainActor var color: Color {
            switch self {
            case .normal: return Color.accent
            case .warning: return Warning.warning500
            case .critical: return Danger.danger500
            }
        }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 380, height: 220)) {
    VStack(alignment: .leading, spacing: Spacing.xl) {
        UsageBar([
            UsageBar.Segment("Apps", value: 48, color: Color.accent),
            UsageBar.Segment("Photos", value: 31, color: Info.info500),
            UsageBar.Segment("Mail", value: 9, color: Warning.warning500),
            UsageBar.Segment("System", value: 18, color: Grey.grey400),
        ], capacity: 256, title: "Storage", showsTotal: true, showsLegend: true) { "\($0.formatted()) GB" }
        UsageBar(value: 412, capacity: 500, title: "Log entries", showsTotal: true)
        UsageBar(value: 96, capacity: 100)
    }
    .padding(Spacing.xl)
}
