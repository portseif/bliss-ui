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

/// The info glyph's size.
public enum InfoButtonSize: Hashable, Sendable {
    /// A 10pt glyph in a 16pt hit area: beside a caption or a row's detail.
    case small
    /// A 12pt glyph in a 20pt hit area: beside a 13pt row title.
    case regular

    var font: Font {
        switch self {
        case .small: Typography.captionTiny
        case .regular: Typography.caption
        }
    }

    var hitSize: CGFloat {
        switch self {
        case .small: Sizing.iconDefault
        case .regular: Sizing.iconMedium
        }
    }
}

// MARK: - Glyph

private struct InfoGlyph: View {
    let systemImage: String
    let size: InfoButtonSize

    var body: some View {
        BlissSymbol(systemImage)
            .font(size.font)
            .foregroundStyle(.secondary)
            .frame(minWidth: size.hitSize, minHeight: size.hitSize)
            .contentShape(Rectangle())
    }
}

// MARK: - Text hint

public struct InfoButton: View {
    let text: LocalizedStringKey
    var title: LocalizedStringKey? = nil
    var maxWidth: CGFloat = InfoButton.defaultMaxWidth
    var size: InfoButtonSize = .small
    var systemImage: String = "info.circle"
    var xPosition: FloatingMenuXPosition = .leading
    var yPosition: FloatingMenuYPosition = .above

    /// How wide the hint's paragraph gets before wrapping.
    public static let defaultMaxWidth: CGFloat = 250

    /// - Parameters:
    ///   - text: The hint. Looked up in your app's strings.
    ///   - title: A semibold first line over the paragraph.
    ///   - maxWidth: How wide the paragraph gets before wrapping.
    ///   - size: The glyph size; `.regular` beside a 13pt row title.
    ///   - systemImage: `questionmark.circle` for help, `exclamationmark.circle` for a caveat.
    ///   - xPosition: Where the panel sits across the glyph.
    ///   - yPosition: Whether the panel opens above or below the glyph.
    public init(
        text: LocalizedStringKey,
        title: LocalizedStringKey? = nil,
        maxWidth: CGFloat = InfoButton.defaultMaxWidth,
        size: InfoButtonSize = .small,
        systemImage: String = "info.circle",
        xPosition: FloatingMenuXPosition = .leading,
        yPosition: FloatingMenuYPosition = .above
    ) {
        self.text = text
        self.title = title
        self.maxWidth = maxWidth
        self.size = size
        self.systemImage = systemImage
        self.xPosition = xPosition
        self.yPosition = yPosition
    }

    public var body: some View {
        InfoHint(xPosition: xPosition, yPosition: yPosition, size: size, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if let title {
                    Text(title)
                        .font(Typography.labelSmallBold)
                        .foregroundStyle(.primary)
                }
                Text(text)
                    .font(Typography.labelSmall)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
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
    var size: InfoButtonSize = .small
    var systemImage: String = "info.circle"
    @ViewBuilder let content: () -> Content

    @State private var isPresented = false

    public init(
        xPosition: FloatingMenuXPosition = .leading,
        yPosition: FloatingMenuYPosition = .above,
        size: InfoButtonSize = .small,
        systemImage: String = "info.circle",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.size = size
        self.systemImage = systemImage
        self.content = content
    }

    public var body: some View {
        Button {
            // Toggle, never set true: the menu's dismiss monitor tears down on an
            // anchor click and expects the button to flip the state — setting it
            // true respawns the panel it just closed.
            isPresented.toggle()
        } label: {
            InfoGlyph(systemImage: systemImage, size: size)
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

#Preview("Info Button", traits: .fixedLayout(width: 300, height: 180)) {
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.xs) {
            Text("Event Categories")
            InfoButton(text: "Choose which types of events to record. Disabling categories you don't need can reduce noise.")
        }

        HStack(spacing: Spacing.xs) {
            Text("Preferred Tools")
            InfoButton(text: "Choose your preferred applications for opening files.", size: .regular)
        }

        HStack(spacing: Spacing.xs) {
            Text("Beta features")
            InfoButton(text: "They may change before release.", title: "Use with care", systemImage: "exclamationmark.circle")
        }
    }
    .padding(Spacing.xxl)
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
    .padding(Spacing.xxl)
}
