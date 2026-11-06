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
}
