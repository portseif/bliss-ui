//
//  CodeBlock.swift
//  BlissUI
//
//  A read-only code snippet: the code font in the `.inputBox` chrome at rest
//  (the same box `CodeField` edits in), colored by the same `CodeHighlighter`
//  and palette, with a Copy button in the corner, optional line numbers and
//  an optional title strip. Long lines scroll sideways unless it wraps, so a
//  command or a YAML block keeps its shape. `MarkdownView` uses it for fenced
//  code, and `CodeField(code:)` is this with wrapping on.
//

import SwiftUI

/// A code snippet the user can read, select and copy.
///
/// ```swift
/// CodeBlock("swift build --build-tests", highlighter: .shell)
/// CodeBlock(workflow, highlighter: .yaml, showsLineNumbers: true, title: "ci.yml")
/// CodeBlock(snippet, highlighter: .swift, highlightedLines: [3, 4], maxHeight: 240)
/// ```
public struct CodeBlock: View {
    private let code: String
    private let highlighter: CodeHighlighter
    private let showsLineNumbers: Bool
    private let showsCopyButton: Bool
    private let font: Font
    private let wraps: Bool
    private let title: String?
    private let maxHeight: CGFloat?
    private let highlightedLines: Set<Int>

    @State private var showCopied = false
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - code: The snippet, shown as-is.
    ///   - highlighter: How to color it (`.shell`, `.yaml`, `.json`, `.swift`,
    ///     your own); `.plain` for the code font alone.
    ///   - showsLineNumbers: A gutter of line numbers.
    ///   - showsCopyButton: A Copy button in the top trailing corner (in the
    ///     title strip when there is one).
    ///   - font: A code token (`Typography.codeSmall`, `code`, …).
    ///   - wraps: Long lines wrap instead of scrolling sideways — a log
    ///     excerpt wraps, a command scrolls.
    ///   - title: A strip above the code ("bash", "Package.swift"), shown as-is.
    ///   - maxHeight: Scrolls past this height; nil grows with the code.
    ///   - highlightedLines: 1-based lines drawn on a wash, for the lines a
    ///     doc is pointing at.
    public init(
        _ code: String,
        highlighter: CodeHighlighter = .plain,
        showsLineNumbers: Bool = false,
        showsCopyButton: Bool = true,
        font: Font = Typography.codeSmall,
        wraps: Bool = false,
        title: String? = nil,
        maxHeight: CGFloat? = nil,
        highlightedLines: Set<Int> = []
    ) {
        self.code = code
        self.highlighter = highlighter
        self.showsLineNumbers = showsLineNumbers
        self.showsCopyButton = showsCopyButton
        self.font = font
        self.wraps = wraps
        self.title = title
        self.maxHeight = maxHeight
        self.highlightedLines = highlightedLines
    }

    /// The code's lines; a trailing newline adds no empty line.
    private var lines: [Substring] {
        let trimmed = code.hasSuffix("\n") ? code.dropLast() : code[...]
        return trimmed.split(separator: "\n", omittingEmptySubsequences: false)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let title {
                titleStrip(title)
                Divider()
            }
            HStack(alignment: .top, spacing: Spacing.sm) {
                scrollingCode
                if showsCopyButton && title == nil {
                    CopyButton(value: code, showCopied: $showCopied)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .inputBox(isFocused: false, cornerRadius: Sizing.textBoxCornerRadius)
    }

    /// The title and, beside it, the Copy button.
    private func titleStrip(_ title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(verbatim: title)
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            if showsCopyButton {
                CopyButton(value: code, showCopied: $showCopied)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    /// The gutter and the code, scrolling sideways (and, past `maxHeight`, down).
    @ViewBuilder
    private var scrollingCode: some View {
        if let maxHeight {
            ScrollViewWithThinIndicator(indicatorTopPadding: 0, indicatorBottomPadding: 0) {
                horizontalCode
            }
            .frame(maxHeight: maxHeight)
        } else {
            horizontalCode
        }
    }

    @ViewBuilder
    private var horizontalCode: some View {
        if wraps {
            codeRow
        } else {
            // A plain horizontal scroll hugs the code's height (the thin-indicator
            // scroll view fills whatever it's offered); the suppressor keeps the
            // legacy scroller off under "Show scroll bars: Always".
            ScrollView(.horizontal) {
                codeRow
                    .background { NativeScrollerSuppressor() }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var codeRow: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if showsLineNumbers {
                CodeGutter(lineCount: max(lines.count, 1), font: font)
            }
            if highlightedLines.isEmpty {
                codeText(attributedCode(code))
            } else {
                // Line by line, so a line can sit on its wash; selection then
                // runs per line, which a pointed-at excerpt can live with.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        codeText(attributedCode(String(line)))
                            .padding(.horizontal, Spacing.xxs)
                            .background {
                                if highlightedLines.contains(index + 1) {
                                    RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                                        .fill(RowTint.selected(colorScheme))
                                }
                            }
                            .padding(.horizontal, -Spacing.xxs)
                    }
                }
            }
        }
        .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
    }

    private func codeText(_ text: AttributedString) -> some View {
        Text(text)
            .font(font)
            .textSelection(.enabled)
            .lineLimit(nil)
            .fixedSize(horizontal: !wraps, vertical: true)
            .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
    }

    /// The tokens in the editor's colors (`CodeSyntaxPalette`).
    private func attributedCode(_ source: String) -> AttributedString {
        let palette = CodeSyntaxPalette(scheme: colorScheme)
        var result = AttributedString()
        for token in highlighter.tokens(in: source) {
            var run = AttributedString(token.text)
            run.foregroundColor = palette.color(for: token.kind)
            result.append(run)
        }
        return result
    }
}

// MARK: - Gutter

/// Line numbers in the code font, one per line, right-aligned; `CodeBlock`
/// and `CodeField`'s editor share it so their gutters match.
struct CodeGutter: View {
    let lineCount: Int
    let font: Font

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...max(lineCount, 1), id: \.self) { number in
                Text(verbatim: "\(number)")
                    .font(font.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("Code block", traits: .fixedLayout(width: 520, height: 360)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        CodeBlock("""
        # Build and test
        swift build --build-tests
        swift test --filter BlissUIPublicAPITests
        """, highlighter: .shell, showsLineNumbers: true)
        CodeBlock("""
        name: CI
        on:
          push:
            branches: [main]
        """, highlighter: .yaml, title: "ci.yml", highlightedLines: [3])
        CodeBlock("""
        let stars = Rating("Quality", value: $stars)   // one Tab stop, ←/→ from the keyboard
        """, highlighter: .swift, wraps: true)
    }
    .padding(Spacing.xl)
}
