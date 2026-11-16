//
//  CheckboxGlyph.swift
//  BlissUI
//
//  The app's checkbox mark.
//

import SwiftUI

/// A rounded square, accent-filled with a check when on (or a dash when mixed).
/// Drawn rather than the `square` / `checkmark.square.fill` symbols, which
/// carry their own side bearings and corner radius, so a focus ring can wrap it
/// exactly. A button built on it pads the glyph by `Spacing.xxs` for its hit
/// area and uses `FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium,
/// outset: -Spacing.hairline)`: the ring then sits 2pt outside the square,
/// concentric with it.
public struct CheckboxGlyph: View {
    let isOn: Bool
    let isMixed: Bool
    var size: CGFloat = Sizing.iconSmall
    let color: Color?

    @Environment(\.isEnabled) private var isEnabled

    /// Below this size the check drops to the smallest bold face.
    private static let compactThreshold: CGFloat = 13

    /// - Parameters:
    ///   - isOn: Filled with a check.
    ///   - isMixed: Filled with a dash — a select-all box over a partial
    ///     selection. Wins over `isOn`.
    ///   - size: The square's side; `Sizing.iconSmall` by default.
    ///   - color: The fill when on or mixed; the accent by default. A status
    ///     color for a "I understand" box or a colored facet.
    public init(isOn: Bool, isMixed: Bool = false, size: CGFloat = Sizing.iconSmall, color: Color? = nil) {
        self.isOn = isOn
        self.isMixed = isMixed
        self.size = size
        self.color = color
    }

    /// The accent, or the caller's color as a tint that holds white.
    private var fill: Color { color?.statusTint ?? Color.accent }

    private var glyphColor: Color { color == nil ? AccentHue.contrastForeground : .white }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
        ZStack {
            if isOn || isMixed {
                shape.fill(fill)
                Image(systemName: isMixed ? "minus" : "checkmark")
                    .font(size < Self.compactThreshold ? Typography.labelMicroBold : Typography.labelMiniBold)
                    .foregroundStyle(glyphColor)
            } else {
                shape.strokeBorder(Color.secondary, lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Checkbox", traits: .fixedLayout(width: 300, height: 80)) {
    HStack(spacing: Spacing.lg) {
        CheckboxGlyph(isOn: false)
        CheckboxGlyph(isOn: true)
        CheckboxGlyph(isOn: false, isMixed: true)
        CheckboxGlyph(isOn: true, size: Sizing.iconTiny)
        CheckboxGlyph(isOn: true, color: Danger.danger500)
        CheckboxGlyph(isOn: false).disabled(true)
    }
    .padding(Spacing.lg)
}
