//
//  InfoButton.swift
//  BlissUI
//
//  The little info glyph. Click it and one of the app's own floating menu panels
//  opens above it; click again (or anywhere else) and it closes.
//
//  `InfoButton` holds a line of text — the kind a settings screen uses
//  throughout. `InfoHint` takes arbitrary content, for a hint that's a small
//  table rather than a sentence (a usage breakdown). Both are the same glyph and
//  the same panel, so the affordance is one thing wherever it appears. It used to
//  be a native popover, whose arrow and system chrome read as foreign next to the
//  custom menus.
//

import SwiftUI

// MARK: - Glyph

private struct InfoGlyph: View {
    var body: some View {
        Image(systemName: "info.circle")
            .font(Typography.captionTiny)
            .foregroundStyle(.secondary)
            .frame(minWidth: 16, minHeight: 16)
            .contentShape(Rectangle())
    }
}

// MARK: - Text hint

public struct InfoButton: View {
    let text: LocalizedStringKey
    var maxWidth: CGFloat = 250

    public init(text: LocalizedStringKey, maxWidth: CGFloat = 250) {
        self.text = text
        self.maxWidth = maxWidth
    }

    public var body: some View {
        InfoHint {
            Text(text)
                .font(Typography.labelSmall)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                // A fixed width with free height, so the panel — sized once, when
                // it opens — measures the wrapped text rather than one long line.
                .frame(width: maxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                // On top of the panel's own inset: a paragraph needs more room
                // from the card's rounded edge than a table of short rows does.
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
        }
    }
}

// MARK: - Toggled hint

public struct InfoHint<Content: View>: View {
    var xPosition: FloatingMenuXPosition = .leading
    var yPosition: FloatingMenuYPosition = .above
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    public init(
        xPosition: FloatingMenuXPosition = .leading,
        yPosition: FloatingMenuYPosition = .above,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.content = content
    }

    public var body: some View {
        Button {
            // Toggle, never set true: the menu's dismiss monitor tears down on an
            // anchor click and expects the button to flip the state — setting it
            // true respawns the panel it just closed.
            isPresented.toggle()
        } label: {
            InfoGlyph()
        }
        .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
        .accessibilityLabel(Text("More info", bundle: .module))
        .floatingMenu(isPresented: $isPresented, xPosition: xPosition, yPosition: yPosition) {
            // The panel supplies the surface, border and shadow; content brings
            // its own padding, like every other menu.
            content()
                .padding(Spacing.menuPadding)
        }
    }
}

// MARK: - Previews

#Preview("Info Button", traits: .fixedLayout(width: 300, height: 150)) {
    VStack(spacing: 20) {
        HStack(spacing: 6) {
            Text("Event Categories")
            InfoButton(text: "Choose which types of events to record. Disabling categories you don't need can reduce noise.")
        }

        HStack(spacing: 6) {
            Text("Preferred Tools")
            InfoButton(text: "Choose your preferred applications for opening files.")
        }
    }
    .padding(40)
}

#Preview("Info Hint", traits: .fixedLayout(width: 320, height: 120)) {
    // Click the glyph to see it — the panel is a detached window, so it can't
    // render in a static preview.
    HStack(spacing: Spacing.xs) {
        Text(verbatim: "2.4 GB used · 3 devices")
            .font(Typography.labelSmall)
            .foregroundStyle(.secondary)
        InfoHint {
            Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: Spacing.xs) {
                GridRow { Text(verbatim: "Photos"); Text(verbatim: "1.2 GB") }
                GridRow { Text(verbatim: "Documents"); Text(verbatim: "860 MB") }
                GridRow { Text(verbatim: "Other"); Text(verbatim: "340 MB") }
            }
            .font(Typography.caption)
        }
    }
    .padding(40)
}
