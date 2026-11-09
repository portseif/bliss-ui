//
//  FormField.swift
//  BlissUI
//
//  A labelled field: the title above the control, and under it a hint, or the
//  error that takes the hint's place. The error also reaches the control — the
//  text field styles and `.inputBox` draw their line in `Danger` while one is
//  set (`\.formFieldIsInvalid`), so a hand-built input can follow suit.
//

import SwiftUI

// MARK: - Environment

struct FormFieldIsInvalidKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True inside a `FormField` that shows an error. The built-in text field
    /// styles and `.inputBox` turn their line red on it; read it in an input of
    /// your own to do the same.
    public var formFieldIsInvalid: Bool {
        get { self[FormFieldIsInvalidKey.self] }
        set { self[FormFieldIsInvalidKey.self] = newValue }
    }
}

// MARK: - Form Field

/// A titled control with a hint or an error under it.
///
/// ```swift
/// FormField("Email", hint: "We only use it for receipts.", error: emailError, isRequired: true) {
///     TextField("Email", text: $email).textFieldStyle(.largePadded)
/// }
/// ```
///
/// The title is drawn for sighted users; the control keeps its own label for
/// VoiceOver (`TextField("Email", …)`), and the hint or error becomes its
/// accessibility hint.
public struct FormField<Content: View>: View {
    private let title: LocalizedStringKey
    private let hint: LocalizedStringKey?
    private let error: LocalizedStringKey?
    private let isRequired: Bool
    private let content: () -> Content

    /// - Parameters:
    ///   - title: The label above the control.
    ///   - hint: Help text under the control, shown while there's no error.
    ///   - error: The problem with the value; nil when it's fine. Replaces the
    ///     hint and tints the control's line.
    ///   - isRequired: Marks the title with a red asterisk.
    ///   - content: The control.
    public init(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        error: LocalizedStringKey? = nil,
        isRequired: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.hint = hint
        self.error = error
        self.isRequired = isRequired
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(.primary)
                if isRequired {
                    Text(verbatim: "*")
                        .font(Typography.labelMedium)
                        .foregroundStyle(Danger.danger500)
                        .accessibilityLabel(Text("Required", bundle: .module))
                }
            }

            content()
                .environment(\.formFieldIsInvalid, error != nil)
                .accessibilityHint(Text(error ?? hint ?? ""))

            if let error {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Typography.captionSmall)
                .foregroundStyle(Danger.danger500)
                // An address or URL in the message is auto-linked; keep it red
                // so the whole line reads as the error.
                .tint(Danger.danger500)
                .transition(.motion(.opacity.combined(with: .move(edge: .top))))
            } else if let hint {
                Text(hint)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Animations.feedback, value: error)
    }
}

// MARK: - Preview

#Preview("Form field", traits: .fixedLayout(width: 420, height: 300)) {
    @Previewable @State var email = "ada@example"
    @Previewable @State var name = ""
    VStack(alignment: .leading, spacing: Spacing.lg) {
        FormField("Name", hint: "Shown on your receipts.", isRequired: true) {
            TextField("Name", text: $name).textFieldStyle(.largePadded)
        }
        FormField("Email", hint: "We only use it for receipts.", error: email.contains("@") && email.contains(".") ? nil : "Enter a full address, like ada@example.com") {
            TextField("Email", text: $email).textFieldStyle(.largePadded)
        }
        FormField("Port", hint: "1 to 65535") {
            NumberField("Port", value: .constant(2222), in: 1...65_535)
        }
    }
    .padding(Spacing.xl)
}
