//
//  FontSettings.swift
//  BlissUI
//
//  The fonts `Typography` draws with: a family and base face for the UI, for
//  content (text the app shows rather than labels it), and for code, plus base
//  sizes for UI and code text. Stored as one value under
//  `BlissAppearance.Keys.typography`, so `.blissTheme()` re-renders on any change.
//

import AppKit
import SwiftUI

/// Which text a font applies to.
public nonisolated enum FontRole: String, CaseIterable, Sendable, Codable {
    /// Labels, controls, headings: the `label*`, `caption*`, `body*`,
    /// `heading*` and `display*` styles.
    case ui
    /// Text the app shows rather than labels it (descriptions, documents):
    /// the `content*` styles.
    case content
    /// The `code*` styles.
    case code
}

/// A font family and its base face.
public nonisolated struct FontChoice: Codable, Hashable, Sendable {
    /// The family name (`NSFontManager.availableFontFamilies`); nil is the
    /// system font (SF Pro, or SF Mono for code).
    public var family: String?
    /// The face regular text uses, on `NSFontManager`'s 0–15 weight scale
    /// (5 is regular). Heavier styles step up from it.
    public var weight: Int

    public init(family: String? = nil, weight: Int = FontChoice.regularWeight) {
        self.family = family
        self.weight = weight
    }

    /// `NSFontManager`'s weight for a regular face.
    public static let regularWeight = 5
    public static let system = FontChoice()
}

/// Every font choice, as stored. Missing fields decode to their defaults, so
/// adding one never discards the rest.
nonisolated struct FontSettings: Codable, Equatable, Sendable {
    var ui = FontChoice.system
    /// The UI font per mode while light and dark are separate; nil follows `ui`.
    var uiLight: FontChoice?
    var uiDark: FontChoice?
    var content = FontChoice.system
    var code = FontChoice.system
    var uiSize = BlissAppearance.defaultUIFontSize
    var codeSize = BlissAppearance.defaultCodeFontSize

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ui = try container.decodeIfPresent(FontChoice.self, forKey: .ui) ?? .system
        uiLight = try container.decodeIfPresent(FontChoice.self, forKey: .uiLight)
        uiDark = try container.decodeIfPresent(FontChoice.self, forKey: .uiDark)
        content = try container.decodeIfPresent(FontChoice.self, forKey: .content) ?? .system
        code = try container.decodeIfPresent(FontChoice.self, forKey: .code) ?? .system
        uiSize = try container.decodeIfPresent(Int.self, forKey: .uiSize) ?? BlissAppearance.defaultUIFontSize
        codeSize = try container.decodeIfPresent(Int.self, forKey: .codeSize) ?? BlissAppearance.defaultCodeFontSize
    }

    /// The stored settings, parsed once per change.
    @MainActor static var current: FontSettings {
        let raw = UserDefaults.standard.string(forKey: BlissAppearance.Keys.typography) ?? ""
        if raw == cache.raw { return cache.settings }
        let settings = raw.isEmpty ? FontSettings() : ((try? JSONDecoder().decode(FontSettings.self, from: Data(raw.utf8))) ?? FontSettings())
        cache = (raw, settings)
        return settings
    }

    @MainActor private static var cache: (raw: String, settings: FontSettings) = ("", FontSettings())

    static func store(_ settings: FontSettings) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(settings) else { return }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: BlissAppearance.Keys.typography)
    }

    func choice(_ role: FontRole, for scheme: ColorScheme, separateModes: Bool) -> FontChoice {
        switch role {
        case .ui:
            guard separateModes else { return ui }
            return (scheme == .dark ? uiDark : uiLight) ?? ui
        case .content: return content
        case .code: return code
        }
    }
}

extension BlissAppearance {
    /// The default UI font size: `Typography.labelMedium` and `.bodySmall`.
    public nonisolated static let defaultUIFontSize = 13
    /// The default code font size: `Typography.codeSmall`.
    public nonisolated static let defaultCodeFontSize = 12
    public nonisolated static let uiFontSizeRange = 11...18
    public nonisolated static let codeFontSizeRange = 10...18

    /// The base size UI and content text scale from (13 is BlissUI's own).
    public static var uiFontSize: Int {
        get { FontSettings.current.uiSize }
        set { updateFonts { $0.uiSize = min(max(newValue, uiFontSizeRange.lowerBound), uiFontSizeRange.upperBound) } }
    }

    /// The base size code text scales from (12 is BlissUI's own).
    public static var codeFontSize: Int {
        get { FontSettings.current.codeSize }
        set { updateFonts { $0.codeSize = min(max(newValue, codeFontSizeRange.lowerBound), codeFontSizeRange.upperBound) } }
    }

    /// The font for `role`. The UI font is kept per mode while
    /// `separateModes` is on.
    public static func font(_ role: FontRole, for scheme: ColorScheme) -> FontChoice {
        FontSettings.current.choice(role, for: scheme, separateModes: separateModes)
    }

    /// Sets the font for `role` (for `scheme`'s mode alone, for the UI font
    /// while `separateModes` is on).
    public static func setFont(_ choice: FontChoice, _ role: FontRole, for scheme: ColorScheme) {
        updateFonts { settings in
            switch role {
            case .ui where separateModes:
                if scheme == .dark { settings.uiDark = choice } else { settings.uiLight = choice }
            case .ui: settings.ui = choice
            case .content: settings.content = choice
            case .code: settings.code = choice
            }
        }
    }

    private static func updateFonts(_ change: (inout FontSettings) -> Void) {
        var settings = FontSettings.current
        change(&settings)
        FontSettings.store(settings)
    }
}

// MARK: - Drawing

/// Builds the fonts `Typography` hands out from the stored choices.
enum FontResolver {
    /// A font for a `Typography` style: `size` and `weight` are the style's own
    /// at BlissUI's default sizes; the stored base size scales it and the
    /// stored family and face draw it.
    static func font(_ role: FontRole, size: CGFloat, weight: Font.Weight) -> Font {
        let settings = FontSettings.current
        let scaledSize = role == .code
            ? size * CGFloat(settings.codeSize) / CGFloat(BlissAppearance.defaultCodeFontSize)
            : size * CGFloat(settings.uiSize) / CGFloat(BlissAppearance.defaultUIFontSize)
        let needsScheme = role == .ui && (settings.uiLight != nil || settings.uiDark != nil)
        let choice = settings.choice(
            role,
            for: needsScheme ? ThemeColors.resolvedScheme : .light,
            separateModes: needsScheme && BlissAppearance.separateModes
        )
        if let family = choice.family,
           let nsFont = nsFont(family: family, weight: managerWeight(weight) + choice.weight - FontChoice.regularWeight, size: scaledSize) {
            return Font(nsFont as CTFont)
        }
        return .system(size: scaledSize, weight: weight, design: role == .code ? .monospaced : .default)
    }

    /// `Font.Weight` on `NSFontManager`'s 0–15 scale, where 5 is regular and
    /// 9 bold.
    static func managerWeight(_ weight: Font.Weight) -> Int {
        switch weight {
        case .ultraLight: return 2
        case .thin: return 3
        case .light: return 4
        case .medium: return 6
        case .semibold: return 8
        case .bold: return 9
        case .heavy: return 10
        case .black: return 11
        default: return FontChoice.regularWeight
        }
    }

    private static var fontCache: [String: NSFont] = [:]

    /// The family's face nearest `weight`, cached: every table cell asks.
    private static func nsFont(family: String, weight: Int, size: CGFloat) -> NSFont? {
        let clampedWeight = min(max(weight, 0), 15)
        let key = "\(family)|\(clampedWeight)|\(size)"
        if let cached = fontCache[key] { return cached }
        let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: clampedWeight, size: size)
        fontCache[key] = font
        return font
    }

    // MARK: Pickers

    /// Installed families, by name, without the hidden system ones.
    static let allFamilies: [String] = NSFontManager.shared.availableFontFamilies
        .filter { !$0.hasPrefix(".") }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

    /// Families with a fixed-pitch face, for code.
    static let monospacedFamilies: [String] = {
        let names = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []
        let families = Set(names.compactMap { NSFont(name: $0, size: 12)?.familyName }).filter { !$0.hasPrefix(".") }
        return families.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }()

    /// A family's upright faces, one per weight, lightest first, as
    /// (style name, weight).
    static func faces(of family: String) -> [(name: String, weight: Int)] {
        let slanted = NSFontTraitMask.italicFontMask.rawValue
        let reshaped = NSFontTraitMask([.condensedFontMask, .expandedFontMask, .narrowFontMask]).rawValue
        var faces: [Int: String] = [:]
        for member in NSFontManager.shared.availableMembers(ofFontFamily: family) ?? [] {
            guard member.count >= 4,
                  let styleName = member[1] as? String,
                  let weight = member[2] as? Int,
                  let traits = member[3] as? UInt,
                  traits & slanted == 0, traits & reshaped == 0,
                  faces[weight] == nil else { continue }
            faces[weight] = styleName
        }
        return faces.keys.sorted().map { (faces[$0] ?? "", $0) }
    }
}
