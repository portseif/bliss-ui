//
//  CustomThemes.swift
//  BlissUI
//
//  The user's own themes: duplicated from another theme (its colors as they
//  look, picks included) or imported from a theme file. Kept as JSON under
//  `BlissAppearance.Keys.customThemes` and added to the picker at launch.
//
//  A theme file is a `BlissTheme` as JSON, colors as "#RRGGBB":
//
//      { "id": "dusk", "name": "Dusk", "swatch": ["#1E1B2E", "#A78BFA"],
//        "light": { "windowBackground": "#F1EEFA", "contentBackground": "#FFFFFF",
//                   "elevatedBackground": "#FBFAFF", "border": "#E2DCF5",
//                   "accent": "#6D28D9", "foreground": "#1E1B2E" },
//        "dark": { … } }
//
//  `status` ({ "success", "warning", "danger", "info" }), `accentForeground`,
//  `foreground` and `minimumStatusContrast` are optional.
//

import AppKit
import SwiftUI

// MARK: - Coding

extension ThemeRGB: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let color = ThemeRGB(hexString: hex) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a #RRGGBB color, got \(hex)")
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}

extension ThemePalette: Codable {
    private enum CodingKeys: String, CodingKey {
        case windowBackground, contentBackground, elevatedBackground, border, accent, accentForeground, status, foreground
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            windowBackground: try container.decode(ThemeRGB.self, forKey: .windowBackground),
            contentBackground: try container.decode(ThemeRGB.self, forKey: .contentBackground),
            elevatedBackground: try container.decode(ThemeRGB.self, forKey: .elevatedBackground),
            border: try container.decode(ThemeRGB.self, forKey: .border),
            accent: try container.decode(ThemeRGB.self, forKey: .accent),
            accentForeground: try container.decodeIfPresent(ThemeRGB.self, forKey: .accentForeground),
            status: try container.decodeIfPresent(ThemeStatusColors.self, forKey: .status) ?? ThemeStatusColors(),
            foreground: try container.decodeIfPresent(ThemeRGB.self, forKey: .foreground)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowBackground, forKey: .windowBackground)
        try container.encode(contentBackground, forKey: .contentBackground)
        try container.encode(elevatedBackground, forKey: .elevatedBackground)
        try container.encode(border, forKey: .border)
        try container.encode(accent, forKey: .accent)
        try container.encodeIfPresent(accentForeground, forKey: .accentForeground)
        if status != ThemeStatusColors() { try container.encode(status, forKey: .status) }
        try container.encodeIfPresent(foreground, forKey: .foreground)
    }
}

extension BlissTheme: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, light, dark, swatch, minimumStatusContrast
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            light: try container.decodeIfPresent(ThemePalette.self, forKey: .light),
            dark: try container.decodeIfPresent(ThemePalette.self, forKey: .dark),
            swatch: try container.decodeIfPresent([ThemeRGB].self, forKey: .swatch) ?? [],
            minimumStatusContrast: try container.decodeIfPresent(Double.self, forKey: .minimumStatusContrast) ?? 4.5
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(lightPalette, forKey: .light)
        try container.encodeIfPresent(darkPalette, forKey: .dark)
        try container.encode(swatch, forKey: .swatch)
        try container.encode(minimumStatusContrast, forKey: .minimumStatusContrast)
    }
}

// MARK: - Store

/// The user's themes as stored.
@MainActor
enum CustomThemeStore {
    static func load() -> [BlissTheme] {
        guard let raw = UserDefaults.standard.string(forKey: BlissAppearance.Keys.customThemes),
              let themes = try? JSONDecoder().decode([BlissTheme].self, from: Data(raw.utf8)) else { return [] }
        return themes
    }

    static func save(_ themes: [BlissTheme]) {
        guard let data = try? JSONEncoder().encode(themes) else { return }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: BlissAppearance.Keys.customThemes)
    }

    static func contains(_ theme: BlissTheme) -> Bool {
        load().contains { $0.id == theme.id }
    }
}

extension BlissTheme {
    /// Whether the user made or imported this theme (so it can be deleted).
    @MainActor public var isCustom: Bool { CustomThemeStore.contains(self) }

    /// A new theme with `theme`'s colors as they look now (the background,
    /// foreground and accent picked for it included), named "<name> Copy",
    /// saved and added to `all`. System's copy takes its built-in surfaces.
    @MainActor @discardableResult
    public static func duplicate(_ theme: BlissTheme) -> BlissTheme {
        func effectivePalette(_ scheme: ColorScheme) -> ThemePalette {
            var palette = ThemeColors.palette(of: theme, for: scheme) ?? .systemBase(for: scheme)
            if let accent = ThemeAccentOverrides.color(for: theme) { palette.accent = accent }
            if palette.foreground == nil { palette.foreground = scheme == .dark ? ThemeRGB(0xF2F2F2) : ThemeRGB(0x1C1C1E) }
            return palette
        }
        let light = effectivePalette(.light)
        let dark = effectivePalette(.dark)
        let copy = BlissTheme(
            id: "custom-" + UUID().uuidString.prefix(8).lowercased(),
            name: uniqueName(String(localized: "\(theme.name) Copy", bundle: .module)),
            light: light,
            dark: dark,
            swatch: theme.swatch.isEmpty ? [dark.windowBackground, dark.accent, light.windowBackground, light.accent] : theme.swatch,
            minimumStatusContrast: theme.minimumStatusContrast
        )
        addCustom(copy)
        return copy
    }

    /// Reads a theme file (see `CustomThemes.swift` for the format), saves it
    /// and adds it to `all`. An id another theme already uses gets a new one,
    /// unless it's the user's own theme, which the file replaces.
    @MainActor @discardableResult
    public static func importTheme(from url: URL) throws -> BlissTheme {
        let data = try Data(contentsOf: url)
        var theme = try JSONDecoder().decode(BlissTheme.self, from: data)
        let existing = BlissThemeRegistry.theme(withID: theme.id)
        if let existing, !existing.isCustom {
            theme = BlissTheme(
                id: "custom-" + UUID().uuidString.prefix(8).lowercased(),
                name: uniqueName(theme.name),
                light: theme.lightPalette, dark: theme.darkPalette,
                swatch: theme.swatch, minimumStatusContrast: theme.minimumStatusContrast
            )
        }
        addCustom(theme)
        return theme
    }

    /// Removes one of the user's themes. A mode that used it goes back to the
    /// app's default theme.
    @MainActor public static func deleteCustom(_ theme: BlissTheme) {
        CustomThemeStore.save(CustomThemeStore.load().filter { $0.id != theme.id })
        BlissThemeRegistry.unregister(theme.id)
        let defaults = UserDefaults.standard
        for key in [BlissAppearance.Keys.theme, BlissAppearance.Keys.themeLight, BlissAppearance.Keys.themeDark]
        where defaults.string(forKey: key) == theme.id {
            defaults.removeObject(forKey: key)
        }
    }

    @MainActor private static func addCustom(_ theme: BlissTheme) {
        var themes = CustomThemeStore.load().filter { $0.id != theme.id }
        themes.append(theme)
        CustomThemeStore.save(themes)
        register(theme)
    }

    /// `name`, or `name 2`, `name 3`… if a theme already has it.
    @MainActor private static func uniqueName(_ name: String) -> String {
        let taken = Set(all.map(\.name))
        guard taken.contains(name) else { return name }
        var number = 2
        while taken.contains("\(name) \(number)") { number += 1 }
        return "\(name) \(number)"
    }
}
