//
//  MarkdownView.swift
//  BlissUI
//
//  A Markdown document rendered with its block structure: headings at the
//  library's sizes, paragraphs with inline bold, italic, links and code,
//  nested lists with markers, block quotes with a bar, fenced code in a
//  `CodeBlock`, and thematic breaks. `Text` alone renders inline markdown;
//  this is the read-only partner to `RichTextEditor` for release notes, help
//  pages and anything an assistant writes back.
//
//  Foundation parses the document (`interpretedSyntax: .full` keeps the block
//  intents), and the runs are grouped by the identity of their innermost
//  block into paragraphs, headings, list items, code and breaks. A table
//  renders one paragraph per row, its cells joined by " · ".
//

import SwiftUI

/// The size a `MarkdownView` reads at.
public enum MarkdownSize: Hashable, Sendable {
    /// `bodySmall` (13pt) — a sheet, a side pane.
    case small
    /// `contentMedium` (14pt, the content font) — a help page, release notes.
    case regular

    var bodyFont: Font {
        switch self {
        case .small: Typography.bodySmall
        case .regular: Typography.contentMedium
        }
    }
}

private struct MarkdownSizeKey: EnvironmentKey {
    static let defaultValue: MarkdownSize = .small
}

private struct MarkdownCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var markdownSize: MarkdownSize {
        get { self[MarkdownSizeKey.self] }
        set { self[MarkdownSizeKey.self] = newValue }
    }

    var markdownIsCompact: Bool {
        get { self[MarkdownCompactKey.self] }
        set { self[MarkdownCompactKey.self] = newValue }
    }
}

// MARK: - Markdown View

/// A Markdown document with headings, lists, quotes and code blocks.
///
/// ```swift
/// ScrollViewWithThinIndicator {
///     MarkdownView(releaseNotes)
///         .padding(Spacing.xl)
/// }
/// ```
///
/// Links open through the environment's `openURL`, as a `Text` link does.
/// `size: .regular` sets the body in the content font for a help page;
/// `compact` halves the gap between blocks for a tooltip-sized note.
public struct MarkdownView: View {
    private let groups: [MarkdownGroup]
    private let size: MarkdownSize
    private let compact: Bool

    /// - Parameters:
    ///   - markdown: The document. A document that doesn't parse shows as one
    ///     plain paragraph.
    ///   - size: `bodySmall` (13pt) or the content font (14pt).
    ///   - compact: Half the gap between blocks.
    public init(_ markdown: String, size: MarkdownSize = .small, compact: Bool = false) {
        self.groups = MarkdownGroup.groups(from: MarkdownBlock.blocks(from: markdown))
        self.size = size
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? Spacing.xs : Spacing.md) {
            ForEach(groups) { group in
                MarkdownGroupView(group: group)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.markdownSize, size)
        .environment(\.markdownIsCompact, compact)
    }
}

// MARK: - Blocks

/// One block of the document, with its text's inline attributes kept.
struct MarkdownBlock: Identifiable {
    enum Kind: Equatable {
        case paragraph
        case heading(level: Int)
        /// `ordinal` is nil in a bulleted list; `depth` starts at 1.
        case listItem(ordinal: Int?, depth: Int)
        case codeBlock(language: String?)
        case thematicBreak
    }

    let id: Int
    let kind: Kind
    /// Inside a block quote.
    let isQuoted: Bool
    var text: AttributedString

    /// The document split into blocks. Runs that share an innermost block
    /// (the same paragraph, heading, code block or table row) join.
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return [MarkdownBlock(id: 0, kind: .paragraph, isQuoted: false, text: AttributedString(markdown))]
        }

        var blocks: [MarkdownBlock] = []
        var lastCellIdentity: Int?
        for run in parsed.runs {
            let shape = BlockShape(intent: run.presentationIntent)
            var piece = AttributedString(parsed[run.range])
            piece.presentationIntent = nil
            if run.inlinePresentationIntent?.contains(.softBreak) == true {
                piece = AttributedString(" ")
            }
            styleInline(&piece, intent: run.inlinePresentationIntent)

            if let last = blocks.indices.last, blocks[last].id == shape.identity {
                // A new table cell in the same row: separate it from the last.
                if let cell = shape.cellIdentity, cell != lastCellIdentity {
                    blocks[last].text.append(AttributedString(" · "))
                }
                blocks[last].text.append(piece)
            } else {
                blocks.append(MarkdownBlock(id: shape.identity, kind: shape.kind, isQuoted: shape.isQuoted, text: piece))
            }
            lastCellIdentity = shape.cellIdentity
        }
        return blocks.map(trimmed)
    }

    /// The wash under inline code.
    static let inlineCodeWashOpacity: Double = 0.08

    /// Inline code in the code font on a faint wash; links in the accent.
    /// Bold, italic and strikethrough stay as intents, which `Text` draws.
    private static func styleInline(_ piece: inout AttributedString, intent: InlinePresentationIntent?) {
        if intent?.contains(.code) == true {
            piece.font = Typography.codeSmall
            piece.backgroundColor = Color.primary.opacity(inlineCodeWashOpacity)
        }
        if piece.link != nil {
            piece.foregroundColor = Color.accent
        }
    }

    /// A block's text without the newline the parser leaves at its end.
    private static func trimmed(_ block: MarkdownBlock) -> MarkdownBlock {
        var block = block
        while let last = block.text.characters.last, last.isNewline {
            block.text.characters.removeLast()
        }
        return block
    }

    var plainText: String { String(text.characters) }
}

/// What a run's presentation intent says about the block it's in. The
/// components are searched by kind, so the order Foundation lists them in
/// (innermost first) doesn't matter beyond picking the innermost block.
private struct BlockShape {
    let identity: Int
    let kind: MarkdownBlock.Kind
    let isQuoted: Bool
    let cellIdentity: Int?

    init(intent: PresentationIntent?) {
        guard let intent else {
            identity = -1
            kind = .paragraph
            isQuoted = false
            cellIdentity = nil
            return
        }
        let components = intent.components
        isQuoted = components.contains { $0.kind == .blockQuote }
        cellIdentity = components.first { if case .tableCell = $0.kind { return true } else { return false } }?.identity

        // The list this run sits in: how deep, and which item of the innermost
        // list (Foundation lists the components innermost first).
        let lists = components.filter { $0.kind == .orderedList || $0.kind == .unorderedList }
        let isOrdered = lists.first?.kind == .orderedList
        var ordinal: Int?
        if let item = components.first(where: { if case .listItem = $0.kind { return true } else { return false } }),
           case .listItem(let itemOrdinal) = item.kind {
            ordinal = itemOrdinal
        }
        let listKind = MarkdownBlock.Kind.listItem(ordinal: isOrdered ? ordinal : nil, depth: lists.count)

        // A table cell has no paragraph of its own; the row is the block.
        let row = components.first { component in
            if case .tableRow = component.kind { return true }
            return component.kind == .tableHeaderRow
        }

        // The innermost block-level component names the block.
        for component in components {
            switch component.kind {
            case .header(let level):
                identity = component.identity
                kind = .heading(level: level)
                return
            case .codeBlock(let languageHint):
                identity = component.identity
                kind = .codeBlock(language: languageHint)
                return
            case .thematicBreak:
                identity = component.identity
                kind = .thematicBreak
                return
            case .paragraph:
                if let row {
                    identity = row.identity
                    kind = .paragraph
                } else if lists.isEmpty {
                    identity = component.identity
                    kind = .paragraph
                } else {
                    identity = component.identity
                    kind = listKind
                }
                return
            default:
                continue
            }
        }
        if let row {
            identity = row.identity
            kind = .paragraph
        } else if !lists.isEmpty, let item = components.first(where: { if case .listItem = $0.kind { return true } else { return false } }) {
            identity = item.identity
            kind = listKind
        } else {
            identity = components.first?.identity ?? -1
            kind = .paragraph
        }
    }
}

// MARK: - Groups

/// Blocks as they're drawn: consecutive list items as one list, consecutive
/// quoted blocks behind one bar, everything else on its own.
struct MarkdownGroup: Identifiable {
    enum Kind {
        case block(MarkdownBlock)
        case list([MarkdownBlock])
        case quote([MarkdownGroup])
    }

    let id: Int
    let kind: Kind

    static func groups(from blocks: [MarkdownBlock]) -> [MarkdownGroup] {
        var result: [MarkdownGroup] = []
        var index = 0
        while index < blocks.count {
            let block = blocks[index]
            if block.isQuoted {
                var quoted: [MarkdownBlock] = []
                while index < blocks.count, blocks[index].isQuoted {
                    quoted.append(blocks[index])
                    index += 1
                }
                let inner = quoted.map { MarkdownBlock(id: $0.id, kind: $0.kind, isQuoted: false, text: $0.text) }
                result.append(MarkdownGroup(id: block.id, kind: .quote(Self.groups(from: inner))))
            } else if case .listItem = block.kind {
                var items: [MarkdownBlock] = []
                while index < blocks.count, !blocks[index].isQuoted, case .listItem = blocks[index].kind {
                    items.append(blocks[index])
                    index += 1
                }
                result.append(MarkdownGroup(id: block.id, kind: .list(items)))
            } else {
                result.append(MarkdownGroup(id: block.id, kind: .block(block)))
                index += 1
            }
        }
        return result
    }
}

// MARK: - Rendering

private struct MarkdownGroupView: View {
    let group: MarkdownGroup
    @Environment(\.markdownIsCompact) private var isCompact

    /// The quote's bar.
    private static let quoteBarWidth: CGFloat = Spacing.insetSpacing

    var body: some View {
        switch group.kind {
        case .block(let block):
            MarkdownBlockView(block: block)
        case .list(let items):
            VStack(alignment: .leading, spacing: isCompact ? Spacing.hairline : Spacing.xs) {
                ForEach(items) { item in
                    MarkdownBlockView(block: item)
                }
            }
        case .quote(let inner):
            HStack(alignment: .top, spacing: Spacing.md) {
                RoundedRectangle(cornerRadius: Self.quoteBarWidth / 2, style: .continuous)
                    .fill(Color.menuBorder)
                    .frame(width: Self.quoteBarWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(inner) { group in
                        MarkdownGroupView(group: group)
                    }
                }
                .foregroundStyle(.secondary)
            }
            // The bar is a greedy shape: hold the row to the text's height, or
            // it runs to the bottom of whatever frame holds the document.
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    @Environment(\.markdownSize) private var size

    var body: some View {
        switch block.kind {
        case .paragraph:
            text(font: size.bodyFont)
        case .heading(let level):
            text(font: headingFont(level))
        case .listItem(let ordinal, let depth):
            listItem(ordinal: ordinal, depth: depth)
        case .codeBlock(let language):
            CodeBlock(block.plainText, highlighter: highlighter(for: language))
        case .thematicBreak:
            Divider()
        }
    }

    private func text(font: Font) -> some View {
        Text(block.text)
            .font(font)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listItem(ordinal: Int?, depth: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(verbatim: ordinal.map { "\($0)." } ?? "•")
                .font(size.bodyFont.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: Spacing.lg, alignment: .trailing)
            text(font: size.bodyFont)
        }
        .padding(.leading, CGFloat(max(depth - 1, 0)) * Spacing.lg)
    }

    /// h1 22, h2 17, h3 15, the rest the body's semibold (CLAUDE.md's size map).
    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return Typography.displaySmall
        case 2: return Typography.headingMedium
        case 3: return Typography.headingSmall
        default: return Typography.bodySmallSemibold
        }
    }

    private func highlighter(for language: String?) -> CodeHighlighter {
        switch language?.lowercased() {
        case "sh", "bash", "zsh", "shell": return .shell
        case "yaml", "yml": return .yaml
        default: return .plain
        }
    }
}

// MARK: - Preview

#Preview("Markdown view", traits: .fixedLayout(width: 520, height: 460)) {
    MarkdownView("""
    # Release notes

    The **Low Glare** theme ships this week, with a dim warm shell and cream surfaces. Read the [design notes](https://example.com/notes) before you change a `token`.

    ## What changed

    - Status marks hold 7:1 on both surfaces
      - The light ramp's `*50` steps are near-full saturation
    - Badges fill with a wash of their tint

    1. Pull `main`
    2. Run the tests

    > A theme's accent is its default; a pick is kept per theme.

    ```sh
    swift build --build-tests && swift test
    ```

    ---

    That's all for 2.2.
    """)
    .padding(Spacing.xl)
}
