//
//  RevealToggleIcon.swift
//  BlissUI
//
//  The eye glyph on every reveal / hide toggle (secrets, passwords, API keys,
//  license keys), so they all animate the same way.
//

import SwiftUI

/// `eye` ↔ `eye.slash` with the symbol replace transition, so the slash draws
/// through the eye instead of the glyph snapping. It only plays when the
/// toggle's state changes inside `withAnimation` — use `Animations.selection`.
public struct RevealToggleIcon: View {
    let isRevealed: Bool

    public init(isRevealed: Bool) {
        self.isRevealed = isRevealed
    }

    public var body: some View {
        Image(systemName: isRevealed ? "eye.slash" : "eye")
            .contentTransition(.symbolEffect(.replace))
    }
}

#Preview(traits: .fixedLayout(width: 200, height: 80)) {
    @Previewable @State var isRevealed = false
    Button {
        withAnimation(Animations.selection) { isRevealed.toggle() }
    } label: {
        HStack(spacing: Spacing.xs) {
            RevealToggleIcon(isRevealed: isRevealed)
            Text(isRevealed ? "Hide" : "Reveal")
        }
    }
    .buttonStyle(SecondaryButtonStyle(compact: true))
    .padding(Spacing.xl)
}
