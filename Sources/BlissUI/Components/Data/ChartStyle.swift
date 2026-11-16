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

// MARK: - Style

extension View {
    /// The library's chart look for a `Chart` you build yourself: no legend
    /// (draw a `ChartLegend`), `menuBorder` grid lines on the value axis,
    /// caption labels on both axes, no plot background.
    public func blissChartStyle() -> some View {
        modifier(BlissChartStyle())
    }
}

private struct BlissChartStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.menuBorder)
                    AxisValueLabel()
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.clear)
            }
    }
}

// MARK: - Legend

/// Dots in the series colors with the series names, in order.
public struct ChartLegend: View {
    private let series: [String]

    /// - Parameter series: The names, in the order the chart colors them.
    public init(series: [String]) {
        self.series = series
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(Array(series.enumerated()), id: \.offset) { index, name in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(ChartPalette.color(forSeriesAt: index))
                        .frame(width: 8, height: 8)
                    Text(verbatim: name)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
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
/// cursor, flipped to its left near the trailing edge so it stays inside.
struct ChartHoverLayer<Callout: View>: View {
    let plotFrame: CGRect
    /// The cursor's x within the plot, when there is one.
    let markX: CGFloat?
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
            if let markX {
                callout
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { calloutSize = $0 }
                    .position(calloutPosition(markX: markX))
                    .allowsHitTesting(false)
            }
        }
    }

    private func calloutPosition(markX: CGFloat) -> CGPoint {
        let cursorX = plotFrame.minX + markX
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
                        .frame(width: 6, height: 6)
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
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}

/// What an empty chart shows in place of its plot.
struct ChartEmptyState: View {
    var body: some View {
        Text("No data", bundle: .module)
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 160)
    }
}
