    //
    //  ButtonStyles.swift
    //  BlissUI
    //
    //  Created by Chris Seifert on 12/6/25.
    //
    //  Linear-inspired button hierarchy in a subtle toolbar language (the
    //  canonical recipe is a toolbar's Filter/Display toggles):
    //  `Sizing.radiusDefault` corners, a `Color.primary.opacity(0.1)` hairline
    //  border, clear fills at rest with `RowTint` hover/press fills,
    //  secondary→primary text on hover, and NO shadows anywhere.
    //  - Primary: neutral filled surface (no accent hue anywhere in the button system)
    //  - Outline: hairline border + primary label (prominent, no accent)
    //  - Secondary: hairline border, RowTint hover (Cancel / Back); `accent: true`
    //    is the same neutral fill as Primary for affirmative secondary actions
    //  - Ghost: borderless, RowTint hover (Skip / Learn more)
    //  - Destructive: muted danger tint unless prominent

import SwiftUI

    // MARK: - Primary Button Style

    /// Primary button — the neutral filled surface, no accent hue
    /// Use for main actions: Submit, Save, Continue, Create
public struct PrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.cornerRadiusOverride = cornerRadiusOverride
    }

        // MARK: - Typography Constants
    private var labelFont: Font {
        Typography.labelMedium
    }

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(
            configuration: configuration,
            isEnabled: isEnabled,
            colorScheme: colorScheme,
            labelFont: labelFont,
            compact: compact,
            cornerRadiusOverride: cornerRadiusOverride
        )
    }
}

/// Internal view for primary button with hover + focus tracking
private struct PrimaryButton: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let labelFont: Font
    var compact: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isPressed: Bool { configuration.isPressed }

    private var cornerRadius: CGFloat {
        cornerRadiusOverride ?? Sizing.radiusMedium
    }

    /// Neutral filled surface — light gray on light themes, a stronger
    /// white-wash on dark — no accent anywhere in the button system. Hover
    /// lifts the fill one small step; disabled drops to a third of the enabled
    /// fill so the states never blur together.
    private var backgroundColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
        }
        if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.11)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg + 2)
            .padding(.vertical, compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4)
            .frame(minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: isPressed)
    }
}

    // MARK: - Outline Button Style

/// Outlined counterpart to `PrimaryButtonStyle` — same metrics, but a clear
/// fill with a primary-toned hairline border and primary label, for prominent
/// actions that shouldn't carry the accent fill (e.g. a title-bar New
/// button).
public struct OutlineButtonStyle: ButtonStyle {
    var compact: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    private var labelFont: Font {
        Typography.labelMedium
    }

    public func makeBody(configuration: Configuration) -> some View {
        OutlineButton(
            configuration: configuration,
            isEnabled: isEnabled,
            colorScheme: colorScheme,
            labelFont: labelFont,
            compact: compact,
            cornerRadiusOverride: cornerRadiusOverride
        )
    }
}

/// Internal view so the style can track hover (RowTint fill, toolbar language).
private struct OutlineButton: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let labelFont: Font
    var compact: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var cornerRadius: CGFloat {
        cornerRadiusOverride ?? Sizing.radiusMedium
    }

    private var fill: Color {
        guard isEnabled else { return .clear }
        if configuration.isPressed { return RowTint.selected(colorScheme) }
        if isHovering { return RowTint.hover(colorScheme) }
        return .clear
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg + 2)
            .padding(.vertical, compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4)
            .frame(minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            // A Tab stop like the other styles (Space presses it).
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

    // MARK: - Secondary Button Style

    /// iOS-style secondary button - subtle background, refined styling
    /// Use for secondary actions: Cancel, Back, Edit
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    var compact: Bool = false
    var iconOnly: Bool = false
    /// Solid accent fill with contrast text — for affirmative secondary actions
    /// (Check Now, Connect…) that should read as primary-colored. Plain secondary
    /// buttons (Cancel, Back) leave this off and stay neutral grey.
    var accent: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph.
    ///   - accent: The filled variant for affirmative secondary actions (Check
    ///     Now, Connect…); plain secondary buttons (Cancel, Back) leave it off.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(
        compact: Bool = false,
        iconOnly: Bool = false,
        accent: Bool = false,
        cornerRadiusOverride: CGFloat? = nil
    ) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.accent = accent
        self.cornerRadiusOverride = cornerRadiusOverride
    }

        // MARK: - Typography Constants
    private var labelFont: Font {
        Typography.labelMedium
    }

    public func makeBody(configuration: Configuration) -> some View {
        SecondaryButton(
            configuration: configuration,
            isEnabled: isEnabled,
            colorScheme: colorScheme,
            compact: compact,
            iconOnly: iconOnly,
            accent: accent,
            labelFont: labelFont,
            cornerRadiusOverride: cornerRadiusOverride
        )
    }
}

/// Internal view for secondary button with hover + focus tracking. Subtle
/// toolbar language: hairline border, clear fill at rest, RowTint hover/press,
/// secondary→primary text on hover. The `accent` variant keeps its solid fill.
private struct SecondaryButton: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let compact: Bool
    let iconOnly: Bool
    let accent: Bool
    let labelFont: Font
    var cornerRadiusOverride: CGFloat? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isPressed: Bool { configuration.isPressed }

    private var cornerRadius: CGFloat {
        cornerRadiusOverride ?? Sizing.radiusMedium
    }

    /// Text color based on state
    private var textColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
        }
        if accent || isPressed || isHovering {
            return Color.primary
        }
        return Color.secondary
    }

    /// Background color based on state. The `accent` (affirmative) variant is
    /// the same neutral filled surface as PrimaryButtonStyle — no accent hue.
    private var backgroundColor: Color {
        if accent {
            if !isEnabled {
                return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
            }
            let rest: Color = colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
            return isPressed ? rest.opacity(0.8) : rest
        }
        guard isEnabled else { return .clear }
        if isPressed { return RowTint.selected(colorScheme) }
        if isHovering { return RowTint.hover(colorScheme) }
        return .clear
    }

    /// Button size for icon-only variant (square)
    private var iconOnlySize: CGFloat {
        compact ? Sizing.controlDefault : Sizing.controlMedium
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(textColor)
            .padding(.horizontal, iconOnly ? 0 : (compact ? Spacing.md : Spacing.lg))
            .padding(.vertical, iconOnly ? 0 : (compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4))
            .frame(width: iconOnly ? iconOnlySize : nil, height: iconOnly ? iconOnlySize : nil)
            .frame(minHeight: iconOnly ? nil : (compact ? Sizing.controlDefault : Sizing.controlMedium))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                // The accent variant is a solid fill — no hairline.
                if !accent {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(isEnabled ? 0.1 : 0.05), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: isPressed)
    }
}

    // MARK: - Ghost Button Style

    /// iOS-style ghost button - minimal, clean hover
    /// Use for tertiary actions: Skip, Learn more, View all
public struct GhostButtonStyle: ButtonStyle {
    var compact: Bool = false
    /// Lay the label out exactly where plain text would sit — no padding of its
    /// own — and draw the hover fill around it instead, bleeding past its edges.
    /// For a heading that's also a link (a title bar's back link), which has to
    /// line up with the static headings beside it.
    var hugsLabel: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - hugsLabel: Keep the label where plain text would sit and let the
    ///     hover fill bleed past it — for a heading that's also a link.
    public init(compact: Bool = false, hugsLabel: Bool = false) {
        self.compact = compact
        self.hugsLabel = hugsLabel
    }

    public func makeBody(configuration: Configuration) -> some View {
        GhostButton(configuration: configuration, colorScheme: colorScheme, compact: compact, hugsLabel: hugsLabel)
    }
}

    /// Internal view for ghost button with hover and focus tracking
private struct GhostButton: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    var compact: Bool = false
    var hugsLabel: Bool = false

    /// How far the `hugsLabel` fill reaches past the label on each side: the
    /// compact ghost button's own padding, so the fill is the size that button
    /// would be — only the label stays put.
    private static let labelBleed = EdgeInsets(top: Spacing.xs + 1, leading: Spacing.md, bottom: Spacing.xs + 1, trailing: Spacing.md)

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

        // MARK: - Typography Constants
    private var labelFont: Font {
        Typography.labelMedium
    }

    private var cornerRadius: CGFloat {
        Sizing.radiusMedium
    }

    private var textColor: Color {
        if isHovering || configuration.isPressed {
            return Color.primary
        }
        return Color.secondary
    }

    /// Background color
    private var backgroundColor: Color {
        if configuration.isPressed {
            return RowTint.selected(colorScheme)
        } else if isHovering {
            return RowTint.hover(colorScheme)
        }
        return Color.clear
    }

    var body: some View {
        if hugsLabel {
            labelHuggingBody
        } else {
            paddedBody
        }
    }

    /// The label at its natural size and position; the fill and the hover and
    /// click area extend past it, then the negative padding hands the layout
    /// back the label's own frame (the same trick as `listRowHover`).
    private var labelHuggingBody: some View {
        configuration.label
            .font(labelFont)
            .padding(Self.labelBleed)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { hovering in
                isHovering = hovering
            }
            .padding(EdgeInsets(
                top: -Self.labelBleed.top,
                leading: -Self.labelBleed.leading,
                bottom: -Self.labelBleed.bottom,
                trailing: -Self.labelBleed.trailing
            ))
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }

    private var paddedBody: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg)
            .padding(.vertical, compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4)
            .frame(minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

    // MARK: - Destructive Button Style

    /// iOS-style destructive button - subtle or prominent
    /// Use secondary/tertiary treatment unless it's a confirmation dialog
public struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    var compact: Bool = false
        /// Set to true in confirmation dialogs for bold red styling
    var prominent: Bool = false

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - prominent: The bold red fill, for confirmation dialogs.
    public init(compact: Bool = false, prominent: Bool = false) {
        self.compact = compact
        self.prominent = prominent
    }

        // MARK: - Typography Constants
    private var prominentFont: Font {
        Typography.labelMedium
    }
    private var subtleFont: Font {
        Typography.labelMedium
    }

    public func makeBody(configuration: Configuration) -> some View {
        if prominent {
            ProminentDestructiveButton(
                configuration: configuration,
                isEnabled: isEnabled,
                colorScheme: colorScheme,
                compact: compact,
                font: prominentFont
            )
        } else {
            SubtleDestructiveButton(
                configuration: configuration,
                isEnabled: isEnabled,
                colorScheme: colorScheme,
                compact: compact,
                font: subtleFont
            )
        }
    }
}

/// Internal view for prominent destructive button with focus tracking
private struct ProminentDestructiveButton: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let compact: Bool
    let font: Font

    @FocusState private var isFocused: Bool

    private var isPressed: Bool { configuration.isPressed }

    private var cornerRadius: CGFloat {
        Sizing.radiusMedium
    }

    /// Background color
    private var backgroundColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
        }
        // The deep red: white text sits on it, and the lifted mark red is too
        // light for that on dark.
        return Danger.tint
    }

    var body: some View {
        configuration.label
            .font(font)
            .foregroundStyle(Color.white)
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg + 2)
            .padding(.vertical, compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4)
            .frame(minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .animation(Animations.press, value: isPressed)
    }
}

/// Internal view for subtle destructive button — the toolbar language in
/// danger red: hairline border, clear fill at rest, red-tinted hover/press
/// fills, with hover tracking like the rest of the system.
private struct SubtleDestructiveButton: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let colorScheme: ColorScheme
    let compact: Bool
    let font: Font

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isPressed: Bool { configuration.isPressed }

    private var cornerRadius: CGFloat {
        Sizing.radiusMedium
    }

    /// Text color — the red mark, which on dark is the lifted tone the status
    /// chips use (a saturated red reads muddy on the dark content surface).
    private var textColor: Color { Danger.danger500 }

    /// Tint for the hover/press fills + hairline border
    private var tint: Color { Danger.tint }

    /// Hairline border — stronger on dark, where a dim red stroke disappears.
    private var borderOpacity: Double {
        guard isEnabled else { return 0.1 }
        return colorScheme == .dark ? 0.4 : 0.25
    }

    /// Background fill — clear at rest, red tint on hover, stronger on press.
    private var backgroundColor: Color {
        guard isEnabled else { return .clear }
        if isPressed { return tint.opacity(colorScheme == .dark ? 0.22 : 0.1) }
        if isHovering { return tint.opacity(colorScheme == .dark ? 0.14 : 0.06) }
        return .clear
    }

    var body: some View {
        configuration.label
            .font(font)
            .foregroundStyle(isEnabled ? textColor : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)))
            .padding(.horizontal, compact ? Spacing.md : Spacing.lg)
            .padding(.vertical, compact ? Spacing.xs + 1 : Spacing.inlineSpacing + 4)
            .frame(minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(borderOpacity), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: isPressed)
    }
}

    // MARK: - Small Pill Button Style

    /// iOS-style small pill button for inline actions
    /// Uses subtle background with accent color
public struct SmallPillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    /// Neutral by default (monochrome button system); semantic colors
    /// (Warning/Success/Danger) may still be passed for status pills.
    var color: Color = .primary

    /// - Parameter color: The label and tint color. Neutral by default; pass a
    ///   status color (Warning/Success/Danger) for a status pill.
    public init(color: Color = .primary) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        SmallPillButton(
            configuration: configuration,
            colorScheme: colorScheme,
            color: color,
            labelFont: Typography.labelMedium
        )
    }
}

/// Internal view for small pill button with focus tracking
private struct SmallPillButton: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    let color: Color
    let labelFont: Font

    @FocusState private var isFocused: Bool

    private var isPressed: Bool { configuration.isPressed }

    /// Background opacity based on state — quieter than Primary's fill so an
    /// inline pill reads as a mini-action, not a sibling of the main CTA.
    private var backgroundOpacity: Double {
        if isPressed {
            return colorScheme == .dark ? 0.14 : 0.10
        }
        return colorScheme == .dark ? 0.08 : 0.06
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs - 1)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(color.statusTint.opacity(backgroundOpacity))
            }
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault, padding: 0)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .animation(Animations.press, value: isPressed)
    }
}

// MARK: - Toolbar Icon Button Style

/// Style for standalone toolbar icon buttons (an inspector or settings toggle),
/// with explicit `isActive` state control for buttons that toggle a panel
public struct ToolbarIconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var extraLeadingPadding: CGFloat = 0
    var extraTrailingPadding: CGFloat = 0
    /// When set, the button keeps this background fill (e.g. `Color.primary` for an
    /// emphasized action) and renders its icon in a contrasting color.
    var fill: Color? = nil
    /// Tighter internal padding for dense toolbars.
    var compact: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - isActive: Keeps the highlighted fill, for a toggle that's on.
    ///   - extraLeadingPadding: Hit-area padding added before the button.
    ///   - extraTrailingPadding: Hit-area padding added after the button.
    ///   - fill: A solid background (e.g. `Color.primary` for an emphasized
    ///     action); the icon switches to a contrasting color.
    ///   - compact: Tighter internal padding for dense toolbars.
    public init(
        isActive: Bool = false,
        extraLeadingPadding: CGFloat = 0,
        extraTrailingPadding: CGFloat = 0,
        fill: Color? = nil,
        compact: Bool = false
    ) {
        self.isActive = isActive
        self.extraLeadingPadding = extraLeadingPadding
        self.extraTrailingPadding = extraTrailingPadding
        self.fill = fill
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        ToolbarIconButton(
            configuration: configuration,
            colorScheme: colorScheme,
            isActive: isActive,
            extraLeadingPadding: extraLeadingPadding,
            extraTrailingPadding: extraTrailingPadding,
            fill: fill,
            compact: compact
        )
    }
}

/// Internal view for toolbar icon button with hover and focus tracking
private struct ToolbarIconButton: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    let isActive: Bool
    let extraLeadingPadding: CGFloat
    let extraTrailingPadding: CGFloat
    var fill: Color? = nil
    var compact: Bool = false

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var cornerRadius: CGFloat {
        Sizing.radiusMedium
    }

    private var isHighlighted: Bool {
        isEnabled && (isHovering || isActive || configuration.isPressed)
    }

    private var iconColor: Color {
        if !isEnabled {
            return Color.primary.opacity(0.3)
        }
        // On a solid fill the glyph reads against the fill — use the same
        // luminance-aware contrast color the primary button uses on its accent fill.
        if fill != nil {
            return AccentHue.contrastForeground
        }
        if isHighlighted || isActive {
            return colorScheme == .dark ? .white : Grey.grey900
        }
        // Idle icons use the full label color rather than a washed grey.
        return Color.primary
    }

    /// Background color — an active toggle keeps the fill (the icon no longer
    /// carries an accent tint, so the fill is the active signal).
    private var backgroundColor: Color {
        // A solid fill stays put; hover only deepens it slightly.
        if let fill {
            return isHighlighted ? fill.opacity(0.85) : fill
        }
        if isHighlighted {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
        }
        return Color.clear
    }

    private var internalPadding: CGFloat {
        if compact { return Spacing.xs }
        return isTahoeOrLater ? Spacing.sm - 1 : Spacing.sm
    }

    private var insetPadding: CGFloat {
        isTahoeOrLater ? Spacing.insetSpacing : 0
    }

    var body: some View {
        configuration.label
            .foregroundStyle(iconColor)
            .padding(internalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(.horizontal, insetPadding)
            .padding(.leading, extraLeadingPadding)
            .padding(.trailing, extraTrailingPadding)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(Animations.hover, value: isHighlighted)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

// MARK: - Focusable Plain Button Style

/// `.plain` for rows and tabs that draw their own hover and selection (sidebar
/// rows, the underline tabs), and for bare text or icon buttons, plus what
/// `.plain` lacks: a Tab stop (Space presses it) and the shared focus ring. No
/// press state, like `.plain` rows. `outset` moves the ring out past a label
/// with no padding of its own (a text link, a glyph), so it doesn't sit on the
/// letters; the ring's radius grows with it to stay concentric. `bleed` widens
/// it sideways only, to trace a `rowHover` / `listRowHover` fill (which bleeds
/// `Spacing.sm` past the row).
public struct FocusablePlainButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Sizing.radiusDefault
    var outset: CGFloat = 0
    var bleed: CGFloat = 0

    /// - Parameters:
    ///   - cornerRadius: The focus ring's corner radius.
    ///   - outset: Moves the ring out past a label with no padding of its own.
    ///   - bleed: Widens the ring sideways only, to trace a row-hover fill.
    public init(cornerRadius: CGFloat = Sizing.radiusDefault, outset: CGFloat = 0, bleed: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.outset = outset
        self.bleed = bleed
    }

    public func makeBody(configuration: Configuration) -> some View {
        FocusablePlainButton(configuration: configuration, cornerRadius: cornerRadius, outset: outset, bleed: bleed)
    }
}

private struct FocusablePlainButton: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let outset: CGFloat
    let bleed: CGFloat

    @FocusState private var isFocused: Bool

    var body: some View {
        configuration.label
            .padding(.horizontal, bleed)
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: -outset)
            .padding(.horizontal, -bleed)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
    }
}

// MARK: - Selectable Card Button Style

/// A card, row or chip picked by clicking it (a sheet's destination cards,
/// frequency chips, weekday pills): a Tab stop with the shared focus
/// ring, the `RowTint` hover wash laid over its own background, and a slight
/// press. The label draws its own selected state. `cornerRadius` follows the
/// label's shape (`Sizing.radiusFull` for a capsule or circle).
public struct SelectableCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Sizing.radiusDefault

    /// - Parameter cornerRadius: The label's corner radius
    ///   (`Sizing.radiusFull` for a capsule or circle).
    public init(cornerRadius: CGFloat = Sizing.radiusDefault) {
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        SelectableCard(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct SelectableCard: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat

    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovering && isEnabled ? RowTint.hover(colorScheme) : Color.clear)
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = $0 }
    }
}

// MARK: - Inline Icon Button Style

/// Press + hover feedback for small inline icon buttons that sit on a field's
/// underline or inside a row (browse, save / get / set, copy, reveal…). A faint
/// rounded hover chip fades in, and the glyph scales down on press — the same
/// micro-interaction language as the toolbar icon buttons, scaled for inline
/// use. Only transform + opacity animate, so it stays cheap.
///
/// Honors `.disabled`: a disabled button shows no hover chip and no press
/// scale, so a greyed-out action reads as inert.
public struct InlineIconButtonStyle: ButtonStyle {
    /// Corner radius of the hover chip; match it to the button's content frame.
    var chipRadius: CGFloat = Sizing.radiusMedium

    /// - Parameter chipRadius: Corner radius of the hover chip; match it to the
    ///   button's content frame.
    public init(chipRadius: CGFloat = Sizing.radiusMedium) {
        self.chipRadius = chipRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        InlineIconButton(configuration: configuration, chipRadius: chipRadius)
    }
}

/// Internal view so the style can track hover and read the enabled state.
private struct InlineIconButton: View {
    let configuration: ButtonStyleConfiguration
    let chipRadius: CGFloat

    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    private var hoverBackground: Color {
        guard isEnabled, isHovering else { return .clear }
        return colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
    }

    var body: some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: chipRadius, style: .continuous)
                    .fill(hoverBackground)
            }
            .focusRing(isFocused: isFocused, cornerRadius: chipRadius, padding: 0)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.92 : 1.0)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

    // MARK: - Animated Gradient Border Button Style

    /// Button with an animated gradient border effect
public struct AnimatedGradientBorderButtonStyle: ButtonStyle {
    /// Density tiers: `.regular` (a toolbar's headline New button), `.compact`
    /// (28pt, mirrors the compact flag on the text-button styles), `.mini`
    /// (24pt, `labelSmall` — sits flush beside small icon controls like the ✕).
    public enum Size { case regular, compact, mini }

    var size: Size = .regular

    /// Back-compat convenience for the boolean call sites.
    public init(compact: Bool = false) {
        self.size = compact ? .compact : .regular
    }

    public init(size: Size) {
        self.size = size
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.floatingMenuActive) private var menuActive

    public func makeBody(configuration: Configuration) -> some View {
        AnimatedGradientBorderButton(
            configuration: configuration,
            colorScheme: colorScheme,
            menuActive: menuActive,
            size: size
        )
    }
}

    /// Internal view for the animated gradient border button
    /// Animation only runs on hover/focus to conserve energy
private struct AnimatedGradientBorderButton: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    let menuActive: Bool
    let size: AnimatedGradientBorderButtonStyle.Size

    @State private var rotation: Double = 0
    @State private var isHovering: Bool = false
    @State private var animationTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var labelFont: Font {
        size == .mini ? Typography.labelSmall : Typography.labelMedium
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return Spacing.md + 2
        case .compact: return Spacing.sm + 2
        case .mini: return Spacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return Spacing.sm
        case .compact: return Spacing.xs + 1
        case .mini: return Spacing.xs - 1
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .regular: return 0
        case .compact: return Sizing.controlDefault
        case .mini: return 24
        }
    }

    private var cornerRadius: CGFloat {
        Sizing.radiusMedium
    }

        /// Whether button should show active/hover state (hovering OR menu is open OR focused)
    private var isActive: Bool {
        isHovering || menuActive || isFocused
    }

    private var borderOpacity: Double {
        isFocused ? 0.9 : 0.6
    }

    private var gradientColors: [Color] {
        return [
            Color.selectionAccent,
            Color(nsColor: .systemPink),
            Color(nsColor: .systemPurple),
            Color(nsColor: .systemIndigo),
            Color.selectionAccent
        ]
    }

    private var backgroundColor: Color {
        if isFocused {
            return colorScheme == .dark
                ? Color.primary.opacity(0.08)
                : Color.primary.opacity(0.05)
        }
        return colorScheme == .dark
            ? Color.primary.opacity(0.05)
            : Color.primary.opacity(0.03)
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(.primary)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 1.5
                    )
                    .opacity(borderOpacity)
            )
            // The same ring as every other button, over the gradient.
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius)
            .fixedSize()
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .padding(.horizontal, isTahoeOrLater ? Spacing.insetSpacing : 0)
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .animation(Animations.press, value: configuration.isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onDisappear {
                stopAnimation()
            }
    }

    private func startAnimation() {
        animationTask?.cancel()
        // Reduce Motion: the gradient border stays, still.
        guard !prefersReducedMotion else { return }
        animationTask = Task {
            // Small delay before starting animation to let toolbar stabilize
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            while !Task.isCancelled {
                withAnimation(.linear(duration: 3)) {
                    rotation += 360
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

    // MARK: - Previews

#Preview("Button Hierarchy", traits: .fixedLayout(width: 480, height: 700)) {
    VStack(spacing: Spacing.xxl) {
        Text("Button Hierarchy")
            .font(Typography.displaySmall)

            // Primary - Main actions
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Primary – Main Actions")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            HStack(spacing: Spacing.md) {
                Button("Continue") { }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Save Changes") { }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Disabled") { }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
            }
        }

            // Secondary - Supporting actions
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Secondary – Supporting Actions")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            HStack(spacing: Spacing.md) {
                Button("Cancel") { }
                    .buttonStyle(SecondaryButtonStyle())
                Button {
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(SecondaryButtonStyle(iconOnly: true))
            }
        }

            // Ghost/Tertiary - Least prominent
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Ghost/Tertiary – Least Prominent")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            HStack(spacing: Spacing.md) {
                Button("Skip for now") { }
                    .buttonStyle(GhostButtonStyle())
                Button("Learn more") { }
                    .buttonStyle(GhostButtonStyle())
                Button("View all") { }
                    .buttonStyle(GhostButtonStyle())
            }
        }

        Divider()

            // Destructive - Two variants
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Destructive – Subtle vs Prominent")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)

            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xxs) {
                    Button("Remove") { }
                        .buttonStyle(DestructiveButtonStyle())
                    Text("Inline (subtle)")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Grey.grey400)
                }

                VStack(spacing: Spacing.xxs) {
                    Button("Delete Item") { }
                        .buttonStyle(DestructiveButtonStyle(prominent: true))
                    Text("Confirmation (prominent)")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Grey.grey400)
                }
            }
        }

        Divider()

            // Small Pill - Inline CTAs
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Small Pill – Inline CTAs")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            HStack(spacing: Spacing.md) {
                Button("Choose...") { }
                    .buttonStyle(SmallPillButtonStyle())
                Button("Upgrade") { }
                    .buttonStyle(SmallPillButtonStyle(color: Warning.warning500))
                Button("Grant Access") { }
                    .buttonStyle(SmallPillButtonStyle(color: Success.success500))
            }
        }

        Divider()

            // Animated Gradient Border
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Animated Gradient Border – Special CTAs")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            Button {
            } label: {
                Label("New Item", systemImage: "plus")
            }
            .buttonStyle(AnimatedGradientBorderButtonStyle())
        }
    }
    .padding(Spacing.xxl)
}
