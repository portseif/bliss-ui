//
//  FieldsPage.swift
//  BlissCatalog
//
//  The "Number & Text Fields" page.
//

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
                    FieldsDemoRow("Disabled") {
                        BlissSlider("Disabled", value: .constant(0.35))
                            .frame(width: 260)
                            .disabled(true)
                    }
                }
                .frame(maxWidth: 480)
            }

            DemoBlock(title: "Input field") {
                FieldsCaption("The boxed field with accessories: a leading icon, a clear button while there's text (Esc clears too), a keyboard hint that hides on focus, a loading spinner and a trailing slot.")
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
                }
                .frame(maxWidth: 420)
            }

            DemoBlock(title: "Message composer") {
                FieldsCaption("Return sends, ⇧Return adds a line. The paperclip adds a sample attachment; a chip's ✕ removes it.")
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
                        .buttonStyle(ToolbarIconButtonStyle(compact: true))
                        .accessibilityLabel(Text("Emoji"))
                }
                .frame(maxWidth: 520)
            }

            DemoBlock(title: "One-time code") {
                FieldsCaption("Type or paste the code; Backspace steps back. The second takes letters too.")
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    OneTimeCodeField(code: $code) { code in
                        ToastService.shared.showSuccess(title: "Verified", message: code)
                    }
                    OneTimeCodeField("Pairing code", code: $pairingCode, length: 4, groupSize: nil, allowsLetters: true)
                }
            }

            DemoBlock(title: "Text area") {
                FieldsCaption("Grows with its text, then scrolls. Tab moves to the next field; ⌥Tab types a tab.")
                VStack(alignment: .leading, spacing: Spacing.md) {
                    TextArea("Notes", text: $notes, prompt: Text("Add a note…"))
                    TextArea("Bio", text: $bio, lineLimit: 2...5, characterLimit: 160)
                    TextArea("Ignore file", text: $ignoreFile, prompt: Text("/node_modules"), lineLimit: 2...6, monospaced: true)
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
