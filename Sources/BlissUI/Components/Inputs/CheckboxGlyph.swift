//
//  CheckboxGlyph.swift
//  BlissUI
//
//  The app's checkbox mark.
//

import SwiftUI

/// A rounded square, accent-filled with a check when on. Drawn rather than the
/// `square` / `checkmark.square.fill` symbols, which carry their own side
/// bearings and corner radius, so a focus ring can wrap it exactly. A button
/// built on it pads the glyph by 4 for its hit area and uses
/// `FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium, outset: -2)`:
/// the ring then sits 2pt outside the square, concentric with it.
public struct CheckboxGlyph: View {
    let isOn: Bool
    var size: CGFloat = 14

    @Environment(\.isEnabled) private var isEnabled

    public init(isOn: Bool, size: CGFloat = 14) {
        self.isOn = isOn
        self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
        ZStack {
            if isOn {
                shape.fill(Color.accent)
                Image(systemName: "checkmark")
                    .font(size < 13 ? Typography.labelMicroBold : Typography.labelMiniBold)
                    .foregroundStyle(AccentHue.contrastForeground)
            } else {
                shape.strokeBorder(Color.secondary.opacity(0.7), lineWidth: 1.25)
            }
        }
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Checkbox", traits: .fixedLayout(width: 220, height: 80)) {
    HStack(spacing: Spacing.lg) {
        CheckboxGlyph(isOn: false)
        CheckboxGlyph(isOn: true)
        CheckboxGlyph(isOn: true, size: 12)
        CheckboxGlyph(isOn: false).disabled(true)
    }
    .padding(Spacing.lg)
}
