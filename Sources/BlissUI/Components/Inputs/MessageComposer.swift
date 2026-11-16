//
//  MessageComposer.swift
//  BlissUI
//
//  A chat-style composer: a text area that grows with the message, a row of
//  attachment chips above it, and a bar below with the attach button, the
//  caller's extra actions and the send button. Return sends, ⇧Return types a
//  newline. The whole thing is one input box; the text area inside draws no
//  box of its own and hands Return to the composer (`TextArea.embedded`).
//

import AppKit
import SwiftUI

// MARK: - Attachment

/// A file or image attached to the message being composed.
public struct ComposerAttachment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    /// The chip's SF Symbol ("doc", "photo", "link").
    public var systemImage: String

    public init(id: UUID = UUID(), name: String, systemImage: String = "doc") {
        self.id = id
        self.name = name
        self.systemImage = systemImage
    }
}

// MARK: - Composer

/// A message composer with attachments, a toolbar slot and a send button.
///
/// ```swift
/// MessageComposer("Message", text: $draft, prompt: Text("Message the team…"), attachments: $attachments, onSend: send, onAttach: pickFile) {
///     Button {} label: { Image(systemName: "face.smiling") }
///         .buttonStyle(ToolbarIconButtonStyle(compact: true))
///         .accessibilityLabel(Text("Emoji"))
/// }
/// ```
///
/// `title` is what VoiceOver reads for the field — a `LocalizedStringResource`
/// like `TextArea`'s, because the hosted text view needs a resolved string.
/// Return sends when the text isn't blank (a blank Return does nothing);
/// ⇧Return inserts a newline. Pass `attachments: nil` for a composer without
/// attachments: the chips row and the attach button both go.
public struct MessageComposer<Toolbar: View>: View {
    private let title: LocalizedStringResource
    @Binding private var text: String
    private let prompt: Text?
    private let attachments: Binding<[ComposerAttachment]>?
    private let lineLimit: ClosedRange<Int>
    private let isSending: Bool
    private let onSend: () -> Void
    private let onAttach: (() -> Void)?
    private let toolbar: Toolbar

    @State private var isFocused = false

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - text: The message.
    ///   - prompt: Shown while the message is empty.
    ///   - attachments: The attached files, shown as chips above the text with
    ///     a remove glyph each; nil hides the chips row and the attach button.
    ///   - lineLimit: How many lines the text area starts at and grows to.
    ///   - isSending: Puts the send button in its loading state.
    ///   - onSend: Return, or the send button.
    ///   - onAttach: The attach button (a file picker, a drop panel).
    ///   - toolbar: Extra actions between the attach button and the send button.
    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        prompt: Text? = nil,
        attachments: Binding<[ComposerAttachment]>? = nil,
        lineLimit: ClosedRange<Int> = 1...6,
        isSending: Bool = false,
        onSend: @escaping () -> Void,
        onAttach: (() -> Void)? = nil,
        @ViewBuilder toolbar: () -> Toolbar
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.attachments = attachments
        self.lineLimit = lineLimit
        self.isSending = isSending
        self.onSend = onSend
        self.onAttach = onAttach
        self.toolbar = toolbar()
    }

    private var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let attachments, !attachments.wrappedValue.isEmpty {
                attachmentChips(attachments)
            }

            TextArea(title, text: $text, prompt: prompt, lineLimit: lineLimit)
                .embedded(onFocusChange: { isFocused = $0 }, onReturn: handleReturn)

            HStack(spacing: Spacing.xs) {
                if attachments != nil {
                    attachButton
                }
                toolbar
                Spacer(minLength: 0)
                sendButton
            }
            .padding(.horizontal, Spacing.xxs)
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.top, Spacing.xxs)
        .padding(.bottom, Spacing.xs)
        .inputBox(isFocused: isFocused, cornerRadius: Sizing.radiusLarge)
        .accessibilityElement(children: .contain)
    }

    // MARK: Keys

    /// Return sends; ⇧Return (or ⌥Return) falls through to a newline. A blank
    /// message swallows Return, so it doesn't grow by a line.
    private func handleReturn(_ modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers.isDisjoint(with: [.shift, .option]) else { return false }
        send()
        return true
    }

    private func send() {
        guard !isBlank, !isSending else { return }
        onSend()
    }

    // MARK: Buttons

    private var attachButton: some View {
        Button { onAttach?() } label: {
            Image(systemName: "paperclip")
        }
        .buttonStyle(ToolbarIconButtonStyle(compact: true))
        .disabled(onAttach == nil)
        .tooltip(position: .above) { Text("Attach", bundle: .module).font(Typography.labelSmall) }
        .accessibilityLabel(Text("Attach", bundle: .module))
    }

    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(Typography.labelMedium)
        }
        .buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: true, accent: true))
        .buttonLoading(isSending)
        .disabled(isBlank)
        .tooltip(position: .above) { Text("Send", bundle: .module).font(Typography.labelSmall) }
        .accessibilityLabel(Text("Send", bundle: .module))
    }

    // MARK: Attachments

    private func attachmentChips(_ attachments: Binding<[ComposerAttachment]>) -> some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(attachments.wrappedValue) { attachment in
                // The token field's chip, with the file's icon in front.
                TokenChip(title: attachment.name, systemImage: attachment.systemImage) {
                    attachments.wrappedValue.removeAll { $0.id == attachment.id }
                }
            }
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.top, Spacing.xxs)
    }
}

extension MessageComposer where Toolbar == EmptyView {
    /// A composer with no extra actions in its bar.
    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        prompt: Text? = nil,
        attachments: Binding<[ComposerAttachment]>? = nil,
        lineLimit: ClosedRange<Int> = 1...6,
        isSending: Bool = false,
        onSend: @escaping () -> Void,
        onAttach: (() -> Void)? = nil
    ) {
        self.init(
            title,
            text: text,
            prompt: prompt,
            attachments: attachments,
            lineLimit: lineLimit,
            isSending: isSending,
            onSend: onSend,
            onAttach: onAttach,
            toolbar: { EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("Message composer", traits: .fixedLayout(width: 480, height: 220)) {
    @Previewable @State var draft = "Here are the mockups from this morning."
    @Previewable @State var attachments = [
        ComposerAttachment(name: "Onboarding.png", systemImage: "photo"),
        ComposerAttachment(name: "Notes.md"),
    ]
    @Previewable @State var reply = ""
    VStack(spacing: Spacing.lg) {
        MessageComposer("Message", text: $draft, prompt: Text("Message the team…"), attachments: $attachments, onSend: {}, onAttach: {}) {
            Button {} label: { Image(systemName: "face.smiling") }
                .buttonStyle(ToolbarIconButtonStyle(compact: true))
                .accessibilityLabel(Text("Emoji"))
        }
        MessageComposer("Reply", text: $reply, prompt: Text("Reply…"), onSend: {})
    }
    .padding(Spacing.lg)
}
