//
//  SecretField.swift
//  BlissUI
//
//  A field for an API key, token or password: masked until revealed, with the
//  eye toggle (`RevealToggleIcon`) and a copy button that goes through
//  `SecretClipboard`. Revealing asks `SecretClipboard.authorize` first, so an
//  app that gates copies behind Touch ID gates reveals the same way, and a
//  revealed value masks itself again when the app goes to the background.
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
/// ```
public struct SecretField: View {
    private enum Field: Hashable {
        case masked, clear
    }

    private let title: LocalizedStringKey
    @Binding private var text: String
    private let prompt: Text?
    private let isCopyable: Bool

    @State private var isRevealed = false
    @State private var showCopied = false
    @FocusState private var focusedField: Field?

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - text: The secret.
    ///   - prompt: Placeholder while the field is empty.
    ///   - isCopyable: Shows the copy button (a secret copy: concealed from
    ///     clipboard managers, cleared after a minute).
    public init(_ title: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil, isCopyable: Bool = true) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.isCopyable = isCopyable
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
            .font(Typography.codeSmall)
            .autocorrectionDisabled()
            .focusEffectDisabled()
            .padding(.leading, Spacing.sm)

            revealButton

            if isCopyable {
                CopyButton(value: text, showCopied: $showCopied, isSecret: true)
                    .disabled(text.isEmpty)
            }
        }
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: Sizing.controlDefault)
        .inputBox(isFocused: focusedField != nil, cornerRadius: Sizing.radiusDefault)
        // Nobody should read it off the screen while the app is in the background.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if isRevealed { isRevealed = false }
        }
    }

    private var revealButton: some View {
        Button {
            Task {
                if !isRevealed, !(await SecretClipboard.authorize(String(localized: "reveal a secret", bundle: .module))) { return }
                // The field that had the cursor hands it to its twin.
                let keepsFocus = focusedField != nil
                withAnimation(Animations.selection) { isRevealed.toggle() }
                if keepsFocus { focusedField = isRevealed ? .clear : .masked }
            }
        } label: {
            RevealToggleIcon(isRevealed: isRevealed)
                .font(Typography.caption)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
        .foregroundStyle(.secondary)
        .tooltip(configuration: .iconHint, position: .above) {
            (isRevealed ? Text("Hide", bundle: .module) : Text("Reveal", bundle: .module))
                .font(Typography.labelSmall)
        }
        .accessibilityLabel(isRevealed ? Text("Hide", bundle: .module) : Text("Reveal", bundle: .module))
    }
}

// MARK: - Preview

#Preview("Secret field", traits: .fixedLayout(width: 420, height: 140)) {
    @Previewable @State var apiKey = "sk-live-4f8a2c9e1b7d6a3f"
    @Previewable @State var empty = ""
    VStack(spacing: Spacing.md) {
        SecretField("API key", text: $apiKey)
        SecretField("Password", text: $empty, prompt: Text("Required"), isCopyable: false)
    }
    .padding(Spacing.xl)
}
