//
//  TextFieldStyles.swift
//  BlissUI
//
//  Boxed text fields: a field rests in a faint well with a hairline, and while
//  focused keeps the well and takes an accent hairline (red inside a
//  `FormField` with an error). `.largePadded` is the regular 32pt box,
//  `.compact` the 28pt one. The search styles are the same well and hairline
//  around a quiet glyph.

import SwiftUI

// MARK: - Boxed field

/// The box every text field style draws, at a control tier's height.
private struct BoxedFieldChrome<Content: View>: View {
    let content: Content
    let isFocused: Bool
    let minHeight: CGFloat
    let verticalPadding: CGFloat

    @Environment(\.formFieldIsInvalid) private var isInvalid
    @Environment(\.controlShape) private var controlShape

    private var cornerRadius: CGFloat { controlShape.radius(rounded: Sizing.fieldCornerRadius) }

    private var hairline: Color {
        if isInvalid { return Danger.danger500 }
        if isFocused { return Color.accent.opacity(TextFieldMetrics.focusedHairlineOpacity) }
        return Color.menuBorder
    }

    var body: some View {
        content
            .font(Typography.labelMedium)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.fieldPaddingH)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                    .fill(Color.restingFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                    .strokeBorder(hairline, lineWidth: 1)
            }
            .focusEffectDisabled()
            .animation(Animations.hover, value: isFocused)
    }
}

enum TextFieldMetrics {
    /// A focused field's accent hairline: present, not loud.
    static let focusedHairlineOpacity: Double = 0.6
}

// MARK: - Large Padded Text Field Style

/// The regular boxed field: 32pt, the form field's default.
public struct LargePaddedTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        BoxedFieldChrome(
            content: configuration.focused($isFocused).textFieldStyle(.plain),
            isFocused: isFocused,
            minHeight: Sizing.controlMedium,
            verticalPadding: Spacing.sm
        )
    }
}

extension TextFieldStyle where Self == LargePaddedTextFieldStyle {
    public static var largePadded: LargePaddedTextFieldStyle {
        LargePaddedTextFieldStyle()
    }
}

// MARK: - Compact Text Field Style

/// The compact boxed field: 28pt, for a toolbar or a dense form.
public struct CompactTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        BoxedFieldChrome(
            content: configuration.focused($isFocused).textFieldStyle(.plain),
            isFocused: isFocused,
            minHeight: Sizing.controlDefault,
            verticalPadding: Spacing.fieldPaddingV
        )
    }
}

extension TextFieldStyle where Self == CompactTextFieldStyle {
    public static var compact: CompactTextFieldStyle {
        CompactTextFieldStyle()
    }
}

// MARK: - Search fields

/// A search field: the field's well and hairline at rest, an accent hairline
/// while focused (red never: a search can't be invalid). The glyph stays quiet.
private struct SearchFieldChrome<Content: View>: View {
    let content: Content
    let isFocused: Bool
    let minHeight: CGFloat
    /// The corners when the control shape is rounded.
    let roundedRadius: CGFloat

    @Environment(\.controlShape) private var controlShape

    private var cornerRadius: CGFloat { controlShape.radius(rounded: roundedRadius) }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            BlissSymbol("magnifyingglass")
                .font(Typography.labelSmall)
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
            content
                .font(Typography.labelMedium)
        }
        .padding(.horizontal, Spacing.fieldPaddingH)
        .frame(minHeight: minHeight)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                .fill(Color.restingFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                .strokeBorder(isFocused ? Color.accent.opacity(TextFieldMetrics.focusedHairlineOpacity) : Color.menuBorder, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius)))
        .focusEffectDisabled()
        .animation(Animations.hover, value: isFocused)
    }
}

// MARK: - Search Text Field Style

/// The search field: regular height, `Sizing.radiusLarge` corners.
public struct SearchTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        SearchFieldChrome(
            content: configuration.focused($isFocused).textFieldStyle(.plain),
            isFocused: isFocused,
            minHeight: Sizing.controlMedium,
            roundedRadius: Sizing.radiusLarge
        )
    }
}

extension TextFieldStyle where Self == SearchTextFieldStyle {
    public static var search: SearchTextFieldStyle {
        SearchTextFieldStyle()
    }
}

// MARK: - Toolbar Search Text Field Style

/// The toolbar's search field: the search field at the compact height, with
/// the field's corners.
public struct ToolbarSearchTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    public init() {}

    public func _body(configuration: TextField<Self._Label>) -> some View {
        SearchFieldChrome(
            content: configuration.focused($isFocused).textFieldStyle(.plain),
            isFocused: isFocused,
            minHeight: Sizing.controlDefault,
            roundedRadius: Sizing.fieldCornerRadius
        )
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
    /// The corners follow `controlShape`: a single-line field's
    /// (`Sizing.fieldCornerRadius` when rounded), or, with `isMultiline`, a
    /// box's (`Sizing.textBoxCornerRadius` when rounded, never a capsule). A
    /// `cornerRadius` replaces either. `fill: .none` drops the resting fill
    /// and hairline for a borderless field inside a card.
    public func inputBox(
        isFocused: Bool,
        cornerRadius: CGFloat? = nil,
        isMultiline: Bool = false,
        fill: InputBoxFill = .resting
    ) -> some View {
        modifier(InputBoxModifier(isFocused: isFocused, cornerRadiusOverride: cornerRadius, isMultiline: isMultiline, fill: fill))
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
    let cornerRadiusOverride: CGFloat?
    let isMultiline: Bool
    let fill: InputBoxFill

    @Environment(\.formFieldIsInvalid) private var isInvalid
    @Environment(\.controlShape) private var controlShape

    private var cornerRadius: CGFloat {
        if let cornerRadiusOverride { return cornerRadiusOverride }
        return isMultiline
            ? controlShape.boxRadius(rounded: Sizing.textBoxCornerRadius)
            : controlShape.radius(rounded: Sizing.fieldCornerRadius)
    }

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
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                    .fill(isFocused ? Color.controlBackground : restingFill)
                    .animation(Animations.hover, value: isFocused)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
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
