//
//  ButtonStyles.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/6/25.
//
//  Linear-inspired button hierarchy in a subtle toolbar language (the
//  canonical recipe is a toolbar's Filter/Display toggles):
//  `Sizing.radiusMedium` corners, a `Color.menuBorder` hairline, clear fills
//  at rest with `RowTint` hover/press fills, secondary→primary text on hover,
//  and NO shadows anywhere. Every text style draws through one body
//  (`TextButtonBody`) on one table of numbers (`ButtonMetrics`), so a compact
//  button is `Sizing.controlDefault` (28pt) and a regular one
//  `Sizing.controlMedium` (32pt) whichever style draws it.
//  - Primary: neutral filled surface (no accent hue anywhere in the button system)
//  - Outline: hairline border + primary label (prominent, no accent)
//  - Secondary: hairline border, RowTint hover (Cancel / Back); `accent: true`
//    is the same neutral fill as Primary for affirmative secondary actions
//  - Ghost: borderless, RowTint hover (Skip / Learn more)
//  - Destructive: muted danger tint unless prominent
//

import SwiftUI

// MARK: - Shared Metrics

/// The numbers every text button shares. A 13pt label is about 16pt tall, so
/// 16 + 2 × 6 lands the compact tier on `Sizing.controlDefault` and 16 + 2 × 8
/// the regular tier on `Sizing.controlMedium`; `minHeight` holds the tier when
/// a label is shorter, and an icon-only button is a square of the tier's side.
enum ButtonMetrics {
    static func minHeight(compact: Bool) -> CGFloat {
        compact ? Sizing.controlDefault : Sizing.controlMedium
    }

    static func horizontalPadding(compact: Bool) -> CGFloat {
        compact ? Spacing.buttonPaddingH : Spacing.lg + 2
    }

    static func verticalPadding(compact: Bool) -> CGFloat {
        compact ? Spacing.buttonPaddingV : Spacing.sm
    }

    static var labelFont: Font { Typography.labelMedium }

    static let cornerRadius: CGFloat = Sizing.radiusMedium

    static let hairlineWidth: CGFloat = 1

    /// A disabled hairline fades to half.
    static let disabledHairlineOpacity: Double = 0.5

    /// The hairline on a Secondary button and on every button-like trigger
    /// (a picker, a filter button): the one neutral line the library draws.
    static func hairline(isEnabled: Bool) -> Color {
        isEnabled ? Color.menuBorder : Color.menuBorder.opacity(disabledHairlineOpacity)
    }

    /// Outline's stronger line — it is the prominent, accent-free button.
    static func outlineBorder(isEnabled: Bool) -> Color {
        Color.primary.opacity(isEnabled ? 0.18 : 0.08)
    }

    /// The neutral filled surface (Primary, and Secondary's `accent`): light
    /// gray on light, a stronger white wash on dark.
    static func primaryRestFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    /// Hover lifts the filled surface one small step.
    static func primaryHoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.11)
    }

    /// Disabled drops to a third of the rest fill so the states never blur.
    static func primaryDisabledFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    /// A disabled prominent destructive button keeps a grey slab where the red was.
    static func prominentDisabledFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }

    /// Hover on a solid red fill: a touch of white over it.
    static let prominentHoverLift: Double = 0.08

    /// The subtle destructive button pressed: a step past its hover wash.
    static func destructivePressFill(_ scheme: ColorScheme) -> Color {
        Danger.tint.opacity(scheme == .dark ? 0.22 : 0.1)
    }

    /// Disabled label text, whatever the style.
    static func disabledText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)
    }

    /// A solid-filled toolbar icon button deepens on hover rather than washing.
    static let solidFillHoverOpacity: Double = 0.85

    /// The small pill's wash of its own color at rest and while pressed or selected.
    static func pillRestOpacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.08 : 0.06 }
    static func pillActiveOpacity(_ scheme: ColorScheme) -> Double { scheme == .dark ? 0.14 : 0.10 }

    /// The spinner that takes a busy button's label.
    static func spinnerSize(compact: Bool) -> CGFloat {
        compact ? Sizing.iconTiny : Sizing.iconSmall
    }
    static let spinnerLineWidth: CGFloat = 2
}

// MARK: - Loading State

extension EnvironmentValues {
    /// True while the button is busy (`.buttonLoading(true)`): the text button
    /// styles hide the label under a spinner at the label's size.
    @Entry public var buttonIsLoading: Bool = false
}

extension View {
    /// A busy button: a spinner takes the label's place (the button keeps its
    /// size) and it can't be pressed, but it keeps its enabled look — it's
    /// working, not unavailable. For the text button styles (Primary,
    /// Secondary, Outline, Ghost, Destructive, the gradient button).
    ///
    /// ```swift
    /// Button("Save") { save() }
    ///     .buttonStyle(PrimaryButtonStyle())
    ///     .buttonLoading(isSaving)
    /// ```
    public func buttonLoading(_ isLoading: Bool) -> some View {
        environment(\.buttonIsLoading, isLoading)
            .disabled(isLoading)
            .accessibilityValue(isLoading ? Text("Loading", bundle: .module) : Text(verbatim: ""))
    }

    /// The label hidden under a spinner while loading, at the label's own size
    /// so the button doesn't shrink.
    fileprivate func loadingSpinner(_ isLoading: Bool, color: Color, compact: Bool) -> some View {
        opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ThinkingSpinner(
                        size: ButtonMetrics.spinnerSize(compact: compact),
                        lineWidth: ButtonMetrics.spinnerLineWidth,
                        color: color
                    )
                }
            }
    }
}

// MARK: - Shared Text Button Body

/// What the body is asked about on every render.
private struct TextButtonState {
    let isEnabled: Bool
    let isHovering: Bool
    let isPressed: Bool
    let scheme: ColorScheme

    var isActive: Bool { isHovering || isPressed }
}

/// The five text looks, each answering fill / highlight / hairline / text for
/// a state. Everything else about a text button is the same and lives in
/// `TextButtonBody`.
private enum TextButtonKind {
    case primary
    case outline
    case secondary(accent: Bool)
    case ghost
    case destructive(prominent: Bool)

    func text(_ state: TextButtonState) -> Color {
        guard state.isEnabled else { return ButtonMetrics.disabledText(state.scheme) }
        switch self {
        case .primary, .outline:
            return Color.textPrimary
        case .secondary(let accent):
            return accent || state.isActive ? Color.primary : Color.secondary
        case .ghost:
            return state.isActive ? Color.primary : Color.secondary
        case .destructive(let prominent):
            // Prominent: white on the deep red. Subtle: the red mark, which on
            // dark is the lifted tone the status chips use.
            return prominent ? Color.white : Danger.danger500
        }
    }

    func fill(_ state: TextButtonState) -> Color {
        switch self {
        case .primary, .secondary(accent: true):
            guard state.isEnabled else { return ButtonMetrics.primaryDisabledFill(state.scheme) }
            return state.isHovering ? ButtonMetrics.primaryHoverFill(state.scheme) : ButtonMetrics.primaryRestFill(state.scheme)
        case .outline, .secondary(accent: false), .ghost:
            guard state.isEnabled else { return .clear }
            if state.isPressed { return RowTint.selected(state.scheme) }
            if state.isHovering { return RowTint.hover(state.scheme) }
            return .clear
        case .destructive(prominent: true):
            // The deep red: white text sits on it, and the lifted mark red is
            // too light for that on dark.
            return state.isEnabled ? Danger.tint : ButtonMetrics.prominentDisabledFill(state.scheme)
        case .destructive(prominent: false):
            guard state.isEnabled else { return .clear }
            if state.isPressed { return ButtonMetrics.destructivePressFill(state.scheme) }
            if state.isHovering { return StatusWash.fill(Danger.danger500, state.scheme) }
            return .clear
        }
    }

    /// A wash laid over the fill: the prominent red lightens on hover.
    func highlight(_ state: TextButtonState) -> Color {
        if case .destructive(prominent: true) = self, state.isEnabled, state.isActive {
            return Color.white.opacity(ButtonMetrics.prominentHoverLift)
        }
        return .clear
    }

    func hairline(_ state: TextButtonState) -> Color? {
        switch self {
        case .primary, .ghost, .secondary(accent: true), .destructive(prominent: true):
            return nil
        case .outline:
            return ButtonMetrics.outlineBorder(isEnabled: state.isEnabled)
        case .secondary(accent: false):
            return ButtonMetrics.hairline(isEnabled: state.isEnabled)
        case .destructive(prominent: false):
            let line = StatusWash.border(Danger.danger500, state.scheme)
            return state.isEnabled ? line : line.opacity(ButtonMetrics.disabledHairlineOpacity)
        }
    }
}

/// Every text button: label, spinner, the tier's padding and height (or a
/// square for `iconOnly`), fill, hairline, focus ring, press scale, hover.
private struct TextButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: TextButtonKind
    let isEnabled: Bool
    let isLoading: Bool
    let compact: Bool
    let iconOnly: Bool
    let fullWidth: Bool
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var state: TextButtonState {
        TextButtonState(isEnabled: isEnabled, isHovering: isHovering, isPressed: configuration.isPressed, scheme: colorScheme)
    }

    var body: some View {
        let state = state
        let textColor = kind.text(state)
        let side = ButtonMetrics.minHeight(compact: compact)
        configuration.label
            .font(ButtonMetrics.labelFont)
            .foregroundStyle(textColor)
            .loadingSpinner(isLoading, color: textColor, compact: compact)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, iconOnly ? 0 : ButtonMetrics.horizontalPadding(compact: compact))
            .padding(.vertical, iconOnly ? 0 : ButtonMetrics.verticalPadding(compact: compact))
            .frame(width: iconOnly ? side : nil, height: iconOnly ? side : nil)
            .frame(minHeight: iconOnly ? nil : side)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(kind.fill(state))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(kind.highlight(state))
                    }
            }
            .overlay {
                if let hairline = kind.hairline(state) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(hairline, lineWidth: ButtonMetrics.hairlineWidth)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(state.isPressed && isEnabled ? Animations.pressScale : 1)
            // A Tab stop like every other style (Space presses it).
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled && !isLoading ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: state.isPressed)
    }
}

// MARK: - Primary Button Style

/// Primary button — the neutral filled surface, no accent hue
/// Use for main actions: Submit, Save, Continue, Create
public struct PrimaryButtonStyle: ButtonStyle {
    var compact: Bool = false
    var iconOnly: Bool = false
    var fullWidth: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph.
    ///   - fullWidth: Spans its container — a sheet's or an onboarding card's call to action.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, iconOnly: Bool = false, fullWidth: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.fullWidth = fullWidth
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            TextButtonBody(
                configuration: configuration,
                kind: .primary,
                // A loading button is disabled, but keeps its enabled look.
                isEnabled: isEnabled || isLoading,
                isLoading: isLoading,
                compact: compact,
                iconOnly: iconOnly,
                fullWidth: fullWidth,
                cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
            )
        }
        .interactiveCursor()
    }
}

// MARK: - Outline Button Style

/// Outlined counterpart to `PrimaryButtonStyle` — same metrics, but a clear
/// fill with a primary-toned hairline border and primary label, for prominent
/// actions that shouldn't carry the accent fill (e.g. a title-bar New
/// button).
public struct OutlineButtonStyle: ButtonStyle {
    var compact: Bool = false
    var iconOnly: Bool = false
    var fullWidth: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph.
    ///   - fullWidth: Spans its container.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, iconOnly: Bool = false, fullWidth: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.fullWidth = fullWidth
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            TextButtonBody(
                configuration: configuration,
                kind: .outline,
                isEnabled: isEnabled || isLoading,
                isLoading: isLoading,
                compact: compact,
                iconOnly: iconOnly,
                fullWidth: fullWidth,
                cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
            )
        }
        .interactiveCursor()
    }
}

// MARK: - Secondary Button Style

/// Secondary button — hairline border, clear fill at rest, `RowTint`
/// hover/press, secondary→primary text on hover.
/// Use for secondary actions: Cancel, Back, Edit
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    var compact: Bool = false
    var iconOnly: Bool = false
    /// The same neutral filled surface as Primary — for affirmative secondary
    /// actions (Check Now, Connect…) that should read as primary-colored. Plain
    /// secondary buttons (Cancel, Back) leave this off and stay neutral grey.
    var accent: Bool = false
    var fullWidth: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph.
    ///   - accent: The filled variant for affirmative secondary actions (Check
    ///     Now, Connect…); plain secondary buttons (Cancel, Back) leave it off.
    ///   - fullWidth: Spans its container.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(
        compact: Bool = false,
        iconOnly: Bool = false,
        accent: Bool = false,
        fullWidth: Bool = false,
        cornerRadiusOverride: CGFloat? = nil
    ) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.accent = accent
        self.fullWidth = fullWidth
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            TextButtonBody(
                configuration: configuration,
                kind: .secondary(accent: accent),
                isEnabled: isEnabled || isLoading,
                isLoading: isLoading,
                compact: compact,
                iconOnly: iconOnly,
                fullWidth: fullWidth,
                cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
            )
        }
        .interactiveCursor()
    }
}

// MARK: - Ghost Button Style

/// Ghost button — borderless, `RowTint` hover, secondary→primary text.
/// Use for tertiary actions: Skip, Learn more, View all
public struct GhostButtonStyle: ButtonStyle {
    var compact: Bool = false
    var iconOnly: Bool = false
    /// Lay the label out exactly where plain text would sit — no padding of its
    /// own — and draw the hover fill around it instead, bleeding past its edges.
    /// For a heading that's also a link (a title bar's back link), which has to
    /// line up with the static headings beside it.
    var hugsLabel: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph — the row action
    ///     that shouldn't carry a hairline.
    ///   - hugsLabel: Keep the label where plain text would sit and let the
    ///     hover fill bleed past it — for a heading that's also a link.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, iconOnly: Bool = false, hugsLabel: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.hugsLabel = hugsLabel
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            if hugsLabel {
                GhostHuggingLabel(
                    configuration: configuration,
                    isEnabled: isEnabled,
                    cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
                )
            } else {
                TextButtonBody(
                    configuration: configuration,
                    kind: .ghost,
                    isEnabled: isEnabled || isLoading,
                    isLoading: isLoading,
                    compact: compact,
                    iconOnly: iconOnly,
                    fullWidth: false,
                    cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
                )
            }
        }
        .interactiveCursor()
    }
}

/// The label at its natural size and position; the fill and the hover and
/// click area extend past it, then the negative padding hands the layout
/// back the label's own frame (the same trick as `listRowHover`). No spinner:
/// a heading link has no room for one.
private struct GhostHuggingLabel: View {
    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    /// How far the fill reaches past the label on each side: the compact ghost
    /// button's own padding, so the fill is the size that button would be —
    /// only the label stays put.
    private static var labelBleed: EdgeInsets {
        EdgeInsets(
            top: ButtonMetrics.verticalPadding(compact: true),
            leading: ButtonMetrics.horizontalPadding(compact: true),
            bottom: ButtonMetrics.verticalPadding(compact: true),
            trailing: ButtonMetrics.horizontalPadding(compact: true)
        )
    }

    private var state: TextButtonState {
        TextButtonState(isEnabled: isEnabled, isHovering: isHovering, isPressed: configuration.isPressed, scheme: colorScheme)
    }

    var body: some View {
        let state = state
        configuration.label
            .font(ButtonMetrics.labelFont)
            .foregroundStyle(TextButtonKind.ghost.text(state))
            .padding(Self.labelBleed)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TextButtonKind.ghost.fill(state))
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(state.isPressed && isEnabled ? Animations.pressScale : 1)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .padding(EdgeInsets(
                top: -Self.labelBleed.top,
                leading: -Self.labelBleed.leading,
                bottom: -Self.labelBleed.bottom,
                trailing: -Self.labelBleed.trailing
            ))
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: state.isPressed)
    }
}

// MARK: - Destructive Button Style

/// Destructive button — subtle (the toolbar language in danger red) or
/// prominent (the solid red of a confirmation dialog).
public struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    var compact: Bool = false
    var iconOnly: Bool = false
    /// Set to true in confirmation dialogs for bold red styling
    var prominent: Bool = false
    var cornerRadiusOverride: CGFloat? = nil

    /// - Parameters:
    ///   - compact: The dense size, for toolbars and tight rows.
    ///   - iconOnly: A square button sized for a lone glyph (a trash can).
    ///   - prominent: The bold red fill, for confirmation dialogs.
    ///   - cornerRadiusOverride: Replaces the default `Sizing.radiusMedium` corners.
    public init(compact: Bool = false, iconOnly: Bool = false, prominent: Bool = false, cornerRadiusOverride: CGFloat? = nil) {
        self.compact = compact
        self.iconOnly = iconOnly
        self.prominent = prominent
        self.cornerRadiusOverride = cornerRadiusOverride
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            TextButtonBody(
                configuration: configuration,
                kind: .destructive(prominent: prominent),
                isEnabled: isEnabled || isLoading,
                isLoading: isLoading,
                compact: compact,
                iconOnly: iconOnly,
                fullWidth: false,
                cornerRadius: cornerRadiusOverride ?? ButtonMetrics.cornerRadius
            )
        }
        .interactiveCursor()
    }
}

// MARK: - Small Pill Button Style

/// A small capsule for an inline action (Upgrade, Grant Access, Choose…):
/// `Sizing.controlSmall` tall on a quiet wash of its own color, so it reads as
/// a mini-action, not a sibling of the main call to action.
public struct SmallPillButtonStyle: ButtonStyle {
    /// Neutral by default (monochrome button system); semantic colors
    /// (Warning/Success/Danger) may still be passed for status pills.
    var color: Color = .primary
    var isSelected: Bool = false
    var compact: Bool = false

    /// - Parameters:
    ///   - color: The label and tint color. Neutral by default; pass a status
    ///     color (Warning/Success/Danger) for a status pill.
    ///   - isSelected: Keeps the pressed wash — a toggleable filter chip.
    ///   - compact: A badge-height pill (`BadgeSize.regular`) for a table cell.
    public init(color: Color = .primary, isSelected: Bool = false, compact: Bool = false) {
        self.color = color
        self.isSelected = isSelected
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            SmallPillButton(configuration: configuration, color: color, isSelected: isSelected, compact: compact)
        }
        .interactiveCursor()
    }
}

/// Internal view for small pill button with hover and focus tracking
private struct SmallPillButton: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let isSelected: Bool
    let compact: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isPressed: Bool { configuration.isPressed }

    private var wash: Color {
        let opacity = isPressed || isSelected
            ? ButtonMetrics.pillActiveOpacity(colorScheme)
            : ButtonMetrics.pillRestOpacity(colorScheme)
        return color.statusTint.opacity(opacity)
    }

    var body: some View {
        configuration.label
            .font(compact ? BadgeSize.regular.font : Typography.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, compact ? BadgeSize.regular.horizontalPadding : Spacing.sm)
            .padding(.vertical, compact ? BadgeSize.regular.verticalPadding : Spacing.hairline)
            .frame(minHeight: compact ? BadgeSize.regular.minHeight : Sizing.controlSmall)
            .background {
                Capsule()
                    .fill(wash)
                    .overlay {
                        Capsule()
                            .fill(isHovering ? RowTint.hover(colorScheme) : Color.clear)
                    }
            }
            .contentShape(Capsule())
            .focusRingCapsule(isFocused: isFocused)
            .scaleEffect(isPressed && isEnabled ? Animations.pressScale : 1)
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: isPressed)
    }
}

// MARK: - Toolbar Icon Button Style

/// Style for standalone toolbar icon buttons (an inspector or settings toggle),
/// with explicit `isActive` state control for buttons that toggle a panel.
/// A `Sizing.controlDefault` square (`Sizing.controlSmall` compact) with the
/// `RowTint` hover and selection fills.
public struct ToolbarIconButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var extraLeadingPadding: CGFloat = 0
    var extraTrailingPadding: CGFloat = 0
    /// When set, the button keeps this background fill (e.g. `Color.primary` for an
    /// emphasized action) and renders its icon in a contrasting color.
    var fill: Color? = nil
    /// A status-colored glyph (a red Stop, a green Run) without a solid fill.
    var tint: Color? = nil
    /// Tighter internal padding for dense toolbars.
    var compact: Bool = false

    /// - Parameters:
    ///   - isActive: Keeps the highlighted fill, for a toggle that's on.
    ///   - extraLeadingPadding: Hit-area padding added before the button.
    ///   - extraTrailingPadding: Hit-area padding added after the button.
    ///   - fill: A solid background (e.g. `Color.primary` for an emphasized
    ///     action); the icon switches to a contrasting color.
    ///   - tint: The glyph's color (a red Stop, a green Run); ignored with `fill`.
    ///   - compact: Tighter internal padding for dense toolbars.
    public init(
        isActive: Bool = false,
        extraLeadingPadding: CGFloat = 0,
        extraTrailingPadding: CGFloat = 0,
        fill: Color? = nil,
        tint: Color? = nil,
        compact: Bool = false
    ) {
        self.isActive = isActive
        self.extraLeadingPadding = extraLeadingPadding
        self.extraTrailingPadding = extraTrailingPadding
        self.fill = fill
        self.tint = tint
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            ToolbarIconButton(
                configuration: configuration,
                isActive: isActive,
                extraLeadingPadding: extraLeadingPadding,
                extraTrailingPadding: extraTrailingPadding,
                fill: fill,
                tint: tint,
                compact: compact
            )
        }
        .interactiveCursor()
    }
}

/// Internal view for toolbar icon button with hover and focus tracking
private struct ToolbarIconButton: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let extraLeadingPadding: CGFloat
    let extraTrailingPadding: CGFloat
    var fill: Color? = nil
    var tint: Color? = nil
    var compact: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var cornerRadius: CGFloat { ButtonMetrics.cornerRadius }

    private var isHighlighted: Bool {
        isEnabled && (isHovering || isActive || configuration.isPressed)
    }

    private var iconColor: Color {
        if !isEnabled {
            return ButtonMetrics.disabledText(colorScheme)
        }
        // On a solid fill the glyph reads against the fill — use the same
        // luminance-aware contrast color the primary button uses on its accent fill.
        if fill != nil {
            return AccentHue.contrastForeground
        }
        // Idle icons use the full label color rather than a washed grey.
        return tint ?? Color.primary
    }

    /// Background — an active toggle keeps the selection fill (the icon no
    /// longer carries an accent tint, so the fill is the active signal).
    private var backgroundColor: Color {
        // A solid fill stays put; hover only deepens it slightly.
        if let fill {
            return isHighlighted ? fill.opacity(ButtonMetrics.solidFillHoverOpacity) : fill
        }
        guard isEnabled else { return .clear }
        if isActive { return RowTint.selected(colorScheme) }
        if isHovering || configuration.isPressed { return RowTint.hover(colorScheme) }
        return .clear
    }

    /// Every icon button is square, whatever its glyph's shape: `sidebar.left`
    /// is wider than tall, `arrow.clockwise` taller than wide.
    private var side: CGFloat {
        compact ? Sizing.controlSmall : Sizing.controlDefault
    }

    private var insetPadding: CGFloat {
        isTahoeOrLater ? Spacing.insetSpacing : 0
    }

    var body: some View {
        configuration.label
            .foregroundStyle(iconColor)
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, padding: 0)
            .scaleEffect(configuration.isPressed && isEnabled ? Animations.iconPressScale : 1)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .padding(.horizontal, insetPadding)
            .padding(.leading, extraLeadingPadding)
            .padding(.trailing, extraTrailingPadding)
            .contentShape(Rectangle())
            .onHover { isHovering = isEnabled ? $0 : false }
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
    ///   - outset: Moves the ring out past a label with no padding of its own
    ///     (`Spacing.ringOutset` for bare text).
    ///   - bleed: Widens the ring sideways only, to trace a row-hover fill.
    public init(cornerRadius: CGFloat = Sizing.radiusDefault, outset: CGFloat = 0, bleed: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.outset = outset
        self.bleed = bleed
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            FocusablePlainButton(configuration: configuration, cornerRadius: cornerRadius, outset: outset, bleed: bleed)
        }
        .interactiveCursor()
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
/// press. With `isSelected` it draws the one shared selected look — the
/// `RowTint` selection wash and an accent hairline — so a card need not draw
/// its own. `cornerRadius` follows the label's shape (`Sizing.radiusFull` for
/// a capsule or circle).
public struct SelectableCardButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Sizing.radiusDefault
    var isSelected: Bool = false

    /// - Parameters:
    ///   - cornerRadius: The label's corner radius (`Sizing.radiusFull` for a
    ///     capsule or circle).
    ///   - isSelected: Draws the selection wash and an accent hairline.
    public init(cornerRadius: CGFloat = Sizing.radiusDefault, isSelected: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            SelectableCard(configuration: configuration, cornerRadius: cornerRadius, isSelected: isSelected)
        }
        .interactiveCursor()
    }
}

private struct SelectableCard: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let isSelected: Bool

    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private var wash: Color {
        if isSelected { return RowTint.selected(colorScheme) }
        if isHovering && isEnabled { return RowTint.hover(colorScheme) }
        return .clear
    }

    var body: some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(wash)
                    .allowsHitTesting(false)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.accent, lineWidth: ButtonMetrics.hairlineWidth)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(configuration.isPressed && isEnabled ? Animations.pressScale : 1)
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
/// underline or inside a row (browse, save / get / set, copy, reveal…). The
/// `RowTint` hover chip fades in, and the glyph scales down on press — the
/// same micro-interaction language as the toolbar icon buttons, scaled for
/// inline use. Only transform + opacity animate, so it stays cheap.
///
/// Honors `.disabled`: a disabled button shows no hover chip and no press
/// scale, so a greyed-out action reads as inert.
public struct InlineIconButtonStyle: ButtonStyle {
    /// Corner radius of the hover chip; `Sizing.radiusSmall` is concentric with
    /// an 18pt chip (`Sizing.inlineIconButton`).
    var chipRadius: CGFloat = Sizing.radiusSmall

    /// - Parameter chipRadius: Corner radius of the hover chip; match it to the
    ///   button's content frame.
    public init(chipRadius: CGFloat = Sizing.radiusSmall) {
        self.chipRadius = chipRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            InlineIconButton(configuration: configuration, chipRadius: chipRadius)
        }
        .interactiveCursor()
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
        return RowTint.hover(colorScheme)
    }

    var body: some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: chipRadius, style: .continuous)
                    .fill(hoverBackground)
            }
            .focusRing(isFocused: isFocused, cornerRadius: chipRadius, padding: 0)
            .scaleEffect(configuration.isPressed && isEnabled ? Animations.iconPressScale : 1)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

// MARK: - Animated Gradient Border Button Style

/// The numbers of the gradient button's own: how its border reads and how it turns.
private enum GradientButtonMetrics {
    static let borderOpacityFocused: Double = 0.9
    static let borderOpacityRest: Double = 0.6
    /// A pause after hover starts, so a toolbar settling doesn't spin it.
    static let startDelay: Duration = .milliseconds(500)
    /// One full turn of the gradient.
    static let rotationPeriod: TimeInterval = 3
}

/// Button with an animated gradient border effect — the signature "this
/// starts something big" button. The regular and compact tiers share the text
/// buttons' metrics; `.mini` sits at `Sizing.controlSmall`.
public struct AnimatedGradientBorderButtonStyle: ButtonStyle {
    /// Density tiers: `.regular` (a toolbar's headline New button), `.compact`
    /// (28pt, mirrors the compact flag on the text-button styles), `.mini`
    /// (24pt, `labelSmall` — sits flush beside small icon controls like the ✕).
    public enum Size { case regular, compact, mini }

    var size: Size = .regular
    var iconOnly: Bool = false

    /// Back-compat convenience for the boolean call sites.
    /// - Parameters:
    ///   - compact: The 28pt tier.
    ///   - iconOnly: A square sized for a lone glyph.
    public init(compact: Bool = false, iconOnly: Bool = false) {
        self.size = compact ? .compact : .regular
        self.iconOnly = iconOnly
    }

    /// - Parameters:
    ///   - size: The density tier.
    ///   - iconOnly: A square sized for a lone glyph.
    public init(size: Size, iconOnly: Bool = false) {
        self.size = size
        self.iconOnly = iconOnly
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.floatingMenuActive) private var menuActive
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.buttonIsLoading) private var isLoading

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            AnimatedGradientBorderButton(
                configuration: configuration,
                colorScheme: colorScheme,
                menuActive: menuActive,
                isEnabled: isEnabled || isLoading,
                isLoading: isLoading,
                size: size,
                iconOnly: iconOnly
            )
        }
        .interactiveCursor()
    }
}

/// Internal view for the animated gradient border button
/// Animation only runs on hover/focus to conserve energy
private struct AnimatedGradientBorderButton: View {
    let configuration: ButtonStyleConfiguration
    let colorScheme: ColorScheme
    let menuActive: Bool
    let isEnabled: Bool
    let isLoading: Bool
    let size: AnimatedGradientBorderButtonStyle.Size
    let iconOnly: Bool

    @State private var rotation: Double = 0
    @State private var isHovering: Bool = false
    @State private var animationTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var labelFont: Font {
        size == .mini ? Typography.labelSmall : ButtonMetrics.labelFont
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return ButtonMetrics.horizontalPadding(compact: false)
        case .compact: return ButtonMetrics.horizontalPadding(compact: true)
        case .mini: return Spacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return ButtonMetrics.verticalPadding(compact: false)
        case .compact: return ButtonMetrics.verticalPadding(compact: true)
        case .mini: return Spacing.xxs
        }
    }

    private var minHeight: CGFloat {
        switch size {
        case .regular: return ButtonMetrics.minHeight(compact: false)
        case .compact: return ButtonMetrics.minHeight(compact: true)
        case .mini: return Sizing.controlSmall
        }
    }

    private var cornerRadius: CGFloat { ButtonMetrics.cornerRadius }

    /// Whether button should show active/hover state (hovering OR menu is open OR focused)
    private var isActive: Bool {
        isEnabled && (isHovering || menuActive || isFocused)
    }

    private var borderOpacity: Double {
        isFocused ? GradientButtonMetrics.borderOpacityFocused : GradientButtonMetrics.borderOpacityRest
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

    /// The resting box fill; hover or focus lifts it to the row hover tint.
    private var backgroundColor: Color {
        isActive ? RowTint.hover(colorScheme) : Color.restingFill
    }

    var body: some View {
        configuration.label
            .font(labelFont)
            .foregroundStyle(isEnabled ? Color.primary : ButtonMetrics.disabledText(colorScheme))
            .loadingSpinner(isLoading, color: .primary, compact: size != .regular)
            .padding(.horizontal, iconOnly ? 0 : horizontalPadding)
            .padding(.vertical, iconOnly ? 0 : verticalPadding)
            .frame(width: iconOnly ? minHeight : nil, height: iconOnly ? minHeight : nil)
            .frame(minHeight: iconOnly ? nil : minHeight)
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
                        lineWidth: ButtonMetrics.hairlineWidth
                    )
                    .opacity(borderOpacity)
            )
            // The same ring as every other button, over the gradient.
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius)
            .fixedSize()
            .scaleEffect(configuration.isPressed && isEnabled ? Animations.pressScale : 1)
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
            .padding(.horizontal, isTahoeOrLater ? Spacing.insetSpacing : 0)
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .animation(Animations.press, value: configuration.isPressed)
            .animation(Animations.hover, value: isActive)
            .onHover { hovering in
                isHovering = isEnabled && !isLoading ? hovering : false
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
            try? await Task.sleep(for: GradientButtonMetrics.startDelay)
            guard !Task.isCancelled else { return }

            while !Task.isCancelled {
                withAnimation(.linear(duration: GradientButtonMetrics.rotationPeriod)) {
                    rotation += 360
                }
                try? await Task.sleep(for: .seconds(GradientButtonMetrics.rotationPeriod))
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
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.md) {
                Button("Continue") { }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Save Changes") { }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Disabled") { }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
                Button { } label: { Image(systemName: "plus") }
                    .buttonStyle(PrimaryButtonStyle(iconOnly: true))
            }
        }

        // Secondary - Supporting actions
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Secondary – Supporting Actions")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xxs) {
                    Button("Remove") { }
                        .buttonStyle(DestructiveButtonStyle())
                    Text("Inline (subtle)")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: Spacing.xxs) {
                    Button("Delete Item") { }
                        .buttonStyle(DestructiveButtonStyle(prominent: true))
                    Text("Confirmation (prominent)")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }
        }

        Divider()

        // Small Pill - Inline CTAs
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Small Pill – Inline CTAs")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.md) {
                Button("Choose...") { }
                    .buttonStyle(SmallPillButtonStyle())
                Button("Upgrade") { }
                    .buttonStyle(SmallPillButtonStyle(color: Warning.warning500))
                Button("Grant Access") { }
                    .buttonStyle(SmallPillButtonStyle(color: Success.success500, isSelected: true))
            }
        }

        Divider()

        // Animated Gradient Border
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Animated Gradient Border – Special CTAs")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            Button {
            } label: {
                Label("New Item", systemImage: "plus")
            }
            .buttonStyle(AnimatedGradientBorderButtonStyle())
        }
    }
    .padding(Spacing.xxl)
}
