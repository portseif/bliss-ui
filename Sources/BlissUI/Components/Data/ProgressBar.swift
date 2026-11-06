//
//  ProgressBar.swift
//  BlissUI
//
//  A thin, tintable progress bar: determinate (the fill springs to each new
//  value) or indeterminate (a segment sweeping across the track). Optional
//  label and percentage above it. Native `ProgressView` can't be tinted on
//  macOS, so this is the bar to use; `ThinkingSpinner` stays the one spinner.
//

import SwiftUI

/// A determinate or indeterminate progress bar.
///
/// ```swift
/// ProgressBar(value: uploaded, total: fileCount, label: "Uploading", showsPercentage: true)
/// ProgressBar(value: nil, label: "Preparing…")          // indeterminate
/// ProgressBar(value: 0.8, tint: Success.success500)
/// ```
///
/// The fill is a mark, like a status dot: pass a status `*500` or the accent,
/// not a `tint`. Under Reduce Motion value changes land without the spring
/// and the indeterminate segment holds still in the middle of the track.
public struct ProgressBar: View {
    private let value: Double?
    private let total: Double
    private let label: LocalizedStringKey?
    private let showsPercentage: Bool
    private let tint: Color
    private let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - value: Progress toward `total`; nil shows the indeterminate sweep.
    ///     Clamped to the track.
    ///   - total: The value that fills the bar.
    ///   - label: A title above the bar, looked up in your app's strings. Also
    ///     what VoiceOver calls the bar ("Progress" when nil).
    ///   - showsPercentage: Shows the whole percent above the bar's trailing
    ///     end (determinate only).
    ///   - tint: The fill.
    ///   - height: The bar's thickness.
    public init(
        value: Double?,
        total: Double = 1,
        label: LocalizedStringKey? = nil,
        showsPercentage: Bool = false,
        tint: Color = Color.accent,
        height: CGFloat = 6
    ) {
        self.value = value
        self.total = total
        self.label = label
        self.showsPercentage = showsPercentage
        self.tint = tint
        self.height = height
    }

    private var fraction: Double? {
        value.map { DataMetrics.fraction($0, of: total) }
    }

    public var body: some View {
        let fraction = self.fraction
        let showsReadout = showsPercentage && fraction != nil
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if label != nil || showsReadout {
                DataHeaderRow(title: label) {
                    if showsReadout, let fraction {
                        Text(fraction, format: DataMetrics.percentFormat)
                            .contentTransition(prefersReducedMotion ? .opacity : .numericText(value: fraction))
                            .animation(prefersReducedMotion ? nil : Animations.disclosure, value: fraction)
                    }
                }
            }
            track(fraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.map { Text($0) } ?? Text("Progress", bundle: .module))
        .accessibilityValue(accessibilityValue(fraction))
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Track

    private func track(_ fraction: Double?) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DataTrack.color(colorScheme))
                if let fraction {
                    Capsule(style: .continuous)
                        .fill(tint)
                        .frame(width: proxy.size.width * fraction)
                        // The same spring the toast's progress ring uses, so
                        // every progress readout in an app moves alike.
                        .animation(prefersReducedMotion ? nil : Animations.disclosure, value: fraction)
                } else {
                    IndeterminateSweep(tint: tint, width: proxy.size.width)
                }
            }
            // Clips the spring's overshoot near 100% and the sweep's ends.
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: height)
    }

    private func accessibilityValue(_ fraction: Double?) -> Text {
        guard let fraction else { return Text("In progress", bundle: .module) }
        return Text(fraction, format: DataMetrics.percentFormat)
    }
}

// MARK: - Indeterminate sweep

/// A segment sliding left to right across the track, forever. Linear on
/// purpose — the motion tokens reserve linear timing for indeterminate
/// progress. Driven by a `TimelineView` rather than a `repeatForever`
/// animation, so a track that changes width mid-sweep just carries on (a
/// repeating offset animation keeps its old endpoints). Under Reduce Motion it
/// holds still, centered: away from the leading edge, so it can't be misread
/// as a value.
private struct IndeterminateSweep: View {
    let tint: Color
    let width: CGFloat

    /// One pass across the track.
    private static let period: TimeInterval = 1.5

    private var segmentWidth: CGFloat {
        min(width, max(width * 0.3, 24))
    }

    var body: some View {
        if prefersReducedMotion {
            segment
                .frame(width: width)
        } else {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed.truncatingRemainder(dividingBy: Self.period) / Self.period
                segment
                    .offset(x: -segmentWidth + (width + segmentWidth) * phase)
            }
        }
    }

    private var segment: some View {
        Capsule(style: .continuous)
            .fill(tint)
            .frame(width: segmentWidth)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 320, height: 200)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ProgressBar(value: 0.62, label: "Uploading", showsPercentage: true)
        ProgressBar(value: 0.9, tint: Success.success500)
        ProgressBar(value: 0.35, label: "Low disk", tint: Warning.warning500, height: 4)
        ProgressBar(value: nil, label: "Preparing…")
    }
    .padding(Spacing.xl)
}
