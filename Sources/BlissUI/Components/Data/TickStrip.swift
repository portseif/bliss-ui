//
//  TickStrip.swift
//  BlissUI
//
//  One thin tick per period (a day, a run, a deploy), oldest at the leading
//  edge, each colored by that period's state, with a dim track tick for a
//  period that has no reading — never interpolated over. Hovering a tick shows
//  its label. Every strip shares the same encoding (no per-row scaling), so a
//  column of them compares across rows.
//

import SwiftUI

/// A row of state-colored ticks, one per period.
///
/// ```swift
/// TickStrip(days.map { day in
///     TickStrip.Tick(color: day.score.map(bandColor), label: "\(day.date.formatted(.dateTime.month().day())) · \(day.summary)")
/// }, accessibilityLabel: "Health, last 20 days")
/// ```
///
/// Geometry is whole points on purpose: 20 ticks × 2pt + 19 gaps × 2pt is
/// exactly 78pt, so every tick edge lands on a whole pixel (a fractional width
/// lets anti-aliasing draw some ticks fatter than others). While
/// `isRefreshing`, the strip desaturates and dims; when it ends, or the ticks
/// change, they ripple back in leading to trailing.
public struct TickStrip: View {
    /// One period.
    public nonisolated struct Tick: Equatable, Sendable {
        /// Its state's color — a mark, like a status dot. nil: no reading for
        /// this period, drawn as a dim track tick.
        public var color: Color?
        /// Shown on hover and read by VoiceOver: the period and its state
        /// ("Mar 3 · Healthy"). Already localized — it's shown as-is.
        public var label: String

        public init(color: Color?, label: String) {
            self.color = color
            self.label = label
        }
    }

    private let ticks: [Tick]
    private let tickWidth: CGFloat
    private let spacing: CGFloat
    private let height: CGFloat
    private let isRefreshing: Bool
    private let highlightedIndex: Int?
    private let fillsWidth: Bool
    private let onSelect: ((Int) -> Void)?
    private let accessibilityLabel: LocalizedStringKey?

    /// Ripple toggle: flipped off without animation, back on with it, so the
    /// ticks sweep in whenever a refresh releases or a reading changes.
    @State private var revealed = true
    @State private var availableWidth: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - ticks: One per period, oldest first.
    ///   - tickWidth: Each tick's width, in whole points.
    ///   - spacing: The gap between ticks, in whole points.
    ///   - height: The ticks' height.
    ///   - isRefreshing: Dims and desaturates the strip while a new reading is
    ///     on its way.
    ///   - highlightedIndex: The tick drawn a step taller (today, the current run).
    ///   - fillsWidth: Widens the ticks to split the container's whole points
    ///     between them, for a table column; the gaps stay as given.
    ///   - onSelect: A click on a tick, with its index; nil leaves them inert.
    ///   - accessibilityLabel: What VoiceOver calls the strip; each tick reads
    ///     its own label inside it.
    public init(
        _ ticks: [Tick],
        tickWidth: CGFloat = TickStripMetrics.tickWidth,
        spacing: CGFloat = TickStripMetrics.spacing,
        height: CGFloat = TickStripMetrics.height,
        isRefreshing: Bool = false,
        highlightedIndex: Int? = nil,
        fillsWidth: Bool = false,
        onSelect: ((Int) -> Void)? = nil,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.ticks = ticks
        self.tickWidth = tickWidth
        self.spacing = spacing
        self.height = height
        self.isRefreshing = isRefreshing
        self.highlightedIndex = highlightedIndex
        self.fillsWidth = fillsWidth
        self.onSelect = onSelect
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let widths = tickWidths
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { index, tick in
                tickView(tick, at: index, width: widths[index])
            }
        }
        // Each tick's hover slot spans half a gap either side (see `tickView`);
        // pulling the row in by that half-gap keeps the strip's own width at
        // exactly ticks + gaps, its first tick flush with the leading edge.
        .padding(.horizontal, -spacing / 2)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .grayscale(isRefreshing ? TickStripMetrics.refreshingGrayscale : 0)
        .opacity(isRefreshing ? TickStripMetrics.refreshingOpacity : 1)
        .animation(Animations.pane, value: isRefreshing)
        // Value-based (not count-based): a same-period refresh REPLACES the
        // newest tick, so the count is unchanged but the tick moved — still
        // ripple.
        .onChange(of: ticks) { _, _ in ripple() }
        .onChange(of: isRefreshing) { _, refreshing in if !refreshing { ripple() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel.map { Text($0) } ?? Text(verbatim: ""), isEnabled: accessibilityLabel != nil)
    }

    /// Each tick's width: as given, or the container's whole points split
    /// between the ticks with the gaps kept.
    private var tickWidths: [CGFloat] {
        guard fillsWidth, availableWidth > 0, !ticks.isEmpty else {
            return Array(repeating: tickWidth, count: ticks.count)
        }
        let room = Int(availableWidth.rounded(.down)) - Int(spacing) * (ticks.count - 1)
        let shares = DataMetrics.wholeShares(of: max(room, ticks.count), weights: Array(repeating: 1, count: ticks.count))
        return shares.map { CGFloat(max($0, 1)) }
    }

    private func tickView(_ tick: Tick, at index: Int, width: CGFloat) -> some View {
        let tickHeight = index == highlightedIndex ? height + TickStripMetrics.highlightRise : height
        return Group {
            if let onSelect {
                Button { onSelect(index) } label: {
                    tickShape(tick, width: width, height: tickHeight)
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: Spacing.hairline))
            } else {
                tickShape(tick, width: width, height: tickHeight)
            }
        }
        .opacity(revealed ? 1 : 0)
        // Leading-to-trailing ripple on reveal; all at once under Reduce
        // Motion (a plain fade).
        .animation(
            Animations.pane.delay(prefersReducedMotion ? 0 : Double(index) * TickStripMetrics.rippleStagger),
            value: revealed
        )
        // A 2pt tick is too thin to hover: the slot takes half a gap from
        // each side, so the whole strip hovers tick by tick.
        .frame(width: width + spacing, height: height + TickStripMetrics.highlightRise, alignment: .bottom)
        .contentShape(Rectangle())
        .tooltip(configuration: .iconHint, position: .above) {
            Text(verbatim: tick.label).font(Typography.labelSmall)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: tick.label))
        .accessibilityAddTraits(index == highlightedIndex ? [.isSelected] : [])
    }

    private func tickShape(_ tick: Tick, width: CGFloat, height: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(tick.color ?? DataTrack.color(colorScheme))
            .frame(width: width, height: height)
    }

    /// Hide instantly (no animation), then reveal on the next runloop so the
    /// ripple runs from a clean slate.
    private func ripple() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { revealed = false }
        DispatchQueue.main.async { revealed = true }
    }

    /// The strip's width: every tick plus the gaps between them.
    nonisolated static func width(tickCount: Int, tickWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        guard tickCount > 0 else { return 0 }
        return CGFloat(tickCount) * tickWidth + CGFloat(tickCount - 1) * spacing
    }
}

/// The strip's defaults: whole points, so a 20-tick strip is exactly 78pt.
public enum TickStripMetrics {
    /// 2pt — a tick.
    public static let tickWidth: CGFloat = Spacing.hairline
    /// 2pt — the gap between ticks.
    public static let spacing: CGFloat = Spacing.hairline
    /// 12pt — a tick's height.
    public static let height: CGFloat = Sizing.iconTiny
    /// How much taller the highlighted tick stands.
    static let highlightRise: CGFloat = Spacing.xxs
    /// The refreshing look: desaturated and dimmed.
    static let refreshingGrayscale: Double = 0.85
    static let refreshingOpacity: Double = 0.6
    /// The delay between neighbouring ticks' reveal.
    static let rippleStagger: TimeInterval = 0.02
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 240, height: 120)) {
    let pattern: [Color?] = [
        Success.success500, Success.success500, nil, Success.success500, Warning.warning500,
        Warning.warning500, Success.success500, Success.success500, Success.success500, nil,
        nil, Danger.danger500, Warning.warning500, Success.success500, Success.success500,
        Success.success500, Success.success500, Warning.warning500, Success.success500, Success.success500,
    ]
    VStack(alignment: .leading, spacing: Spacing.md) {
        TickStrip(pattern.enumerated().map { day, color in
            TickStrip.Tick(color: color, label: color == nil ? "Day \(day + 1) · No reading" : "Day \(day + 1)")
        }, highlightedIndex: 19)
        TickStrip(pattern.map { TickStrip.Tick(color: $0, label: "") }, tickWidth: 3, spacing: 2, height: 16, isRefreshing: true)
        TickStrip(pattern.map { TickStrip.Tick(color: $0, label: "") }, fillsWidth: true)
    }
    .padding(Spacing.xl)
}
