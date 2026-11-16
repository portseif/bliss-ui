    //
    //  Badge.swift
    //  BlissUI
    //
    //  A unified badge component that handles all badge variants:
    //  - Status indicators (with optional dot, icon, text)
    //  - Notification counts (circular)
    //  - License badges (gradient backgrounds)
    //  - Step numbers
    //

import SwiftUI

    // MARK: - Badge Component

    /// A versatile badge component for status indicators, counts, and labels
    ///
    /// Usage examples:
    /// ```swift
    /// // Simple text badge
    /// Badge("New")
    ///
    /// // With icon
    /// Badge("Success", icon: "checkmark")
    ///     .badgeStyle(.success)
    ///
    /// // Notification count
    /// Badge(count: 5)
    ///
    /// // Pro badge with gradient
    /// Badge("PRO")
    ///     .badgeStyle(.gradient(.pro))
    ///     .badgeSize(.small)
    /// ```
public struct Badge: View {
        // MARK: - Configuration
    
    private let content: BadgeContent
    private var style: BadgeStyle = .secondary
    private var size: BadgeSize = .regular
    private var dot: BadgeDot? = nil
    private var shape: BadgeShape = .capsule
    
        // MARK: - Content Types
    
    private enum BadgeContent {
        case text(LocalizedStringKey, icon: String?)
        case count(Int, maximum: Int)
    }
    
        // MARK: - Initializers
    
        /// Create a text badge with optional icon
    public init(_ text: LocalizedStringKey, icon: String? = nil) {
        self.content = .text(text, icon: icon)
    }
    
        /// Create a count badge (circular notification style). Past `maximum`
        /// it reads "99+" (or "999+" for a mail count).
    public init(count: Int, maximum: Int = 99) {
        self.content = .count(count, maximum: maximum)
        self.style = .solid(.notification)
    }
    
        // MARK: - Body
    
    public var body: some View {
        switch content {
            case .text(let text, let icon):
                textBadge(text: text, icon: icon)
            case .count(let count, let maximum):
                countBadge(count: count, maximum: maximum)
        }
    }
    
        // MARK: - Text Badge

    private func textBadge(text: LocalizedStringKey, icon: String?) -> some View {
        TextBadgeContent(
            text: text,
            icon: icon,
            style: style,
            size: size,
            dot: dot,
            shape: shape
        )
    }

        // MARK: - Count Badge

    private func countBadge(count: Int, maximum: Int) -> some View {
        CountBadgeContent(
            count: count,
            maximum: maximum,
            style: style,
            size: size
        )
    }
}

    // MARK: - Text Badge Content (with colorScheme access)

private struct TextBadgeContent: View {
    let text: LocalizedStringKey
    let icon: String?
    let style: BadgeStyle
    let size: BadgeSize
    let dot: BadgeDot?
    let shape: BadgeShape

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: size.iconSpacing) {
                // Status dot
            if let dot = dot {
                Circle()
                    .fill(style.dotColor(dot.color, for: colorScheme))
                    .frame(width: size.dotSize, height: size.dotSize)
            }

                // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(size.iconFont)
                    .foregroundStyle(style.iconColor(for: colorScheme))
            }

                // Text
            Text(text)
                .font(style.font(for: size))
                .foregroundStyle(style.textColor(for: colorScheme))
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .frame(height: size.minHeight)
        .background {
            shapeBackground
        }
        .overlay {
            if style.hasBorder {
                shapeBorder
            }
        }
    }

    @ViewBuilder
    private var shapeBackground: some View {
        switch shape {
            case .capsule:
                Capsule()
                    .fill(style.backgroundColor(for: colorScheme))
            case .roundedRect:
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(style.backgroundColor(for: colorScheme))
        }
    }

    @ViewBuilder
    private var shapeBorder: some View {
        switch shape {
            case .capsule:
                Capsule()
                    .strokeBorder(style.borderColor(for: colorScheme), lineWidth: 1)
            case .roundedRect:
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(style.borderColor(for: colorScheme), lineWidth: 1)
        }
    }
}

    // MARK: - Count Badge Content (with colorScheme access)

private struct CountBadgeContent: View {
    let count: Int
    let maximum: Int
    let style: BadgeStyle
    let size: BadgeSize

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if count > 0 {
                Text(count > maximum ? "\(maximum)+" : "\(count)")
                    .font(size.countFont)
                    .foregroundStyle(style.textColor(for: colorScheme))
                    .frame(minWidth: size.countMinSize, minHeight: size.countMinSize)
                    .padding(.horizontal, count > 9 ? Spacing.xxs : 0)
                    .background(style.backgroundColor(for: colorScheme))
                    .clipShape(Capsule())
            }
        }
    }
}

    // MARK: - Badge Modifiers

extension Badge {
    
        // MARK: - Modifiers
    
        /// Set the badge style
    public func badgeStyle(_ style: BadgeStyle) -> Badge {
        var badge = self
        badge.style = style
        return badge
    }
    
        /// Set the badge size
    public func badgeSize(_ size: BadgeSize) -> Badge {
        var badge = self
        badge.size = size
        return badge
    }

        /// Set the badge shape
    public func badgeShape(_ shape: BadgeShape) -> Badge {
        var badge = self
        badge.shape = shape
        return badge
    }

        /// Add a leading status dot
    public func dot(_ color: Color) -> Badge {
        var badge = self
        badge.dot = BadgeDot(color: color)
        return badge
    }

        /// Add a leading status dot from a preset
    public func dot(_ preset: BadgeDot.Preset) -> Badge {
        var badge = self
        badge.dot = BadgeDot(preset: preset)
        return badge
    }
}

    // MARK: - Badge Style

public enum BadgeStyle {
        // Semantic styles (with borders)
    case primary
    case secondary
    case success
    case warning
    case error
    case info

        // A hairline and secondary text, no wash: a version or kind tag ("v6.2", "beta").
    case outline

        // Solid color (no border)
    case solid(Color)

        // Gradient backgrounds
    case gradient(GradientPreset)

        // Semantic status chip — one color drives label, icon, dot and fill.
        // Unlike `.custom`, it adapts that color to the scheme (see
        // `Color.legibleOnDark`), which a caller can't do at construction time.
    case status(Color)

        // Custom
    case custom(text: Color, icon: Color, background: Color, border: Color?)

    public enum GradientPreset {
        case pro      // Purple to blue
        case lifetime // Gold
        case custom([Color])

        public var colors: [Color] {
            switch self {
                case .pro:
                    return [
                        Color(red: 0.6, green: 0.3, blue: 0.9),
                        Color(red: 0.3, green: 0.5, blue: 0.95)
                    ]
                case .lifetime:
                    return [
                        Color(red: 0.85, green: 0.65, blue: 0.2),
                        Color(red: 0.75, green: 0.5, blue: 0.15)
                    ]
                case .custom(let colors):
                    return colors
            }
        }
    }

    /// A status chip's dot is the same semantic color as its label, so it takes
    /// the same dark-mode lift; every other style leaves the caller's dot alone.
    func dotColor(_ base: Color, for scheme: ColorScheme) -> Color {
        if case .status = self { return base.legibleOnDark(scheme) }
        return base
    }

    func textColor(for scheme: ColorScheme) -> Color {
        switch self {
            case .primary: return scheme == .dark ? Primary.primary300 : Primary.primary700
            case .secondary: return scheme == .dark ? Grey.grey300 : Grey.grey600
            case .success: return scheme == .dark || StatusTones.isThemed(.success) ? Success.success500 : Success.success700
            case .warning: return scheme == .dark || StatusTones.isThemed(.warning) ? Warning.warning500 : Warning.warning700
            // The red mark in both schemes: on dark that's the lifted tone the
            // status chips use (4.9:1), since pure red carries far less luminance
            // than green or amber and a deep red label reads as muddy.
            case .error: return Danger.danger500
            case .info: return scheme == .dark || StatusTones.isThemed(.info) ? Info.info500 : Info.info700
            case .outline: return Color.textSecondary
            case .status(let color): return color.legibleOnDark(scheme)
            case .solid: return .white
            case .gradient: return .white
            case .custom(let text, _, _, _): return text
        }
    }

    func iconColor(for scheme: ColorScheme) -> Color {
        switch self {
            // Dark icons sit one step brighter than the light-mode tone for the
            // same reason the labels do: a `*400` glyph lands near 3.6:1 on the
            // badge fill and reads dimmer than the text beside it.
            case .primary: return scheme == .dark ? Primary.primary300 : Color.accent
            case .secondary: return scheme == .dark ? Grey.grey300 : Color.textSecondary
            case .success: return Success.success500
            case .warning: return Warning.warning500
            case .error: return Danger.danger500
            case .info: return Info.info500
            case .status(let color): return color.legibleOnDark(scheme)
            case .solid: return .white.opacity(0.9)
            case .gradient: return .white.opacity(0.9)
            case .custom(_, let icon, _, _): return icon
            case .outline: return Color.textSecondary
        }
    }

    /// Semantic styles fill with a wash of their tint in both schemes. The
    /// light ramp steps (`*50` fills, `*200` hairlines) are near-full
    /// saturation, so they read as solid fills and a red label on them all
    /// but vanished; the wash keeps the `*700` labels and the red mark legible.
    func backgroundColor(for scheme: ColorScheme) -> AnyShapeStyle {
        switch self {
            case .primary: return AnyShapeStyle(StatusWash.fill(Color.accent, scheme))
            case .secondary:
                return AnyShapeStyle(scheme == .dark ? Grey.grey500.opacity(0.15) : Grey.grey100)
            case .success: return AnyShapeStyle(StatusWash.fill(Success.success500, scheme))
            case .warning: return AnyShapeStyle(StatusWash.fill(Warning.warning500, scheme))
            case .error: return AnyShapeStyle(StatusWash.fill(Danger.danger500, scheme))
            case .info: return AnyShapeStyle(StatusWash.fill(Info.info500, scheme))
            case .status(let color): return AnyShapeStyle(StatusWash.fill(color, scheme))
            case .outline: return AnyShapeStyle(Color.clear)
            case .solid(let color): return AnyShapeStyle(color)
            case .gradient(let preset):
                return AnyShapeStyle(
                    LinearGradient(
                        colors: preset.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case .custom(_, _, let background, _): return AnyShapeStyle(background)
        }
    }

    func borderColor(for scheme: ColorScheme) -> Color {
        switch self {
            case .primary: return StatusWash.border(Color.accent, scheme)
            case .secondary, .outline: return Color.menuBorder
            case .success: return StatusWash.border(Success.success500, scheme)
            case .warning: return StatusWash.border(Warning.warning500, scheme)
            case .error: return StatusWash.border(Danger.danger500, scheme)
            case .info: return StatusWash.border(Info.info500, scheme)
            case .status, .solid, .gradient: return .clear
            case .custom(_, _, _, let border): return border ?? .clear
        }
    }

    var hasBorder: Bool {
        switch self {
            case .status, .solid, .gradient: return false
            case .custom(_, _, _, let border): return border != nil
            default: return true
        }
    }

        /// Label font — the size's token; the gradient badges (Pro / Lifetime)
        /// take its bold face.
    func font(for size: BadgeSize) -> Font {
        switch self {
            case .gradient: return size.boldFont
            default: return size.font
        }
    }
}

    // MARK: - Badge Size

/// The pill size every chip in the library shares: `Badge`, `StatusPill`,
/// `StatusDotPill`, `ShortcutKey` and the count chips read the same table, so
/// a small status pill and a small badge sit at one cap height.
public enum BadgeSize {
    case small
    case regular
    case large

        /// Label font (10/11/12 regular)
    var font: Font {
        switch self {
            case .small: return Typography.labelTiny
            case .regular: return Typography.captionSmall
            case .large: return Typography.caption
        }
    }

        /// Label font with emphasis (10/11/12 semibold) — the gradient badges
    var boldFont: Font {
        switch self {
            case .small: return Typography.labelTinyBold
            case .regular: return Typography.captionSmallBold
            case .large: return Typography.captionBold
        }
    }

        /// The pill's height: 16 / 20 / 24
    public var minHeight: CGFloat {
        switch self {
            case .small: return Sizing.iconDefault
            case .regular: return Sizing.iconMedium
            case .large: return Sizing.controlSmall
        }
    }

        /// Icon font (8/9/11 regular)
    var iconFont: Font {
        switch self {
            case .small: return Typography.labelMini
            case .regular: return Typography.labelXTiny
            case .large: return Typography.labelXSmall
        }
    }

        /// Count font (9/10/12 medium)
    var countFont: Font {
        switch self {
            case .small: return Typography.labelXTiny
            case .regular: return Typography.labelTiny
            case .large: return Typography.caption
        }
    }

    var iconSpacing: CGFloat {
        switch self {
            case .small: return Spacing.insetSpacing
            case .regular: return Spacing.xxs
            case .large: return Spacing.xs
        }
    }
    
        /// 6 / 6 / 8 — `Spacing.tagPaddingH` for the regular pill
    public var horizontalPadding: CGFloat {
        switch self {
            case .small: return Spacing.xs
            case .regular: return Spacing.tagPaddingH
            case .large: return Spacing.sm
        }
    }
    
        /// 2 / 3 / 4 — `Spacing.tagPaddingV` for the regular pill
    public var verticalPadding: CGFloat {
        switch self {
            case .small: return Spacing.hairline
            case .regular: return Spacing.tagPaddingV
            case .large: return Spacing.xxs
        }
    }
    
        /// 4 / 6 / 8 for a `.roundedRect` pill
    public var cornerRadius: CGFloat {
        switch self {
            case .small: return Sizing.radiusSmall
            case .regular: return Sizing.radiusDefault
            case .large: return Sizing.radiusMedium
        }
    }
    
        /// The status dot: `Sizing.statusCircle` a point either side
    public var dotSize: CGFloat {
        switch self {
            case .small: return Sizing.statusCircle - 1
            case .regular: return Sizing.statusCircle
            case .large: return Sizing.statusCircle + 1
        }
    }
    
    var countMinSize: CGFloat {
        switch self {
            case .small: return Sizing.iconSmall
            case .regular: return Sizing.iconDefault
            case .large: return Sizing.iconMedium
        }
    }

    var stepSize: CGFloat {
        switch self {
            case .small: return Sizing.inlineIconButton
            case .regular: return Sizing.iconMedium
            case .large: return Sizing.iconLarge
        }
    }
}

    // MARK: - Badge Shape

public enum BadgeShape {
    case capsule
    case roundedRect
}

    // MARK: - Badge Dot

public struct BadgeDot {
    public let color: Color
    
    public init(color: Color) {
        self.color = color
    }
    
    public init(preset: Preset) {
        self.color = preset.color
    }
    
    public enum Preset {
        case active    // Green
        case warning   // Orange
        case error     // Red
        case inactive  // Grey
        case info      // Blue
        
        public var color: Color {
            switch self {
                case .active: return Success.success500
                case .warning: return Warning.warning500
                case .error: return Danger.danger500
                case .inactive: return Grey.grey400
                case .info: return Info.info500
            }
        }
    }
}

    // MARK: - Convenience Extensions

extension Badge {
        /// Create a step number badge (circular, aspect-ratio 1:1)
    public static func step(_ number: Int, size: BadgeSize = .small) -> some View {
        StepBadge(number: number, size: size)
    }

        /// Tinted status pill — colored dot + label on a soft same-color tint
        /// (Healthy / Completed / Needs setup …). The one shape for status chips;
        /// `.small` sits in a table cell, `.large` heads a detail pane.
    public static func status(_ title: LocalizedStringKey, color: Color, size: BadgeSize = .large) -> Badge {
        Badge(title)
            .badgeStyle(.status(color))
            .badgeSize(size)
            .dot(color)
    }

        /// Create a Pro badge
    public static func pro(size: BadgeSize = .regular) -> Badge {
        Badge(.verbatim(String(localized: "Pro", bundle: .module)))
            .badgeStyle(.gradient(.pro))
            .badgeSize(size)
            .badgeShape(.roundedRect)
    }
    
        /// Create a Lifetime badge
    public static func lifetime(size: BadgeSize = .regular) -> Badge {
        Badge(.verbatim(String(localized: "Lifetime", bundle: .module)))
            .badgeStyle(.gradient(.lifetime))
            .badgeSize(size)
            .badgeShape(.roundedRect)
    }
}

/// The step disc: the info mark on the info wash.
private struct StepBadge: View {
    let number: Int
    let size: BadgeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("\(number)")
            .font(size.font)
            .foregroundStyle(Info.info500)
            .frame(width: size.stepSize, height: size.stepSize)
            .background {
                Circle()
                    .fill(StatusWash.fill(Info.info500, colorScheme))
            }
            .overlay {
                Circle()
                    .strokeBorder(StatusWash.border(Info.info500, colorScheme), lineWidth: 1)
            }
    }
}

    // MARK: - Previews

#Preview("Badge Styles", traits: .fixedLayout(width: 400, height: 600)) {
    VStack(alignment: .leading, spacing: 16) {
        Text("Semantic Styles")
            .font(Typography.bodySmallSemibold)

        HStack(spacing: 8) {
            Badge("Secondary")
            Badge("Primary").badgeStyle(.primary)
        }

        HStack(spacing: 8) {
            Badge("Success", icon: "checkmark").badgeStyle(.success)
            Badge("Warning", icon: "exclamationmark.triangle").badgeStyle(.warning)
            Badge("Error", icon: "xmark").badgeStyle(.error)
        }

        HStack(spacing: 8) {
            Badge("Info", icon: "info.circle").badgeStyle(.info)
            Badge("v6.2").badgeStyle(.outline)
        }

        Divider()

        Text("Gradient Styles")
            .font(Typography.bodySmallSemibold)

        HStack(spacing: 8) {
            Badge.pro()
            Badge.pro(size: .small)
            Badge.lifetime()
            Badge.lifetime(size: .small)
        }

        Divider()

        Text("Count Badges")
            .font(Typography.bodySmallSemibold)

        HStack(spacing: 12) {
            Badge(count: 3)
            Badge(count: 12).badgeSize(.large)
            Badge(count: 99)
            Badge(count: 150) // Shows 99+
        }

        Divider()

        Text("Sizes")
            .font(Typography.bodySmallSemibold)

        HStack(spacing: 12) {
            Badge("Small", icon: "star").badgeStyle(.primary).badgeSize(.small)
            Badge("Regular", icon: "star").badgeStyle(.primary)
            Badge("Large", icon: "star").badgeStyle(.primary).badgeSize(.large)
        }
    }
    .padding(24)
}

#Preview("Real-world Examples", traits: .fixedLayout(width: 350, height: 300)) {
    VStack(alignment: .leading, spacing: 16) {
            // Feature row with Pro badge
        HStack {
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
            Text("Cloud Sync")
            Spacer()
            Badge.pro(size: .small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))

            // Status tags
        HStack(spacing: 6) {
            Badge("Swift").badgeStyle(.primary)
            Badge("v6.2").badgeSize(.small)
        }

            // Git status
        HStack(spacing: 6) {
            Badge("Clean", icon: "checkmark.circle").badgeStyle(.success).badgeSize(.small)
            Badge("main", icon: "arrow.triangle.branch").badgeSize(.small)
        }

            // Step badges (circular, aspect-ratio 1:1)
        HStack(spacing: 8) {
            Badge.step(1)
            Badge.step(2)
            Badge.step(3)
            Badge.step(4, size: .regular)
            Badge.step(5, size: .large)
        }

            // Notification example
        HStack {
            Text("Notifications")
            Badge(count: 5)
        }
    }
    .padding(24)
}
