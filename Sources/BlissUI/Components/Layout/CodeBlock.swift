//
//  CodeBlock.swift
//  BlissUI
//
//  A read-only code snippet: the code font over a faint fill, colored by the
//  same `CodeHighlighter` and palette as `CodeField`, with a Copy button in
//  the corner and optional line numbers. Long lines scroll sideways instead
//  of wrapping, so a command or a YAML block keeps its shape. `MarkdownView`
//  uses it for fenced code.
//

import SwiftUI

/// A code snippet the user can read, select and copy.
///
/// ```swift
/// CodeBlock("swift build --build-tests", highlighter: .shell)
/// CodeBlock(workflow, highlighter: .yaml, showsLineNumbers: true)
/// ```
public struct CodeBlock: View {
    private let code: String
    private let highlighter: CodeHighlighter
    private let showsLineNumbers: Bool
    private let showsCopyButton: Bool

    @State private var showCopied = false
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - code: The snippet, shown as-is.
    ///   - highlighter: How to color it (`.shell`, `.yaml`, your own); `.plain`
    ///     for the code font alone.
    ///   - showsLineNumbers: A gutter of line numbers.
    ///   - showsCopyButton: A Copy button in the top trailing corner.
    public init(
        _ code: String,
        highlighter: CodeHighlighter = .plain,
        showsLineNumbers: Bool = false,
        showsCopyButton: Bool = true
    ) {
        self.code = code
        self.highlighter = highlighter
        self.showsLineNumbers = showsLineNumbers
        self.showsCopyButton = showsCopyButton
    }

    /// Lines, for the gutter; a trailing newline adds no empty line.
    private var lineCount: Int {
        let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
        return max(trimmed.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // A plain horizontal scroll hugs the code's height (the thin-indicator
            // scroll view fills whatever it's offered); the suppressor keeps the
            // legacy scroller off under "Show scroll bars: Always".
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    if showsLineNumbers {
                        gutter
                    }
                    Text(attributedCode)
                        .font(Typography.codeSmall)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .background { NativeScrollerSuppressor() }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            if showsCopyButton {
                CopyButton(value: code, showCopied: $showCopied)
            }
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }

    /// Line numbers in the code font, so each sits on its line.
    private var gutter: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...lineCount, id: \.self) { number in
                Text(verbatim: "\(number)")
                    .font(Typography.codeSmall.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityHidden(true)
    }

    /// The tokens in the editor's colors (`CodeSyntaxPalette`).
    private var attributedCode: AttributedString {
        let palette = CodeSyntaxPalette(scheme: colorScheme)
        var result = AttributedString()
        for token in highlighter.tokens(in: code) {
            var run = AttributedString(token.text)
            run.foregroundColor = palette.color(for: token.kind)
            result.append(run)
        }
        return result
    }
}

// MARK: - Preview

#Preview("Code block", traits: .fixedLayout(width: 520, height: 260)) {
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
        """, highlighter: .yaml)
    }
    .padding(Spacing.xl)
}
