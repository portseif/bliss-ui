//
//  SecretField.swift
//  BlissUI
//
//  A field for an API key, token or password: masked until revealed, with the
//  eye toggle and a copy button that goes through `SecretClipboard`.
//  Revealing asks `SecretClipboard.authorize` first, so an app that gates
//  copies behind Touch ID gates reveals the same way, and a revealed value
//  masks itself again when the app goes to the background.
//
//  The masked and the clear field are both mounted, one hidden: a
//  `SecureField` ↔ `TextField` swap would drop focus and reset the cursor.
//

import AppKit
import SwiftUI

/// A masked text field with reveal and copy.
///
/// ```swift
/// SecretField("API key", text: $apiKey, prompt: Text("sk-…"))
/// SecretField("Confirm password", text: $confirmation, isCopyable: false, isRevealable: false, monospaced: false)
/// ```
public struct SecretField: View {
    private enum Field: Hashable {
        case masked, clear
    }

    /// How long the copy button shows its checkmark.
    static let copiedResetDelay: Duration = .milliseconds(1500)

    private let title: LocalizedStringKey
    @Binding private var text: String
    private let prompt: Text?
    private let isCopyable: Bool
    private let isRevealable: Bool
    private let monospaced: Bool

    @State private var isRevealed = false
    @State private var showCopied = false
    @State private var copyGeneration = 0
    @FocusState private var focusedField: Field?

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - text: The secret.
    ///   - prompt: Placeholder while the field is empty.
    ///   - isCopyable: Shows the copy button (a secret copy: concealed from
    ///     clipboard managers, cleared after a minute).
    ///   - isRevealable: Shows the eye toggle. Off for a field that must never
    ///     unmask (a confirm-password field).
    ///   - monospaced: Sets the value in the code font, where a key's
    ///     characters tell apart; off for a passphrase.
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        isCopyable: Bool = true,
        isRevealable: Bool = true,
        monospaced: Bool = true
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.isCopyable = isCopyable
        self.isRevealable = isRevealable
        self.monospaced = monospaced
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            ZStack(alignment: .leading) {
                SecureField(title, text: $text, prompt: prompt)
                    .focused($focusedField, equals: .masked)
                    .opacity(isRevealed ? 0 : 1)
                    .allowsHitTesting(!isRevealed)
                    .accessibilityHidden(isRevealed)
                TextField(title, text: $text, prompt: prompt)
                    .focused($focusedField, equals: .clear)
                    .opacity(isRevealed ? 1 : 0)
                    .allowsHitTesting(isRevealed)
                    .accessibilityHidden(!isRevealed)
            }
            .textFieldStyle(.plain)
            .font(monospaced ? Typography.codeSmall : Typography.labelMedium)
            .autocorrectionDisabled()
            .focusEffectDisabled()
            .padding(.leading, Spacing.fieldPaddingH)

            if isRevealable {
                revealButton
            }

            if isCopyable {
                copyButton
                    .disabled(text.isEmpty)
            }
        }
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: Sizing.controlDefault)
        .inputBox(isFocused: focusedField != nil)
        // Nobody should read it off the screen while the app is in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if isRevealed { isRevealed = false }
        }
    }

    /// The eye: the inline icon button every field accessory is.
    private var revealButton: some View {
        HoverIconButton(
            systemImage: isRevealed ? "eye.slash" : "eye",
            size: Sizing.iconTiny,
            chipPadding: Spacing.insetSpacing,
            help: isRevealed ? String(localized: "Hide", bundle: .module) : String(localized: "Reveal", bundle: .module)
        ) {
            Task {
                if !isRevealed, !(await SecretClipboard.authorize(String(localized: "reveal a secret", bundle: .module))) { return }
                // The field that had the cursor hands it to its twin.
                let keepsFocus = focusedField != nil
                withAnimation(Animations.selection) { isRevealed.toggle() }
                if keepsFocus { focusedField = isRevealed ? .clear : .masked }
            }
        }
    }

    /// A secret copy, with the checkmark for a moment.
    private var copyButton: some View {
        HoverIconButton(
            systemImage: showCopied ? "checkmark" : "doc.on.doc",
            size: Sizing.iconTiny,
            chipPadding: Spacing.insetSpacing,
            tint: showCopied ? Success.success500 : nil,
            help: String(localized: "Copy", bundle: .module)
        ) {
            Task {
                guard await SecretClipboard.copy(text, reason: String(localized: "copy a secret", bundle: .module)) else { return }
                copyGeneration += 1
                let generation = copyGeneration
                showCopied = true
                try? await Task.sleep(for: Self.copiedResetDelay)
                guard generation == copyGeneration else { return }
                showCopied = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Secret field", traits: .fixedLayout(width: 420, height: 180)) {
    @Previewable @State var apiKey = "sk-live-4f8a2c9e1b7d6a3f"
    @Previewable @State var empty = ""
    @Previewable @State var confirmation = ""
    VStack(spacing: Spacing.md) {
        SecretField("API key", text: $apiKey)
        SecretField("Password", text: $empty, prompt: Text("Required"), isCopyable: false)
        SecretField("Confirm password", text: $confirmation, prompt: Text("Again"), isCopyable: false, isRevealable: false, monospaced: false)
    }
    .padding(Spacing.xl)
}
