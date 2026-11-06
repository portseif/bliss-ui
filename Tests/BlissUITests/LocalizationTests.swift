import Foundation
import Testing
@testable import BlissUI

/// The library's own strings resolve in `Bundle.module`, so they come translated
/// whatever the app's catalog holds.
@Suite struct LocalizationTests {
    /// The languages `Resources/Localizable.xcstrings` translates into.
    nonisolated static let translatedLanguages = ["de", "es", "fr", "it", "ja", "ko", "pt-BR", "ru", "zh-Hans"]

    @Test func catalogShipsInTheModuleBundle() {
        let localizations = Set(Bundle.module.localizations)
        for language in Self.translatedLanguages {
            #expect(localizations.contains(language), "\(language).lproj is missing from Bundle.module")
        }
    }

    /// A `LocalizedStringResource` picks its language from `locale`;
    /// `String(localized:bundle:locale:)` only formats with it, so it can't
    /// check a translation.
    @Test(arguments: translatedLanguages)
    func translatesCancel(language: String) {
        let resource = LocalizedStringResource("Cancel", locale: Locale(identifier: language), bundle: .module)
        #expect(String(localized: resource) != "Cancel")
    }

    @Test func resolvesPluralVariations() {
        let resource = LocalizedStringResource("\(3) selected", locale: Locale(identifier: "de"), bundle: .module)
        #expect(String(localized: resource) == "3 ausgewählt")
    }

    @Test(arguments: translatedLanguages)
    func translatesSpaceKeyName(language: String) {
        let resource = LocalizedStringResource("Space", locale: Locale(identifier: language), bundle: .module)
        #expect(String(localized: resource) != "Space")
    }

    /// Russian has four plural categories; 5 takes "many".
    @Test func resolvesRussianPluralCategories() {
        let resource = LocalizedStringResource("Last \(5) days", locale: Locale(identifier: "ru"), bundle: .module)
        #expect(String(localized: resource) == "Последние 5 дней")
    }

    /// Two plurals in one string: each argument picks its own category.
    @Test func resolvesPluralPerArgument() {
        let english = LocalizedStringResource("\(1) additions, \(3) deletions", locale: Locale(identifier: "en"), bundle: .module)
        #expect(String(localized: english) == "1 addition, 3 deletions")
        let german = LocalizedStringResource("\(2) additions, \(1) deletions", locale: Locale(identifier: "de"), bundle: .module)
        #expect(String(localized: german) == "2 Einfügungen, 1 Löschung")
    }
}
