//
//  ChartStyle.swift
//  BlissUI
//
//  What the charts share: the series palette, the `.blissChartStyle()` look
//  for any Swift Chart, the legend, and the hover layer with its callout card.
//

import Charts
import SwiftUI

// MARK: - Palette

/// The series colors, in the order series appear.
public enum ChartPalette {
    /// Accent first, then the status marks, then grey. Computed on access: the
    /// marks follow the theme.
    public static var series: [Color] {
        [Color.accent, Info.info500, Success.success500, Warning.warning500, Danger.danger500, Grey.grey500]
    }

    static func color(forSeriesAt index: Int) -> Color {
        let palette = series
        return palette[index % palette.count]
    }
}

/// The charts' drawing constants.
enum ChartMetrics {
    /// A bar's corners.
    static let barCornerRadius: CGFloat = Sizing.radiusSmall
    /// The hover point's area (Swift Charts sizes symbols by area, not diameter): about 7pt across.
    static let hoverPointArea: CGFloat = 40
    /// The area wash under a series' line: on the tint, never the lifted mark.
    static let areaWashOpacity: Double = 0.15
}

// MARK: - Style

extension View {
    /// The library's chart look for a `Chart` you build yourself: no legend
    /// (draw a `ChartLegend`), `menuBorder` grid lines on the value axis,
    /// caption labels on both axes, no plot background.
    /// - Parameters:
    ///   - showsAxes: The axis labels; off for a chart inside a card or a tile.
    ///   - showsGrid: The value axis's grid lines.
    public func blissChartStyle(showsAxes: Bool = true, showsGrid: Bool = true) -> some View {
        modifier(BlissChartStyle(showsAxes: showsAxes, showsGrid: showsGrid))
    }
}

private struct BlissChartStyle: ViewModifier {
    let showsAxes: Bool
    let showsGrid: Bool

    func body(content: Content) -> some View {
        content
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    if showsAxes {
                        AxisValueLabel()
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    if showsGrid {
                        AxisGridLine()
                            .foregroundStyle(Color.menuBorder)
                    }
                    if showsAxes {
                        AxisValueLabel()
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.clear)
            }
    }
}

// MARK: - Legend

/// Dots in the series colors with the series names, in order. Wraps onto
/// more lines when the names don't fit.
public struct ChartLegend: View {
    private let series: [String]
    private let colors: [Color]?

    /// - Parameters:
    ///   - series: The names, in the order the chart colors them.
    ///   - colors: The series' colors, when a chart of your own assigns them;
    ///     nil takes `ChartPalette.series` in order.
    public init(series: [String], colors: [Color]? = nil) {
        self.series = series
        self.colors = colors
    }

    public var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(Array(series.enumerated()), id: \.offset) { index, name in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(color(at: index))
                        .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                    Text(verbatim: name)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                // A wider gap between items than between lines.
                .padding(.trailing, Spacing.xs)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func color(at index: Int) -> Color {
        if let colors, !colors.isEmpty { return colors[index % colors.count] }
        return ChartPalette.color(forSeriesAt: index)
    }
}

/// One value under the hover cursor.
struct HoveredValue: Identifiable {
    let name: String
    let color: Color
    let value: Double
    var id: String { name }
}


// MARK: - Hover plumbing

/// Tracks the pointer over the chart and places the callout beside the
/// cursor, flipped to its left near the trailing edge so it stays inside. A
/// horizontal chart passes `markY` instead: the callout sits beside the bar.
struct ChartHoverLayer<Callout: View>: View {
    let plotFrame: CGRect
    /// The cursor's x within the plot, when there is one.
    var markX: CGFloat? = nil
    /// The cursor's y within the plot (horizontal bars).
    var markY: CGFloat? = nil
    let callout: Callout
    /// The pointer's location in this layer, or nil when it left.
    let onHover: (CGPoint?) -> Void

    @State private var calloutSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        if plotFrame.contains(location) {
                            onHover(location)
                        } else {
                            onHover(nil)
                        }
                    case .ended:
                        onHover(nil)
                    }
                }
            if markX != nil || markY != nil {
                callout
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { calloutSize = $0 }
                    .position(calloutPosition())
                    .allowsHitTesting(false)
            }
        }
    }

    private func calloutPosition() -> CGPoint {
        if let markY {
            // Beside the bar, inside the plot's trailing half if it fits there.
            let cursorY = plotFrame.minY + markY
            let x = plotFrame.midX + Spacing.sm + calloutSize.width / 2 <= plotFrame.maxX
                ? plotFrame.midX + Spacing.sm + calloutSize.width / 2
                : plotFrame.maxX - calloutSize.width / 2
            let y = min(max(cursorY, plotFrame.minY + calloutSize.height / 2), plotFrame.maxY - calloutSize.height / 2)
            return CGPoint(x: x, y: y)
        }
        let cursorX = plotFrame.minX + (markX ?? 0)
        let fitsOnRight = cursorX + Spacing.sm + calloutSize.width <= plotFrame.maxX
        let x = fitsOnRight
            ? cursorX + Spacing.sm + calloutSize.width / 2
            : cursorX - Spacing.sm - calloutSize.width / 2
        let y = plotFrame.minY + Spacing.sm + calloutSize.height / 2
        return CGPoint(x: x, y: y)
    }
}

/// The card beside the cursor: the x value, then each series' value with its dot.
struct ChartCallout: View {
    let title: Text
    let values: [HoveredValue]
    let valueFormat: FloatingPointFormatStyle<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            title
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(.primary)
            ForEach(values) { value in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(value.color)
                        .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                    if !value.name.isEmpty {
                        Text(verbatim: value.name)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: Spacing.sm)
                    }
                    Text(value.value, format: valueFormat)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
                .font(Typography.captionSmall)
            }
        }
        .padding(Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                .fill(Color.controlBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .elevation(.lift)
        .accessibilityHidden(true)
    }
}

/// What an empty chart shows in place of its plot.
struct ChartEmptyState: View {
    var minHeight: CGFloat = Sizing.chartMinimumHeight

    var body: some View {
        Text("No data", bundle: .module)
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}
