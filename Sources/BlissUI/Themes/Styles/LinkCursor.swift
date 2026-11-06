//
//  LinkCursor.swift
//  BlissUI
//
//  The pointing-hand cursor for clickable URLs (`example.com/docs`,
//  `https://…`). Links only — buttons keep the arrow, like the rest of macOS.
//

import SwiftUI

extension View {
    /// Show the pointing-hand cursor while hovering this clickable URL.
    public func linkCursor() -> some View {
        modifier(LinkCursorModifier())
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
