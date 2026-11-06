//
//  CodeField.swift
//  BlissUI
//
//  A code-font input — a shell command, a YAML file — colored by a
//  `CodeHighlighter`, in the `.inputBox` chrome, with a Copy button. Or the
//  same box read-only, to show code the user can select and copy.
//
//  How it colors live text: the real editor (a `TextField`, or a `TextEditor`
//  for several lines) draws its text clear, and the highlighted `Text` sits on
//  top of it at the same font and position, letting clicks through. The editor
//  keeps the caret, the selection, undo and input methods; the overlay only
//  paints.
//

import AppKit
import SwiftUI

// MARK: - Layout

/// The shape of an editable `CodeField`.
public enum CodeFieldLayout: Hashable, Sendable {
    /// One command: a long one wraps, and Return submits (`.onSubmit`).
    case singleLine
    /// A multi-line editor this tall; Return starts a new line and longer
    /// text scrolls.
    case editor(height: CGFloat)
}

// MARK: - Code Field

/// A code-font field with syntax highlighting.
///
/// ```swift
/// CodeField(text: $command, highlighter: .shell, prompt: "npm install")
///     .onSubmit { run(command) }
/// CodeField(text: $workflow, highlighter: .yaml, layout: .editor(height: 200), font: Typography.codeSmall)
/// CodeField(code: snippet, highlighter: .shell)   // read-only, selectable
/// ```
public struct CodeField: View {
    private let text: Binding<String>?
    private let code: String
    private let highlighter: CodeHighlighter
    private let prompt: LocalizedStringKey?
    private let layout: CodeFieldLayout
    private let font: Font
    private let showsCopyButton: Bool
    private let maxHeight: CGFloat?

    @FocusState private var isFocused: Bool
    @State private var showCopied = false
    /// The highlighted text's height, which the editor follows so the two
    /// scroll as one.
    @State private var highlightedHeight: CGFloat = 0
    /// One line of the code font, the slack the editor keeps below the text so
    /// a new line has room before the overlay re-measures.
    @State private var lineHeight: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme

    /// An editable field.
    /// - Parameters:
    ///   - text: The code.
    ///   - highlighter: How to color it.
    ///   - prompt: Shown while empty, looked up in your app's strings.
    ///   - layout: One wrapping command, or a multi-line editor.
    ///   - font: A code token (`Typography.code`, `codeSmall`, …).
    ///   - showsCopyButton: A Copy button at the trailing edge.
    public init(
        text: Binding<String>,
        highlighter: CodeHighlighter = .plain,
        prompt: LocalizedStringKey? = nil,
        layout: CodeFieldLayout = .singleLine,
        font: Font = Typography.code,
        showsCopyButton: Bool = true
    ) {
        self.text = text
        self.code = ""
        self.highlighter = highlighter
        self.prompt = prompt
        self.layout = layout
        self.font = font
        self.showsCopyButton = showsCopyButton
        self.maxHeight = nil
    }

    /// Read-only code the user can select and copy.
    /// - Parameters:
    ///   - code: The code to show.
    ///   - highlighter: How to color it.
    ///   - font: A code token (`Typography.code`, `codeSmall`, …).
    ///   - maxHeight: Scrolls past this height; nil grows with the code.
    ///   - showsCopyButton: A Copy button at the trailing edge.
    public init(
        code: String,
        highlighter: CodeHighlighter = .plain,
        font: Font = Typography.code,
        maxHeight: CGFloat? = nil,
        showsCopyButton: Bool = true
    ) {
        self.text = nil
        self.code = code
        self.highlighter = highlighter
        self.prompt = nil
        self.layout = .singleLine
        self.font = font
        self.showsCopyButton = showsCopyButton
        self.maxHeight = maxHeight
    }

    // MARK: Metrics

    /// The box's inner padding (StackMe's command field: 12 × 10).
    private static let horizontalPadding = Spacing.md
    private static let verticalPadding = Spacing.sm + 2
    /// `TextEditor`'s text view keeps AppKit's default line fragment padding
    /// on both sides of every line, so the overlay is inset the same to sit
    /// exactly over its glyphs (measured: without it the colors drew 5pt left
    /// of the caret).
    private static let editorLineInset: CGFloat = 5
    /// The Copy button's box (`CopyButton` draws 18pt).
    private static let copyButtonSize: CGFloat = 18

    public var body: some View {
        if let text {
            switch layout {
            case .singleLine:
                singleLineField(text)
            case .editor(let height):
                editorField(text, height: height)
            }
        } else {
            readOnlyField
        }
    }

    // MARK: Single line

    private func singleLineField(_ text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                // Invisible text field for editing - always clear color, cursor still visible.
                // Vertical, so a long command wraps instead of scrolling sideways
                // under the overlay; Return still submits.
                TextField(
                    prompt ?? "",
                    text: text,
                    prompt: prompt.map { Text($0).foregroundStyle(.tertiary) },
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(font)
                .multilineTextAlignment(.leading)
                .foregroundStyle(text.wrappedValue.isEmpty ? Color.primary : Color.clear)
                .focused($isFocused)

                // Always show syntax highlighted text when there's content. On top
                // of the field, so its selection highlight shows under the colors
                // instead of covering them.
                if !text.wrappedValue.isEmpty {
                    highlightedText(text.wrappedValue)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsCopyButton {
                copyButton(for: text.wrappedValue)
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inputBox(isFocused: isFocused)
    }

    // MARK: Editor

    private func editorField(_ text: Binding<String>, height: CGFloat) -> some View {
        let isEmpty = text.wrappedValue.isEmpty
        let visibleHeight = max(0, height - Self.verticalPadding * 2)
        return ScrollViewWithThinIndicator(indicatorTopPadding: Spacing.xs, indicatorBottomPadding: Spacing.xs) {
            ZStack(alignment: .topLeading) {
                // Invisible TextEditor for editing. It doesn't scroll on its own:
                // it's as tall as the text plus a line, and the scroll around it
                // moves it and the overlay together (two scrolls drifted apart).
                TextEditor(text: text)
                    .font(font)
                    .foregroundStyle(isEmpty ? Color.primary : Color.clear)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .focused($isFocused)
                    .frame(height: max(visibleHeight, (isEmpty ? 0 : highlightedHeight) + lineHeight))

                if isEmpty, let prompt {
                    Text(prompt)
                        .font(font)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, Self.editorLineInset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                // Syntax highlighted overlay, above the editor (see `singleLineField`).
                if !isEmpty {
                    highlightedText(text.wrappedValue)
                        .padding(.horizontal, Self.editorLineInset)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { highlightedHeight = $0 }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background {
                Text(verbatim: "M")
                    .font(font)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lineHeight = $0 }
            }
            .padding(.leading, Self.horizontalPadding - Self.editorLineInset)
            .padding(.trailing, trailingInset)
            .padding(.vertical, Self.verticalPadding)
        }
        .frame(height: height)
        .overlay(alignment: .topTrailing) {
            if showsCopyButton {
                copyButton(for: text.wrappedValue)
                    .padding(.top, Self.verticalPadding - 1)
                    .padding(.trailing, Spacing.sm)
            }
        }
        .inputBox(isFocused: isFocused)
    }

    /// Room on the trailing side for the Copy button, so lines wrap before it.
    private var trailingInset: CGFloat {
        let edge = Self.horizontalPadding - Self.editorLineInset
        return showsCopyButton ? edge + Self.copyButtonSize + Spacing.xs : edge
    }

    // MARK: Read-only

    private var readOnlyField: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Group {
                if let maxHeight {
                    ScrollViewWithThinIndicator(indicatorTopPadding: 0, indicatorBottomPadding: 0) {
                        selectableCode
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { highlightedHeight = $0 }
                    }
                    // Hug the code up to the cap; a bare `maxHeight` frame would
                    // always grow to it.
                    .frame(height: min(maxHeight, max(highlightedHeight, lineHeight)))
                } else {
                    selectableCode
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsCopyButton {
                copyButton(for: code)
            }
        }
        .background {
            Text(verbatim: "M")
                .font(font)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lineHeight = $0 }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inputBox(isFocused: false)
    }

    private var selectableCode: some View {
        highlightedText(code)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Pieces

    private func highlightedText(_ source: String) -> some View {
        Text(attributedCode(source))
            .font(font)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

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

    /// Kept in place (invisible and inert) while there's nothing to copy, so
    /// the box doesn't change height when the first character lands.
    private func copyButton(for value: String) -> some View {
        CopyButton(value: value, showCopied: $showCopied)
            .opacity(value.isEmpty ? 0 : 1)
            .disabled(value.isEmpty)
            .accessibilityHidden(value.isEmpty)
    }
}

// MARK: - Syntax colors

/// The color per token kind. Pastels read on a dark field; light mode gets
/// deeper tones of the same hues (the pastels were about 2:1 on the near-white
/// field). Color Blind Safe swaps in Okabe & Ito's hues, and every color is
/// then held to the theme's status contrast against the field's surfaces —
/// 4.5:1, or 7:1 under High Contrast — so a theme's cream or near-black
/// surfaces never wash a token out.
struct CodeSyntaxPalette {
    let scheme: ColorScheme

    func color(for kind: CodeTokenKind) -> Color {
        switch kind {
        case .plain: return .primary
        case .operator: return .secondary  // Subtle color for &&, ||, etc.
        case .punctuation: return Color.primary.opacity(0.5)
        default:
            return legibleColor(for: kind)?.color ?? .primary
        }
    }

    /// A colored kind's tone, held to the theme's contrast on `surfaces`; nil
    /// for the kinds drawn in the label colors.
    func legibleColor(for kind: CodeTokenKind) -> ThemeRGB? {
        guard let base = baseColor(for: kind) else { return nil }
        return StatusToneMath.legible(base, on: surfaces, ratio: BlissTheme.active.minimumStatusContrast)
    }

    private var isDark: Bool { scheme == .dark }

    func baseColor(for kind: CodeTokenKind) -> ThemeRGB? {
        if BlissTheme.active == .colorBlindSafe {
            switch kind {
            case .keyword, .key: return isDark ? ThemeRGB(0x56B4E9) : ThemeRGB(0x0072B2)  // sky blue / blue
            case .flag, .number: return ThemeRGB(0x009E73)                                 // bluish green
            case .string: return ThemeRGB(0xE69F00)                                        // orange
            case .placeholder, .literal: return ThemeRGB(0xCC79A7)                         // reddish purple
            case .comment: return isDark ? ThemeRGB(red: 0.5, green: 0.5, blue: 0.5) : ThemeRGB(red: 0.42, green: 0.42, blue: 0.42)
            case .plain, .operator, .punctuation: return nil
            }
        }
        switch kind {
        case .keyword, .key:  // Blue for commands and keys
            return isDark ? ThemeRGB(red: 0.4, green: 0.7, blue: 1.0) : ThemeRGB(red: 0.0, green: 0.36, blue: 0.75)
        case .flag, .number:  // Green for flags and numbers
            return isDark ? ThemeRGB(red: 0.6, green: 0.8, blue: 0.6) : ThemeRGB(red: 0.13, green: 0.5, blue: 0.2)
        case .string:  // Orange for strings
            return isDark ? ThemeRGB(red: 1.0, green: 0.7, blue: 0.4) : ThemeRGB(red: 0.7, green: 0.35, blue: 0.0)
        case .placeholder, .literal:  // Purple for {name}/{path} and booleans
            return isDark ? ThemeRGB(red: 0.9, green: 0.5, blue: 0.9) : ThemeRGB(red: 0.6, green: 0.15, blue: 0.6)
        case .comment:  // Gray for comments
            return isDark ? ThemeRGB(red: 0.5, green: 0.5, blue: 0.5) : ThemeRGB(red: 0.42, green: 0.42, blue: 0.42)
        case .plain, .operator, .punctuation:
            return nil
        }
    }

    /// What the field sits on: the theme's content and raised surfaces, or the
    /// system's control and window backgrounds.
    var surfaces: [ThemeRGB] {
        if let palette = BlissTheme.active.palette(for: scheme) {
            return [palette.contentBackground, palette.elevatedBackground]
        }
        return [NSColor.controlBackgroundColor, NSColor.windowBackgroundColor].map(resolved)
    }

    private func resolved(_ color: NSColor) -> ThemeRGB {
        var rgb = ThemeRGB(isDark ? 0x1E1E1E : 0xFFFFFF)
        NSAppearance(named: isDark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            if let srgb = color.usingColorSpace(.sRGB) {
                rgb = ThemeRGB(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
            }
        }
        return rgb
    }
}

// MARK: - Preview

private struct CodeFieldPreviewHost: View {
    @State private var command = "cd {path} && composer install --no-dev | tee \"install.log\""
    @State private var workflow = """
    # Runs on every push
    name: CI
    on:
      push:
        branches: [main]
    jobs:
      build:
        runs-on: macos-15
        timeout-minutes: 30
        steps:
          - uses: actions/checkout@v4
          - run: swift test
            continue-on-error: false
    """

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            CodeField(text: $command, highlighter: .shell, prompt: "composer create-project…")
            CodeField(text: $workflow, highlighter: .yaml, layout: .editor(height: 180), font: Typography.codeSmall)
            CodeField(code: "git clone \"https://github.com/user/repo\" {path}", highlighter: .shell)
        }
        .padding(Spacing.xl)
    }
}

#Preview(traits: .fixedLayout(width: 520, height: 400)) {
    CodeFieldPreviewHost()
}
