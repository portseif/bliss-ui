import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: avatars, breadcrumbs, the
/// inspector split and the code field, built the way an app would build them.
@MainActor
@Suite struct LayoutAPITests {
    private struct Member {
        let name: String
        let photo: Image?
    }

    private struct Folder {
        let name: String
        let isFile: Bool
    }

    @Test func avatarsAreReachable() {
        _ = Avatar(name: "Ada Lovelace")
        _ = Avatar(name: "Grace Hopper", image: Image(systemName: "person"), size: .large, shape: .rounded, status: .online)
        for size in AvatarSize.allCases {
            _ = Avatar(name: "Alan Turing", size: size)
            #expect(size.diameter > 0)
        }
        for status in AvatarStatus.allCases {
            _ = Avatar(name: "Katherine Johnson", status: status)
        }
        #expect(AvatarSize.small.diameter < AvatarSize.medium.diameter)
        #expect(AvatarSize.medium.diameter < AvatarSize.large.diameter)
        _ = AvatarShape.circle
    }

    @Test func avatarStacksAreReachable() {
        let members = [Member(name: "Ada", photo: nil), Member(name: "Grace", photo: Image(systemName: "person"))]
        _ = AvatarStack(members, name: \.name, image: \.photo)
        _ = AvatarStack(members, name: { $0.name }, limit: 1, size: .small, shape: .rounded)
        _ = AvatarStack(names: ["Ada", "Grace", "Alan"])
        _ = AvatarStack(names: [], limit: 3, size: .large, shape: .circle)
    }

    @Test func breadcrumbsAreReachable() {
        let folders = [Folder(name: "Projects", isFile: false), Folder(name: "README.md", isFile: true)]
        _ = Breadcrumbs(folders, title: \.name) { _ in }
        _ = Breadcrumbs(folders, title: { $0.name }, systemImage: { $0.isFile ? "doc" : "folder" }, font: Typography.headingSmall) { _ in }
        _ = Breadcrumbs(["Home"], title: { $0 }, onSelect: { _ in })
    }

    @Test func inspectorSplitIsReachable() {
        _ = InspectorSplit(isPresented: .constant(true)) {
            Text("Content")
        } inspector: {
            Text("Inspector")
        }
        _ = InspectorSplit(
            isPresented: .constant(false),
            isPinned: .constant(false),
            idealWidth: 300,
            minWidth: 200,
            maxWidth: 500,
            widthStorageKey: "layoutAPITests.inspectorWidth"
        ) {
            Color.clear
        } inspector: {
            Color.clear
        }
    }

    @Test func codeFieldsAreReachable() {
        _ = CodeField(text: .constant("npm install"))
        _ = CodeField(text: .constant("swift build"), highlighter: .shell, prompt: "Command", layout: .singleLine, font: Typography.codeSmall, showsCopyButton: false)
        _ = CodeField(text: .constant("name: CI"), highlighter: .yaml, layout: .editor(height: 200))
        _ = CodeField(code: "git status")
        _ = CodeField(code: "key: value", highlighter: .yaml, font: Typography.codeTiny, maxHeight: 120, showsCopyButton: false)
        _ = CodeField(text: .constant("")).onSubmit {}
    }

    @Test func highlightersArePluggable() {
        let custom = CodeHighlighter { text in [CodeToken(text, kind: .keyword)] }
        #expect(custom.tokens(in: "select") == [CodeToken("select", kind: .keyword)])

        let rules = CodeHighlighter(rules: [
            CodeHighlightRule(#"--[^\n]*"#, kind: .comment),
            CodeHighlightRule(#"\d+"#, kind: .number),
        ])
        let tokens = rules.tokens(in: "limit 10 -- page")
        #expect(tokens.map(\.text).joined() == "limit 10 -- page")
        #expect(tokens.contains(CodeToken("10", kind: .number)))
        #expect(tokens.last == CodeToken("-- page", kind: .comment))

        for highlighter in [CodeHighlighter.plain, .shell, .yaml] {
            #expect(highlighter.tokens(in: "a: b").map(\.text).joined() == "a: b")
        }
        let token = CodeToken("x", kind: .plain)
        #expect(token.text == "x" && token.kind == .plain)
        #expect(CodeTokenKind.allCases.count > 1)
        let rule = CodeHighlightRule("x", kind: .string)
        #expect(rule.pattern == "x" && rule.kind == .string)
        #expect(CodeFieldLayout.editor(height: 10) != .singleLine)
    }
}
