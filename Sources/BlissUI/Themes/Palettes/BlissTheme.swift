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
    public var windowBackground: ThemeRGB
    /// Content panes that sit above the shell.
    public var contentBackground: ThemeRGB
    /// Raised surfaces — cards, controls, text fields.
    public var elevatedBackground: ThemeRGB
    /// Hairline borders and floating-surface edges (menus, tooltips, popups).
    public var border: ThemeRGB
    /// Filled-accent surfaces — selected rows, primary buttons, focus rings.
    public var accent: ThemeRGB
    /// Text and glyphs on an accent fill, when the theme publishes one; else
    /// `AccentHue.contrastForeground` picks white or near-black by luminance.
    public var accentForeground: ThemeRGB? = nil
    /// The theme's status colors; nil members keep the built-in ones.
    public var status = ThemeStatusColors()
    /// The theme's text color. Primary text uses it as is; secondary and
    /// tertiary text are mixed from it toward the background. Nil keeps the
    /// system's label colors.
    public var foreground: ThemeRGB? = nil

    public init(
        windowBackground: ThemeRGB,
        contentBackground: ThemeRGB,
        elevatedBackground: ThemeRGB,
        border: ThemeRGB,
        accent: ThemeRGB,
        accentForeground: ThemeRGB? = nil,
        status: ThemeStatusColors = ThemeStatusColors(),
        foreground: ThemeRGB? = nil
    ) {
        self.windowBackground = windowBackground
        self.contentBackground = contentBackground
        self.elevatedBackground = elevatedBackground
        self.border = border
        self.accent = accent
        self.accentForeground = accentForeground
        self.status = status
        self.foreground = foreground
    }

    /// Whether the palette's surfaces are dark.
    public var isDark: Bool { StatusToneMath.luminance(contentBackground) < 0.18 }

    /// This palette with its surfaces rebuilt around `background`: the window
    /// (shell) takes it as is, and the content pane, raised surfaces and
    /// border step away from it the way the built-in themes do — lighter
    /// panes over a dark shell, white panes over a light one. With no
    /// foreground of its own, text turns light or dark to suit it.
    public func withBackground(_ background: ThemeRGB) -> ThemePalette {
        let dark = StatusToneMath.luminance(background) < 0.18
        let white = ThemeRGB(red: 1, green: 1, blue: 1)
        let black = ThemeRGB(red: 0, green: 0, blue: 0)
        var palette = self
        palette.windowBackground = background
        palette.contentBackground = background.mixed(with: white, amount: dark ? 0.03 : 0.55)
        palette.elevatedBackground = background.mixed(with: white, amount: dark ? 0.08 : 0.75)
        palette.border = background.mixed(with: dark ? white : black, amount: dark ? 0.14 : 0.10)
        if palette.foreground == nil || palette.isDark != isDark {
            palette.foreground = dark ? ThemeRGB(0xF2F2F2) : ThemeRGB(0x1C1C1E)
        }
        return palette
    }
}

extension ThemeRGB {
    /// This color moved `amount` (0…1) of the way toward `other`.
    public func mixed(with other: ThemeRGB, amount: Double) -> ThemeRGB {
        let t = min(max(amount, 0), 1)
        return ThemeRGB(red: red + (other.red - red) * t, green: green + (other.green - green) * t, blue: blue + (other.blue - blue) * t)
    }
}

// MARK: - Theme Status Colors

/// A theme's success / warning / danger / info colors, one base each as the
/// theme publishes it; nil keeps the built-in one. `StatusTones` derives what's
/// drawn: a mark legible on the theme's surfaces and a fill deep enough for
/// white text.
public nonisolated struct ThemeStatusColors: Equatable, Sendable, Codable {
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
    /// Name shown in pickers, looked up in the app's string catalog. The
    /// built-ins' names come already translated from BlissUI's own.
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
        name: String(localized: "System", bundle: .module),
        light: nil,
        dark: nil,
        swatch: [ThemeRGB(0x3A3A3C), ThemeRGB(0xF4F4F4), ThemeRGB(0x0A84FF), ThemeRGB(0x34C759)]
    )

    /// For low vision: black-on-white (and the reverse), full-strength borders,
    /// status marks held to 7:1. Status colors are macOS's system green /
    /// orange / red / blue.
    public static let highContrast = BlissTheme(
        id: "high-contrast",
        name: String(localized: "High Contrast", bundle: .module),
        light: ThemePalette(
            windowBackground: ThemeRGB(0xFFFFFF), contentBackground: ThemeRGB(0xFFFFFF),
            elevatedBackground: ThemeRGB(0xF2F2F2), border: ThemeRGB(0x000000), accent: ThemeRGB(0x0030C0),
            status: ThemeStatusColors(success: 0x34C759, warning: 0xFF8D28, danger: 0xFF383C, info: 0x0088FF),
            foreground: ThemeRGB(0x000000)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x000000), contentBackground: ThemeRGB(0x0A0A0A),
            elevatedBackground: ThemeRGB(0x141414), border: ThemeRGB(0x5A5A5A), accent: ThemeRGB(0x3B9DFF),
            status: ThemeStatusColors(success: 0x30D158, warning: 0xFF9230, danger: 0xFF4245, info: 0x0091FF),
            foreground: ThemeRGB(0xFFFFFF)
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
        name: String(localized: "Color Blind Safe", bundle: .module),
        light: ThemePalette(
            windowBackground: ThemeRGB(0xF4F4F4), contentBackground: ThemeRGB(0xFFFFFF),
            elevatedBackground: ThemeRGB(0xFFFFFF), border: ThemeRGB(0xE0E0E0), accent: ThemeRGB(0x0072B2),
            status: ThemeStatusColors(success: 0x009E73, warning: 0xE69F00, danger: 0xD55E00, info: 0x0072B2),
            foreground: ThemeRGB(0x1C1C1E)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x1C1C1E), contentBackground: ThemeRGB(0x232325),
            elevatedBackground: ThemeRGB(0x2C2C2E), border: ThemeRGB(0x3A3A3C), accent: ThemeRGB(0x56B4E9),
            status: ThemeStatusColors(success: 0x009E73, warning: 0xE69F00, danger: 0xD55E00, info: 0x0072B2),
            foreground: ThemeRGB(0xF2F2F7)
        ),
        swatch: [ThemeRGB(0x0072B2), ThemeRGB(0x009E73), ThemeRGB(0xE69F00), ThemeRGB(0xD55E00)]
    )

    /// Dim, warm surfaces for light sensitivity and visual stress: cream rather
    /// than white in light mode (the dyslexia style guides' advice against
    /// glare), low contrast between surfaces, a muted amber accent.
    public static let lowGlare = BlissTheme(
        id: "low-glare",
        name: String(localized: "Low Glare", bundle: .module),
        light: ThemePalette(
            windowBackground: ThemeRGB(0xECE5D5), contentBackground: ThemeRGB(0xF5EFE2),
            elevatedBackground: ThemeRGB(0xFAF6EC), border: ThemeRGB(0xDDD3BF), accent: ThemeRGB(0x8A6A3B),
            status: ThemeStatusColors(success: 0x5E7F45, warning: 0x8F6A2A, danger: 0xA4533F, info: 0x4B7590),
            foreground: ThemeRGB(0x3B342A)
        ),
        dark: ThemePalette(
            windowBackground: ThemeRGB(0x1C1B19), contentBackground: ThemeRGB(0x21201D),
            elevatedBackground: ThemeRGB(0x2A2926), border: ThemeRGB(0x36342F), accent: ThemeRGB(0xC4A374),
            status: ThemeStatusColors(success: 0x8FB573, warning: 0xD6A85C, danger: 0xD9826F, info: 0x7FA7C2),
            foreground: ThemeRGB(0xDDD3C0)
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
    /// The built-ins, then the user's own (`CustomThemeStore`), then the app's.
    private(set) static var themes: [BlissTheme] = BlissTheme.builtIn + CustomThemeStore.load()

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

    static func unregister(_ id: String) {
        themes.removeAll { $0.id == id }
        StatusTones.invalidateCache()
    }
}

extension BlissTheme {
    /// Adds a theme to `all` (or replaces the one with the same `id`).
    @MainActor public static func register(_ theme: BlissTheme) { BlissThemeRegistry.register(theme) }

    /// The built-ins plus every registered theme, in picker order.
    @MainActor public static var all: [BlissTheme] { BlissThemeRegistry.themes }

    /// The theme in effect for the scheme the app is showing.
    @MainActor public static var active: BlissTheme {
        active(for: ThemeColors.resolvedScheme)
    }

    /// The theme for `scheme`: the one picked for that mode while light and
    /// dark are set separately (`BlissAppearance.separateModes`), else the one
    /// picked for both (`BlissAppearance.Keys.theme`), else `.system`.
    @MainActor public static func active(for scheme: ColorScheme) -> BlissTheme {
        let defaults = UserDefaults.standard
        var id = defaults.string(forKey: BlissAppearance.Keys.theme)
        if defaults.bool(forKey: BlissAppearance.Keys.separateModes),
           let modeID = defaults.string(forKey: scheme == .dark ? BlissAppearance.Keys.themeDark : BlissAppearance.Keys.themeLight) {
            id = modeID
        }
        return BlissThemeRegistry.theme(withID: id ?? BlissTheme.system.id) ?? .system
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

    /// The palette in effect for the resolved scheme; nil for `.system` with
    /// no colors of its own.
    public static var activePalette: ThemePalette? {
        palette(for: resolvedScheme)
    }

    /// The palette for `scheme`: that mode's theme, with the background and
    /// foreground the user set for it laid over. `.system` has none unless
    /// colors were set for it, then its built-in surfaces are the base.
    public static func palette(for scheme: ColorScheme) -> ThemePalette? {
        palette(of: BlissTheme.active(for: scheme), for: scheme)
    }

    /// `theme`'s palette for `scheme` with the background and foreground the
    /// user set for it laid over.
    public static func palette(of theme: BlissTheme, for scheme: ColorScheme) -> ThemePalette? {
        let background = ThemeSurfaceOverrides.color(.background, for: theme, scheme: scheme)
        let foreground = ThemeSurfaceOverrides.color(.foreground, for: theme, scheme: scheme)
        let base = theme.palette(for: scheme) ?? ((background != nil || foreground != nil) ? .systemBase(for: scheme) : nil)
        guard var palette = base else { return nil }
        if let background { palette = palette.withBackground(background) }
        if let foreground { palette.foreground = foreground }
        return palette
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

extension ThemePalette {
    /// The built-in System surfaces as a palette, for colors set on the System
    /// theme. The accent is the System theme's (macOS's or the custom pick),
    /// read from the stored choice so it never loops back through a palette.
    @MainActor static func systemBase(for scheme: ColorScheme) -> ThemePalette {
        let accent: ThemeRGB
        if BlissAppearance.accentOption == .custom {
            accent = BlissAppearance.customAccent
        } else if let system = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
            accent = ThemeRGB(red: system.redComponent, green: system.greenComponent, blue: system.blueComponent)
        } else {
            accent = BlissAppearance.defaultCustomAccent
        }
        return scheme == .dark
            ? ThemePalette(windowBackground: ThemeRGB(0x262629), contentBackground: ThemeRGB(0x1E1E1E), elevatedBackground: ThemeRGB(0x2C2C2E), border: ThemeRGB(0x3A3A3C), accent: accent)
            : ThemePalette(windowBackground: ThemeRGB(0xF4F4F4), contentBackground: ThemeRGB(0xFFFFFF), elevatedBackground: ThemeRGB(0xFFFFFF), border: ThemeRGB(0xE0E0E0), accent: accent)
    }
}

// MARK: - Per-theme background and foreground

/// The surfaces a user can recolor in a theme.
public nonisolated enum ThemeSurfaceRole: String, CaseIterable, Sendable {
    case background
    case foreground
}

/// The background and foreground the user set per theme and mode, stored as
/// `id.mode.role=#RRGGBB` pairs in one string so a single `@AppStorage`
/// observes every change.
enum ThemeSurfaceOverrides {
    private static var cache: (raw: String, colors: [String: ThemeRGB]) = ("", [:])

    static func color(_ role: ThemeSurfaceRole, for theme: BlissTheme, scheme: ColorScheme) -> ThemeRGB? {
        colors(in: storedValue)[key(role, theme, scheme)]
    }

    static func set(_ color: ThemeRGB?, _ role: ThemeSurfaceRole, for theme: BlissTheme, scheme: ColorScheme) {
        var all = colors(in: storedValue)
        all[key(role, theme, scheme)] = color
        let raw = all.keys.sorted().compactMap { key in all[key].map { "\(key)=\($0.hexString)" } }.joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: BlissAppearance.Keys.surfaceOverrides)
    }

    private static func key(_ role: ThemeSurfaceRole, _ theme: BlissTheme, _ scheme: ColorScheme) -> String {
        "\(theme.id).\(scheme == .dark ? "dark" : "light").\(role.rawValue)"
    }

    private static var storedValue: String {
        UserDefaults.standard.string(forKey: BlissAppearance.Keys.surfaceOverrides) ?? ""
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
