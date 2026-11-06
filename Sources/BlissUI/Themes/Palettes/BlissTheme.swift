//
//  BlissTheme.swift
//  BlissUI
//
//  Color themes. A theme recolors the *surfaces* (the window shell, content
//  panes, raised controls, hairline borders), the accent, and — when it
//  publishes them — the status colors. The Grey ramp stays fixed so semantics
//  read the same across themes.
//
//  `.system` has no palettes, so every token falls back to its built-in value
//  and the app follows macOS (system accent, system appearance). Every other
//  theme carries a light and a dark palette, picked against the Light / Dark /
//  System toggle, so the toggle keeps working under any theme.
//
//  BlissUI ships four built-ins — System, High Contrast, Color Blind Safe and
//  Low Glare. Register your own with `BlissTheme.register(_:)`.
//

import SwiftUI
import AppKit

// MARK: - Theme RGB

/// A plain sRGB color authored from a `0xRRGGBB` literal. Exposes both a
/// SwiftUI `Color` (for surfaces) and an `NSColor` (for the accent pipeline,
/// which works in NSColor/HSB), so palette authoring stays a single hex value.
public nonisolated struct ThemeRGB: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255.0
        green = Double((hex >> 8) & 0xFF) / 255.0
        blue = Double(hex & 0xFF) / 255.0
    }

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `#RRGGBB` (or `RRGGBB`); nil for anything else.
    public init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(value)
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
    public var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

// MARK: - Theme Palette

/// The resolved surface colors for one mode (light or dark) of a color theme.
public nonisolated struct ThemePalette: Equatable, Sendable {
    /// The app shell behind everything — window chrome + sidebar surface.
    public let windowBackground: ThemeRGB
    /// Content panes that sit above the shell.
    public let contentBackground: ThemeRGB
    /// Raised surfaces — cards, controls, text fields.
    public let elevatedBackground: ThemeRGB
    /// Hairline borders and floating-surface edges (menus, tooltips, popups).
    public let border: ThemeRGB
    /// Filled-accent surfaces — selected rows, primary buttons, focus rings.
    public let accent: ThemeRGB
    /// Text and glyphs on an accent fill, when the theme publishes one; else
    /// `AccentHue.contrastForeground` picks white or near-black by luminance.
    public var accentForeground: ThemeRGB? = nil
    /// The theme's status colors; nil members keep the built-in ones.
    public var status = ThemeStatusColors()

    public init(
        windowBackground: ThemeRGB,
        contentBackground: ThemeRGB,
        elevatedBackground: ThemeRGB,
        border: ThemeRGB,
        accent: ThemeRGB,
        accentForeground: ThemeRGB? = nil,
        status: ThemeStatusColors = ThemeStatusColors()
    ) {
        self.windowBackground = windowBackground
        self.contentBackground = contentBackground
        self.elevatedBackground = elevatedBackground
        self.border = border
        self.accent = accent
        self.accentForeground = accentForeground
        self.status = status
    }
}

// MARK: - Theme Status Colors

/// A theme's success / warning / danger / info colors, one base each as the
/// theme publishes it; nil keeps the built-in one. `StatusTones` derives what's
/// drawn: a mark legible on the theme's surfaces and a fill deep enough for
/// white text.
public nonisolated struct ThemeStatusColors: Equatable, Sendable {
    public var success: ThemeRGB? = nil
    public var warning: ThemeRGB? = nil
    public var danger: ThemeRGB? = nil
    public var info: ThemeRGB? = nil

    public init(success: UInt32? = nil, warning: UInt32? = nil, danger: UInt32? = nil, info: UInt32? = nil) {
        self.success = success.map(ThemeRGB.init)
        self.warning = warning.map(ThemeRGB.init)
        self.danger = danger.map(ThemeRGB.init)
        self.info = info.map(ThemeRGB.init)
    }
}

// MARK: - Bliss Theme

/// A color theme: a light and a dark palette (or none, for `.system`), the
/// contrast its status marks are held to, and a swatch for pickers.
public nonisolated struct BlissTheme: Identifiable, Hashable, Sendable {
    /// Stable identifier, persisted as the user's choice.
    public let id: String
    /// Name shown in pickers.
    public let name: String
    public let lightPalette: ThemePalette?
    public let darkPalette: ThemePalette?
    /// The contrast a status mark keeps against the theme's surfaces: WCAG AA
    /// for text (4.5) by default, AAA (7) for High Contrast.
    public let minimumStatusContrast: Double
    /// Four colors that represent the theme in a picker.
    public let swatch: [ThemeRGB]

    public init(
        id: String,
        name: String,
        light: ThemePalette?,
        dark: ThemePalette?,
        swatch: [ThemeRGB],
        minimumStatusContrast: Double = 4.5
    ) {
        self.id = id
        self.name = name
        self.lightPalette = light
        self.darkPalette = dark
        self.swatch = swatch
        self.minimumStatusContrast = minimumStatusContrast
    }

    /// The theme with no palettes: built-in tokens, system accent.
    public var isSystem: Bool { lightPalette == nil && darkPalette == nil }

    /// The palette for a scheme, or nil when the theme leaves that scheme to
    /// the built-in tokens.
    public func palette(for scheme: ColorScheme) -> ThemePalette? {
        scheme == .dark ? darkPalette : lightPalette
    }

    public var swatchColors: [Color] { swatch.map(\.color) }

    public static func == (lhs: BlissTheme, rhs: BlissTheme) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Built-in themes

extension BlissTheme {
    /// Follows macOS: the built-in tokens and the system accent color.
    public static let system = BlissTheme(
        id: "system",
        name: "System",
        light: nil,
        dark: nil,
        swatch: [ThemeRGB(0x3A3A3C), ThemeRGB(0xF4F4F4), ThemeRGB(0x0A84FF), ThemeRGB(0x34C759)]
    )

    /// For low vision: black-on-white (and the reverse), full-strength borders,
    /// status marks held to 7:1. Status colors are macOS's system green /
    /// orange / red / blue.
    public static let highContrast = BlissTheme(
        id: "high-contrast",
        name: "High Contrast",
        light: ThemePalette(
            windowBackground: ThemeRGB(0xFFFFFF), contentBackground: ThemeRGB(0xFFFFFF),
            elevatedBackground: ThemeRGB(0xF2F2F2), border: ThemeRGB(0x000000), accent: ThemeRGB(0x0030C0),
            status: ThemeStatusColors(success: 0x34C759, warning: 0xFF8D28, danger: 0xFF383C, info: 0x0088FF)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x000000), contentBackground: ThemeRGB(0x0A0A0A),
            elevatedBackground: ThemeRGB(0x141414), border: ThemeRGB(0x5A5A5A), accent: ThemeRGB(0x3B9DFF),
            status: ThemeStatusColors(success: 0x30D158, warning: 0xFF9230, danger: 0xFF4245, info: 0x0091FF)
        ),
        swatch: [ThemeRGB(0x000000), ThemeRGB(0xFFFFFF), ThemeRGB(0x3B9DFF), ThemeRGB(0xFF5C5C)],
        minimumStatusContrast: 7
    )

    /// Okabe & Ito's palette: bluish green / orange / vermillion / blue for
    /// success / warning / danger / info, distinct with protan, deutan and
    /// tritan vision. Info is Okabe-Ito blue because the dark accent is its
    /// sky blue, and a status mark must never equal the accent (`statusTint`
    /// matches by color).
    public static let colorBlindSafe = BlissTheme(
        id: "color-blind-safe",
        name: "Color Blind Safe",
        light: ThemePalette(
            windowBackground: ThemeRGB(0xF4F4F4), contentBackground: ThemeRGB(0xFFFFFF),
            elevatedBackground: ThemeRGB(0xFFFFFF), border: ThemeRGB(0xE0E0E0), accent: ThemeRGB(0x0072B2),
            status: ThemeStatusColors(success: 0x009E73, warning: 0xE69F00, danger: 0xD55E00, info: 0x0072B2)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x1C1C1E), contentBackground: ThemeRGB(0x232325),
            elevatedBackground: ThemeRGB(0x2C2C2E), border: ThemeRGB(0x3A3A3C), accent: ThemeRGB(0x56B4E9),
            status: ThemeStatusColors(success: 0x009E73, warning: 0xE69F00, danger: 0xD55E00, info: 0x0072B2)
        ),
        swatch: [ThemeRGB(0x0072B2), ThemeRGB(0x009E73), ThemeRGB(0xE69F00), ThemeRGB(0xD55E00)]
    )

    /// Dim, warm surfaces for light sensitivity and visual stress: cream rather
    /// than white in light mode (the dyslexia style guides' advice against
    /// glare), low contrast between surfaces, a muted amber accent.
    public static let lowGlare = BlissTheme(
        id: "low-glare",
        name: "Low Glare",
        light: ThemePalette(
            windowBackground: ThemeRGB(0xECE5D5), contentBackground: ThemeRGB(0xF5EFE2),
            elevatedBackground: ThemeRGB(0xFAF6EC), border: ThemeRGB(0xDDD3BF), accent: ThemeRGB(0x8A6A3B),
            status: ThemeStatusColors(success: 0x5E7F45, warning: 0x8F6A2A, danger: 0xA4533F, info: 0x4B7590)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x1C1B19), contentBackground: ThemeRGB(0x21201D),
            elevatedBackground: ThemeRGB(0x2A2926), border: ThemeRGB(0x36342F), accent: ThemeRGB(0xC4A374),
            status: ThemeStatusColors(success: 0x8FB573, warning: 0xD6A85C, danger: 0xD9826F, info: 0x7FA7C2)
        ),
        swatch: [ThemeRGB(0x21201D), ThemeRGB(0xC4A374), ThemeRGB(0x8FB573), ThemeRGB(0xF5EFE2)]
    )

    /// The themes BlissUI ships, in picker order.
    public static let builtIn: [BlissTheme] = [.system, .highContrast, .colorBlindSafe, .lowGlare]
}

// MARK: - Registry

/// Every theme a picker offers: the built-ins, then any the app registered.
/// Touched only on the main actor (pickers, the theme modifier, token reads).
@MainActor
enum BlissThemeRegistry {
    private(set) static var themes: [BlissTheme] = BlissTheme.builtIn

    static func register(_ theme: BlissTheme) {
        if let index = themes.firstIndex(where: { $0.id == theme.id }) {
            themes[index] = theme
        } else {
            themes.append(theme)
        }
        StatusTones.invalidateCache()
    }

    static func theme(withID id: String) -> BlissTheme? {
        themes.first { $0.id == id }
    }
}

extension BlissTheme {
    /// Adds a theme to `all` (or replaces the one with the same `id`).
    @MainActor public static func register(_ theme: BlissTheme) { BlissThemeRegistry.register(theme) }

    /// The built-ins plus every registered theme, in picker order.
    @MainActor public static var all: [BlissTheme] { BlissThemeRegistry.themes }

    /// The theme the user picked (`BlissAppearance.Keys.theme`), else `.system`.
    @MainActor public static var active: BlissTheme {
        let id = UserDefaults.standard.string(forKey: BlissAppearance.Keys.theme) ?? BlissTheme.system.id
        return BlissThemeRegistry.theme(withID: id) ?? .system
    }
}

// MARK: - Active theme lookups

/// Reads of the active theme for the resolved scheme. Tokens read these on
/// access, which is why `.blissTheme()` re-IDs the tree when they change.
public enum ThemeColors {
    /// The color scheme in effect: the app's Light/Dark override, else the
    /// system appearance.
    public static var resolvedScheme: ColorScheme {
        switch BlissAppearance.colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .system:
            let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }

    /// The active theme's palette for the resolved scheme; nil for `.system`.
    public static var activePalette: ThemePalette? {
        BlissTheme.active.palette(for: resolvedScheme)
    }

    /// The accent in use: the one picked for this theme, else the theme's own.
    public static var activeAccent: ThemeRGB? {
        guard let palette = activePalette else { return nil }
        return ThemeAccentOverrides.color(for: BlissTheme.active) ?? palette.accent
    }

    public static var activeAccentNSColor: NSColor? {
        activeAccent?.nsColor
    }

    /// The theme's published accent foreground — only while its own accent is
    /// in use; a picked accent gets the luminance rule instead.
    public static var activeAccentForeground: ThemeRGB? {
        guard ThemeAccentOverrides.color(for: BlissTheme.active) == nil else { return nil }
        return activePalette?.accentForeground
    }
}

// MARK: - Per-theme accent picks

/// The accent the user picked for each theme, stored as `id=#RRGGBB` pairs in
/// one string so a single `@AppStorage` observes every pick.
enum ThemeAccentOverrides {
    private static var cache: (raw: String, colors: [String: ThemeRGB]) = ("", [:])

    static func color(for theme: BlissTheme) -> ThemeRGB? {
        guard !theme.isSystem else { return nil }
        return colors(in: storedValue)[theme.id]
    }

    static func set(_ color: ThemeRGB?, for theme: BlissTheme) {
        var all = colors(in: storedValue)
        all[theme.id] = color
        let raw = all.keys.sorted().compactMap { key in all[key].map { "\(key)=\($0.hexString)" } }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: BlissAppearance.Keys.themeAccentOverrides)
    }

    private static var storedValue: String {
        UserDefaults.standard.string(forKey: BlissAppearance.Keys.themeAccentOverrides) ?? ""
    }

    private static func colors(in raw: String) -> [String: ThemeRGB] {
        if raw == cache.raw { return cache.colors }
        var colors: [String: ThemeRGB] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, let color = ThemeRGB(hexString: parts[1]) else { continue }
            colors[parts[0]] = color
        }
        cache = (raw, colors)
        return colors
    }
}
