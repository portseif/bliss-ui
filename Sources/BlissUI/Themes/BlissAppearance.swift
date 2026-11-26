//
//  BlissAppearance.swift
//  BlissUI
//
//  The user's appearance choices — theme, Light/Dark/System, accent — stored in
//  `UserDefaults` so `@AppStorage` in your settings UI and `.blissTheme()` see
//  the same values. Set them from code with the static properties here, or bind
//  `@AppStorage(BlissAppearance.Keys.theme)` and friends directly.
//

import SwiftUI

// MARK: - Options

/// The app's Light / Dark override, or System to follow macOS.
public nonisolated enum ColorSchemeOption: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    /// The option's name, translated. `rawValue` is the persisted value.
    public var title: String {
        switch self {
        case .system: return String(localized: "System", bundle: .module)
        case .light: return String(localized: "Light", bundle: .module)
        case .dark: return String(localized: "Dark", bundle: .module)
        }
    }

    public var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

/// Where the accent comes from when the System theme is active: macOS's
/// accent, or a custom RGB.
public nonisolated enum AccentColorOption: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case custom = "Custom"

    public var id: String { rawValue }
}

/// Whether motion is reduced: following macOS's Reduce Motion, or always on
/// or off for this app.
public nonisolated enum ReduceMotionOption: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case on = "On"
    case off = "Off"

    public var id: String { rawValue }

    /// The option's name, translated. `rawValue` is the persisted value.
    public var title: String {
        switch self {
        case .system: return String(localized: "System", bundle: .module)
        case .on: return String(localized: "On", bundle: .module)
        case .off: return String(localized: "Off", bundle: .module)
        }
    }
}

// MARK: - Appearance

public enum BlissAppearance {
    /// `UserDefaults` keys. Namespaced so they can't collide with the app's own.
    public nonisolated enum Keys {
        public static let theme = "bliss.theme"
        public static let colorScheme = "bliss.colorScheme"
        public static let accentColorOverride = "bliss.accentColorOverride"
        public static let customAccentColorRed = "bliss.customAccentColorRed"
        public static let customAccentColorGreen = "bliss.customAccentColorGreen"
        public static let customAccentColorBlue = "bliss.customAccentColorBlue"
        /// The accents picked per theme (`id=#RRGGBB` pairs).
        public static let themeAccentOverrides = "bliss.themeAccentOverrides"
        /// `ReduceMotionOption`: follow macOS, or force reduced motion on or off.
        public static let reduceMotion = "bliss.reduceMotion"
        /// The background and foreground set per theme and mode.
        public static let surfaceOverrides = "bliss.surfaceOverrides"
        /// Whether light and dark each have their own theme and colors.
        public static let separateModes = "bliss.separateModes"
        /// The light mode's theme while `separateModes` is on.
        public static let themeLight = "bliss.theme.light"
        /// The dark mode's theme while `separateModes` is on.
        public static let themeDark = "bliss.theme.dark"
        /// The fonts and base font sizes (`FontChoice`s and sizes, as JSON).
        public static let typography = "bliss.typography"
        /// Whether buttons and other controls show the pointing-hand cursor.
        public static let pointerCursors = "bliss.pointerCursors"
        /// Contrast, 0–100 (50 is the theme as designed).
        public static let contrast = "bliss.contrast"
        /// Whether the window shell (title bar and sidebar) shows the desktop
        /// blurred through it.
        public static let translucentSidebar = "bliss.translucentSidebar"
        /// The picked `DockIconOption`'s id.
        public static let dockIcon = "bliss.dockIcon"
        /// The user's own themes (duplicated or imported), as JSON. Not
        /// cleared by `resetToDefaults()`.
        public static let customThemes = "bliss.customThemes"
        /// Whether `.persistsWindowFrame()` restores the last frame.
        public static let saveWindowLocation = "bliss.saveWindowLocation"
        /// The persisted main-window frame.
        public static let mainWindowFrame = "bliss.mainWindowFrame"
    }

    /// The default custom accent (macOS blue) before the user picks one.
    public static let defaultCustomAccent = ThemeRGB(red: 0.0, green: 0.478, blue: 1.0)

    /// The active theme. Setting it re-themes every view under `.blissTheme()`.
    public static var theme: BlissTheme {
        get { BlissTheme.active }
        set { UserDefaults.standard.set(newValue.id, forKey: Keys.theme) }
    }

    /// Light, Dark, or System.
    public static var colorScheme: ColorSchemeOption {
        get {
            UserDefaults.standard.string(forKey: Keys.colorScheme).flatMap(ColorSchemeOption.init(rawValue:)) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.colorScheme) }
    }

    /// System accent or a custom one (System theme only; other themes own
    /// their accent, see `setAccent(_:for:)`).
    public static var accentOption: AccentColorOption {
        get {
            UserDefaults.standard.string(forKey: Keys.accentColorOverride).flatMap(AccentColorOption.init(rawValue:)) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.accentColorOverride) }
    }

    /// The custom accent used when `accentOption` is `.custom`.
    public static var customAccent: ThemeRGB {
        get {
            let defaults = UserDefaults.standard
            func component(_ key: String, _ fallback: Double) -> Double {
                defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
            }
            return ThemeRGB(
                red: component(Keys.customAccentColorRed, defaultCustomAccent.red),
                green: component(Keys.customAccentColorGreen, defaultCustomAccent.green),
                blue: component(Keys.customAccentColorBlue, defaultCustomAccent.blue)
            )
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.red, forKey: Keys.customAccentColorRed)
            defaults.set(newValue.green, forKey: Keys.customAccentColorGreen)
            defaults.set(newValue.blue, forKey: Keys.customAccentColorBlue)
        }
    }

    /// Picks an accent for one theme (nil returns it to the theme's own).
    public static func setAccent(_ color: ThemeRGB?, for theme: BlissTheme) {
        ThemeAccentOverrides.set(color, for: theme)
    }

    /// The accent picked for one theme, or nil while it uses its own.
    public static func accent(for theme: BlissTheme) -> ThemeRGB? {
        ThemeAccentOverrides.color(for: theme)
    }

    /// Follow macOS's Reduce Motion, or force it for this app.
    public static var reduceMotion: ReduceMotionOption {
        get {
            UserDefaults.standard.string(forKey: Keys.reduceMotion).flatMap(ReduceMotionOption.init(rawValue:)) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.reduceMotion) }
    }

    /// Whether buttons, switches, pickers and menu rows show the pointing-hand
    /// cursor on hover (off: the arrow, like the rest of macOS).
    public static var usesPointerCursors: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.pointerCursors) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.pointerCursors) }
    }

    /// The default contrast: the theme as designed.
    public nonisolated static let defaultContrast = 50

    /// Contrast, 0–100. Above 50, borders, hover and selection washes and
    /// muted text step toward the text color; below, they soften. Muted text
    /// never drops under 4.5:1.
    public static var contrast: Int {
        get { (UserDefaults.standard.object(forKey: Keys.contrast) as? Int) ?? defaultContrast }
        set { UserDefaults.standard.set(min(max(newValue, 0), 100), forKey: Keys.contrast) }
    }

    /// Whether the title bar and sidebar show the desktop blurred through them
    /// (`Color.shellBackground` over a vibrancy view).
    public static var translucentSidebar: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.translucentSidebar) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.translucentSidebar) }
    }

    /// Whether light and dark each have their own theme and colors.
    public static var separateModes: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.separateModes) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.separateModes) }
    }

    /// The theme for one mode. Writing it while `separateModes` is off sets
    /// the theme for both.
    @MainActor public static func theme(for scheme: ColorScheme) -> BlissTheme {
        BlissTheme.active(for: scheme)
    }

    @MainActor public static func setTheme(_ theme: BlissTheme, for scheme: ColorScheme) {
        let key = separateModes ? (scheme == .dark ? Keys.themeDark : Keys.themeLight) : Keys.theme
        UserDefaults.standard.set(theme.id, forKey: key)
    }

    /// The background or foreground set for a theme in one mode; nil while it
    /// uses the theme's own.
    @MainActor public static func surfaceColor(_ role: ThemeSurfaceRole, for theme: BlissTheme, in scheme: ColorScheme) -> ThemeRGB? {
        ThemeSurfaceOverrides.color(role, for: theme, scheme: scheme)
    }

    /// Sets (or, with nil, clears) a theme's background or foreground for one mode.
    @MainActor public static func setSurfaceColor(_ color: ThemeRGB?, _ role: ThemeSurfaceRole, for theme: BlissTheme, in scheme: ColorScheme) {
        ThemeSurfaceOverrides.set(color, role, for: theme, scheme: scheme)
    }

    /// Every appearance choice back to its default: the app's default theme
    /// (`UserDefaults.register(defaults:)`, else System), System scheme and
    /// accent, no per-theme accent or color picks, one theme for both modes,
    /// system fonts at their default sizes, motion following macOS. Window placement is left alone.
    public static func resetToDefaults() {
        let defaults = UserDefaults.standard
        for key in [
            Keys.theme, Keys.colorScheme, Keys.accentColorOverride,
            Keys.customAccentColorRed, Keys.customAccentColorGreen, Keys.customAccentColorBlue,
            Keys.themeAccentOverrides, Keys.reduceMotion,
            Keys.surfaceOverrides, Keys.separateModes, Keys.themeLight, Keys.themeDark,
            Keys.typography, Keys.pointerCursors, Keys.contrast, Keys.translucentSidebar, Keys.dockIcon,
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
