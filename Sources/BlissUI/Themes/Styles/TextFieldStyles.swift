//
//  TextFieldStyles.swift
//  BlissUI
//
//  Linear-inspired text field styles:
//  - Clean, minimal borders
//  - Subtle focus states
//  - No heavy shadows or gradients
//  - Muted placeholder colors

import SwiftUI

// MARK: - Filled field colors

/// The compact, search and toolbar search fields' fill and border: the active
/// color theme's raised surface and border, or the built-in greys under System
/// (fixed greys read as a grey box on a tinted theme).
private enum FilledFieldColors {
    static func background(_ scheme: ColorScheme) -> Color {
        if let palette = ThemeColors.activePalette { return palette.elevatedBackground.color }
        return scheme == .dark ? Grey.grey800 : Grey.grey50
    }

    /// The one neutral hairline every box draws.
    static func border(_ scheme: ColorScheme) -> Color {
        Color.menuBorder
    }
}

// MARK: - Large Padded Text Field Style

/// Linear-style form text field — minimal underline that turns accent on focus.
public struct LargePaddedTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.formFieldIsInvalid) private var isInvalid

    public init() {}

    /// Underline color — red inside a `FormField` with an error, accent on
    /// focus, muted grey otherwise.
    private var lineColor: Color {
        if isInvalid {
            return Danger.danger500
        }
        if isFocused {
            return Color.accent
        }
        if let palette = ThemeColors.activePalette { return palette.border.color }
        return colorScheme == .dark ? Grey.grey600 : Grey.grey300
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .textFieldStyle(.plain)
            .font(Typography.labelMedium)
            .multilineTextAlignment(.leading)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Sizing.controlMedium, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(lineColor)
                    .frame(height: 1)
            }
            .focusEffectDisabled()
            .animation(Animations.hover, value: isFocused)
    }
}

extension TextFieldStyle where Self == LargePaddedTextFieldStyle {
    public static var largePadded: LargePaddedTextFieldStyle {
        LargePaddedTextFieldStyle()
    }
}

// MARK: - Compact Text Field Style

/// Linear-style compact text field
public struct CompactTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.formFieldIsInvalid) private var isInvalid

    public init() {}

    private var cornerRadius: CGFloat {
        isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault
    }

    private var borderColor: Color {
        if isInvalid {
            return Danger.danger500
        }
        if isFocused {
            return Color.accent
        }
        return FilledFieldColors.border(colorScheme)
    }

    private var backgroundColor: Color {
        FilledFieldColors.background(colorScheme)
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .textFieldStyle(.plain)
            .font(Typography.labelMedium)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.fieldPaddingH)
            .padding(.vertical, Spacing.fieldPaddingV)
            .frame(maxWidth: .infinity, minHeight: Sizing.controlDefault, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .focusEffectDisabled()
            .animation(Animations.hover, value: isFocused)
    }
}

extension TextFieldStyle where Self == CompactTextFieldStyle {
    public static var compact: CompactTextFieldStyle {
        CompactTextFieldStyle()
    }
}

// MARK: - Search Text Field Style

/// Linear-style search field with pill shape
public struct SearchTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    private var borderColor: Color {
        if isFocused {
            return Color.accent
        }
        return FilledFieldColors.border(colorScheme)
    }

    private var backgroundColor: Color {
        FilledFieldColors.background(colorScheme)
    }

    private var iconColor: Color {
        isFocused
            ? .accent
            : Color.textTertiary
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Typography.labelMedium)
                .foregroundStyle(iconColor)

            configuration
                .focused($isFocused)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Sizing.controlMedium)
        .background {
            Capsule()
                .fill(backgroundColor)
        }
        .overlay {
            Capsule()
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .focusEffectDisabled()
        .animation(Animations.hover, value: isFocused)
    }
}

extension TextFieldStyle where Self == SearchTextFieldStyle {
    public static var search: SearchTextFieldStyle {
        SearchTextFieldStyle()
    }
}

// MARK: - Toolbar Search Text Field Style

/// Linear-style toolbar search field with icon inside the style for proper focus tracking
/// Uses rounded corners (not capsule) for toolbar aesthetic
public struct ToolbarSearchTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    private var cornerRadius: CGFloat {
        isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault
    }

    private var borderColor: Color {
        if isFocused {
            return Color.accent
        }
        return FilledFieldColors.border(colorScheme)
    }

    private var backgroundColor: Color {
        FilledFieldColors.background(colorScheme)
    }

    private var iconColor: Color {
        isFocused
            ? .accent
            : Color.textTertiary
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(Typography.labelMedium)
                .foregroundStyle(iconColor)

            configuration
                .focused($isFocused)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, Spacing.fieldPaddingH)
        .padding(.vertical, Spacing.fieldPaddingV)
        .frame(minHeight: Sizing.controlDefault)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .focusEffectDisabled()
        .animation(Animations.hover, value: isFocused)
    }
}

extension TextFieldStyle where Self == ToolbarSearchTextFieldStyle {
    public static var toolbarSearch: ToolbarSearchTextFieldStyle {
        ToolbarSearchTextFieldStyle()
    }
}

// MARK: - Hand-built input box

extension View {
    /// The box behind an input built by hand — a search bar with an icon, a
    /// note field with a timestamp beside it, an inline composer field: a faint
    /// fill and a hairline at rest, the control surface and the shared focus
    /// ring (the one every button shows) while focused, and a red hairline
    /// inside a `FormField` with an error. The field needs its own
    /// `.focused(_:)` binding to pass in as `isFocused`.
    ///
    /// A single-line field keeps the default corners (`Sizing.fieldCornerRadius`,
    /// a capsule on macOS 26); a box that holds more than one line passes
    /// `Sizing.textBoxCornerRadius`. `fill: .none` drops the resting fill and
    /// hairline for a borderless field inside a card.
    public func inputBox(
        isFocused: Bool,
        cornerRadius: CGFloat = Sizing.fieldCornerRadius,
        fill: InputBoxFill = .resting
    ) -> some View {
        modifier(InputBoxModifier(isFocused: isFocused, cornerRadius: cornerRadius, fill: fill))
    }
}

/// What an `.inputBox` draws at rest.
public enum InputBoxFill {
    /// The faint fill and hairline every boxed field has.
    case resting
    /// Nothing at rest; the box appears only while focused or invalid.
    case none
}

private struct InputBoxModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat
    let fill: InputBoxFill

    @Environment(\.formFieldIsInvalid) private var isInvalid

    private var restingFill: Color {
        fill == .resting ? Color.restingFill : .clear
    }

    private var hairline: Color {
        if isInvalid { return Danger.danger500 }
        return fill == .resting || isFocused ? Color.menuBorder : .clear
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isFocused ? Color.controlBackground : restingFill)
                    .animation(Animations.hover, value: isFocused)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(hairline, lineWidth: 1)
            }
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius, showsOnPointerFocus: true)
    }
}

// MARK: - Previews

#Preview("Text Field Styles") {
    VStack(spacing: Spacing.xl) {
        Text("Text Field Styles")
            .font(Typography.displaySmall)

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Large Padded (Default)")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            TextField("", text: .constant(""), prompt: Text("Enter a name..."))
                .textFieldStyle(.largePadded)
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Large Padded (With Content)")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            TextField("", text: .constant("Quarterly Report"), prompt: Text("Enter a name..."))
                .textFieldStyle(.largePadded)
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Compact")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            TextField("", text: .constant(""), prompt: Text("Quick edit..."))
                .textFieldStyle(.compact)
                .frame(width: 200)
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Search")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            TextField("", text: .constant(""), prompt: Text("Search..."))
                .textFieldStyle(.search)
        }

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Multiline")
                .font(Typography.caption)
                .foregroundStyle(Grey.grey500)
            TextField("", text: .constant(""), prompt: Text("Enter notes..."), axis: .vertical)
                .textFieldStyle(.largePadded)
                .lineLimit(3...5)
        }
    }
    .padding(Spacing.xl)
    .frame(width: 350)
}
