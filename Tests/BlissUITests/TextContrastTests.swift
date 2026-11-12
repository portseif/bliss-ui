import AppKit
import SwiftUI
import Testing
@testable import BlissUI

/// The text tokens and on-accent text hold WCAG AA (4.5:1) where they're used.
@MainActor
@Suite struct TextContrastTests {
    private func resolved(_ color: Color, dark: Bool) -> ThemeRGB {
        var rgb = ThemeRGB(0x000000)
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            let c = NSColor(color).usingColorSpace(.sRGB)!
            rgb = ThemeRGB(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent)
        }
        return rgb
    }

    /// The lightest and darkest surfaces text sits on across the built-in themes,
    /// accent-tinted selections included.
    private let lightSurfaces: [UInt32] = [0xFFFFFF, 0xF4F4F4, 0xF5EFE2, 0xECE5D5, 0xE6E6E6]
    private let darkSurfaces: [UInt32] = [0x1E1E1E, 0x262629, 0x21201D, 0x0A0A0A, 0x323236]

    @Test func secondaryTextIsAAOnEverySurface() {
        for surface in lightSurfaces {
            #expect(StatusToneMath.contrast(resolved(Color.textSecondary, dark: false), ThemeRGB(surface)) >= 4.5, "light on \(String(surface, radix: 16))")
        }
        for surface in darkSurfaces {
            #expect(StatusToneMath.contrast(resolved(Color.textSecondary, dark: true), ThemeRGB(surface)) >= 4.5, "dark on \(String(surface, radix: 16))")
        }
    }

    @Test func tertiaryTextIsAAOnContentSurfaces() {
        #expect(StatusToneMath.contrast(resolved(Color.textTertiary, dark: false), ThemeRGB(0xFFFFFF)) >= 4.5)
        #expect(StatusToneMath.contrast(resolved(Color.textTertiary, dark: true), ThemeRGB(0x1E1E1E)) >= 4.5)
    }

    @Test func primaryTextFollowsTheAppearance() {
        #expect(StatusToneMath.contrast(resolved(Color.textPrimary, dark: false), ThemeRGB(0xFFFFFF)) >= 7)
        #expect(StatusToneMath.contrast(resolved(Color.textPrimary, dark: true), ThemeRGB(0x1E1E1E)) >= 7)
    }

    @Test func onAccentTextPicksTheReadableSide() {
        #expect(AccentHue.needsDarkText(on: ThemeRGB(0xA78BFA)))   // lavender: white was 2.7:1
        #expect(AccentHue.needsDarkText(on: ThemeRGB(0xFFCC00)))   // yellow
        #expect(!AccentHue.needsDarkText(on: ThemeRGB(0x6D28D9)))  // deep violet
        #expect(!AccentHue.needsDarkText(on: ThemeRGB(0x007AFF)))  // system blue keeps white
    }
}
