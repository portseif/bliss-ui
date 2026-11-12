//
//  LocalizedStringKey+Verbatim.swift
//  BlissUI
//
//  Shared components take `LocalizedStringKey`, so a literal passed to them is
//  translated like `Text("…")`. Dynamic text (a project name, an error, a string
//  already localized with `String(localized:)`) goes through `.verbatim(_:)`.
//

import SwiftUI

extension LocalizedStringKey {
    /// Shows `text` as-is. An interpolated key: the text is never looked up in the
    /// catalog, and never parsed as Markdown (a `LocalizedStringKey(String)` would
    /// style a project name containing `_` or `*`).
    /// `nonisolated` because it touches no actor state and gets passed as a function
    /// value (`subtitle.map(LocalizedStringKey.verbatim)`) into nonisolated closures.
    public nonisolated static func verbatim(_ text: String) -> LocalizedStringKey {
        "\(text)"
    }

    /// Like `verbatim(_:)`, except a `backticked` span shows as inline code:
    /// monospaced on a faint tint, backticks dropped. Nothing else is parsed, so
    /// a name with `_` or `*` in it still shows as-is. An unpaired backtick
    /// stays a backtick.
    public nonisolated static func verbatimWithCode(_ text: String) -> LocalizedStringKey {
        "\(AttributedString.inlineCodeSpans(in: text))"
    }
}

extension AttributedString {
    /// `text` with each `backticked` span marked as code, the rest plain.
    nonisolated static func inlineCodeSpans(in text: String) -> AttributedString {
        var result = AttributedString()
        var remainder = Substring(text)
        while let open = remainder.firstIndex(of: "`"),
              let close = remainder[remainder.index(after: open)...].firstIndex(of: "`") {
            result += AttributedString(remainder[..<open])
            var code = AttributedString(remainder[remainder.index(after: open)..<close])
            code.inlinePresentationIntent = .code
            code.backgroundColor = Color.primary.opacity(0.08)
            result += code
            remainder = remainder[remainder.index(after: close)...]
        }
        result += AttributedString(remainder)
        return result
    }
}
