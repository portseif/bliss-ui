//
//  ShortcutHint.swift
//  BlissUI
//
//  `.shortcutHint("⌘N")` centers a key pill on a control while ⌘ or ⌃ is held
//  (`ShortcutHintService`). The pill floats over the control, so it takes no
//  layout space, and a disabled control shows none (a dead shortcut, or a
//  control under an open sheet).
//

import SwiftUI

extension View {
    /// Show `keys` over the middle of this control while the shortcut hints are up.
    public func shortcutHint(_ keys: String) -> some View {
        modifier(ShortcutHintModifier(keys: keys))
    }
}

private struct ShortcutHintModifier: ViewModifier {
    let keys: String

    @Environment(\.isEnabled) private var isEnabled

    private var hints: ShortcutHintService { .shared }

    func body(content: Content) -> some View {
        content
            .overlay {
                if hints.isShowingHints && isEnabled {
                    ShortcutKey(keys, floating: true, compact: true)
                        .fixedSize()
                        .transition(.motion(.scale(scale: 0.9).combined(with: .opacity)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { hints.startIfNeeded() }
    }
}

#Preview(traits: .fixedLayout(width: 320, height: 120)) {
    HStack(spacing: Spacing.sm) {
        Button("Import") {}
            .buttonStyle(SecondaryButtonStyle(compact: true))
            .shortcutHint("⌘O")
        Button("New Document") {}
            .buttonStyle(PrimaryButtonStyle(compact: true))
            .shortcutHint("⌘N")
    }
    .padding()
}
