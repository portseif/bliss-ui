//
//  StatusTones.swift
//  BlissUI
//
//  The success / warning / danger / info colors a color theme supplies
//  (`ThemeStatusColors`), turned into the two tones the app draws, the same
//  split as the built-in palettes in ColorSystem.swift:
//  - the MARK (text, icons, dots, bars): the theme's color, lightened on a dark
//    theme or darkened on a light one only as far as it needs to reach the
//    theme's contrast floor (`BlissTheme.minimumStatusContrast`) on the content
//    and raised surfaces, bare and under the status's own chip/badge wash;
//  - the TINT (fills, borders, washes, and solid fills behind white text): the
//    theme's color, darkened until white text on it reads (4:1, about the
//    built-in tints' own).
//  A status the theme doesn't set keeps the built-in tones, and the Default
//  theme sets none, so it draws exactly as before.
//

import AppKit
import SwiftUI

public enum StatusKind: CaseIterable {
    case success, warning, danger, info
}

public enum StatusTones {
    /// The active theme's mark for `kind`, or nil for the built-in one.
    public static func mark(_ kind: StatusKind) -> Color? { activeTones()?.marks[kind] }

    /// The active theme's tint for `kind`, or nil for the built-in one.
    public static func tint(_ kind: StatusKind) -> Color? { activeTones()?.tints[kind] }

    /// Whether the active theme sets `kind` (else it's the built-in color).
    public static func isThemed(_ kind: StatusKind) -> Bool { activeTones()?.marks[kind] != nil }

    /// Whether the active theme sets any status color — a cheap check before
    /// resolving a color to match it against the theme's marks.
    public static var isAnyThemed: Bool { activeTones() != nil }

    /// The tint behind a themed mark, matched by the mark's dark-appearance
    /// components (what `Color.statusTint` / `legibleOnDark` resolve).
    public static func tint(matchingDarkMark red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> Color? {
        guard let tones = activeTones() else { return nil }
        for (kind, mark) in tones.darkMarks
        where abs(mark.red - red) < 0.01 && abs(mark.green - green) < 0.01 && abs(mark.blue - blue) < 0.01 {
            return tones.tints[kind]
        }
        return nil
    }

    // MARK: Resolution

    private struct Tones {
        var marks: [StatusKind: Color] = [:]
        var tints: [StatusKind: Color] = [:]
        var darkMarks: [StatusKind: ThemeRGB] = [:]
    }

    /// Built once per theme; nil when the theme sets no status colors.
    private static var cache: [String: Tones?] = [:]

    /// Drops the built tones (a registered theme may have replaced one).
    public static func invalidateCache() { cache.removeAll() }

    private static func activeTones() -> Tones? {
        let theme = BlissTheme.active
        if let cached = cache[theme.id] { return cached }
        let tones = makeTones(for: theme)
        cache[theme.id] = tones
        return tones
    }

    private static func makeTones(for theme: BlissTheme) -> Tones? {
        guard let dark = theme.palette(for: .dark), let light = theme.palette(for: .light) else { return nil }
        var tones = Tones()
        for kind in StatusKind.allCases {
            // A status is themed only when the theme sets it for both schemes.
            guard let darkBase = dark.status[kind], let lightBase = light.status[kind] else { continue }
            let darkTint = StatusToneMath.fillTone(darkBase)
            let lightTint = StatusToneMath.fillTone(lightBase)
            let darkMark = StatusToneMath.legible(
                darkBase, on: StatusToneMath.markSurfaces(of: dark, tint: darkTint, isDark: true), ratio: theme.minimumStatusContrast
            )
            let lightMark = StatusToneMath.legible(
                lightBase, on: StatusToneMath.markSurfaces(of: light, tint: lightTint, isDark: false), ratio: theme.minimumStatusContrast
            )
            tones.marks[kind] = Color.statusTone(dark: darkMark.nsColor, light: lightMark.nsColor)
            tones.tints[kind] = Color.statusTone(dark: darkTint.nsColor, light: lightTint.nsColor)
            tones.darkMarks[kind] = darkMark
        }
        return tones.marks.isEmpty ? nil : tones
    }
}

private extension ThemeStatusColors {
    subscript(kind: StatusKind) -> ThemeRGB? {
        switch kind {
        case .success: success
        case .warning: warning
        case .danger: danger
        case .info: info
        }
    }
}

// MARK: - Contrast math

public nonisolated enum StatusToneMath {
    /// WCAG relative luminance.
    public static func luminance(_ color: ThemeRGB) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// WCAG contrast ratio, 1…21.
    public static func contrast(_ first: ThemeRGB, _ second: ThemeRGB) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// `base` at `ratio` or better against every one of `backgrounds`, keeping
    /// its hue: on a dark surface it brightens (then pales, once at full
    /// brightness), on a light one it darkens. Unchanged if it already reads.
    public static func legible(_ base: ThemeRGB, on backgrounds: [ThemeRGB], ratio: Double) -> ThemeRGB {
        guard let first = backgrounds.first else { return base }
        let onDark = luminance(first) < 0.18
        var color = base
        for _ in 0..<100 {
            if backgrounds.allSatisfy({ contrast(color, $0) >= ratio }) { return color }
            var (hue, saturation, brightness) = hsb(of: color)
            if onDark {
                if brightness < 1 { brightness = min(1, brightness + 0.02) } else { saturation = max(0, saturation - 0.03) }
            } else {
                brightness = max(0, brightness - 0.02)
            }
            color = rgb(hue: hue, saturation: saturation, brightness: brightness)
        }
        return color
    }

    /// How strong a status wash gets under its own mark — a chip's or badge's
    /// fill (`Badge`: `tint.opacity(0.1)` / `0.12` light, `0.18` / `0.2` dark).
    public static let lightWashOpacity = 0.12
    public static let darkWashOpacity = 0.2

    /// What a status mark is drawn on: the theme's content and raised surfaces,
    /// bare and under its own tint's wash (a badge's text sits on its fill).
    public static func markSurfaces(of palette: ThemePalette, tint: ThemeRGB, isDark: Bool) -> [ThemeRGB] {
        let opacity = isDark ? darkWashOpacity : lightWashOpacity
        let surfaces = [palette.contentBackground, palette.elevatedBackground]
        return surfaces + surfaces.map { blend(tint, over: $0, opacity: opacity) }
    }

    /// `color` at `opacity` over `surface`, as it composites.
    public static func blend(_ color: ThemeRGB, over surface: ThemeRGB, opacity: Double) -> ThemeRGB {
        ThemeRGB(
            red: surface.red + (color.red - surface.red) * opacity,
            green: surface.green + (color.green - surface.green) * opacity,
            blue: surface.blue + (color.blue - surface.blue) * opacity
        )
    }

    /// `base` darkened until white text on it reaches `ratio`.
    public static func fillTone(_ base: ThemeRGB, ratio: Double = 4) -> ThemeRGB {
        legible(base, on: [ThemeRGB(0xFFFFFF)], ratio: ratio)
    }

    public static func hsb(of color: ThemeRGB) -> (hue: Double, saturation: Double, brightness: Double) {
        let maximum = max(color.red, color.green, color.blue)
        let minimum = min(color.red, color.green, color.blue)
        let delta = maximum - minimum
        var hue = 0.0
        if delta > 0 {
            if maximum == color.red { hue = (color.green - color.blue) / delta }
            else if maximum == color.green { hue = 2 + (color.blue - color.red) / delta }
            else { hue = 4 + (color.red - color.green) / delta }
            hue = (hue / 6).truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
        }
        return (hue, maximum == 0 ? 0 : delta / maximum, maximum)
    }

    public static func rgb(hue: Double, saturation: Double, brightness: Double) -> ThemeRGB {
        let sector = hue * 6
        let whole = floor(sector)
        let fraction = sector - whole
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - saturation * fraction)
        let t = brightness * (1 - saturation * (1 - fraction))
        switch Int(whole) % 6 {
        case 0: return ThemeRGB(red: brightness, green: t, blue: p)
        case 1: return ThemeRGB(red: q, green: brightness, blue: p)
        case 2: return ThemeRGB(red: p, green: brightness, blue: t)
        case 3: return ThemeRGB(red: p, green: q, blue: brightness)
        case 4: return ThemeRGB(red: t, green: p, blue: brightness)
        default: return ThemeRGB(red: brightness, green: p, blue: q)
        }
    }
}
