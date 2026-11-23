//
//  Elevation.swift
//  BlissUI
//
//  The three shadows the library draws. Buttons and inputs draw none (their
//  depth is a hairline); everything that floats picks one of these tiers, so
//  a menu, a toast and a sheet agree on how far off the page they sit.
//

import SwiftUI

/// How far a surface floats above the page.
public enum Elevation {
    /// A card lifted while dragged, a chart callout: barely off the page.
    case lift
    /// A detached panel: a menu, a popup, a tooltip, a toast, a selection bar,
    /// a slide-out panel. A soft shadow plus a tight contact shadow.
    case panel
    /// A modal card: an `AppSheet`, the command palette.
    case sheet
}

extension View {
    /// Draws the tier's shadow(s). Never combine with `hasShadow` on a panel.
    public func elevation(_ level: Elevation) -> some View {
        modifier(ElevationModifier(level: level, strength: 1))
    }

    /// The tier's shadow, faded out while `isVisible` is false — for a surface
    /// that lifts and settles (a dragged row) without an `if` that would swap
    /// its identity, and with it any gesture in flight.
    func elevation(_ level: Elevation, isVisible: Bool) -> some View {
        modifier(ElevationModifier(level: level, strength: isVisible ? 1 : 0))
    }
}

private struct ElevationModifier: ViewModifier {
    let level: Elevation
    /// Scales every shadow's opacity: 1 drawn, 0 hidden.
    let strength: Double
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        switch level {
        case .lift:
            content.shadow(color: .black.opacity(0.12 * strength), radius: 8, y: 2)
        case .panel:
            content
                .shadow(color: .black.opacity((colorScheme == .dark ? 0.4 : 0.14) * strength), radius: 16, y: 6)
                .shadow(color: .black.opacity((colorScheme == .dark ? 0.25 : 0.08) * strength), radius: 3, y: 1)
        case .sheet:
            content.shadow(color: .black.opacity(0.28 * strength), radius: 28, y: 14)
        }
    }
}
