//
//  FieldsPage.swift
//  BlissCatalog
//
//  The "Number & Text Fields" page.
//

import AppKit
import BlissUI
import SwiftUI

struct FieldsPage: View {
    @State private var retentionDays = 30
    @State private var port = 2222
    @State private var lineHeight = 1.5
    @State private var padding = 12
    @State private var volume = 0.6
    @State private var columns = 3
    @State private var opacity = 0.8
    @State private var notes = ""
    @State private var bio = "Designer and tinkerer. Builds small tools for people who make things."
    @State private var ignoreFile = "/node_modules\n/dist\n.env"
    @State private var query = ""
    @State private var domain = "bliss"
    @State private var isCheckingDomain = false
    @State private var code = ""
    @State private var pairingCode = ""
    @State private var draft = ""
    @State private var draftAttachments = [ComposerAttachment(name: "Onboarding.png", systemImage: "photo")]
    @State private var isSendingDraft = false
    @State private var releaseNotes = CatalogRichText.article
    @State private var price = 12
    @State private var year = 2026
    @State private var timeout = 30
    @State private var warmth = 0.4
    @State private var comment = ""
    @State private var commentNotes = AttributedString()
    @State private var pin = ""
    @State private var review = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Number field") {
                FieldsCaption("Type a number, or step it with − / + and ↑ / ↓ — Shift steps ten. Anything that isn't a number reverts when you leave the field.")
                RoundedSection(divided: true) {
                    FieldsDemoRow("Keep backups for") {
                        NumberField("Days to keep", value: $retentionDays, in: 1...365, unit: "days")
                    }
                    FieldsDemoRow("SSH port") {
                        NumberField("SSH port", value: $port, in: 1...65_535)
                    }
                    FieldsDemoRow("Line height") {
                        NumberField("Line height", value: $lineHeight, in: 1...3, step: 0.1)
                    }
                    FieldsDemoRow("Price") {
                        NumberField("Price", value: $price, in: 0...999, unit: "$", unitPlacement: .leading)
                    }
                    FieldsDemoRow("Year (no steppers)") {
                        NumberField("Year", value: $year, in: 1900...2100, showsSteppers: false)
                    }
                    FieldsDemoRow("Padding (small)") {
                        NumberField("Padding", value: $padding, in: 0...64, step: 4, unit: "px")
                            .controlSize(.small)
                    }
                    FieldsDemoRow("Disabled") {
                        NumberField("Disabled", value: .constant(8), in: 0...10)
                            .disabled(true)
                    }
                }
                .frame(maxWidth: 480)
                FormField("Timeout", hint: "Fills its column like the other boxed fields.") {
                    NumberField("Timeout", value: $timeout, in: 1...120, unit: "s", fillsWidth: true)
                }
                .frame(maxWidth: 480)
            }

            DemoBlock(title: "Slider") {
                FieldsCaption("Drag, or focus it with Tab and use ← / → (Shift steps ten, Home / End jump to the ends).")
                RoundedSection(divided: true) {
                    FieldsDemoRow("Volume") {
                        BlissSlider("Volume", value: $volume, valueLabel: { Text($0, format: .percent.precision(.fractionLength(0))) })
                            .frame(width: 260)
                    }
                    FieldsDemoRow("Columns") {
                        BlissSlider("Columns", value: $columns, in: 1...6, showsTicks: true, valueLabel: { Text($0, format: .number) })
                            .frame(width: 260)
                    }
                    FieldsDemoRow("Opacity") {
                        BlissSlider("Opacity", value: $opacity, step: 0.1, showsTicks: true)
                            .frame(width: 260)
                    }
                    FieldsDemoRow("Warmth") {
                        BlissSlider("Warmth", value: $warmth, color: Warning.warning500, minimumValueLabel: Text("Cool"), maximumValueLabel: Text("Warm"))
                            .frame(width: 260)
                    }
                    FieldsDemoRow("Disabled") {
                        BlissSlider("Disabled", value: .constant(0.35))
                            .frame(width: 260)
                            .disabled(true)
                    }
                }
                .frame(maxWidth: 480)
            }

            DemoBlock(title: "Input field") {
                FieldsCaption("The boxed field with accessories: a leading icon, a clear button while there's text (Esc clears too), a keyboard hint that hides on focus, a loading spinner, a leading and a trailing slot. The read-only one can be selected and copied but not edited.")
                VStack(spacing: Spacing.md) {
                    InputField("Search", text: $query, prompt: Text("Search components"), systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
                    InputField("Domain", text: $domain, isLoading: isCheckingDomain) {
                        Text(verbatim: ".dev")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: domain) { _, _ in
                        isCheckingDomain = true
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            isCheckingDomain = false
                        }
                    }
                    InputField("Amount", text: .constant("1,284.00"), isReadOnly: true) {
                        Text(verbatim: "$")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    } trailing: {
                        Text(verbatim: "USD")
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 420)
            }

            DemoBlock(title: "Message composer") {
                FieldsCaption("Return sends, ⇧Return adds a line. The paperclip adds a sample attachment; a chip's ✕ removes it. In the comment box Return adds a line and ⌘Return sends.")
                MessageComposer("Message", text: $draft, prompt: Text("Message the team…"), attachments: $draftAttachments, isSending: isSendingDraft, onSend: {
                    isSendingDraft = true
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        ToastService.shared.showSuccess(title: "Sent", message: draft)
                        draft = ""
                        draftAttachments.removeAll()
                        isSendingDraft = false
                    }
                }, onAttach: {
                    draftAttachments.append(ComposerAttachment(name: "Notes \(draftAttachments.count + 1).md"))
                }) {
                    Button {} label: { Image(systemName: "face.smiling") }
                        .buttonStyle(ToolbarIconButtonStyle())
                        .accessibilityLabel(Text("Emoji"))
                }
                .frame(maxWidth: 520)
                MessageComposer("Comment", text: $comment, prompt: Text("Leave a comment…"), characterLimit: 280, sendsOnReturn: false, onSend: {
                    ToastService.shared.showSuccess(title: "Posted", message: comment)
                    comment = ""
                })
                .frame(maxWidth: 520)
            }

            DemoBlock(title: "Rich text editor") {
                FieldsCaption("Select text and use the toolbar, or ⌘B, ⌘I, ⌘U and ⌘K. Return in a list item starts the next; Return in an empty item ends the list.")
                RichTextEditor("Release notes", text: $releaseNotes, prompt: Text("Write the notes…"))
                    .frame(maxWidth: 560)
                RichTextEditor("Comment", text: $commentNotes, prompt: Text("Bold, italic and links only…"), minimumHeight: Sizing.controlXLarge * 2, tools: [.inlineStyles, .link])
                    .frame(maxWidth: 560)
            }

            DemoBlock(title: "One-time code") {
                FieldsCaption("Type or paste the code; Backspace steps back. The second takes letters too; the third is a compact, masked PIN.")
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    OneTimeCodeField(code: $code) { code in
                        ToastService.shared.showSuccess(title: "Verified", message: code)
                    }
                    OneTimeCodeField("Pairing code", code: $pairingCode, length: 4, groupSize: nil, allowsLetters: true)
                    OneTimeCodeField("PIN", code: $pin, length: 4, groupSize: nil, compact: true, isSecure: true)
                }
            }

            DemoBlock(title: "Text area") {
                FieldsCaption("Grows with its text, then scrolls. Tab moves to the next field; ⌥Tab types a tab.")
                VStack(alignment: .leading, spacing: Spacing.md) {
                    TextArea("Notes", text: $notes, prompt: Text("Add a note…"))
                    TextArea("Bio", text: $bio, lineLimit: 2...5, characterLimit: 160)
                    TextArea("Ignore file", text: $ignoreFile, prompt: Text("/node_modules"), lineLimit: 2...6, monospaced: true)
                    RoundedSection("Review") {
                        TextArea("Review", text: $review, prompt: Text("A borderless note inside a card…"), lineLimit: 2...4, isBordered: false)
                    }
                }
                .frame(maxWidth: 480)
            }
        }
    }
}

/// A form row: the label leading, the control trailing (the divided
/// section pads each row).
private struct FieldsDemoRow<Control: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let control: () -> Control

    init(_ title: LocalizedStringKey, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.control = control
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(title)
                .font(Typography.bodySmall)
            Spacer(minLength: Spacing.md)
            control()
        }
    }
}

private struct FieldsCaption: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A heading, bold, a link, a list and inline code, built with AppKit
/// attributes. Shared by the Fields page and its gallery entry.
enum CatalogRichText {
    static var article: AttributedString {
        let text = NSMutableAttributedString()
        func append(_ string: String, font: NSFont, extra: [NSAttributedString.Key: Any] = [:]) {
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            attributes.merge(extra) { _, new in new }
            text.append(NSAttributedString(string: string, attributes: attributes))
        }
        let body = NSFont.systemFont(ofSize: 13)
        append("Release notes\n", font: .systemFont(ofSize: 17, weight: .semibold))
        append("The ", font: body)
        append("Low Glare", font: .systemFont(ofSize: 13, weight: .bold))
        append(" theme ships this week, with a dim warm shell and cream surfaces. Read the ", font: body)
        append("design notes", font: body, extra: [.link: URL(string: "https://example.com/notes")!])
        append(" before you change a token.\n", font: body)
        let bullets = NSTextList(markerFormat: .disc, options: 0)
        let list = NSMutableParagraphStyle()
        list.textLists = [bullets]
        list.headIndent = 28
        list.tabStops = [NSTextTab(textAlignment: .right, location: 18), NSTextTab(textAlignment: .left, location: 28)]
        append("\t\(bullets.marker(forItemNumber: 1))\tStatus marks hold 7:1 on both surfaces\n", font: body, extra: [.paragraphStyle: list])
        append("\t\(bullets.marker(forItemNumber: 2))\tBadges fill with a wash of their tint\n", font: body, extra: [.paragraphStyle: list])
        append("Run ", font: body)
        append("swift test", font: .monospacedSystemFont(ofSize: 12, weight: .regular), extra: [.backgroundColor: NSColor.labelColor.withAlphaComponent(0.08)])
        append(" before you push.", font: body)
        return AttributedString(text)
    }
}
