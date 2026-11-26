//
//  BlissIcons.swift
//  BlissUI
//
//  BlissUI draws its glyphs as SF Symbols. An app with its own icon set sets
//  `BlissIcons.replacement` once at launch, and every glyph a component draws
//  (a picker's chevron, a menu row's checkmark, a sheet's ✕, the symbols an
//  app passes as `systemImage:`) asks it first.
//
//  A replacement draws in the frame the SF Symbol would have taken: the symbol
//  is still laid out, hidden, at the font and image scale it was given, so
//  rows, buttons and baselines line up the same with either set.
//

import AppKit
import SwiftUI

/// The hook for drawing BlissUI's glyphs with another icon set.
public enum BlissIcons {
    /// Returns the view to draw in place of an SF Symbol, by the symbol's name, or nil to keep the symbol.
    ///
    /// The view is proposed the symbol's frame and should fill it; it takes the surrounding
    /// `foregroundStyle`. A name that isn't an SF Symbol (an app's own icon, passed as `systemImage:`)
    /// is proposed the frame of `square`. Set it once at launch, before the first window opens:
    ///
    /// ```swift
    /// BlissIcons.replacement = { symbolName in
    ///     guard let iconName = myIcons[symbolName] else { return nil }
    ///     return AnyView(MyIcon(iconName))
    /// }
    /// ```
    public static var replacement: (@MainActor (_ symbolName: String) -> AnyView?)?
}

/// An SF Symbol by name, or the app's replacement for it (`BlissIcons.replacement`). Every glyph BlissUI
/// draws goes through this instead of `Image(systemName:)`.
struct BlissSymbol: View {
    let name: String

    init(_ name: String) {
        self.name = name
    }

    var body: some View {
        if let replacement = BlissIcons.replacement?(name) {
            Image(systemName: Self.layoutSymbolName(for: name))
                .hidden()
                .overlay { replacement }
                // VoiceOver hears the symbol's own description, as it would without a replacement.
                .accessibilityRepresentation { Image(systemName: name) }
        } else {
            Image(systemName: name)
        }
    }

    /// An app can pass its own icon's name as `systemImage:`. That isn't an SF Symbol, which would lay out
    /// as nothing, so the replacement takes the frame of `square` instead, about the size of a typical glyph.
    private static func layoutSymbolName(for name: String) -> String {
        if let isSymbol = isSystemSymbol[name] {
            return isSymbol ? name : "square"
        }
        let isSymbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        isSystemSymbol[name] = isSymbol
        return isSymbol ? name : "square"
    }

    /// Whether each name asked about so far is an SF Symbol.
    private static var isSystemSymbol: [String: Bool] = [:]
}

#Preview(traits: .fixedLayout(width: 240, height: 60)) {
    HStack(spacing: Spacing.md) {
        BlissSymbol("checkmark")
        BlissSymbol("chevron.down")
        BlissSymbol("xmark.circle.fill")
            .foregroundStyle(.secondary)
    }
    .font(Typography.bodySmall)
    .padding()
}
