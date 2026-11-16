//
//  DataSupport.swift
//  BlissUI
//
//  Shared plumbing for the data and progress views: clamped fractions, the
//  percent format, the empty-track tone, the title/readout row over a bar, and
//  the whole-point width split that keeps a row of bars crisp.
//

import SwiftUI

// MARK: - Math

/// Pure geometry and number helpers behind the data views. `nonisolated` so
/// they're tested without a view. Public for the one constant a caller may
/// want (`lineWidth`); the helpers stay internal.
public nonisolated enum DataMetrics {
    /// The family's line: a sparkline, a chart's series, a commit lane.
    public static let lineWidth: CGFloat = 2

    /// How far a value's text may shrink before it truncates (a stat card's
    /// value, a ring's center, an avatar's initials).
    static let minimumScaleFactor: CGFloat = 0.7

    /// `value / total`, clamped to 0...1. A non-finite value, or a total of zero
    /// or less, is 0 — a bad reading draws an empty bar, never NaN geometry.
    static func fraction(_ value: Double, of total: Double) -> Double {
        guard value.isFinite, total.isFinite, total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    /// Whole percent, rounded DOWN: a task at 99.6% reads 99%, so 100% only
    /// ever means done (and a quota at 99.6% doesn't claim to be full).
    static var percentFormat: FloatingPointFormatStyle<Double>.Percent {
        .percent.precision(.fractionLength(0)).rounded(rule: .down)
    }

    /// Splits `available` whole points across `weights` in proportion, by
    /// largest remainder: every share is an integer and the shares sum to
    /// exactly `available`. Ties go to the earlier weight. Zero (or negative)
    /// weights get nothing.
    static func wholeShares(of available: Int, weights: [Double]) -> [Int] {
        let cleaned = weights.map { $0.isFinite ? max($0, 0) : 0 }
        let weightSum = cleaned.reduce(0, +)
        guard available > 0, weightSum > 0 else { return Array(repeating: 0, count: weights.count) }
        let quotas = cleaned.map { Double(available) * $0 / weightSum }
        var shares = quotas.map { Int($0.rounded(.down)) }
        var remainder = available - shares.reduce(0, +)
        let leftover = quotas.indices.map { quotas[$0] - Double(shares[$0]) }
        let byRemainder = quotas.indices
            .filter { cleaned[$0] > 0 }
            .sorted { leftover[$0] != leftover[$1] ? leftover[$0] > leftover[$1] : $0 < $1 }
        for index in byRemainder where remainder > 0 {
            shares[index] += 1
            remainder -= 1
        }
        return shares
    }
}

// MARK: - Thickness

/// How thick a `ProgressBar` or `UsageBar` is.
public nonisolated enum BarThickness: Hashable, Sendable, CaseIterable {
    /// 3pt — a bar inside a table row or a toast.
    case thin
    /// 6pt — the bar under a title.
    case regular
    /// 10pt — a bar that is the point of the card.
    case thick

    /// The bar's height in points.
    public var height: CGFloat {
        switch self {
        case .thin: 3
        case .regular: 6
        case .thick: 10
        }
    }
}

// MARK: - Readout

/// What a progress view writes beside (or inside) its bar or ring.
public enum ProgressReadout {
    /// Nothing.
    case none
    /// The whole percent, rounded down.
    case percentage
    /// Your own short text ("3/5"), looked up in your app's strings.
    case text(LocalizedStringKey)
}

// MARK: - Track

/// The unfilled part of a bar or ring: a faint wash of the label color, so it
/// sits on any surface and theme. Increase Contrast raises it, like the row
/// tints.
enum DataTrack {
    static func color(_ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return Color.primary.opacity(scheme == .dark ? 0.22 : 0.18) }
        return Color.primary.opacity(scheme == .dark ? 0.1 : 0.08)
    }
}

// MARK: - Header row

/// The title and trailing readout over a bar (`ProgressBar`'s label and
/// percentage, `UsageBar`'s title and total). Both sides are optional; the row
/// is skipped when neither is set.
struct DataHeaderRow<Readout: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let readout: () -> Readout

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            if let title {
                Text(title)
                    .font(Typography.labelSmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            readout()
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
