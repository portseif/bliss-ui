import SwiftUI
import Testing
@testable import BlissUI

/// The logic behind the layout components: avatar initials and colors, the
/// stack's overflow, breadcrumb collapsing, inspector width clamping and the
/// code highlighters.
@MainActor
@Suite struct LayoutTests {
    // MARK: Avatar initials

    @Test(arguments: [
        ("Ada Lovelace", "AL"),
        ("ada lovelace", "AL"),
        ("Mary Jane Watson", "MW"),
        ("Grace", "G"),
        ("grace@example.com", "G"),
        ("  Alan   Turing  ", "AT"),
        ("José-María López", "JL"),
        ("Élodie Durand", "ÉD"),
        ("e\u{301}lodie durand", "ÉD"),
        ("🦊 Fox", "F"),
        ("(Ada) - Lovelace", "AL"),
        ("R2 D2", "RD"),
        ("", ""),
        ("   ", ""),
        ("🦊", ""),
    ])
    func latinInitials(name: String, expected: String) {
        #expect(AvatarInitials.initials(for: name) == expected)
    }

    @Test(arguments: [
        ("Анна Каренина", "АК"),
        ("Ελένη Παππά", "ΕΠ"),
        ("محمد علي", "مع"),
        ("דוד כהן", "דכ"),
        ("山田太郎", "山"),
        ("山田 太郎", "山"),
        ("李", "李"),
        ("김민준", "김"),
        ("やまだ たろう", "や"),
        ("Ada 山田", "A"),
    ])
    func nonLatinInitials(name: String, expected: String) {
        #expect(AvatarInitials.initials(for: name) == expected)
    }

    // MARK: Avatar colors

    @Test func colorIsDeterministic() {
        // FNV-1a of "a" is 0xE40C292C (the published test vector), and
        // 0xE40C292C % 10 == 0: a hash seeded per process would fail this.
        #expect(AvatarPalette.hues.count == 10)
        #expect(AvatarPalette.hueIndex(for: "a") == 0)
        #expect(AvatarPalette.hueIndex(for: "Ada Lovelace") == 8)
        #expect(AvatarPalette.hueIndex(for: "Grace Hopper") == 1)
        #expect(AvatarPalette.hueIndex(for: "Alan Turing") == 6)
        // Case and surrounding whitespace don't change it.
        #expect(AvatarPalette.hueIndex(for: "  ada LOVELACE ") == AvatarPalette.hueIndex(for: "Ada Lovelace"))
        #expect(AvatarPalette.fill(for: "Ada Lovelace") == AvatarPalette.fill(for: "Ada Lovelace"))
    }

    @Test func colorsSpreadAcrossNames() {
        let names = ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra",
                     "Barbara Liskov", "Donald Knuth", "Margaret Hamilton", "Ken Thompson", "Frances Allen",
                     "Linus Torvalds", "Hedy Lamarr", "Tim Berners-Lee", "Radia Perlman", "John McCarthy"]
        let indices = Set(names.map(AvatarPalette.hueIndex(for:)))
        #expect(indices.count >= 5)
        #expect(indices.allSatisfy { AvatarPalette.hues.indices.contains($0) })
    }

    @Test func initialsAreReadableOnEveryFill() {
        let ratio = BlissTheme.active.minimumStatusContrast
        let foreground = AvatarPalette.foreground
        for name in ["Ada Lovelace", "Grace Hopper", "Alan Turing", "山田太郎", "Анна", "🦊", ""] {
            let fill = AvatarPalette.fill(for: name)
            #expect(StatusToneMath.contrast(fill, foreground) >= ratio, "\(name)")
        }
        // Every hue, at the strictest built-in ratio (High Contrast's 7:1).
        for hue in AvatarPalette.hues {
            let base = StatusToneMath.rgb(hue: hue / 360, saturation: 0.55, brightness: 0.8)
            let fill = StatusToneMath.legible(base, on: [ThemeRGB(0xFFFFFF)], ratio: 7)
            #expect(StatusToneMath.contrast(fill, ThemeRGB(0xFFFFFF)) >= 7, "hue \(hue)")
        }
    }

    // MARK: Avatar stack

    @Test func stackOverflow() {
        #expect(AvatarStack<String>.split(count: 0, limit: 4) == (0, 0))
        #expect(AvatarStack<String>.split(count: 3, limit: 4) == (3, 0))
        #expect(AvatarStack<String>.split(count: 4, limit: 4) == (4, 0))
        // One over the limit shows everyone: a "+1" would take the same room.
        #expect(AvatarStack<String>.split(count: 5, limit: 4) == (5, 0))
        #expect(AvatarStack<String>.split(count: 6, limit: 4) == (4, 2))
        #expect(AvatarStack<String>.split(count: 30, limit: 3) == (3, 27))
        #expect(AvatarStack<String>.split(count: 3, limit: 1) == (1, 2))
    }

    // MARK: Breadcrumbs

    private func collapse(_ widths: [CGFloat], available: CGFloat, separator: CGFloat = 20, overflow: CGFloat = 16) -> Range<Int> {
        BreadcrumbCollapse.collapsedRange(widths: widths, separatorWidth: separator, overflowWidth: overflow, availableWidth: available)
    }

    @Test func breadcrumbsFitWithoutCollapsing() {
        let widths: [CGFloat] = [50, 50, 50, 50, 50]  // 250 + 4 × 20 = 330
        #expect(collapse(widths, available: 330).isEmpty)
        #expect(collapse(widths, available: 400).isEmpty)
        // Within the half-point slack for fractional widths.
        #expect(collapse(widths, available: 329.6).isEmpty)
    }

    @Test func breadcrumbsCollapseFromTheRoot() {
        let widths: [CGFloat] = [50, 50, 50, 50, 50]
        // First + … + last = 156; each segment back from the end adds 70.
        #expect(collapse(widths, available: 329) == 1..<2)
        #expect(collapse(widths, available: 296) == 1..<2)
        #expect(collapse(widths, available: 295) == 1..<3)
        #expect(collapse(widths, available: 226) == 1..<3)
        #expect(collapse(widths, available: 225) == 1..<4)
        // Too narrow for even first + … + last: everything in the middle folds
        // and the last segment truncates.
        #expect(collapse(widths, available: 60) == 1..<4)
    }

    @Test func shortPathsNeverCollapse() {
        #expect(collapse([], available: 10).isEmpty)
        #expect(collapse([200], available: 10).isEmpty)
        #expect(collapse([200, 200], available: 10).isEmpty)
        #expect(collapse([100, 100, 100], available: 10) == 1..<2)
    }

    @Test func breadcrumbsDontCollapseIntoSomethingWider() {
        // Hiding a 10pt segment behind a 30pt "…" makes the path longer.
        #expect(collapse([50, 10, 50], available: 140, overflow: 30).isEmpty)
        #expect(collapse([50, 60, 50], available: 140, overflow: 30) == 1..<2)
    }

    // MARK: Inspector width

    @Test func inspectorWidthClamps() {
        func clamp(_ width: CGFloat, container: CGFloat? = nil) -> CGFloat {
            InspectorSplitMetrics.clampedWidth(width, minWidth: 200, maxWidth: 480, containerWidth: container)
        }
        #expect(clamp(300) == 300)
        #expect(clamp(100) == 200)
        #expect(clamp(900) == 480)
        #expect(clamp(250.4) == 250)
        // The content keeps its minimum once the container is known.
        let minimumContent = InspectorSplitMetrics.minimumContentWidth
        #expect(clamp(450, container: 500) == 500 - minimumContent)
        #expect(clamp(300, container: 500) == 300)
        #expect(clamp(450, container: 2_000) == 450)
        // Too small a container for even the minimum: the minimum wins.
        #expect(clamp(450, container: 250) == 200)
        // An unmeasured container doesn't count.
        #expect(clamp(450, container: 0) == 450)
        // A maximum below the minimum can't invert the range.
        #expect(InspectorSplitMetrics.clampedWidth(500, minWidth: 300, maxWidth: 100, containerWidth: nil) == 300)
    }

    // MARK: Shell highlighting

    private func kinds(_ tokens: [CodeToken]) -> [CodeTokenKind] { tokens.map(\.kind) }

    @Test func shellTokens() {
        let tokens = ShellTokenizer.tokens(in: "cd {path} && composer install --no-dev | tee \"install.log\"")
        #expect(tokens == [
            CodeToken("cd", kind: .keyword), CodeToken(" ", kind: .plain),
            CodeToken("{path}", kind: .placeholder), CodeToken(" ", kind: .plain),
            CodeToken("&&", kind: .operator), CodeToken(" ", kind: .plain),
            CodeToken("composer", kind: .keyword), CodeToken(" ", kind: .plain),
            CodeToken("install", kind: .plain), CodeToken(" ", kind: .plain),
            CodeToken("--no-dev", kind: .flag), CodeToken(" ", kind: .plain),
            CodeToken("|", kind: .operator), CodeToken(" ", kind: .plain),
            CodeToken("tee", kind: .keyword), CodeToken(" ", kind: .plain),
            CodeToken("\"install.log\"", kind: .string),
        ])
    }

    @Test func shellLinesAndComments() {
        let tokens = ShellTokenizer.tokens(in: "npm ci\nnpm test # quick")
        #expect(tokens.filter { $0.kind == .keyword }.map(\.text) == ["npm", "npm"])
        #expect(tokens.last == CodeToken("# quick", kind: .comment))
        // `;` and `||` start a new command too.
        let chained = ShellTokenizer.tokens(in: "make;make test || echo failed")
        #expect(chained.filter { $0.kind == .keyword }.map(\.text) == ["make", "make", "echo"])
    }

    @Test(arguments: [
        "git clone \"https://github.com/user/repo\" {path}",
        "echo 'unterminated",
        "sleep 1 & wait",
        "open {unclosed",
        "a&&b||c|d;e",
        "  leading and trailing  ",
        "-flag-first --x=1",
        "multi\nline\n\nscript\n",
        "",
    ])
    func shellTokensCoverTheText(input: String) {
        #expect(ShellTokenizer.tokens(in: input).map(\.text).joined() == input)
    }

    // MARK: YAML highlighting

    @Test func yamlKeyValues() {
        #expect(YAMLTokenizer.tokens(in: "name: CI") == [
            CodeToken("name", kind: .key), CodeToken(":", kind: .punctuation),
            CodeToken(" ", kind: .plain), CodeToken("CI", kind: .string),
        ])
        #expect(kinds(YAMLTokenizer.tokens(in: "timeout: 30")).last == .number)
        #expect(kinds(YAMLTokenizer.tokens(in: "enabled: true")).last == .literal)
        #expect(kinds(YAMLTokenizer.tokens(in: "value: ~")).last == .literal)
        #expect(kinds(YAMLTokenizer.tokens(in: "title: \"Hello\"")).last == .string)
        #expect(kinds(YAMLTokenizer.tokens(in: "on:")) == [.key, .punctuation])
    }

    @Test func yamlListItemsKeepTheirKeys() {
        #expect(YAMLTokenizer.tokens(in: "  - uses: actions/checkout@v4") == [
            CodeToken("  ", kind: .plain), CodeToken("- ", kind: .punctuation),
            CodeToken("uses", kind: .key), CodeToken(":", kind: .punctuation),
            CodeToken(" ", kind: .plain), CodeToken("actions/checkout@v4", kind: .string),
        ])
        #expect(kinds(YAMLTokenizer.tokens(in: "- main")) == [.punctuation, .string])
    }

    @Test func yamlColonsAndHashesInValues() {
        // One key, not two: the URL's colon has no space after it.
        let url = YAMLTokenizer.tokens(in: "url: https://example.com:8080")
        #expect(url.filter { $0.kind == .key }.map(\.text) == ["url"])
        #expect(url.last == CodeToken("https://example.com:8080", kind: .string))
        // A quoted # isn't a comment; one after a space is.
        #expect(!kinds(YAMLTokenizer.tokens(in: "color: \"#fff\"")).contains(.comment))
        let commented = YAMLTokenizer.tokens(in: "on: true # always")
        #expect(commented.last == CodeToken("# always", kind: .comment))
        #expect(commented.contains(CodeToken("true", kind: .literal)))
        #expect(YAMLTokenizer.tokens(in: "  # a comment line") == [
            CodeToken("  ", kind: .plain), CodeToken("# a comment line", kind: .comment),
        ])
    }

    @Test(arguments: [
        "name: CI\non:\n  push:\n    branches: [main]\n",
        "key:   value   \n\tindented: 1",
        "- \n-\n- a: b # c",
        "\"quoted key\": 1",
        "plain text only",
        "\n\n",
        "",
    ])
    func yamlTokensCoverTheText(input: String) {
        #expect(YAMLTokenizer.tokens(in: input).map(\.text).joined() == input)
    }

    // MARK: Rule highlighting

    @Test func ruleHighlighting() {
        let rules = [
            CodeHighlightRule(#"--[^\n]*"#, kind: .comment),
            CodeHighlightRule(#"(?i)\bselect\b"#, kind: .keyword),
            CodeHighlightRule(#"\d+"#, kind: .number),
        ]
        #expect(RuleTokenizer.tokens(in: "SELECT 1 -- one", rules: rules) == [
            CodeToken("SELECT", kind: .keyword), CodeToken(" ", kind: .plain),
            CodeToken("1", kind: .number), CodeToken(" ", kind: .plain),
            CodeToken("-- one", kind: .comment),
        ])
        // The earlier rule wins an overlap: a keyword inside a comment stays a comment.
        #expect(RuleTokenizer.tokens(in: "-- select 2", rules: rules) == [CodeToken("-- select 2", kind: .comment)])
        // A pattern that doesn't compile matches nothing.
        #expect(RuleTokenizer.tokens(in: "a(b", rules: [CodeHighlightRule("(", kind: .string)]) == [CodeToken("a(b", kind: .plain)])
        #expect(RuleTokenizer.tokens(in: "", rules: rules).isEmpty)
    }

    // MARK: Syntax colors

    @Test(arguments: [ColorScheme.light, .dark])
    func syntaxColorsAreReadable(scheme: ColorScheme) {
        let palette = CodeSyntaxPalette(scheme: scheme)
        let ratio = BlissTheme.active.minimumStatusContrast
        for kind in CodeTokenKind.allCases {
            guard let color = palette.legibleColor(for: kind) else { continue }
            for surface in palette.surfaces {
                #expect(StatusToneMath.contrast(color, surface) >= ratio, "\(kind) in \(scheme)")
            }
        }
        #expect(palette.legibleColor(for: .plain) == nil)
        #expect(palette.legibleColor(for: .keyword) != nil)
    }
}
