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
    private let accessibilityLabel: LocalizedStringKey?

    /// Ripple toggle: flipped off without animation, back on with it, so the
    /// ticks sweep in whenever a refresh releases or a reading changes.
    @State private var revealed = true

    /// - Parameters:
    ///   - ticks: One per period, oldest first.
    ///   - tickWidth: Each tick's width, in whole points.
    ///   - spacing: The gap between ticks, in whole points.
    ///   - height: The ticks' height.
    ///   - isRefreshing: Dims and desaturates the strip while a new reading is
    ///     on its way.
    ///   - accessibilityLabel: What VoiceOver calls the strip; each tick reads
    ///     its own label inside it.
    public init(
        _ ticks: [Tick],
        tickWidth: CGFloat = 2,
        spacing: CGFloat = 2,
        height: CGFloat = 12,
        isRefreshing: Bool = false,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.ticks = ticks
        self.tickWidth = tickWidth
        self.spacing = spacing
        self.height = height
        self.isRefreshing = isRefreshing
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { index, tick in
                tickView(tick, at: index)
            }
        }
        // Each tick's hover slot spans half a gap either side (see `tickView`);
        // pulling the row in by that half-gap keeps the strip's own width at
        // exactly ticks + gaps, its first tick flush with the leading edge.
        .padding(.horizontal, -spacing / 2)
        .grayscale(isRefreshing ? 0.85 : 0)
        .opacity(isRefreshing ? 0.6 : 1)
        .animation(Animations.pane, value: isRefreshing)
        // Value-based (not count-based): a same-period refresh REPLACES the
        // newest tick, so the count is unchanged but the tick moved — still
        // ripple.
        .onChange(of: ticks) { _, _ in ripple() }
        .onChange(of: isRefreshing) { _, refreshing in if !refreshing { ripple() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel.map { Text($0) } ?? Text(verbatim: ""), isEnabled: accessibilityLabel != nil)
    }

    private func tickView(_ tick: Tick, at index: Int) -> some View {
        Capsule(style: .continuous)
            .fill(tick.color ?? Self.emptyTickColor)
            .frame(width: tickWidth, height: height)
            .opacity(revealed ? 1 : 0)
            // Leading-to-trailing ripple on reveal; all at once under Reduce
            // Motion (a plain fade).
            .animation(
                Animations.pane.delay(prefersReducedMotion ? 0 : Double(index) * 0.02),
                value: revealed
            )
            // A 2pt tick is too thin to hover: the slot takes half a gap from
            // each side, so the whole strip hovers tick by tick.
            .frame(width: tickWidth + spacing, height: height)
            .contentShape(Rectangle())
            .tooltip(configuration: .iconHint, position: .above) {
                Text(verbatim: tick.label).font(Typography.labelSmall)
            }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: tick.label))
    }

    /// A period with no reading: a dim track tick.
    private static var emptyTickColor: Color {
        Color.primary.opacity(prefersIncreasedContrast ? 0.25 : 0.12)
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

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 240, height: 100)) {
    let pattern: [Color?] = [
        Success.success500, Success.success500, nil, Success.success500, Warning.warning500,
        Warning.warning500, Success.success500, Success.success500, Success.success500, nil,
        nil, Danger.danger500, Warning.warning500, Success.success500, Success.success500,
        Success.success500, Success.success500, Warning.warning500, Success.success500, Success.success500,
    ]
    VStack(alignment: .leading, spacing: Spacing.md) {
        TickStrip(pattern.enumerated().map { day, color in
            TickStrip.Tick(color: color, label: color == nil ? "Day \(day + 1) · No reading" : "Day \(day + 1)")
        })
        TickStrip(pattern.map { TickStrip.Tick(color: $0, label: "") }, tickWidth: 3, spacing: 2, height: 16, isRefreshing: true)
    }
    .padding(Spacing.xl)
}
