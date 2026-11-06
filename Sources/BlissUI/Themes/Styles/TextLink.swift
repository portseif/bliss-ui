//
//  TextLink.swift
//  BlissUI
//
//  BlissUI's link style for clickable URLs (`example.com/docs`,
//  `http://127.0.0.1:8080`), the way a table's domain column shows them: dimmed
//  text over an offset dotted underline, both turning accent on hover, with the
//  pointing-hand cursor. URLs only — actions stay buttons.
//

import SwiftUI

public struct TextLink: View {
    let title: String
    /// Nil inherits the surrounding font (e.g. a monospaced meta line).
    let font: Font?
    let truncationMode: Text.TruncationMode
    /// An SF Symbol shown after the text on hover. Its slot is always laid out, so
    /// hovering never reflows the line.
    let hoverSymbol: String?
    let action: () -> Void

    @State private var hovering = false

    /// - Parameters:
    ///   - title: The link text, shown verbatim (usually the URL itself).
    ///   - font: Nil inherits the surrounding font.
    ///   - truncationMode: Where a long link is cut to fit one line.
    ///   - hoverSymbol: An SF Symbol shown after the text on hover.
    ///   - action: Opens the link.
    public init(
        _ title: String,
        font: Font? = nil,
        truncationMode: Text.TruncationMode = .tail,
        hoverSymbol: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.font = font
        self.truncationMode = truncationMode
        self.hoverSymbol = hoverSymbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxs) {
                text
                    .lineLimit(1)
                    .truncationMode(truncationMode)
                    // Hand-drawn (not `.underline`) so it sits a couple of points
                    // BELOW the text with breathing room. An overlay, so it adds no
                    // height to the line it's in.
                    .overlay(alignment: .bottom) {
                        DottedRule()
                            .stroke(
                                hovering ? Color.accent.opacity(0.7) : Color.primary.opacity(0.18),
                                style: StrokeStyle(lineWidth: 1, dash: [1, 2])
                            )
                            .frame(height: 1)
                            .offset(y: 2.5)
                    }
                if let hoverSymbol {
                    Image(systemName: hoverSymbol)
                        .font(Typography.captionTiny)
                        .opacity(hovering ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(hovering ? Color.accent : Color.primary.opacity(0.55))
            .contentShape(Rectangle())
        }
        // 4pt out so the ring clears the dotted underline (offset 2.5pt below).
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 4))
        .onHover { isHovering in
            withAnimation(Animations.hover) { hovering = isHovering }
        }
        .linkCursor()
    }

    private var text: Text {
        let text = Text(verbatim: title)
        return font.map { text.font($0) } ?? text
    }
}

/// A horizontal 1pt rule, stroked dashed by its caller — the link's offset dotted
/// underline (`.underline` can't add space below the text).
private struct DottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

#Preview(traits: .fixedLayout(width: 320, height: 150)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        TextLink("example.com/docs", font: Typography.codeTiny) {}
        HStack(spacing: 6) {
            TextLink("localhost:8080") {}
            Text(verbatim: "·")
            Text(verbatim: "pid 4120")
        }
        .font(Typography.code)
        .foregroundStyle(.secondary)
        TextLink("example.com", font: Typography.code, hoverSymbol: "arrow.up.right") {}
    }
    .padding()
}
