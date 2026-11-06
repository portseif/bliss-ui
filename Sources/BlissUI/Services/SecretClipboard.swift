//
//  SecretClipboard.swift
//  BlissUI
//
//  Copying a secret: the pasteboard item carries the nspasteboard.org
//  `ConcealedType` marker (clipboard managers obscure it and don't save it) and
//  is cleared after `clearsAfter` if nothing replaced it. Gate it behind Touch ID
//  or anything else by setting `authorize`.
//

import AppKit

public enum SecretClipboard {
    /// nspasteboard.org: "content that should be treated as confidential".
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    /// Asked before every copy with a reason ("copy a secret"); return false to
    /// refuse. Defaults to allowing every copy.
    public static var authorize: (_ reason: String) async -> Bool = { _ in true }

    /// How long a copied secret stays on the pasteboard; nil keeps it.
    public static var clearsAfter: TimeInterval? = 60

    /// Copies `value` as a secret; false when `authorize` refused (nothing copied).
    @discardableResult
    public static func copy(_ value: String, reason: String) async -> Bool {
        guard await authorize(reason) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        pasteboard.setData(Data(), forType: concealedType)
        guard let lifetime = clearsAfter else { return true }
        let changeCount = pasteboard.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
            // Only if it's still ours: a later copy, by the user or another app, stays.
            if NSPasteboard.general.changeCount == changeCount { NSPasteboard.general.clearContents() }
        }
        return true
    }
}
