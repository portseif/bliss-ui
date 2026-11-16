//
//  RadioGlyph.swift
//  BlissUI
//
//  The app's radio mark, the single-choice partner of `CheckboxGlyph`.
//

import SwiftUI

/// A circle, accent-filled with a dot when on — the single-choice mark beside
/// `CheckboxGlyph`'s many-choice one, the same size and stroke so a form that
/// mixes them reads as one set. Drawn rather than the `circle` /
/// `largecircle.fill.circle` symbols, whose side bearings don't match the
/// checkbox's.
public struct RadioGlyph: View {
    let isOn: Bool
    var size: CGFloat = Sizing.iconSmall
    let tint: Color?

    @Environment(\.isEnabled) private var isEnabled

    /// The dot's share of the circle.
    private static let dotRatio: CGFloat = 0.4

    /// - Parameters:
    ///   - isOn: Filled with a dot.
    ///   - size: The circle's diameter; `Sizing.iconSmall` by default, the
    ///     checkbox's side.
    ///   - tint: The fill when on; the accent by default. A status color for a
    ///     severity picker.
    public init(isOn: Bool, size: CGFloat = Sizing.iconSmall, tint: Color? = nil) {
        self.isOn = isOn
        self.size = size
        self.tint = tint
    }

    /// The accent, or the caller's color as a tint that holds white.
    private var fill: Color { tint?.statusTint ?? Color.accent }

    private var dotColor: Color { tint == nil ? AccentHue.contrastForeground : .white }

    public var body: some View {
        ZStack {
            if isOn {
                Circle().fill(fill)
                Circle()
                    .fill(dotColor)
                    .frame(width: size * Self.dotRatio, height: size * Self.dotRatio)
            } else {
                Circle().strokeBorder(Color.secondary, lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Radio", traits: .fixedLayout(width: 260, height: 80)) {
    HStack(spacing: Spacing.lg) {
        RadioGlyph(isOn: false)
        RadioGlyph(isOn: true)
        RadioGlyph(isOn: true, size: Sizing.iconDefault)
        RadioGlyph(isOn: true, tint: Warning.warning500)
        RadioGlyph(isOn: false).disabled(true)
    }
    .padding(Spacing.lg)
}
