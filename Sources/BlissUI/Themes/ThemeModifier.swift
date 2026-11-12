//
//  ThemeModifier.swift
//  BlissUI
//
//  Applies the user's preferred color scheme and accent color to views.
//

import AppKit
import SwiftUI

// MARK: - Accent Color Environment Key

extension EnvironmentValues {
    /// The current accent color hue (0.0 to 1.0)
    /// Views that use Primary colors should depend on this to re-render when accent changes
    @Entry public var accentHue: Double = 217/360
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
    /// Read on access through `prefersReducedMotion`, so a change re-IDs the tree.
    @AppStorage(BlissAppearance.Keys.reduceMotion) private var reduceMotion = ReduceMotionOption.system.rawValue
    // Colors set per theme and mode, and a theme per mode: read on access too.
    @AppStorage(BlissAppearance.Keys.surfaceOverrides) private var surfaceOverrides = ""
    @AppStorage(BlissAppearance.Keys.separateModes) private var separateModes = false
    @AppStorage(BlissAppearance.Keys.themeLight) private var lightThemeID = ""
    @AppStorage(BlissAppearance.Keys.themeDark) private var darkThemeID = ""
    /// Fonts and base sizes; `Typography` reads them on access.
    @AppStorage(BlissAppearance.Keys.typography) private var typography = ""
    @AppStorage(BlissAppearance.Keys.pointerCursors) private var usesPointerCursors = false
    @AppStorage(BlissAppearance.Keys.contrast) private var contrastSetting = BlissAppearance.defaultContrast
    @AppStorage(BlissAppearance.Keys.translucentSidebar) private var translucentSidebar = false
    /// Increase Contrast; tokens read `prefersIncreasedContrast` on access, so a
    /// change re-IDs the tree like a theme switch.
    @Environment(\.colorSchemeContrast) private var contrast
    /// The appearance the window actually has. Under System it flips with the
    /// Mac's, and the themed tokens (read on access) must be re-read when it does.
    @Environment(\.colorScheme) private var appearanceScheme
    /// Bumped after the app's appearance is changed to match the setting.
    /// Leaving Light or Dark for System hands the window back to the Mac, but
    /// SwiftUI's `colorScheme` can stay on the forced one, so nothing would
    /// re-render; this does.
    @State private var appearanceRevision = 0

    /// The theme in effect for the mode on screen (`.system` when none is selected).
    private var activeTheme: BlissTheme { BlissTheme.active }

    /// The palette in effect, with the user's colors over it; nil for default.
    private var themePalette: ThemePalette? {
        ThemeColors.activePalette
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

    /// The scheme views should draw in, when SwiftUI's own differs: the one
    /// the theme's surfaces read as (a light background picked for dark mode,
    /// or a dark one for light), else the mode actually in effect (SwiftUI's
    /// can lag behind it after leaving Light or Dark for System). Views get it
    /// as their color scheme, so system colors (`Color.primary`, control
    /// labels, washes) match the surfaces under them.
    private var surfaceScheme: ColorScheme? {
        let scheme: ColorScheme = themePalette.map { $0.isDark ? .dark : .light } ?? ThemeColors.resolvedScheme
        return scheme == appearanceScheme ? nil : scheme
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
            // The theme's text color for every view that doesn't set its own;
            // `.primary`, `.secondary` and `.tertiary` styles derive from it.
            .modifier(ThemeForeground(color: themePalette?.foreground?.color, surfaceScheme: surfaceScheme))
            .preferredColorScheme(preferredScheme)
            .tint(accentColor)
            .environment(\.accentHue, accentHue)  // Inject accent hue for Primary colors
            .id(accentColorId)  // Force view refresh when accent color changes
            .onChange(of: colorSchemeSetting, initial: true) { previousSetting, setting in
                syncAppAppearance()
                if previousSetting != setting { appearanceRevision += 1 }
            }
            // The shell backdrop is AppKit's: swap it for the blur (or back).
            .onChange(of: translucentSidebar) { _, _ in WindowChrome.reapplyShellBackdrops() }
    }

    /// `preferredColorScheme(nil)` doesn't hand a window back to the system on
    /// macOS: after Light or Dark it keeps the forced appearance while SwiftUI's
    /// environment moves on, so system colors and SwiftUI colors disagree (black
    /// text on a dark card). The app's appearance follows the setting too, and
    /// choosing System clears what each window was forced to.
    private func syncAppAppearance() {
        guard let app = NSApp else { return }
        switch preferredScheme {
        case .light: app.appearance = NSAppearance(named: .aqua)
        case .dark: app.appearance = NSAppearance(named: .darkAqua)
        default:
            app.appearance = nil
            for window in app.windows { window.appearance = nil }
        }
    }

    /// Unique ID based on theme + accent + scheme settings to force a view
    /// refresh when any of them change (themed surface tokens are read on access,
    /// so the tree must re-render to repick them).
    private var accentColorId: String {
        "\(colorTheme)-\(colorSchemeSetting)-\(appearanceScheme)-\(accentColorOverride)-\(customRed)-\(customGreen)-\(customBlue)-\(themeAccentOverrides)-\(reduceMotion)-\(surfaceOverrides)-\(separateModes)-\(lightThemeID)-\(darkThemeID)-\(typography)-\(usesPointerCursors)-\(contrastSetting)-\(translucentSidebar)-\(appearanceRevision)-\(contrast == .increased)"
    }
}

/// The theme's text color as the base foreground style, when it has one, and
/// the surfaces' scheme when it differs from the mode's.
private struct ThemeForeground: ViewModifier {
    let color: Color?
    let surfaceScheme: ColorScheme?

    func body(content: Content) -> some View {
        Group {
            if let color {
                content.foregroundStyle(color)
            } else {
                content
            }
        }
        .modifier(SurfaceScheme(scheme: surfaceScheme))
    }
}

private struct SurfaceScheme: ViewModifier {
    let scheme: ColorScheme?

    func body(content: Content) -> some View {
        if let scheme {
            content.environment(\.colorScheme, scheme)
        } else {
            content
        }
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
