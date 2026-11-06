//
//  Bundle+BlissUI.swift
//  BlissUI
//
//  The library's own strings ("Cancel", "Copied", "Select all") live in
//  `Resources/Localizable.xcstrings` and are looked up in `Bundle.module`, so
//  they're translated whatever the app's catalog holds:
//  `Text("Copy", bundle: .module)`, `String(localized: "Copy", bundle: .module)`.
//  Strings a caller passes in (a `Badge` title, a column name) stay in the
//  app's bundle — never route those here.
//

import Foundation

extension Bundle {
    /// `Bundle.module` under a name a public default argument may reference:
    /// default arguments are compiled into the caller, and `.module` is
    /// internal. Everywhere else, use `.module`.
    @usableFromInline nonisolated static var blissUI: Bundle { .module }
}
