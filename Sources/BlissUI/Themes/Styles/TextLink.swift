//
//  TextLink.swift
//  BlissUI
//
//  BlissUI's link style for clickable URLs (`example.com/docs`,
//  `http://127.0.0.1:8080`), the way a table's domain column shows them: text
//  over a faint offset underline that turns solid, with the text, on hover,
//  and the pointing-hand cursor. URLs only — actions stay buttons.
//

import SwiftUI

/// How a `TextLink` reads at rest.
public enum TextLinkTone {
    /// Dimmed text — a URL in a table column or a meta line.
    case dimmed
    /// Full text color — a link inside body copy.
    case primary
}

/// The link's own numbers: the underline and the dimmed tone.
private enum TextLinkMetrics {
    static let dimmedTextOpacity: Double = 0.55
    static let ruleRestOpacity: Double = 0.3
    static let ruleWidth: CGFloat = 1
    /// The rule sits this far under the baseline, so it doesn't touch descenders.
    static let ruleOffset: CGFloat = 2.5
    /// The ring clears the rule by this much.
    static let ringOutset: CGFloat = Spacing.xxs
}

public struct TextLink: View {
    let title: String
    /// Nil inherits the surrounding font (e.g. a monospaced meta line).
    let font: Font?
    let truncationMode: Text.TruncationMode
    /// An SF Symbol shown after the text on hover. Its slot is always laid out, so
    /// hovering never reflows the line.
    let hoverSymbol: String?
    let tone: TextLinkTone
    let showsUnderline: Bool
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - title: The link text, shown verbatim (usually the URL itself).
    ///   - font: Nil inherits the surrounding font.
    ///   - truncationMode: Where a long link is cut to fit one line.
    ///   - hoverSymbol: An SF Symbol shown after the text on hover.
    ///   - tone: Dimmed (a URL column) or the full text color (body copy).
    ///   - showsUnderline: Draw the underline at rest; off, it shows on hover only.
    ///   - action: Opens the link.
    public init(
        _ title: String,
        font: Font? = nil,
        truncationMode: Text.TruncationMode = .tail,
        hoverSymbol: String? = nil,
        tone: TextLinkTone = .dimmed,
        showsUnderline: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.font = font
        self.truncationMode = truncationMode
        self.hoverSymbol = hoverSymbol
        self.tone = tone
        self.showsUnderline = showsUnderline
        self.action = action
    }

    private var textColor: Color {
        if hovering { return Color.primary }
        return tone == .primary ? Color.primary : Color.primary.opacity(TextLinkMetrics.dimmedTextOpacity)
    }

    private var ruleColor: Color {
        if hovering { return Color.primary }
        return showsUnderline ? Color.primary.opacity(TextLinkMetrics.ruleRestOpacity) : .clear
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
                        Rectangle()
                            .fill(ruleColor)
                            .frame(height: TextLinkMetrics.ruleWidth)
                            .offset(y: TextLinkMetrics.ruleOffset)
                    }
                if let hoverSymbol {
                    Image(systemName: hoverSymbol)
                        .font(Typography.captionTiny)
                        .opacity(hovering ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(textColor)
            .contentShape(Rectangle())
        }
        // Out past the underline, so the ring doesn't sit on it.
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: TextLinkMetrics.ringOutset))
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .onHover { isHovering in
            withAnimation(Animations.hover) { hovering = isEnabled && isHovering }
        }
        .linkCursor()
    }

    private var text: Text {
        let text = Text(verbatim: title)
        return font.map { text.font($0) } ?? text
    }
}

#Preview(traits: .fixedLayout(width: 320, height: 150)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        TextLink("example.com/docs", font: Typography.codeTiny) {}
        HStack(spacing: Spacing.xs) {
            TextLink("localhost:8080") {}
            Text(verbatim: "·")
            Text(verbatim: "pid 4120")
        }
        .font(Typography.code)
        .foregroundStyle(.secondary)
        TextLink("example.com", font: Typography.code, hoverSymbol: "arrow.up.right") {}
        TextLink("Read the design notes", tone: .primary, showsUnderline: false) {}
    }
    .padding()
}
