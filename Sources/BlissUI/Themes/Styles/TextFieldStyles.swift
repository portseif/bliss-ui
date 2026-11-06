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

// MARK: - Large Padded Text Field Style

/// Linear-style form text field — minimal underline that turns accent on focus.
public struct LargePaddedTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    /// Underline color — accent on focus, muted grey otherwise.
    private var lineColor: Color {
        if isFocused {
            return Color.accent
        }
        return colorScheme == .dark ? Grey.grey600 : Grey.grey300
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .padding(.vertical, Spacing.inlineSpacing + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    public init() {}

    private var cornerRadius: CGFloat {
        isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault
    }

    private var borderColor: Color {
        if isFocused {
            return Color.accent
        }
        // Use grey300 in light mode for better visibility against light backgrounds
        return colorScheme == .dark ? Grey.grey700 : Grey.grey300
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Grey.grey800 : Grey.grey50
    }

    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .focused($isFocused)
            .textFieldStyle(.plain)
            .font(Typography.labelMedium)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
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
        // Use grey300 in light mode for better visibility against light backgrounds
        return colorScheme == .dark ? Grey.grey700 : Grey.grey300
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Grey.grey800 : Grey.grey50
    }

    private var iconColor: Color {
        isFocused
            ? .accent
            : Grey.grey400
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
        .background {
            Capsule()
                .fill(backgroundColor)
        }
        .overlay {
            Capsule()
                .stroke(borderColor, lineWidth: 1)
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
        // Use grey300 in light mode for better visibility against light backgrounds
        return colorScheme == .dark ? Grey.grey700 : Grey.grey300
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Grey.grey800 : Grey.grey50
    }

    private var iconColor: Color {
        isFocused
            ? .accent
            : Grey.grey400
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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
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
    /// ring (the one every button shows) while focused. The field needs its own
    /// `.focused(_:)` binding to pass in as `isFocused`.
    public func inputBox(isFocused: Bool, cornerRadius: CGFloat = Sizing.radiusDefault) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isFocused ? Color.controlBackground : Color.primary.opacity(0.04))
                .animation(Animations.hover, value: isFocused)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
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
