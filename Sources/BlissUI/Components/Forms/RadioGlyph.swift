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
    var size: CGFloat = 14

    @Environment(\.isEnabled) private var isEnabled

    public init(isOn: Bool, size: CGFloat = 14) {
        self.isOn = isOn
        self.size = size
    }

    public var body: some View {
        ZStack {
            if isOn {
                Circle().fill(Color.accent)
                Circle()
                    .fill(AccentHue.contrastForeground)
                    .frame(width: size * 0.4, height: size * 0.4)
            } else {
                Circle().strokeBorder(Color.secondary.opacity(0.7), lineWidth: 1.25)
            }
        }
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Radio", traits: .fixedLayout(width: 220, height: 80)) {
    HStack(spacing: Spacing.lg) {
        RadioGlyph(isOn: false)
        RadioGlyph(isOn: true)
        RadioGlyph(isOn: true, size: 18)
        RadioGlyph(isOn: false).disabled(true)
    }
    .padding(Spacing.lg)
}
