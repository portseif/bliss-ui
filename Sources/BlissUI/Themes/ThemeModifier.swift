//
//  ThemeModifier.swift
//  BlissUI
//
//  Applies the user's preferred color scheme and accent color to views.
//

import SwiftUI

// MARK: - Accent Color Environment Key

/// Environment key for the current accent color hue (used to force re-renders when accent changes)
private struct AccentHueKey: EnvironmentKey {
    static let defaultValue: Double = 217/360  // Default blue
}

extension EnvironmentValues {
    /// The current accent color hue (0.0 to 1.0)
    /// Views that use Primary colors should depend on this to re-render when accent changes
    public var accentHue: Double {
        get { self[AccentHueKey.self] }
        set { self[AccentHueKey.self] = newValue }
    }
}

// MARK: - Theme Modifier

/// A view modifier that applies the user's theme preferences (color scheme and accent color)
public struct ThemeModifier: ViewModifier {
    @AppStorage(BlissAppearance.Keys.colorScheme) private var colorSchemeSetting = ColorSchemeOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.accentColorOverride) private var accentColorOverride = AccentColorOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.customAccentColorRed) private var customRed: Double = BlissAppearance.defaultCustomAccent.red
    @AppStorage(BlissAppearance.Keys.customAccentColorGreen) private var customGreen: Double = BlissAppearance.defaultCustomAccent.green
    @AppStorage(BlissAppearance.Keys.customAccentColorBlue) private var customBlue: Double = BlissAppearance.defaultCustomAccent.blue
    @AppStorage(BlissAppearance.Keys.theme) private var colorTheme = BlissTheme.system.id
    /// The accents picked per theme — observed so a pick re-renders the tree.
    @AppStorage(BlissAppearance.Keys.themeAccentOverrides) private var themeAccentOverrides = ""
    /// Increase Contrast; tokens read `prefersIncreasedContrast` on access, so a
    /// change re-IDs the tree like a theme switch.
    @Environment(\.colorSchemeContrast) private var contrast

    /// The active color theme (`.system` when none is selected).
    private var activeTheme: BlissTheme { BlissThemeRegistry.theme(withID: colorTheme) ?? .system }

    /// The theme's accent palette for the resolved scheme, or nil for default.
    private var themePalette: ThemePalette? {
        activeTheme.palette(for: ThemeColors.resolvedScheme)
    }

    private var preferredScheme: ColorScheme? {
        guard let option = ColorSchemeOption(rawValue: colorSchemeSetting) else { return nil }
        switch option {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var accentColor: Color? {
        // An active color theme owns the accent (or the one picked for it).
        if let palette = themePalette { return (ThemeAccentOverrides.color(for: activeTheme) ?? palette.accent).color }
        guard let option = AccentColorOption(rawValue: accentColorOverride) else { return nil }
        switch option {
        case .system: return nil
        case .custom: return Color(red: customRed, green: customGreen, blue: customBlue)
        }
    }

    /// Compute the accent hue for environment injection
    private var accentHue: Double {
        // An active color theme owns the accent — use its resolved hue.
        if themePalette != nil { return AccentHue.current }
        guard let option = AccentColorOption(rawValue: accentColorOverride),
              option == .custom else {
            return 217/360  // Default blue
        }

        // Convert RGB to hue
        let maxComponent = max(customRed, customGreen, customBlue)
        let minComponent = min(customRed, customGreen, customBlue)
        let delta = maxComponent - minComponent

        guard delta > 0 else { return 217/360 }

        var hue: Double = 0
        if customRed == maxComponent {
            hue = ((customGreen - customBlue) / delta).truncatingRemainder(dividingBy: 6)
        } else if customGreen == maxComponent {
            hue = (customBlue - customRed) / delta + 2
        } else {
            hue = (customRed - customGreen) / delta + 4
        }

        hue = hue / 6
        if hue < 0 { hue += 1 }

        return hue
    }

    public func body(content: Content) -> some View {
        content
            .preferredColorScheme(preferredScheme)
            .tint(accentColor)
            .accentColor(accentColor)  // Also set accentColor for legacy support
            .environment(\.accentHue, accentHue)  // Inject accent hue for Primary colors
            .id(accentColorId)  // Force view refresh when accent color changes
    }

    /// Unique ID based on theme + accent + scheme settings to force a view
    /// refresh when any of them change (themed surface tokens are read on access,
    /// so the tree must re-render to repick them).
    private var accentColorId: String {
        "\(colorTheme)-\(colorSchemeSetting)-\(accentColorOverride)-\(customRed)-\(customGreen)-\(customBlue)-\(themeAccentOverrides)-\(contrast == .increased)"
    }
}

// MARK: - View Extension

extension View {
    /// Applies the user's appearance choices — theme, Light/Dark/System and
    /// accent — to this view tree. Put it once at the root of each window.
    public func blissTheme() -> some View {
        modifier(ThemeModifier())
    }
}
