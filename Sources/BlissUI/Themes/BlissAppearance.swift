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

    public var title: String { rawValue }

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
}
