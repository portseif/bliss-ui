//
//  Skeleton.swift
//  BlissUI
//
//  Loading placeholders: `SkeletonBlock` shapes to sketch a layout that
//  hasn't loaded, and `.skeleton(isLoading:)`, which redacts real content to
//  placeholder bars. A soft highlight sweeps across both — one continuous band
//  across the window, so neighbouring blocks shimmer as one — and holds still
//  under Reduce Motion.
//

import SwiftUI

// MARK: - Shapes

/// The shape of a `SkeletonBlock`.
public nonisolated enum SkeletonShape: Sendable, Hashable {
    /// A rounded rectangle: a line of text, a thumbnail, a card.
    case rectangle(cornerRadius: CGFloat)
    /// A pill: a badge, a button.
    case capsule
    /// A circle: an avatar, an icon.
    case circle
}

// MARK: - Skeleton Block

/// A placeholder shape for content that hasn't loaded, with the sweep running
/// across it. Leave `width` nil to fill the row; a circle takes its width as
/// its height. Hidden from VoiceOver — label the loading area as a whole, or
/// use `.skeleton(isLoading:)`, which says "Loading".
///
/// ```swift
/// HStack(spacing: Spacing.sm) {
///     SkeletonBlock(.circle, width: 32)
///     VStack(alignment: .leading, spacing: Spacing.xs) {
///         SkeletonBlock.line(width: 140)
///         SkeletonBlock.line(width: 90, height: 8)
///     }
/// }
/// ```
public struct SkeletonBlock: View {
    private let shape: SkeletonShape
    private let width: CGFloat?
    private let height: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - shape: The block's shape; `Sizing.radiusSmall` corners by default.
    ///   - width: Its width; nil fills the available width.
    ///   - height: Its height; nil is a text line's height (or, for a circle, its width).
    public init(_ shape: SkeletonShape = .rectangle(cornerRadius: Sizing.radiusSmall), width: CGFloat? = nil, height: CGFloat? = nil) {
        self.shape = shape
        self.width = width
        self.height = height
    }

    /// A line of text: a short rounded bar.
    public static func line(width: CGFloat? = nil, height: CGFloat = 10) -> SkeletonBlock {
        SkeletonBlock(.rectangle(cornerRadius: height / 2), width: width, height: height)
    }

    private var resolvedHeight: CGFloat {
        if let height { return height }
        if case .circle = shape, let width { return width }
        return 12
    }

    public var body: some View {
        SkeletonSweepFill(base: SkeletonTones.base(colorScheme), highlight: SkeletonTones.highlight(colorScheme))
            .clipShape(SkeletonClipShape(shape: shape))
            .frame(width: width, height: resolvedHeight)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .accessibilityHidden(true)
    }
}

// MARK: - Redacting modifier

extension View {
    /// Shows the content as placeholders while `isLoading`: text and images
    /// redact to bars with the sweep running over them, controls stop taking
    /// clicks and focus, and VoiceOver hears "Loading" instead of the
    /// placeholder text. Lay the content out with sample values so the bars
    /// take the real shape.
    ///
    /// The content keeps its identity across the switch — its state, and any
    /// `.task` or `.onAppear` in it, aren't rerun when loading ends.
    public func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }
}

/// `.shimmer()` would mask the content with a second copy of itself, which runs
/// that copy's `.task` and `.onAppear` too; the sweep here is an overlay instead.
private struct SkeletonModifier: ViewModifier {
    let isLoading: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .disabled(isLoading)
            .accessibilityHidden(isLoading)
            .overlay {
                if isLoading {
                    SkeletonSweepFill(base: .clear, highlight: SkeletonTones.overlayHighlight(colorScheme))
                        .allowsHitTesting(false)
                        .accessibilityElement()
                        .accessibilityLabel(Text("Loading", bundle: .module))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
    }
}

// MARK: - Sweep

/// The placeholder tones, against whatever surface sits behind.
enum SkeletonTones {
    static func base(_ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return Color.primary.opacity(scheme == .dark ? 0.18 : 0.16) }
        // Close to the bars `.redacted` draws for secondary text, so blocks
        // and redacted content side by side read as one placeholder.
        return Color.primary.opacity(scheme == .dark ? 0.11 : 0.09)
    }

    /// The band over a block. In light mode it's the raised surface (white, or
    /// a theme's cream), so a Low Glare window never sweeps pure white.
    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.14) : Color.controlBackground.opacity(0.9)
    }

    /// The band over redacted content, which also crosses the gaps between
    /// the bars, so it's fainter.
    static func overlayHighlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary.opacity(0.05) : Color.controlBackground.opacity(0.6)
    }
}

/// Where the band is. Measured in window points, so every block and every
/// redacted area on screen shows the same band at the same place.
enum SkeletonSweep {
    /// The band's width.
    static let bandWidth: CGFloat = 160
    /// The span the band crosses before starting over. Past the right edge of
    /// a narrower window the band is off-screen, which is the pause between
    /// sweeps.
    static let travel: CGFloat = 2_000
    /// One sweep, start to start.
    static let period: TimeInterval = 2.2

    /// The band's center in window coordinates at `time`.
    static func bandCenter(at time: TimeInterval) -> CGFloat {
        let progress = time.truncatingRemainder(dividingBy: period) / period
        return -bandWidth + (travel + bandWidth * 2) * progress
    }

    /// The band's start and end in a view's own unit space, for a horizontal
    /// gradient across a view at `minX` (window coordinates) that's `width` wide.
    static func gradientPoints(bandCenter: CGFloat, minX: CGFloat, width: CGFloat) -> (start: UnitPoint, end: UnitPoint) {
        guard width > 0 else { return (.leading, .trailing) }
        let localCenter = bandCenter - minX
        return (
            UnitPoint(x: (localCenter - bandWidth / 2) / width, y: 0.5),
            UnitPoint(x: (localCenter + bandWidth / 2) / width, y: 0.5)
        )
    }
}

/// A fill of `base` with the band of `highlight` crossing it. Drawn as one
/// gradient per frame — no mask and no overlay, so nothing renders off-screen.
/// Still (just `base`) under Reduce Motion.
private struct SkeletonSweepFill: View {
    let base: Color
    let highlight: Color

    @State private var frameInWindow: CGRect = .zero

    var body: some View {
        Group {
            if prefersReducedMotion {
                Rectangle().fill(base)
            } else {
                TimelineView(.animation) { timeline in
                    let points = SkeletonSweep.gradientPoints(
                        bandCenter: SkeletonSweep.bandCenter(at: timeline.date.timeIntervalSinceReferenceDate),
                        minX: frameInWindow.minX,
                        width: frameInWindow.width
                    )
                    Rectangle().fill(
                        LinearGradient(
                            stops: [
                                .init(color: base, location: 0),
                                .init(color: highlight, location: 0.5),
                                .init(color: base, location: 1),
                            ],
                            startPoint: points.start,
                            endPoint: points.end
                        )
                    )
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frameInWindow = $0 }
    }
}

/// The block's clip, from its `SkeletonShape`.
private struct SkeletonClipShape: Shape {
    let shape: SkeletonShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .rectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        case .capsule:
            Capsule(style: .continuous).path(in: rect)
        case .circle:
            Circle().path(in: rect)
        }
    }
}

// MARK: - Previews

#Preview("Skeleton blocks", traits: .fixedLayout(width: 420, height: 160)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        ForEach(0..<2, id: \.self) { _ in
            HStack(spacing: Spacing.sm) {
                SkeletonBlock(.circle, width: 32)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SkeletonBlock.line(width: 180)
                    SkeletonBlock.line(width: 110, height: 8)
                }
                Spacer()
                SkeletonBlock(.capsule, width: 56, height: 18)
            }
        }
    }
    .padding(Spacing.lg)
}

#Preview("Redacted content", traits: .fixedLayout(width: 420, height: 140)) {
    @Previewable @State var isLoading = true
    VStack(alignment: .leading, spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(Typography.displaySmall)
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text("Ada Lovelace").font(Typography.bodySmallSemibold)
                Text("Analytical Engine team").font(Typography.captionSmall).foregroundStyle(.secondary)
            }
        }
        .skeleton(isLoading: isLoading)
        Toggle("Loading", isOn: $isLoading).toggleStyle(.flatSwitch(showsLabel: true))
    }
    .padding(Spacing.lg)
}
