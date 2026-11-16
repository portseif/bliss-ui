//
//  RichTextEditor.swift
//  BlissUI
//
//  A rich text field with a formatting toolbar: bold, italic, underline and
//  strikethrough, three heading levels, bulleted and numbered lists, links,
//  inline code and block quotes. The toolbar and the text sit in one input
//  box, like `MessageComposer`; the text is an `AttributedString`, so an app
//  stores and renders it with Foundation and SwiftUI alone.
//
//  The AppKit side (the hosted `NSTextView`, the controller and the
//  formatting operations) is in `RichTextEditorHost.swift`.
//

import AppKit
import SwiftUI

// MARK: - Editor

/// A rich text field with a formatting toolbar, bound to an `AttributedString`.
///
/// ```swift
/// RichTextEditor("Description", text: $description, prompt: Text("Describe the change…"))
/// ```
///
/// `title` is what VoiceOver reads for the text view — a `LocalizedStringResource`
/// like `TextArea`'s, because the hosted text view needs a resolved string.
/// ⌘B, ⌘I and ⌘U toggle bold, italic and underline; ⌘K opens the link
/// popover. The field is at least `minimumHeight` tall and grows with its
/// text; put it in a scroll view when it can grow past the window.
public struct RichTextEditor: View {
    private let title: LocalizedStringResource
    @Binding private var text: AttributedString
    private let prompt: Text?
    private let minimumHeight: CGFloat
    private let showsToolbar: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var controller = RichTextController()
    @State private var isFocused = false
    /// Bumped to put the caret in the text view (after the link popover closes).
    @State private var focusRequest = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isLinkPopoverPresented = false
    @State private var linkURL = ""

    /// - Parameters:
    ///   - title: What VoiceOver reads for the text view.
    ///   - text: The formatted text.
    ///   - prompt: Shown while the text is empty.
    ///   - minimumHeight: How tall the text area is before it has that much text.
    ///   - showsToolbar: The formatting toolbar above the text; without it the
    ///     keyboard shortcuts still work.
    public init(
        _ title: LocalizedStringResource,
        text: Binding<AttributedString>,
        prompt: Text? = nil,
        minimumHeight: CGFloat = 160,
        showsToolbar: Bool = true
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.minimumHeight = max(minimumHeight, 40)
        self.showsToolbar = showsToolbar
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsToolbar {
                RichTextToolbar(controller: controller, isLinkPopoverPresented: $isLinkPopoverPresented, onLink: presentLinkPopover) {
                    linkPopover
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                Rectangle()
                    .fill(Color.menuBorder)
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }

            RichTextEditorHost(
                text: $text,
                accessibilityLabel: String(localized: title),
                isEnabled: isEnabled,
                minimumHeight: minimumHeight,
                contentHeight: contentHeight,
                focusRequest: focusRequest,
                controller: controller,
                onFocusChange: { isFocused = $0 },
                onContentHeightChange: { contentHeight = $0 }
            )
            .overlay(alignment: .topLeading) { placeholder }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inputBox(isFocused: isFocused, cornerRadius: Sizing.radiusLarge)
        .onAppear { controller.onLinkShortcut = presentLinkPopover }
    }

    @ViewBuilder
    private var placeholder: some View {
        if text.characters.isEmpty, let prompt {
            prompt
                .font(Typography.bodySmall)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, RichTextStyle.textInset.width)
                .padding(.vertical, RichTextStyle.textInset.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Link

    private func presentLinkPopover() {
        linkURL = controller.currentLink?.absoluteString ?? ""
        isLinkPopoverPresented = true
    }

    private var linkPopover: some View {
        RichTextLinkPopover(
            url: $linkURL,
            hasLink: controller.formatting.isLink,
            onAdd: { url in
                controller.setLink(url)
                closeLinkPopover()
            },
            onRemove: {
                controller.removeLink()
                closeLinkPopover()
            },
            onCancel: closeLinkPopover
        )
    }

    private func closeLinkPopover() {
        isLinkPopoverPresented = false
        focusRequest += 1
    }
}

// MARK: - Toolbar

/// The formatting buttons, lit for the text under the caret.
private struct RichTextToolbar<LinkPopover: View>: View {
    let controller: RichTextController
    @Binding var isLinkPopoverPresented: Bool
    let onLink: () -> Void
    @ViewBuilder let linkPopover: () -> LinkPopover

    @State private var isHeadingMenuPresented = false
    @State private var headingFocusedIndex: Int?

    private var formatting: RichTextFormatting { controller.formatting }

    var body: some View {
        HStack(spacing: Spacing.hairline) {
            toolButton("bold", label: Text("Bold", bundle: .module), isActive: formatting.isBold, action: controller.toggleBold)
            toolButton("italic", label: Text("Italic", bundle: .module), isActive: formatting.isItalic, action: controller.toggleItalic)
            toolButton("underline", label: Text("Underline", bundle: .module), isActive: formatting.isUnderlined, action: controller.toggleUnderline)
            toolButton("strikethrough", label: Text("Strikethrough", bundle: .module), isActive: formatting.isStruck, action: controller.toggleStrikethrough)

            separator

            headingButton

            separator

            toolButton("list.bullet", label: Text("Bulleted list", bundle: .module), isActive: formatting.list == .bulleted) {
                controller.toggleList(.bulleted)
            }
            toolButton("list.number", label: Text("Numbered list", bundle: .module), isActive: formatting.list == .numbered) {
                controller.toggleList(.numbered)
            }

            separator

            toolButton("link", label: Text("Link", bundle: .module), isActive: formatting.isLink, action: onLink)
                .popover(isPresented: $isLinkPopoverPresented, arrowEdge: .bottom) {
                    linkPopover()
                }
            toolButton("chevron.left.forwardslash.chevron.right", label: Text("Code", bundle: .module), isActive: formatting.isCode, action: controller.toggleCode)
            toolButton("text.quote", label: Text("Quote", bundle: .module), isActive: formatting.isQuote, action: controller.toggleQuote)

            Spacer(minLength: 0)
        }
    }

    private func toolButton(_ systemImage: String, label: Text, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(ToolbarIconButtonStyle(isActive: isActive, compact: true))
        .tooltip(position: .above) { label.font(Typography.labelSmall) }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(width: 1, height: Sizing.iconDefault)
            .padding(.horizontal, Spacing.xxs)
            .accessibilityHidden(true)
    }

    /// Body and the three headings in a floating menu, the current one checked.
    private var headingButton: some View {
        Button {
            isHeadingMenuPresented.toggle()
        } label: {
            Image(systemName: "textformat")
        }
        .buttonStyle(ToolbarIconButtonStyle(isActive: formatting.heading.isHeading || isHeadingMenuPresented, compact: true))
        .tooltip(position: .above) { Text("Text style", bundle: .module).font(Typography.labelSmall) }
        .accessibilityLabel(Text("Text style", bundle: .module))
        .accessibilityValue(Text(verbatim: RichTextHeadingMenu.title(for: formatting.heading)))
        .floatingMenu(
            isPresented: $isHeadingMenuPresented,
            itemCount: RichTextHeading.allCases.count,
            focusedIndex: $headingFocusedIndex,
            xPosition: .leading,
            yPosition: .below,
            onActivate: { index in
                pickHeading(at: index)
                return .dismiss
            }
        ) {
            RichTextHeadingMenu(controller: controller, focusedIndex: $headingFocusedIndex, onPick: pickHeading)
        }
    }

    private func pickHeading(at index: Int) {
        let headings = RichTextHeading.allCases
        guard headings.indices.contains(index) else { return }
        controller.setHeading(headings[index])
        isHeadingMenuPresented = false
    }
}

/// The heading menu's rows. A `View` struct with bindings: the floating menu
/// snapshots its content at open.
private struct RichTextHeadingMenu: View {
    let controller: RichTextController
    @Binding var focusedIndex: Int?
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(RichTextHeading.allCases.enumerated()), id: \.offset) { index, heading in
                let isCurrent = controller.formatting.heading == heading
                FilterMenuRow(.verbatim(Self.title(for: heading)), isFocused: focusedIndex == index, isSelected: isCurrent) {
                    onPick(index)
                } leading: {
                    Image(systemName: "checkmark")
                        .font(Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .frame(width: Sizing.iconDefault)
                        .opacity(isCurrent ? 1 : 0)
                }
                .onHover { if $0 { focusedIndex = index } }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: 160)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The style's name, from the library's strings.
    static func title(for heading: RichTextHeading) -> String {
        switch heading {
        case .body: return String(localized: "Body", bundle: .module)
        case .heading1: return String(localized: "Heading 1", bundle: .module)
        case .heading2: return String(localized: "Heading 2", bundle: .module)
        case .heading3: return String(localized: "Heading 3", bundle: .module)
        }
    }
}

// MARK: - Link popover

/// The URL field with Add, Cancel and (over an existing link) Remove. A
/// native popover on purpose: a floating panel can't become key, and the
/// field must.
private struct RichTextLinkPopover: View {
    @Binding var url: String
    let hasLink: Bool
    let onAdd: (URL) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    private var parsedURL: URL? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let candidate = URL(string: withScheme), candidate.host != nil else { return nil }
        return candidate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Add link", bundle: .module)
                .font(Typography.bodySmallSemibold)
            InputField(.verbatim(String(localized: "URL", bundle: .module)), text: $url, prompt: Text(verbatim: "https://"), systemImage: "link", isClearable: true)
                .onSubmit(add)
            HStack(spacing: Spacing.sm) {
                if hasLink {
                    Button(String(localized: "Remove link", bundle: .module), action: onRemove)
                        .buttonStyle(DestructiveButtonStyle(compact: true))
                }
                Spacer(minLength: 0)
                Button(String(localized: "Cancel", bundle: .module), action: onCancel)
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Add", bundle: .module), action: add)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .disabled(parsedURL == nil)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 340)
    }

    private func add() {
        guard let parsedURL else { return }
        onAdd(parsedURL)
    }
}

// MARK: - Preview

/// A sample with a heading, bold, a link and a list, built the way the editor
/// builds them.
enum RichTextSample {
    static var article: AttributedString {
        let text = NSMutableAttributedString()
        func append(_ string: String, font: NSFont, extra: [NSAttributedString.Key: Any] = [:]) {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            attributes.merge(extra) { _, new in new }
            text.append(NSAttributedString(string: string, attributes: attributes))
        }
        let body = RichTextStyle.bodyFont
        append("Release notes\n", font: RichTextStyle.font(for: .heading2, bold: false, italic: false))
        append("The ", font: body)
        append("Low Glare", font: RichTextStyle.font(for: .body, bold: true, italic: false))
        append(" theme ships this week, with a dim warm shell and cream surfaces. Read the ", font: body)
        append("design notes", font: body, extra: [.link: URL(string: "https://example.com/notes")!])
        append(" before you change a token.\n", font: body)
        let bullets = RichTextListKind.bulleted.makeList()
        let list = RichTextStyle.listParagraphStyle(bullets, from: nil)
        append(RichTextStyle.marker(for: bullets, itemNumber: 1) + "Status marks hold 7:1 on both surfaces\n", font: body, extra: [.paragraphStyle: list])
        append(RichTextStyle.marker(for: bullets, itemNumber: 2) + "Badges fill with a wash of their tint\n", font: body, extra: [.paragraphStyle: list])
        append("Run ", font: body)
        append("swift test", font: RichTextStyle.codeFont, extra: [.backgroundColor: RichTextStyle.codeBackground])
        append(" before you push.", font: body)
        return AttributedString(text)
    }
}

#Preview("Rich text editor", traits: .fixedLayout(width: 560, height: 320)) {
    @Previewable @State var text = RichTextSample.article
    RichTextEditor("Release notes", text: $text, prompt: Text("Write something…"))
        .padding(Spacing.lg)
}
