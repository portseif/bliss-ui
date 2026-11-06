//
//  Color+System.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/5/25.
//
//  Linear-inspired design system:
//  - Cool grey palette with very low saturation
//  - Ultra-subtle shadows and borders
//  - Monochromatic with occasional accent pops
//  - Clean, muted aesthetic

import SwiftUI
import AppKit

// MARK: - Grey Palette (Linear-style cool greys)

/// Linear-inspired grey palette - very low saturation, cool undertones
/// Designed for ultra-clean, minimal interfaces
public enum Grey {
    public static let grey50 = Color(hue: 220/360, saturation: 0.02, brightness: 0.99)   // Almost white
    public static let grey100 = Color(hue: 220/360, saturation: 0.03, brightness: 0.97)  // Subtle hover bg
    public static let grey200 = Color(hue: 220/360, saturation: 0.04, brightness: 0.93)  // Borders, dividers
    public static let grey300 = Color(hue: 220/360, saturation: 0.04, brightness: 0.87)  // Muted borders
    public static let grey400 = Color(hue: 220/360, saturation: 0.03, brightness: 0.72)  // Placeholder, icons
    public static let grey500 = Color(hue: 220/360, saturation: 0.03, brightness: 0.56)  // Tertiary text
    public static let grey600 = Color(hue: 220/360, saturation: 0.04, brightness: 0.44)  // Secondary text
    public static let grey700 = Color(hue: 220/360, saturation: 0.05, brightness: 0.32)  // Primary text
    public static let grey800 = Color(hue: 220/360, saturation: 0.06, brightness: 0.20)  // Headings
    public static let grey900 = Color(hue: 220/360, saturation: 0.08, brightness: 0.11)  // Near black
}

// MARK: - Accent Color Hue (Dynamic, User-Configurable)

/// Helper to get the current accent hue from user preferences
/// Falls back to system blue (hue 217) when no custom accent is set
public enum AccentHue {
    // Default blue hue (used when no custom accent color is set)
    private static let defaultHue: Double = 217/360
    private static let defaultSaturation: Double = 1.0

    /// Cached HSB components from the user's custom accent color
    private static var cachedHSB: (hue: Double, saturation: Double, brightness: Double) {
        // An active color theme owns the accent — derive HSB from its accent.
        if let themeAccent = ThemeColors.activeAccentNSColor?.usingColorSpace(.sRGB) {
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            themeAccent.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return (Double(hue), Double(saturation), Double(brightness))
        }

        let accentOverride = UserDefaults.standard.string(forKey: "accentColorOverride") ?? "System"

        guard accentOverride == "Custom" else {
            return (defaultHue, defaultSaturation, 1.0)
        }

        let red = UserDefaults.standard.double(forKey: "customAccentColorRed")
        let green = UserDefaults.standard.double(forKey: "customAccentColorGreen")
        let blue = UserDefaults.standard.double(forKey: "customAccentColorBlue")

        let nsColor = NSColor(red: red, green: green, blue: blue, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if let hsbColor = nsColor.usingColorSpace(.sRGB) {
            hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return (Double(hue), Double(saturation), Double(brightness))
        }

        return (defaultHue, defaultSaturation, 1.0)
    }

    /// The hue of the user's accent color (0.0 to 1.0)
    public static var current: Double { cachedHSB.hue }

    /// The saturation of the user's accent color (0.0 to 1.0).
    /// Used to scale Primary palette so desaturated picks (white, grey) stay desaturated.
    public static var currentSaturation: Double { cachedHSB.saturation }

    /// The user's custom accent color as an actual Color (direct RGB, no hue re-synthesis).
    /// Used when saturation is too low for hue-based generation to produce meaningful results.
    public static var resolvedColor: Color {
        // An active color theme owns the accent (or the one picked for it).
        if let themeAccent = ThemeColors.activeAccent {
            return themeAccent.color
        }

        let accentOverride = UserDefaults.standard.string(forKey: "accentColorOverride") ?? "System"

        guard accentOverride == "Custom" else {
            // System default — use standard blue
            return Color(hue: defaultHue, saturation: 0.70, brightness: 0.54)
        }

        let red = UserDefaults.standard.double(forKey: "customAccentColorRed")
        let green = UserDefaults.standard.double(forKey: "customAccentColorGreen")
        let blue = UserDefaults.standard.double(forKey: "customAccentColorBlue")
        return Color(red: red, green: green, blue: blue)
    }

    /// The effective accent as an NSColor — the macOS system accent, or the
    /// user's custom pick. Single source of truth for "the color the toggles use".
    public static var effectiveAccentNSColor: NSColor {
        // An active color theme owns the accent.
        if let themeAccent = ThemeColors.activeAccentNSColor { return themeAccent }
        let accentOverride = UserDefaults.standard.string(forKey: "accentColorOverride") ?? "System"
        guard accentOverride == "Custom" else { return .controlAccentColor }
        let red = UserDefaults.standard.double(forKey: "customAccentColorRed")
        let green = UserDefaults.standard.double(forKey: "customAccentColorGreen")
        let blue = UserDefaults.standard.double(forKey: "customAccentColorBlue")
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    /// Whether the accent is light enough to need dark text on top. Computed from
    /// the real effective accent (system or custom) via ITU-R BT.709 luminance, so
    /// contrast text stays correct for any system accent (yellow, green, etc.).
    public static var accentIsLight: Bool {
        // A theme that publishes its on-accent color decides: dark text = light accent.
        if let foreground = ThemeColors.activeAccentForeground {
            return StatusToneMath.luminance(foreground) < 0.5
        }
        guard let c = effectiveAccentNSColor.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.6
    }

    /// The ideal text color to use on top of the accent color for readable contrast.
    public static var contrastForeground: Color {
        if let foreground = ThemeColors.activeAccentForeground { return foreground.color }
        return accentIsLight ? Color(red: 0.1, green: 0.1, blue: 0.1) : .white
    }
}

// MARK: - Primary Color Palette (Dynamic Accent)

/// Dynamic primary color palette based on user's accent color preference
/// Falls back to system blue (hue 217) when no custom accent is set
/// Note: For most cases, prefer using `Color.accent` for semantic clarity
public enum Primary {
    // Scale palette saturation by the user's accent saturation.
    // Vivid accent → vivid palette. White/grey accent → desaturated palette.
    private static func sat(_ baseSaturation: Double) -> Double {
        baseSaturation * AccentHue.currentSaturation
    }

    // Dynamic computed colors based on current accent
    public static var primary50: Color { Color(hue: AccentHue.current, saturation: sat(0.92), brightness: 0.97) }
    public static var primary100: Color { Color(hue: AccentHue.current, saturation: sat(0.88), brightness: 0.94) }
    public static var primary200: Color { Color(hue: AccentHue.current, saturation: sat(0.80), brightness: 0.88) }
    public static var primary300: Color { Color(hue: AccentHue.current, saturation: sat(0.72), brightness: 0.78) }
    public static var primary400: Color { Color(hue: AccentHue.current, saturation: sat(0.68), brightness: 0.65) }
    public static var primary500: Color { Color(hue: AccentHue.current, saturation: sat(0.70), brightness: 0.54) }
    public static var primary600: Color { Color(hue: AccentHue.current, saturation: sat(0.75), brightness: 0.45) }
    public static var primary700: Color { Color(hue: AccentHue.current, saturation: sat(0.80), brightness: 0.36) }
    public static var primary800: Color { Color(hue: AccentHue.current, saturation: sat(0.85), brightness: 0.28) }
    public static var primary900: Color { Color(hue: AccentHue.current, saturation: sat(0.90), brightness: 0.20) }
}

// MARK: - Success Color Palette (Green)

public enum Success {
    public static let success50 = Color(hue: 142/360, saturation: 0.72, brightness: 0.97)
    public static let success100 = Color(hue: 142/360, saturation: 0.68, brightness: 0.92)
    public static let success200 = Color(hue: 142/360, saturation: 0.60, brightness: 0.84)
    public static let success300 = Color(hue: 142/360, saturation: 0.55, brightness: 0.72)
    public static let success400 = Color(hue: 142/360, saturation: 0.55, brightness: 0.58)
    // Base green, for marks — text, icons, dots, bars. On dark it's the lifted
    // tone the status chips' labels use (`legibleOnDark` of the deep base below),
    // so a check, a success message or a progress bar is the same green as the
    // "Healthy" pill beside it; the deep base read muddy next to the chips.
    // Unchanged in light. A color theme can set its own (`StatusTones`).
    public static var success500: Color { StatusTones.mark(.success) ?? standardMark }
    private static let standardMark = Color.statusTone(
        dark: NSColor(hue: 142/360, saturation: 0.58 * 0.72, brightness: 0.88, alpha: 1),
        light: NSColor(hue: 142/360, saturation: 0.60, brightness: 0.45, alpha: 1)
    )
    /// The green under fills, borders and washes (`Success.tint.opacity(…)`). A
    /// lifted green at low opacity goes grey on a dark surface, so tints keep the
    /// deep, saturated base the chips were designed on. Same as `success500` in
    /// light.
    public static var tint: Color { StatusTones.tint(.success) ?? standardTint }
    private static let standardTint = Color.statusTone(
        dark: NSColor(hue: 142/360, saturation: 0.58, brightness: 0.56, alpha: 1),
        light: NSColor(hue: 142/360, saturation: 0.60, brightness: 0.45, alpha: 1)
    )
    public static let success600 = Color(hue: 142/360, saturation: 0.65, brightness: 0.38)
    public static let success700 = Color(hue: 142/360, saturation: 0.70, brightness: 0.30)
    public static let success800 = Color(hue: 142/360, saturation: 0.75, brightness: 0.24)
    public static let success900 = Color(hue: 142/360, saturation: 0.80, brightness: 0.18)
}

// MARK: - Warning Color Palette (Amber/Yellow)

public enum Warning {
    public static let warning50 = Color(hue: 45/360, saturation: 0.92, brightness: 0.98)
    public static let warning100 = Color(hue: 45/360, saturation: 0.88, brightness: 0.95)
    public static let warning200 = Color(hue: 43/360, saturation: 0.82, brightness: 0.90)
    public static let warning300 = Color(hue: 40/360, saturation: 0.78, brightness: 0.82)
    public static let warning400 = Color(hue: 38/360, saturation: 0.85, brightness: 0.70)
    // Base amber, for marks. On dark it's the chips' lifted label tone (see
    // `Success.success500` for why); `tint` keeps the deep base for fills.
    public static var warning500: Color { StatusTones.mark(.warning) ?? standardMark }
    private static let standardMark = Color.statusTone(
        dark: NSColor(hue: 35/360, saturation: 0.90 * 0.72, brightness: 0.88, alpha: 1),
        light: NSColor(hue: 35/360, saturation: 0.90, brightness: 0.58, alpha: 1)
    )
    public static var tint: Color { StatusTones.tint(.warning) ?? standardTint }
    private static let standardTint = Color(hue: 35/360, saturation: 0.90, brightness: 0.58)
    public static let warning600 = Color(hue: 32/360, saturation: 0.92, brightness: 0.48)
    public static let warning700 = Color(hue: 28/360, saturation: 0.94, brightness: 0.40)
    public static let warning800 = Color(hue: 24/360, saturation: 0.95, brightness: 0.32)
    public static let warning900 = Color(hue: 20/360, saturation: 0.96, brightness: 0.25)
}

// MARK: - Danger/Error Color Palette (Red)

public enum Danger {
    public static let danger50 = Color(hue: 0/360, saturation: 0.85, brightness: 0.98)
    public static let danger100 = Color(hue: 0/360, saturation: 0.80, brightness: 0.95)
    public static let danger200 = Color(hue: 0/360, saturation: 0.72, brightness: 0.90)
    public static let danger300 = Color(hue: 0/360, saturation: 0.68, brightness: 0.82)
    public static let danger400 = Color(hue: 0/360, saturation: 0.70, brightness: 0.70)
    // Base red, for marks. On dark it's the chips' lifted label tone (see
    // `Success.success500`); `tint` keeps the deep base — a touch warmer and
    // brighter than light's, so it reads as a clean red beside the amber — for
    // fills, including the destructive button's solid fill behind white text.
    public static var danger500: Color { StatusTones.mark(.danger) ?? standardMark }
    private static let standardMark = Color.statusTone(
        dark: NSColor(hue: 3/360, saturation: 0.72 * 0.72, brightness: 0.88, alpha: 1),
        light: NSColor(hue: 0/360, saturation: 0.75, brightness: 0.58, alpha: 1)
    )
    public static var tint: Color { StatusTones.tint(.danger) ?? standardTint }
    private static let standardTint = Color.statusTone(
        dark: NSColor(hue: 3/360, saturation: 0.72, brightness: 0.68, alpha: 1),
        light: NSColor(hue: 0/360, saturation: 0.75, brightness: 0.58, alpha: 1)
    )
    public static let danger600 = Color(hue: 358/360, saturation: 0.78, brightness: 0.48)
    public static let danger700 = Color(hue: 356/360, saturation: 0.80, brightness: 0.40)
    public static let danger800 = Color(hue: 354/360, saturation: 0.82, brightness: 0.32)
    public static let danger900 = Color(hue: 352/360, saturation: 0.85, brightness: 0.25)
}

// MARK: - Info Color Palette (Cyan/Teal)

public enum Info {
    public static let info50 = Color(hue: 190/360, saturation: 0.85, brightness: 0.97)
    public static let info100 = Color(hue: 190/360, saturation: 0.78, brightness: 0.94)
    public static let info200 = Color(hue: 190/360, saturation: 0.70, brightness: 0.88)
    public static let info300 = Color(hue: 190/360, saturation: 0.65, brightness: 0.78)
    public static let info400 = Color(hue: 190/360, saturation: 0.62, brightness: 0.65)
    // Base cyan, for marks. On dark it's the chips' lifted label tone (see
    // `Success.success500`); `tint` keeps the deep base for fills.
    public static var info500: Color { StatusTones.mark(.info) ?? standardMark }
    private static let standardMark = Color.statusTone(
        dark: NSColor(hue: 190/360, saturation: 0.65 * 0.72, brightness: 0.88, alpha: 1),
        light: NSColor(hue: 190/360, saturation: 0.65, brightness: 0.52, alpha: 1)
    )
    public static var tint: Color { StatusTones.tint(.info) ?? standardTint }
    private static let standardTint = Color(hue: 190/360, saturation: 0.65, brightness: 0.52)
    public static let info600 = Color(hue: 190/360, saturation: 0.70, brightness: 0.44)
    public static let info700 = Color(hue: 190/360, saturation: 0.75, brightness: 0.36)
    public static let info800 = Color(hue: 190/360, saturation: 0.78, brightness: 0.28)
    public static let info900 = Color(hue: 190/360, saturation: 0.82, brightness: 0.22)
}

// MARK: - Row Highlight Tints

/// Shared neutral highlight fills for list/menu rows, so the sidebar selection and the
/// floating-menu hover use the exact same gray — and tune in one place. Resolved against
/// the caller's color scheme (callers pass their own `@Environment(\.colorScheme)`).
public enum RowTint {
    /// Subtle hover / menu-highlight fill.
    public static func hover(_ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return Color.primary.opacity(scheme == .dark ? 0.10 : 0.12) }
        return scheme == .dark ? Color.primary.opacity(0.04) : Color.primary.opacity(0.05)
    }

    /// Stronger fill for an active/selected sidebar row.
    public static func selected(_ scheme: ColorScheme) -> Color {
        if prefersIncreasedContrast { return Color.primary.opacity(scheme == .dark ? 0.18 : 0.20) }
        // Twice the hover, as in light — the same 0.04 made a selected row look hovered.
        return scheme == .dark ? Color.primary.opacity(0.08) : Color.primary.opacity(0.10)
    }
}

/// System Settings → Accessibility → Display → Increase contrast. The faint
/// fills and hairlines that carry state (row hover and selection, menu and card
/// borders) strengthen under it. Read on every render like
/// `prefersReducedMotion`; `ThemeModifier` re-IDs the tree when it changes.
public var prefersIncreasedContrast: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
}

// MARK: - Purple Color Palette (Violet)

public enum Purple {
    public static let purple50 = Color(hue: 270/360, saturation: 0.75, brightness: 0.98)
    public static let purple100 = Color(hue: 270/360, saturation: 0.68, brightness: 0.94)
    public static let purple200 = Color(hue: 270/360, saturation: 0.60, brightness: 0.88)
    public static let purple300 = Color(hue: 270/360, saturation: 0.55, brightness: 0.78)
    public static let purple400 = Color(hue: 270/360, saturation: 0.55, brightness: 0.65)
    public static let purple500 = Color(hue: 270/360, saturation: 0.60, brightness: 0.55)  // Base
    public static let purple600 = Color(hue: 270/360, saturation: 0.65, brightness: 0.46)
    public static let purple700 = Color(hue: 270/360, saturation: 0.70, brightness: 0.38)
    public static let purple800 = Color(hue: 270/360, saturation: 0.75, brightness: 0.30)
    public static let purple900 = Color(hue: 270/360, saturation: 0.80, brightness: 0.22)
}

// MARK: - Semantic Color Aliases

extension Color {
    // MARK: - Accent Color (Dynamic)

    /// Whether the system is currently in light mode
    /// Uses NSApp's effective appearance to determine current mode
    private static var isLightMode: Bool {
        let appearance = NSApp.effectiveAppearance
        return !appearance.bestMatch(from: [.darkAqua, .aqua])!.rawValue.contains("Dark")
    }

    /// The app's accent color - respects user's custom accent color preference
    /// Use this for interactive elements, selections, links, and highlights
    /// When user picks white/grey (desaturated) in light mode, returns an off-grey for visibility
    /// The app's accent. Resolves to the system-matching accent (the same color
    /// the toggle switches use) so accent fills, text, and tints across the app
    /// match macOS rather than the old deliberately-muted blue. See `selectionAccent`.
    public static var accent: Color { selectionAccent }

    /// Accent for *filled* accent surfaces that should match the system controls
    /// (toggles, etc.) — selected sidebar rows, hovered menu items, and primary
    /// buttons — rather than the app's deliberately-muted `accent`. For the System
    /// accent this is the live `controlAccentColor` (exactly what a switch's
    /// on-state uses); for a custom accent it's the user's chosen color. Falls back
    /// to a visible grey for a near-white custom pick so the fill never vanishes.
    public static var selectionAccent: Color {
        // An active color theme owns the accent. One picked for it gets the same
        // near-white fallback as a custom accent; the themes' own are all tested.
        if let themeAccent = ThemeColors.activeAccent {
            if ThemeAccentOverrides.color(for: BlissTheme.active) != nil, AccentHue.currentSaturation < 0.08, isLightMode {
                return Grey.grey400
            }
            return themeAccent.color
        }
        let accentOverride = UserDefaults.standard.string(forKey: "accentColorOverride") ?? "System"
        if accentOverride == "Custom" {
            if AccentHue.currentSaturation < 0.08 {
                return isLightMode ? Grey.grey400 : AccentHue.resolvedColor
            }
            return AccentHue.resolvedColor
        }
        return Color(nsColor: .controlAccentColor)
    }

    /// Lighter accent variant — hover states, subtle highlights. Derived from the
    /// effective (system or custom) accent so it keeps the real hue.
    public static var accentLight: Color { accentAdjusted(brightnessFactor: 1.15, saturationFactor: 0.9) }

    /// Darker accent variant — pressed states.
    public static var accentDark: Color { accentAdjusted(brightnessFactor: 0.82, saturationFactor: 1.0) }

    /// Very light accent — selected backgrounds, subtle tints.
    public static var accentTint: Color { accent.opacity(isLightMode ? 0.12 : 0.16) }

    /// Lift a semantic status color into legible range on a dark surface.
    ///
    /// A status chip paints its label in the status color itself, and the base
    /// `*500` tones are tuned against white — on a dark pane amber lands at
    /// 2.8:1 and red at 2.5:1, well under the 4.5:1 AA floor for small text.
    /// Raising brightness and easing saturation keeps the hue unmistakably
    /// semantic while clearing AA (amber 6.6:1, green 8.6:1, red 4.9:1). Light
    /// mode is returned untouched — the base tones already read there.
    public func legibleOnDark(_ scheme: ColorScheme) -> Color {
        guard scheme == .dark, let (h, s, b, a) = hsbOnDark else { return self }
        // The status palettes' dark tones already ARE this lift — lifting one
        // again would wash the chips' own labels out. A theme's marks are
        // already legible on its surfaces.
        if Self.liftedStatusTint(h: h, s: s, b: b) != nil || themedStatusTint != nil { return self }
        return Color(hue: h, saturation: s * 0.72, brightness: max(b, 0.88), opacity: a)
    }

    /// The tone to fill or border with when tinting this color: a status color's
    /// deep `tint` (its dark tone is the lifted mark, and a lifted color at low
    /// opacity goes grey on a dark surface); any other color is itself. The
    /// tints equal the marks in light, so this holds in either scheme.
    public var statusTint: Color {
        guard let (h, s, b, _) = hsbOnDark else { return self }
        return themedStatusTint ?? Self.liftedStatusTint(h: h, s: s, b: b) ?? self
    }

    /// The active theme's tint behind this color, when it's one of the theme's
    /// status marks.
    private var themedStatusTint: Color? {
        // Default and the brand themes set none: skip resolving the color.
        guard StatusTones.isAnyThemed else { return nil }
        var resolved: NSColor?
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            resolved = NSColor(self).usingColorSpace(.sRGB)
        }
        guard let color = resolved else { return nil }
        return StatusTones.tint(matchingDarkMark: color.redComponent, color.greenComponent, color.blueComponent)
    }

    /// A light/dark pair, resolved against the drawing appearance.
    public static func statusTone(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }))
    }

    /// Hue, saturation, brightness and alpha as a dark surface draws this color.
    /// The status `*500`s are dynamic NSColors, so they only resolve to real
    /// components inside a drawing appearance.
    private var hsbOnDark: (CGFloat, CGFloat, CGFloat, CGFloat)? {
        var resolved: NSColor?
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            resolved = NSColor(self).usingColorSpace(.sRGB)
        }
        guard let c = resolved else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

    /// The deep tint behind a status palette's lifted dark mark, if these
    /// components are one (hue + saturation of the `*500` dark tones, all at the
    /// lift's 0.88 brightness).
    private static func liftedStatusTint(h: CGFloat, s: CGFloat, b: CGFloat) -> Color? {
        guard abs(b - 0.88) < 0.02 else { return nil }
        let marks: [(hue: CGFloat, saturation: CGFloat, tint: Color)] = [
            (142.0 / 360.0, 0.58 * 0.72, Success.tint),
            (35.0 / 360.0, 0.90 * 0.72, Warning.tint),
            (190.0 / 360.0, 0.65 * 0.72, Info.tint),
            (3.0 / 360.0, 0.72 * 0.72, Danger.tint),
        ]
        return marks.first { abs(h - $0.hue) < 0.01 && abs(s - $0.saturation) < 0.02 }?.tint
    }

    /// Adjust the effective accent's brightness/saturation while keeping its hue.
    private static func accentAdjusted(brightnessFactor: CGFloat, saturationFactor: CGFloat) -> Color {
        guard let c = AccentHue.effectiveAccentNSColor.usingColorSpace(.sRGB) else { return accent }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(s * saturationFactor, 1), brightness: min(b * brightnessFactor, 1))
    }

    // MARK: - Backgrounds (System + Custom)

    /// The standard background color for windows. Follows the active color
    /// theme's window surface when one is selected.
    public static var windowBackground: Color {
        if let palette = ThemeColors.activePalette { return palette.windowBackground.color }
        return Color(nsColor: .windowBackgroundColor)
    }

    /// Solid app-shell background for light mode — the window chrome + sidebar.
    /// White content panes (`contentAreaBackground`) sit above it, so the shell
    /// reads as the recessed surface (the standard macOS sidebar/content
    /// relationship). Dark mode keeps the window's vibrant material instead of a
    /// flat color (see `WindowShellBackground`).
    public static let appShellLight = Color(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF4 / 255)

    /// Solid app-shell background for dark mode — the opaque counterpart to
    /// `appShellLight`. With the floating panels inset on the shell, an opaque
    /// chrome keeps the exposed margins from revealing the desktop when the
    /// window is inactive (the old `.thinMaterial` chrome bled through).
    public static let appShellDark = Color(red: 0x26 / 255, green: 0x26 / 255, blue: 0x29 / 255)

    /// The resolved app-shell surface for the *current* scheme + theme — the
    /// same color `WindowShellBackground` paints via `containerBackground`,
    /// exposed as a plain color. `containerBackground(for: .window)` leaves the
    /// transparent title-bar band unpainted, so views paint this full-bleed
    /// (ignoring safe areas) to keep the desktop from showing through that band
    /// behind the traffic lights.
    public static var appShell: Color {
        if let palette = ThemeColors.activePalette { return palette.windowBackground.color }
        return ThemeColors.resolvedScheme == .dark ? appShellDark : appShellLight
    }

    // MARK: - Menu / Popover Surfaces

    /// Subtle definition edge shared by every floating surface — kebab menus,
    /// dropdowns, fly-out submenus, tooltips, and right-click popups. They all
    /// fill with a vibrant `.regularMaterial` (native menu/popover feel) and
    /// share this border so they read identically no matter which presentation
    /// path they came through. `primary` adapts (white in dark, black in light)
    /// so one token works for both modes.
    public static var menuBorder: Color {
        let increased = prefersIncreasedContrast
        if let palette = ThemeColors.activePalette { return palette.border.color.opacity(increased ? 1 : 0.5) }
        return Color.primary.opacity(increased ? 0.25 : 0.08)
    }

    /// Background for the main content pane on Tahoe+. The pane sits on the
    /// window's translucent material and gets a slight black wash so it reads as
    /// gently recessed from the bare-material sidebar.
    ///
    /// Light and dark need very different amounts: 0.25 over the dark material
    /// is a tasteful inset, but the same heavy wash over the light material
    /// turns the whole pane a muddy grey next to the bright sidebar. Light mode
    /// uses a much lighter touch so the content stays clean.
    public static var contentAreaBackground: Color {
        if let palette = ThemeColors.activePalette { return palette.contentBackground.color }
        return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                // Dark: recess the pane a touch below the chrome material.
                return isTahoeOrLater ? NSColor.black.withAlphaComponent(0.25) : .windowBackgroundColor
            }
            // Light: white content panes (projects, stacks, plugins, detail)
            // sit above the #F4F4F4 app shell — the standard macOS
            // sidebar(grey)/content(white) relationship.
            return .white
        }))
    }

    /// The background color for controls like buttons and text fields. Follows
    /// the active color theme's raised surface when one is selected.
    public static var controlBackground: Color {
        if let palette = ThemeColors.activePalette { return palette.elevatedBackground.color }
        return Color(nsColor: .controlBackgroundColor)
    }

    // MARK: - Content Colors

    /// The color for links
    public static let link = Color(nsColor: .linkColor)

    // MARK: - Separators & Borders

    /// The standard separator color for dividers and borders
    public static let separator = Color(nsColor: .separatorColor)

    /// Subtle border for cards and containers
    public static let borderSubtle = Grey.grey200

    // MARK: - Labels

    /// Primary label color for text
    public static let labelColor = Color(nsColor: .labelColor)

    /// Secondary label color for less prominent text
    public static let secondaryLabel = Color(nsColor: .secondaryLabelColor)

    /// Tertiary label color for even less prominent text
    public static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)

    /// Quaternary label color for very subtle text
    public static let quaternaryLabel = Color(nsColor: .quaternaryLabelColor)

    // MARK: - Text Colors

    /// The color for text
    public static let text = Color(nsColor: .textColor)

    /// The color for placeholder text in controls
    public static let placeholderText = Color(nsColor: .placeholderTextColor)

    /// The color for selected text
    public static let selectedText = Color(nsColor: .selectedTextColor)

    /// The color for text in a non-key window
    public static let unemphasizedSelectedText = Color(nsColor: .unemphasizedSelectedTextColor)

    /// Primary text on light backgrounds
    public static let textPrimary = Grey.grey800

    /// Secondary/muted text
    public static let textSecondary = Grey.grey600

    /// Tertiary/disabled text
    public static let textTertiary = Grey.grey500

    // MARK: - Control Colors

    /// The color for the flat surfaces of controls
    public static let controlColor = Color(nsColor: .controlColor)

    /// The color for text on controls
    public static let controlText = Color(nsColor: .controlTextColor)

    /// The color for text on disabled controls
    public static let disabledControlText = Color(nsColor: .disabledControlTextColor)

    /// The current system control accent color
    public static let controlAccent = Color(nsColor: .controlAccentColor)

    /// The color for selected controls
    public static let selectedControl = Color(nsColor: .selectedControlColor)

    /// The color for text in selected controls
    public static let selectedControlText = Color(nsColor: .selectedControlTextColor)

    // MARK: - Header Colors

    /// The color for text in header cells
    public static let headerText = Color(nsColor: .headerTextColor)

    // MARK: - Shadow

    /// The shadow color for the screen
    public static let shadow = Color(nsColor: .shadowColor)

    // MARK: - System Colors

    /// The system red color used for notification badges
    public static let notification = Color(nsColor: .systemRed)

    // MARK: - Semantic Status Colors

    /// Success state color (base)
    public static var success: Color { Success.success500 }

    /// Warning state color (base)
    public static var warning: Color { Warning.warning500 }

    /// Danger/error state color (base)
    public static var danger: Color { Danger.danger500 }

    /// Info/neutral state color (base)
    public static var info: Color { Info.info500 }
}

// MARK: - Previews

#Preview("Grey Palette") {
    VStack(alignment: .leading, spacing: 2) {
        Text("Grey Palette (Warm)")
            .font(.headline)
            .padding(.bottom, 8)

        ColorSwatchRow(name: "Grey 50", color: Grey.grey50)
        ColorSwatchRow(name: "Grey 100", color: Grey.grey100)
        ColorSwatchRow(name: "Grey 200", color: Grey.grey200)
        ColorSwatchRow(name: "Grey 300", color: Grey.grey300)
        ColorSwatchRow(name: "Grey 400", color: Grey.grey400)
        ColorSwatchRow(name: "Grey 500", color: Grey.grey500)
        ColorSwatchRow(name: "Grey 600", color: Grey.grey600)
        ColorSwatchRow(name: "Grey 700", color: Grey.grey700)
        ColorSwatchRow(name: "Grey 800", color: Grey.grey800)
        ColorSwatchRow(name: "Grey 900", color: Grey.grey900)
    }
    .padding(24)
    .frame(width: 300)
}

#Preview("Semantic Colors") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Semantic Color Palettes")
            .font(.headline)

        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("Primary").font(.caption)
                ColorSwatch(color: Primary.primary50)
                ColorSwatch(color: Primary.primary200)
                ColorSwatch(color: Primary.primary500)
                ColorSwatch(color: Primary.primary700)
                ColorSwatch(color: Primary.primary900)
            }

            VStack(spacing: 2) {
                Text("Success").font(.caption)
                ColorSwatch(color: Success.success50)
                ColorSwatch(color: Success.success200)
                ColorSwatch(color: Success.success500)
                ColorSwatch(color: Success.success700)
                ColorSwatch(color: Success.success900)
            }

            VStack(spacing: 2) {
                Text("Warning").font(.caption)
                ColorSwatch(color: Warning.warning50)
                ColorSwatch(color: Warning.warning200)
                ColorSwatch(color: Warning.warning500)
                ColorSwatch(color: Warning.warning700)
                ColorSwatch(color: Warning.warning900)
            }

            VStack(spacing: 2) {
                Text("Danger").font(.caption)
                ColorSwatch(color: Danger.danger50)
                ColorSwatch(color: Danger.danger200)
                ColorSwatch(color: Danger.danger500)
                ColorSwatch(color: Danger.danger700)
                ColorSwatch(color: Danger.danger900)
            }

            VStack(spacing: 2) {
                Text("Info").font(.caption)
                ColorSwatch(color: Info.info50)
                ColorSwatch(color: Info.info200)
                ColorSwatch(color: Info.info500)
                ColorSwatch(color: Info.info700)
                ColorSwatch(color: Info.info900)
            }
        }
    }
    .padding(24)
}

// MARK: - Preview Helpers

private struct ColorSwatchRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 40, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                )
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct ColorSwatch: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 40, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
}

