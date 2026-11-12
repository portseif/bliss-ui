//
//  LinkCursor.swift
//  BlissUI
//
//  The pointing-hand cursor for clickable URLs (`example.com/docs`,
//  `https://…`). Buttons keep the arrow, like the rest of macOS, unless
//  `BlissAppearance.usesPointerCursors` is on.
//

import SwiftUI

extension View {
    /// Show the pointing-hand cursor while hovering this clickable URL.
    public func linkCursor() -> some View {
        modifier(LinkCursorModifier())
    }
}

extension View {
    /// The pointing-hand cursor over an enabled control, while
    /// `BlissAppearance.usesPointerCursors` is on. Every BlissUI button style,
    /// switch and menu row applies it.
    func interactiveCursor() -> some View {
        modifier(InteractiveCursorModifier())
    }
}

private struct InteractiveCursorModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        // Read on access; `.blissTheme()` re-renders when the setting changes.
        content.pointerStyle(isEnabled && BlissAppearance.usesPointerCursors ? .link : nil)
    }
}

private struct LinkCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.pointerStyle(.link)
    }
}

#Preview(traits: .fixedLayout(width: 240, height: 60)) {
    Button {} label: {
        Text(verbatim: "example.com/docs")
            .font(Typography.codeSmall)
            .foregroundStyle(Color.accent)
    }
    .buttonStyle(.plain)
    .linkCursor()
    .padding()
}
