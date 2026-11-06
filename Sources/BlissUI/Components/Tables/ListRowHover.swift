//
//  ListRowHover.swift
//  BlissUI
//
//  The shared hover fill for plain (card-less) list rows — any bare row
//  separated by dividers rather than a card.
//

import SwiftUI

extension View {
    /// Self-contained variant: tracks its own hover state. Use it when the row
    /// doesn't already need `isHovering` for something else (a reveal-on-hover
    /// button), or when the row is built inline and can't hold `@State`.
    /// `isEnabled: false` keeps the layout but never fills (a row that's only
    /// tappable sometimes).
    public func rowHover(
        verticalPadding: CGFloat = Spacing.listRowPadding,
        horizontalBleed: CGFloat = Spacing.sm,
        isEnabled: Bool = true
    ) -> some View {
        modifier(RowHoverModifier(verticalPadding: verticalPadding, horizontalBleed: horizontalBleed, isEnabled: isEnabled))
    }

    /// Fills a list row with the neutral `RowTint` hover wash.
    ///
    /// The fill bleeds `horizontalBleed` past the row's content on both sides and
    /// the matching negative padding pulls the layout back, so rows still line up
    /// with their section headers and dividers. Applies the row's vertical padding
    /// too, so the fill covers the whole row rather than just its text.
    public func listRowHover(
        isHovering: Bool,
        scheme: ColorScheme,
        verticalPadding: CGFloat = Spacing.listRowPadding,
        horizontalBleed: CGFloat = Spacing.sm
    ) -> some View {
        padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalBleed)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(isHovering ? RowTint.hover(scheme) : Color.clear)
            }
            .padding(.horizontal, -horizontalBleed)
    }
}

private struct RowHoverModifier: ViewModifier {
    let verticalPadding: CGFloat
    let horizontalBleed: CGFloat
    var isEnabled = true

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .listRowHover(
                isHovering: isHovering && isEnabled,
                scheme: scheme,
                verticalPadding: verticalPadding,
                horizontalBleed: horizontalBleed
            )
            .onHover { hovering in
                withAnimation(Animations.hover) { isHovering = hovering }
            }
    }
}

// MARK: - Tappable rows

extension View {
    /// `.onTapGesture` for a row that opens or selects something, plus what a
    /// gesture doesn't give: VoiceOver and Voice Control see one button (the
    /// row's text combined) with the same press, and the keyboard gets a Tab
    /// stop (`keyboardTapTarget`). `isSelected` marks a picked card. The focus
    /// ring traces the row's hover fill: the defaults match `rowHover` /
    /// `listRowHover`; a card with its own shape passes its radius and no bleed.
    public func rowTapAction(
        isSelected: Bool = false,
        focusCornerRadius: CGFloat = Sizing.radiusMedium,
        focusBleed: CGFloat = Spacing.sm,
        perform action: @escaping () -> Void
    ) -> some View {
        onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            .accessibilityAction(.default, action)
            .keyboardTapTarget(cornerRadius: focusCornerRadius, bleed: focusBleed, perform: action)
    }

    /// The keyboard half of a tap target: a Tab stop that Space activates, with
    /// the focus ring every button shows. Use it on its own for a tap target
    /// that keeps its own accessibility (a row holding other buttons). `bleed`
    /// widens the ring past the view on both sides, the way `rowHover` /
    /// `listRowHover` bleed their fill by `Spacing.sm`.
    public func keyboardTapTarget(
        cornerRadius: CGFloat = Sizing.radiusMedium,
        bleed: CGFloat = Spacing.sm,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardTapTargetModifier(cornerRadius: cornerRadius, bleed: bleed, action: action))
    }
}

private struct KeyboardTapTargetModifier: ViewModifier {
    let cornerRadius: CGFloat
    let bleed: CGFloat
    let action: () -> Void

    @State private var isFocused = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, bleed)
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius)
            .padding(.horizontal, -bleed)
            .background { KeyboardTapFocusLayer(isFocused: $isFocused, action: action) }
    }
}

/// The row's own Tab stop, in a layer BEHIND its content rather than around
/// it. A focusable container counts as focused while anything inside it is
/// (its ring lit up beside a focused button's), and its Space handler took the
/// key from that button — the row opened instead of the link or badge in it.
/// A layer behind isn't an ancestor of the row's buttons, so each keeps its
/// own keys (both checked in a throwaway app).
private struct KeyboardTapFocusLayer: View {
    @Binding var isFocused: Bool
    let action: () -> Void

    @FocusState private var hasFocus: Bool

    var body: some View {
        Color.clear
            .focusable()
            .focused($hasFocus)
            .focusEffectDisabled()
            .onChange(of: hasFocus) { _, focused in isFocused = focused }
            // Key-down only: a held key would repeat the action.
            .onKeyPress(.space, phases: .down) { _ in
                action()
                return .handled
            }
            .allowsHitTesting(false)
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 140)) {
    VStack(alignment: .leading, spacing: 0) {
        Text("Hovered row")
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowHover(isHovering: true, scheme: .dark)
        Divider()
        Text("Idle row")
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowHover(isHovering: false, scheme: .dark)
    }
    .padding(Spacing.xl)
}
