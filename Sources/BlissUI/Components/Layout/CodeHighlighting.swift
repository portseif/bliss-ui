//
//  CodeHighlighting.swift
//  BlissUI
//
//  What `CodeField` colors with: a highlighter splits the text into runs, each
//  tagged with a kind (command, flag, string, comment…), and the field picks a
//  color per kind. Shell and YAML ship; an app adds a language with its own
//  tokenizer or a list of regex rules.
//

import Foundation

// MARK: - Tokens

/// What a run of code is, which decides its color. Kinds are semantic, so any
/// language maps onto them: a SQL keyword is `.keyword`, a JSON key `.key`.
public nonisolated enum CodeTokenKind: Hashable, Sendable, CaseIterable {
    /// Text with no special meaning, and whitespace.
    case plain
    /// A language keyword, or the program a shell command starts with.
    case keyword
    /// A mapping key (YAML, JSON, TOML).
    case key
    /// A command-line option (`--save-dev`, `-v`).
    case flag
    /// A quoted string, or a YAML scalar value.
    case string
    /// A number.
    case number
    /// `true` / `false` / `null` and other built-in literals.
    case literal
    /// A template placeholder the app fills in (`{name}`, `{path}`).
    case placeholder
    /// A comment.
    case comment
    /// A command chain operator (`&&`, `||`, `|`, `;`).
    case `operator`
    /// Separators that structure the text (YAML's `:` and `- `).
    case punctuation
}

/// One run of a highlighted text. A highlighter's tokens cover the text
/// exactly, in order, so joining their `text` gives it back.
public nonisolated struct CodeToken: Hashable, Sendable {
    public var text: String
    public var kind: CodeTokenKind

    public init(_ text: String, kind: CodeTokenKind) {
        self.text = text
        self.kind = kind
    }
}

// MARK: - Highlighter

/// Splits code into colored runs for `CodeField`. Use `.shell` or `.yaml`, or
/// add a language:
///
/// ```swift
/// extension CodeHighlighter {
///     static let sql = CodeHighlighter(rules: [
///         CodeHighlightRule(#"--[^\n]*"#, kind: .comment),
///         CodeHighlightRule(#"'[^']*'"#, kind: .string),
///         CodeHighlightRule(#"(?i)\b(select|from|where|join|order by)\b"#, kind: .keyword),
///         CodeHighlightRule(#"\b\d+(\.\d+)?\b"#, kind: .number),
///     ])
/// }
/// ```
///
/// or with a tokenizer of your own: `CodeHighlighter { text in [CodeToken(text, kind: .plain)] }`.
/// The tokens must cover the text exactly; the field shows them over the
/// editor, so a dropped character would shift everything after it.
public nonisolated struct CodeHighlighter: Sendable {
    private let tokenize: @Sendable (String) -> [CodeToken]

    /// A highlighter from a tokenizer whose tokens cover its input exactly.
    public init(tokenize: @escaping @Sendable (String) -> [CodeToken]) {
        self.tokenize = tokenize
    }

    /// A highlighter from regex rules: every match of a rule takes its kind,
    /// the first rule wins where matches overlap, and the rest is plain.
    public init(rules: [CodeHighlightRule]) {
        self.init { RuleTokenizer.tokens(in: $0, rules: rules) }
    }

    /// `text`'s runs, in order.
    public func tokens(in text: String) -> [CodeToken] {
        tokenize(text)
    }

    /// No highlighting: the code font only.
    public static let plain = CodeHighlighter { text in text.isEmpty ? [] : [CodeToken(text, kind: .plain)] }

    /// Shell commands: the command words, flags, quoted strings, `{placeholder}`s,
    /// chain operators (`&&`, `||`, `|`, `;`) and `#` comments.
    public static let shell = CodeHighlighter { ShellTokenizer.tokens(in: $0) }

    /// YAML: keys, quoted and plain values, numbers, booleans and null, list
    /// markers and comments.
    public static let yaml = CodeHighlighter { YAMLTokenizer.tokens(in: $0) }
}

/// A regex and the kind its matches get, for `CodeHighlighter(rules:)`.
public nonisolated struct CodeHighlightRule: Sendable {
    public let pattern: String
    public let kind: CodeTokenKind

    /// - Parameters:
    ///   - pattern: A regular expression (Swift `Regex` syntax). A pattern that
    ///     doesn't compile matches nothing.
    ///   - kind: What its matches are.
    public init(_ pattern: String, kind: CodeTokenKind) {
        self.pattern = pattern
        self.kind = kind
    }
}

// MARK: - Rule tokenizer

nonisolated enum RuleTokenizer {
    static func tokens(in text: String, rules: [CodeHighlightRule]) -> [CodeToken] {
        guard !text.isEmpty else { return [] }
        // Every rule's matches, earlier rules first, keeping only those that
        // don't overlap one already taken.
        var claimed: [(range: Range<String.Index>, kind: CodeTokenKind)] = []
        for rule in rules {
            guard let regex = try? Regex(rule.pattern) else { continue }
            for match in text.matches(of: regex) where !match.range.isEmpty {
                let range = match.range
                if !claimed.contains(where: { $0.range.overlaps(range) }) {
                    claimed.append((range, rule.kind))
                }
            }
        }
        claimed.sort { $0.range.lowerBound < $1.range.lowerBound }

        var tokens: [CodeToken] = []
        var cursor = text.startIndex
        for (range, kind) in claimed {
            if cursor < range.lowerBound {
                tokens.append(CodeToken(String(text[cursor..<range.lowerBound]), kind: .plain))
            }
            tokens.append(CodeToken(String(text[range]), kind: kind))
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            tokens.append(CodeToken(String(text[cursor...]), kind: .plain))
        }
        return tokens
    }
}

// MARK: - Shell tokenizer

nonisolated enum ShellTokenizer {
    /// Characters that end a plain word.
    private static func endsWord(_ character: Character) -> Bool {
        character.isWhitespace || "{}|&;\"'".contains(character)
    }

    static func tokens(in input: String) -> [CodeToken] {
        var tokens: [CodeToken] = []
        var remaining = input[...]
        var expectCommand = true  // Next word should be colored as command

        while !remaining.isEmpty {
            let startCount = remaining.count  // Safety check to prevent infinite loops

            // Whitespace (including newlines). A new line starts a new command.
            let whitespace = remaining.prefix(while: \.isWhitespace)
            if !whitespace.isEmpty {
                tokens.append(CodeToken(String(whitespace), kind: .plain))
                if whitespace.contains(where: \.isNewline) { expectCommand = true }
                remaining = remaining.dropFirst(whitespace.count)
                continue
            }

            // Command chain operators: &&, ||, ;, |
            if let chain = ["&&", "||", "|", ";"].first(where: { remaining.hasPrefix($0) }) {
                tokens.append(CodeToken(chain, kind: .operator))
                remaining = remaining.dropFirst(chain.count)
                expectCommand = true  // Next word is a new command
                continue
            }

            // A comment runs to the end of the line.
            if remaining.hasPrefix("#") {
                let comment = remaining.prefix(while: { !$0.isNewline })
                tokens.append(CodeToken(String(comment), kind: .comment))
                remaining = remaining.dropFirst(comment.count)
                continue
            }

            // Placeholder {name} or {path}
            if remaining.hasPrefix("{") {
                if let endIndex = remaining.firstIndex(of: "}") {
                    let placeholder = String(remaining[remaining.startIndex...endIndex])
                    tokens.append(CodeToken(placeholder, kind: .placeholder))
                    remaining = remaining[remaining.index(after: endIndex)...]
                } else {
                    // Incomplete placeholder - treat { as text
                    tokens.append(CodeToken("{", kind: .plain))
                    remaining = remaining.dropFirst(1)
                }
                expectCommand = false
                continue
            }

            // Quoted string (an unterminated one runs to the end)
            if let quote = remaining.first, quote == "\"" || quote == "'" {
                var endIndex = remaining.index(after: remaining.startIndex)
                while endIndex < remaining.endIndex && remaining[endIndex] != quote {
                    endIndex = remaining.index(after: endIndex)
                }
                if endIndex < remaining.endIndex {
                    endIndex = remaining.index(after: endIndex)
                }
                tokens.append(CodeToken(String(remaining[..<endIndex]), kind: .string))
                remaining = remaining[endIndex...]
                expectCommand = false
                continue
            }

            // Flag (starts with -)
            if remaining.hasPrefix("-") {
                let flag = remaining.prefix(while: { !$0.isWhitespace && !"|&;".contains($0) })
                tokens.append(CodeToken(String(flag), kind: .flag))
                remaining = remaining.dropFirst(flag.count)
                expectCommand = false
                continue
            }

            // Word (stop at operators and special chars)
            let word = remaining.prefix(while: { !endsWord($0) })
            if !word.isEmpty {
                tokens.append(CodeToken(String(word), kind: expectCommand ? .keyword : .plain))
                remaining = remaining.dropFirst(word.count)
                expectCommand = false
                continue
            }

            // Safety: if nothing matched, consume one character to prevent infinite loop
            if remaining.count == startCount {
                tokens.append(CodeToken(String(remaining.prefix(1)), kind: .plain))
                remaining = remaining.dropFirst(1)
                expectCommand = false
            }
        }

        return tokens
    }
}

// MARK: - YAML tokenizer

nonisolated enum YAMLTokenizer {
    static func tokens(in input: String) -> [CodeToken] {
        var tokens: [CodeToken] = []
        let lines = input.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            tokens.append(contentsOf: tokenizeLine(line))
            if index < lines.count - 1 {
                tokens.append(CodeToken("\n", kind: .plain))
            }
        }
        return tokens
    }

    private static func isIndent(_ character: Character) -> Bool {
        character == " " || character == "\t"
    }

    /// - Parameter isListItem: The rest of a `- ` line, where a bare value is
    ///   a string (`- main`) rather than plain text.
    static func tokenizeLine(_ line: String, isListItem: Bool = false) -> [CodeToken] {
        var tokens: [CodeToken] = []

        // Handle empty lines
        if line.isEmpty {
            return tokens
        }

        // Leading whitespace
        let leadingWhitespace = String(line.prefix(while: isIndent))
        if !leadingWhitespace.isEmpty {
            tokens.append(CodeToken(leadingWhitespace, kind: .plain))
        }

        let trimmedLine = String(line.dropFirst(leadingWhitespace.count))

        // Comment line
        if trimmedLine.hasPrefix("#") {
            tokens.append(CodeToken(trimmedLine, kind: .comment))
            return tokens
        }

        // List item marker. What follows can be a `key: value` of its own
        // (`- name: Checkout`), so it's read like a line.
        if trimmedLine.hasPrefix("- ") || trimmedLine == "-" {
            let marker = trimmedLine.hasPrefix("- ") ? "- " : "-"
            tokens.append(CodeToken(marker, kind: .punctuation))
            tokens.append(contentsOf: tokenizeLine(String(trimmedLine.dropFirst(marker.count)), isListItem: true))
            return tokens
        }

        // Key: value pair. The colon has to end the line or be followed by a
        // space — `url: https://example.com` has one key, not two.
        if let colonIndex = keySeparator(in: trimmedLine) {
            tokens.append(CodeToken(String(trimmedLine[..<colonIndex]), kind: .key))
            tokens.append(CodeToken(":", kind: .punctuation))
            tokens.append(contentsOf: tokenizeValueAndComment(String(trimmedLine[trimmedLine.index(after: colonIndex)...])))
            return tokens
        }

        // Plain text, and a flow value with no key (`[a, b]`)
        tokens.append(contentsOf: tokenizeValueAndComment(trimmedLine, plainValue: !isListItem))
        return tokens
    }

    /// The colon after a mapping key: outside quotes, at the end of the line
    /// or before whitespace.
    private static func keySeparator(in line: String) -> String.Index? {
        guard let first = line.first, first != "\"", first != "'", first != "[", first != "{" else {
            return quotedKeySeparator(in: line)
        }
        var index = line.startIndex
        while index < line.endIndex {
            if line[index] == "#" && index > line.startIndex && line[line.index(before: index)].isWhitespace { return nil }
            if line[index] == ":" {
                let next = line.index(after: index)
                if next == line.endIndex || line[next].isWhitespace { return index }
            }
            index = line.index(after: index)
        }
        return nil
    }

    /// `"quoted key": value`.
    private static func quotedKeySeparator(in line: String) -> String.Index? {
        guard let quote = line.first, quote == "\"" || quote == "'",
              let closing = line.dropFirst().firstIndex(of: quote) else { return nil }
        let colon = line.index(after: closing)
        guard colon < line.endIndex, line[colon] == ":" else { return nil }
        let next = line.index(after: colon)
        return next == line.endIndex || line[next].isWhitespace ? colon : nil
    }

    /// A value, then an inline comment if one follows: `#` after whitespace,
    /// outside quotes (`color: "#fff"` has none).
    private static func tokenizeValueAndComment(_ text: String, plainValue: Bool = false) -> [CodeToken] {
        var inQuote: Character?
        var previous: Character = " "
        for index in text.indices {
            let character = text[index]
            if let quote = inQuote {
                if character == quote { inQuote = nil }
            } else if character == "\"" || character == "'" {
                if previous.isWhitespace || previous == ":" || index == text.startIndex { inQuote = character }
            } else if character == "#" && previous.isWhitespace {
                return tokenizeValue(String(text[..<index]), plainValue: plainValue)
                    + [CodeToken(String(text[index...]), kind: .comment)]
            }
            previous = character
        }
        return tokenizeValue(text, plainValue: plainValue)
    }

    static func tokenizeValue(_ value: String, plainValue: Bool = false) -> [CodeToken] {
        var tokens: [CodeToken] = []

        // Leading and trailing space, kept so the tokens cover the line.
        let leadingSpace = String(value.prefix(while: isIndent))
        let rest = value.dropFirst(leadingSpace.count)
        let trailingSpace = String(rest.reversed().prefix(while: isIndent).reversed())
        let trimmed = String(rest.dropLast(trailingSpace.count))
        if !leadingSpace.isEmpty {
            tokens.append(CodeToken(leadingSpace, kind: .plain))
        }

        // Empty value
        if !trimmed.isEmpty {
            tokens.append(CodeToken(trimmed, kind: valueKind(trimmed, plainValue: plainValue)))
        }
        if !trailingSpace.isEmpty {
            tokens.append(CodeToken(trailingSpace, kind: .plain))
        }
        return tokens
    }

    private static func valueKind(_ value: String, plainValue: Bool) -> CodeTokenKind {
        // Quoted string
        if value.hasPrefix("\"") || value.hasPrefix("'") {
            return .string
        }

        // Boolean and null
        let lowercased = value.lowercased()
        if ["true", "false", "yes", "no", "on", "off", "null", "~"].contains(lowercased) {
            return .literal
        }

        // Number
        if Double(value) != nil {
            return .number
        }

        // Plain text/string value
        return plainValue ? .plain : .string
    }
}
