//
//  StatusWash.swift
//  BlissUI
//
//  The one recipe for a status-colored surface: a wash of the color's tint
//  behind a label, and the hairline around it. Badges, status pills, banners,
//  a timeline's icon disc, a token field's invalid chip and a destructive
//  menu row's hover all draw it, so a "warning" reads the same everywhere.
//
//  The wash is built on `statusTint` (the deep base), never on the lifted
//  mark: a lifted color at low opacity goes grey on a dark surface. Dark gets
//  twice the opacity of light so the wash still shows on the dark pane, and
//  Increase Contrast strengthens both.
//

import SwiftUI

public enum StatusWash {
    /// The fill behind a status label: 10% of the tint in light, 20% in dark.
    public static func fill(_ color: Color, _ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return color.statusTint.opacity(scheme == .dark ? 0.3 : 0.18) }
        return color.statusTint.opacity(scheme == .dark ? 0.2 : 0.1)
    }

    /// The hairline around a status surface: 30% of the tint in light, 40% in
    /// dark, 60% under Increase Contrast.
    public static func border(_ color: Color, _ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return color.statusTint.opacity(0.6) }
        return color.statusTint.opacity(scheme == .dark ? 0.4 : 0.3)
    }
}
