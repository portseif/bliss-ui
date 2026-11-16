//
//  KeyHintPill.swift
//  BlissUI
//
//  An outlined key cap for keyboard hints in running text — a sheet footer's
//  "esc to cancel · ↩ to save". The same pill as `ShortcutKey(_:outlined:
//  true)`, kept under its own name for callers that already use it.
//

import SwiftUI

/// An outlined key cap for inline keyboard hints ("esc", "⌘↩") — `ShortcutKey`
/// with `outlined: true`.
///
/// ```swift
/// HStack(spacing: Spacing.xs) {
///     KeyHintPill("esc")
///     Text("to cancel").font(Typography.captionTiny).foregroundStyle(.tertiary)
/// }
/// ```
public struct KeyHintPill: View {
    private let keys: String

    /// - Parameter keys: The key or chord, shown as-is ("esc", "↩", "⌘↩").
    public init(_ keys: String) {
        self.keys = keys
    }

    public var body: some View {
        ShortcutKey(keys, outlined: true)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 280, height: 70)) {
    HStack(spacing: Spacing.xs) {
        KeyHintPill("esc")
        Text(verbatim: "to cancel").font(Typography.captionTiny).foregroundStyle(.tertiary)
        Text(verbatim: "·").font(Typography.captionTiny).foregroundStyle(.quaternary)
        KeyHintPill("⌘↩")
        Text(verbatim: "to restore").font(Typography.captionTiny).foregroundStyle(.tertiary)
    }
    .padding(Spacing.xl)
}
