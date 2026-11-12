import AppKit
import Foundation
import SwiftUI
import Testing
@testable import BlissUI

/// The appearance choices `AppearanceSettings` writes.
@MainActor
@Suite(.serialized) struct AppearanceSettingsTests {
    private let defaults = UserDefaults.standard

    @Test func reduceMotionOverridesTheSystem() {
        defer { defaults.removeObject(forKey: BlissAppearance.Keys.reduceMotion) }
        BlissAppearance.reduceMotion = .on
        #expect(prefersReducedMotion)
        BlissAppearance.reduceMotion = .off
        #expect(!prefersReducedMotion)
        BlissAppearance.reduceMotion = .system
        #expect(prefersReducedMotion == NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    @Test func resetToDefaultsClearsEveryAppearanceChoice() {
        let keys = [
            BlissAppearance.Keys.theme, BlissAppearance.Keys.colorScheme, BlissAppearance.Keys.accentColorOverride,
            BlissAppearance.Keys.customAccentColorRed, BlissAppearance.Keys.themeAccentOverrides, BlissAppearance.Keys.reduceMotion,
        ]
        let saved = keys.map { defaults.object(forKey: $0) }
        let savedFrameSetting = defaults.object(forKey: BlissAppearance.Keys.saveWindowLocation)
        defer {
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
            defaults.set(savedFrameSetting, forKey: BlissAppearance.Keys.saveWindowLocation)
        }

        BlissAppearance.colorScheme = .dark
        BlissAppearance.accentOption = .custom
        BlissAppearance.reduceMotion = .on
        defaults.set(false, forKey: BlissAppearance.Keys.saveWindowLocation)
        BlissAppearance.resetToDefaults()

        #expect(BlissAppearance.colorScheme == .system)
        #expect(BlissAppearance.accentOption == .system)
        #expect(BlissAppearance.reduceMotion == .system)
        // Window placement isn't an appearance choice.
        #expect(defaults.object(forKey: BlissAppearance.Keys.saveWindowLocation) as? Bool == false)
    }

    // MARK: - Background, foreground and separate modes

    /// Runs `body`, then puts every theme and color choice back.
    private func preservingThemeChoices(_ body: () -> Void) {
        let keys = [
            BlissAppearance.Keys.theme, BlissAppearance.Keys.colorScheme, BlissAppearance.Keys.surfaceOverrides,
            BlissAppearance.Keys.separateModes, BlissAppearance.Keys.themeLight, BlissAppearance.Keys.themeDark,
        ]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        body()
    }

    private func resolved(_ color: Color) -> ThemeRGB {
        let rgb = NSColor(color).usingColorSpace(.sRGB)!
        return ThemeRGB(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
    }

    @Test func aNewBackgroundRebuildsTheSurfacesAroundIt() throws {
        let light = try #require(BlissTheme.lowGlare.palette(for: .light))
        let darkened = light.withBackground(ThemeRGB(0x14171C))
        #expect(darkened.windowBackground == ThemeRGB(0x14171C))
        #expect(darkened.isDark)
        // Text flips to light when the surfaces turn dark.
        let foreground = try #require(darkened.foreground)
        #expect(StatusToneMath.contrast(foreground, darkened.contentBackground) >= 7)
        #expect(darkened.border != darkened.windowBackground)

        // A light background on a light palette keeps the theme's own text.
        let tinted = light.withBackground(ThemeRGB(0xF0F4FA))
        #expect(!tinted.isDark)
        #expect(tinted.foreground == light.foreground)
    }

    @Test func surfaceColorsAreKeptPerThemeAndMode() {
        preservingThemeChoices {
            defaults.removeObject(forKey: BlissAppearance.Keys.surfaceOverrides)
            let navy = ThemeRGB(0x1A2340)
            BlissAppearance.setSurfaceColor(navy, .background, for: .lowGlare, in: .dark)
            #expect(BlissAppearance.surfaceColor(.background, for: .lowGlare, in: .dark) == navy)
            #expect(BlissAppearance.surfaceColor(.background, for: .lowGlare, in: .light) == nil)
            #expect(BlissAppearance.surfaceColor(.foreground, for: .lowGlare, in: .dark) == nil)
            #expect(BlissAppearance.surfaceColor(.background, for: .highContrast, in: .dark) == nil)

            BlissAppearance.setSurfaceColor(nil, .background, for: .lowGlare, in: .dark)
            #expect(BlissAppearance.surfaceColor(.background, for: .lowGlare, in: .dark) == nil)
        }
    }

    @Test func separateModesKeepAThemePerMode() {
        preservingThemeChoices {
            BlissAppearance.separateModes = false
            BlissAppearance.setTheme(.lowGlare, for: .dark)
            // One theme for both while the modes share it.
            #expect(BlissTheme.active(for: .light).id == BlissTheme.lowGlare.id)
            #expect(BlissTheme.active(for: .dark).id == BlissTheme.lowGlare.id)

            BlissAppearance.separateModes = true
            BlissAppearance.setTheme(.highContrast, for: .dark)
            BlissAppearance.setTheme(.colorBlindSafe, for: .light)
            #expect(BlissTheme.active(for: .dark).id == BlissTheme.highContrast.id)
            #expect(BlissTheme.active(for: .light).id == BlissTheme.colorBlindSafe.id)

            // Turning it back off returns to the shared theme.
            BlissAppearance.separateModes = false
            #expect(BlissTheme.active(for: .dark).id == BlissTheme.lowGlare.id)
        }
    }

    @Test func mutedTextHoldsAAOnCustomColors() {
        preservingThemeChoices {
            BlissAppearance.colorScheme = .light
            defaults.set(BlissTheme.lowGlare.id, forKey: BlissAppearance.Keys.theme)
            BlissAppearance.setSurfaceColor(ThemeRGB(0x2A2A2E), .background, for: .lowGlare, in: .light)
            BlissAppearance.setSurfaceColor(ThemeRGB(0xE4E0D6), .foreground, for: .lowGlare, in: .light)

            guard let palette = ThemeColors.palette(for: .light) else { Issue.record("no palette"); return }
            #expect(palette.foreground == ThemeRGB(0xE4E0D6))
            for surface in [palette.contentBackground, palette.windowBackground] {
                #expect(StatusToneMath.contrast(resolved(Color.textPrimary), surface) >= 7)
                #expect(StatusToneMath.contrast(resolved(Color.textSecondary), surface) >= 4.5)
                #expect(StatusToneMath.contrast(resolved(Color.textTertiary), surface) >= 4.5)
            }
        }
    }

    // MARK: - Fonts

    private func preservingFontChoices(_ body: () -> Void) {
        let keys = [BlissAppearance.Keys.typography, BlissAppearance.Keys.separateModes]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        defaults.removeObject(forKey: BlissAppearance.Keys.typography)
        body()
    }

    @Test func fontSizesClampToTheirRanges() {
        preservingFontChoices {
            #expect(BlissAppearance.uiFontSize == BlissAppearance.defaultUIFontSize)
            BlissAppearance.uiFontSize = 40
            #expect(BlissAppearance.uiFontSize == BlissAppearance.uiFontSizeRange.upperBound)
            BlissAppearance.codeFontSize = 2
            #expect(BlissAppearance.codeFontSize == BlissAppearance.codeFontSizeRange.lowerBound)
            // Setting one keeps the other.
            #expect(BlissAppearance.uiFontSize == BlissAppearance.uiFontSizeRange.upperBound)
        }
    }

    @Test func theUIFontIsKeptPerModeOnlyWhileModesAreSeparate() {
        preservingFontChoices {
            BlissAppearance.separateModes = false
            BlissAppearance.setFont(FontChoice(family: "Helvetica Neue"), .ui, for: .dark)
            #expect(BlissAppearance.font(.ui, for: .light).family == "Helvetica Neue")

            BlissAppearance.separateModes = true
            BlissAppearance.setFont(FontChoice(family: "Avenir Next"), .ui, for: .dark)
            #expect(BlissAppearance.font(.ui, for: .dark).family == "Avenir Next")
            // Light hasn't been set on its own, so it keeps the shared font.
            #expect(BlissAppearance.font(.ui, for: .light).family == "Helvetica Neue")

            BlissAppearance.setFont(FontChoice(family: "Menlo"), .code, for: .light)
            #expect(BlissAppearance.font(.code, for: .dark).family == "Menlo")
        }
    }

    @Test func stylesScaleFromTheBaseSizes() {
        preservingFontChoices {
            BlissAppearance.uiFontSize = 16
            BlissAppearance.codeFontSize = 15
            let label = FontResolver.font(.ui, size: 13, weight: .regular)
            #expect(label == .system(size: 16, weight: .regular, design: .default))
            let code = FontResolver.font(.code, size: 12, weight: .regular)
            #expect(code == .system(size: 15, weight: .regular, design: .monospaced))
        }
    }

    @Test func aFamilysFacesAreUprightAndOnePerWeight() {
        let faces = FontResolver.faces(of: "Helvetica")
        #expect(faces.map(\.weight) == faces.map(\.weight).sorted())
        #expect(Set(faces.map(\.weight)).count == faces.count)
        #expect(faces.contains { $0.weight == FontChoice.regularWeight })
        #expect(!faces.contains { $0.name.localizedCaseInsensitiveContains("oblique") || $0.name.localizedCaseInsensitiveContains("italic") })
        #expect(FontResolver.monospacedFamilies.contains("Menlo"))
    }

    @Test func resetToDefaultsClearsFonts() {
        preservingFontChoices {
            BlissAppearance.uiFontSize = 17
            BlissAppearance.setFont(FontChoice(family: "Menlo"), .code, for: .light)
            BlissAppearance.resetToDefaults()
            #expect(BlissAppearance.uiFontSize == BlissAppearance.defaultUIFontSize)
            #expect(BlissAppearance.font(.code, for: .light) == .system)
        }
    }

    // MARK: - Contrast, custom themes

    @Test func mutedTextHoldsAAAtEveryContrast() {
        preservingThemeChoices {
            let savedContrast = defaults.object(forKey: BlissAppearance.Keys.contrast)
            defer { defaults.set(savedContrast, forKey: BlissAppearance.Keys.contrast) }
            BlissAppearance.colorScheme = .light
            defaults.set(BlissTheme.lowGlare.id, forKey: BlissAppearance.Keys.theme)
            guard let palette = ThemeColors.palette(for: .light) else { Issue.record("no palette"); return }
            var secondaryContrasts: [Double] = []
            for contrast in [0, 50, 100] {
                BlissAppearance.contrast = contrast
                let secondary = StatusToneMath.contrast(resolved(Color.textSecondary), palette.contentBackground)
                #expect(secondary >= 4.5, "contrast \(contrast)")
                #expect(StatusToneMath.contrast(resolved(Color.textTertiary), palette.contentBackground) >= 4.5)
                secondaryContrasts.append(secondary)
            }
            // More contrast moves muted text toward the text color.
            #expect(secondaryContrasts[2] > secondaryContrasts[1])
            BlissAppearance.contrast = 400
            #expect(BlissAppearance.contrast == 100)
        }
    }

    @Test func themesRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(BlissTheme.lowGlare)
        let decoded = try JSONDecoder().decode(BlissTheme.self, from: data)
        #expect(decoded.id == BlissTheme.lowGlare.id)
        #expect(decoded.lightPalette == BlissTheme.lowGlare.lightPalette)
        #expect(decoded.darkPalette == BlissTheme.lowGlare.darkPalette)
        #expect(decoded.swatch == BlissTheme.lowGlare.swatch)
        // Colors are written as hex.
        #expect(String(decoding: data, as: UTF8.self).contains("\"#"))
    }

    @Test func aDuplicateKeepsTheColorsAsTheyLookAndCanBeDeleted() {
        let keys = [BlissAppearance.Keys.customThemes, BlissAppearance.Keys.surfaceOverrides, BlissAppearance.Keys.theme]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        BlissAppearance.setSurfaceColor(ThemeRGB(0x203040), .background, for: .lowGlare, in: .dark)
        let copy = BlissTheme.duplicate(.lowGlare)
        #expect(copy.isCustom)
        #expect(copy.id != BlissTheme.lowGlare.id)
        #expect(copy.darkPalette?.windowBackground == ThemeRGB(0x203040))
        #expect(BlissTheme.all.contains { $0.id == copy.id })

        defaults.set(copy.id, forKey: BlissAppearance.Keys.theme)
        BlissTheme.deleteCustom(copy)
        #expect(!BlissTheme.all.contains { $0.id == copy.id })
        #expect(defaults.string(forKey: BlissAppearance.Keys.theme) == nil)
    }

    @Test func importingRenamesAnIDABuiltInUsesAndRejectsBadFiles() throws {
        let saved = defaults.object(forKey: BlissAppearance.Keys.customThemes)
        defer { defaults.set(saved, forKey: BlissAppearance.Keys.customThemes) }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let file = folder.appendingPathComponent("theme.json")
        try JSONEncoder().encode(BlissTheme.highContrast).write(to: file)
        let imported = try BlissTheme.importTheme(from: file)
        #expect(imported.id != BlissTheme.highContrast.id)
        #expect(imported.isCustom)
        BlissTheme.deleteCustom(imported)

        let bad = folder.appendingPathComponent("bad.json")
        try Data(#"{"id":"x","name":"X","light":{"windowBackground":"blue"}}"#.utf8).write(to: bad)
        #expect(throws: (any Error).self) { try BlissTheme.importTheme(from: bad) }
    }

    @Test func resetKeepsTheUsersThemesAndClearsTheNewChoices() {
        let keys = [BlissAppearance.Keys.customThemes, BlissAppearance.Keys.contrast, BlissAppearance.Keys.pointerCursors, BlissAppearance.Keys.translucentSidebar]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) } }
        defaults.set("[]", forKey: BlissAppearance.Keys.customThemes)
        BlissAppearance.contrast = 80
        BlissAppearance.usesPointerCursors = true
        BlissAppearance.translucentSidebar = true
        BlissAppearance.resetToDefaults()
        #expect(BlissAppearance.contrast == BlissAppearance.defaultContrast)
        #expect(!BlissAppearance.usesPointerCursors)
        #expect(!BlissAppearance.translucentSidebar)
        #expect(defaults.string(forKey: BlissAppearance.Keys.customThemes) == "[]")
    }
}
