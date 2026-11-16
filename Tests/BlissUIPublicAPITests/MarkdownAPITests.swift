import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the code block and the
/// markdown view, built the way an app would build them.
@MainActor
@Suite struct MarkdownAPITests {
    @Test func codeBlockIsReachable() {
        _ = CodeBlock("swift build")
        _ = CodeBlock("swift build --build-tests", highlighter: .shell, showsLineNumbers: true)
        _ = CodeBlock("name: CI\non: [push]", highlighter: .yaml, showsLineNumbers: false, showsCopyButton: false)
        _ = CodeBlock("", highlighter: .plain)
    }

    @Test func markdownViewIsReachable() {
        _ = MarkdownView("# Title\n\nA paragraph with **bold**, a [link](https://example.com) and `code`.\n\n- One\n- Two\n\n```sh\nswift test\n```")
        _ = MarkdownView("")
        _ = MarkdownView("plain text with no markdown at all")
    }
}
