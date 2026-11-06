import AppKit
import SwiftUI
import Testing
@testable import BlissUI

/// `Color.accent` reads the same `BlissAppearance.Keys` that `AppearanceSettings`
/// and `.blissTheme()` write, so a custom pick reaches every accent token.
@Suite(.serialized) struct AccentColorTests {
    /// The keys these tests write, restored afterwards so the test process's
    /// defaults are left as they were.
    static let touchedKeys = [
        BlissAppearance.Keys.theme,
        BlissAppearance.Keys.accentColorOverride,
        BlissAppearance.Keys.customAccentColorRed,
        BlissAppearance.Keys.customAccentColorGreen,
        BlissAppearance.Keys.customAccentColorBlue,
    ]

    @Test func customAccentWrittenWithAppearanceKeysChangesAccent() throws {
        let defaults = UserDefaults.standard
        let savedValues = Self.touchedKeys.map { defaults.object(forKey: $0) }
        defer {
            for (key, savedValue) in zip(Self.touchedKeys, savedValues) {
                defaults.set(savedValue, forKey: key)
            }
        }

        // The System theme leaves the accent to the user's pick.
        defaults.set(BlissTheme.system.id, forKey: BlissAppearance.Keys.theme)
        // Exactly what AppearanceSettings' @AppStorage bindings write.
        let customAccent = ThemeRGB(red: 0.8, green: 0.2, blue: 0.4)
        defaults.set(AccentColorOption.custom.rawValue, forKey: BlissAppearance.Keys.accentColorOverride)
        defaults.set(customAccent.red, forKey: BlissAppearance.Keys.customAccentColorRed)
        defaults.set(customAccent.green, forKey: BlissAppearance.Keys.customAccentColorGreen)
        defaults.set(customAccent.blue, forKey: BlissAppearance.Keys.customAccentColorBlue)

        let resolvedAccent = try #require(NSColor(Color.accent).usingColorSpace(.sRGB))
        let tolerance = 0.005
        #expect(abs(resolvedAccent.redComponent - customAccent.red) < tolerance)
        #expect(abs(resolvedAccent.greenComponent - customAccent.green) < tolerance)
        #expect(abs(resolvedAccent.blueComponent - customAccent.blue) < tolerance)
        #expect(AccentHue.effectiveAccentNSColor == customAccent.nsColor)
    }
}
