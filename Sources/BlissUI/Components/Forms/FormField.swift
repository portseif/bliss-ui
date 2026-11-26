//
//  FormField.swift
//  BlissUI
//
//  A labelled field: the title above the control (or in a column beside it),
//  and under it a hint, or the error that takes the hint's place. The error
//  also reaches the control — the text field styles and `.inputBox` draw their
//  line in `Danger` while one is set (`\.formFieldIsInvalid`), so a hand-built
//  input can follow suit.
//

import SwiftUI

// MARK: - Environment

extension EnvironmentValues {
    /// True inside a `FormField` that shows an error. The built-in text field
    /// styles and `.inputBox` turn their line red on it; read it in an input of
    /// your own to do the same.
    @Entry public var formFieldIsInvalid: Bool = false
}

// MARK: - Label placement

/// Where a `FormField` puts its title.
public enum FormFieldLabelPlacement: Sendable {
    /// Above the control, the web form's layout.
    case above
    /// In a column before the control, trailing-aligned — the classic macOS
    /// "Name: [____]" sheet. The column is at least `Sizing.detailLabelWidth` wide
    /// and never truncates a title.
    case leading
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
public struct FormField<Content: View, Accessory: View>: View {
    private let title: LocalizedStringKey
    private let hint: LocalizedStringKey?
    private let error: LocalizedStringKey?
    private let isRequired: Bool
    private let showsOptionalMark: Bool
    private let labelPlacement: FormFieldLabelPlacement
    private let characterCount: (current: Int, maximum: Int)?
    private let content: () -> Content
    private let titleAccessory: () -> Accessory

    /// - Parameters:
    ///   - title: The label above the control.
    ///   - hint: Help text under the control, shown while there's no error.
    ///   - error: The problem with the value; nil when it's fine. Replaces the
    ///     hint and tints the control's line.
    ///   - isRequired: Marks the title with a red asterisk.
    ///   - showsOptionalMark: Writes "Optional" after the title, for a form
    ///     that marks the optional fields instead of the required ones.
    ///   - labelPlacement: The title above the control, or in a column before it.
    ///   - characterCount: "12 / 80" under the control's trailing edge, in the
    ///     danger mark past the maximum.
    ///   - content: The control.
    ///   - titleAccessory: Sits after the title on its line — an `InfoButton`,
    ///     a "Forgot?" `TextLink`.
    public init(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        error: LocalizedStringKey? = nil,
        isRequired: Bool = false,
        showsOptionalMark: Bool = false,
        labelPlacement: FormFieldLabelPlacement = .above,
        characterCount: (current: Int, maximum: Int)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder titleAccessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.hint = hint
        self.error = error
        self.isRequired = isRequired
        self.showsOptionalMark = showsOptionalMark
        self.labelPlacement = labelPlacement
        self.characterCount = characterCount
        self.content = content
        self.titleAccessory = titleAccessory
    }

    public var body: some View {
        switch labelPlacement {
        case .above:
            VStack(alignment: .leading, spacing: 0) {
                titleRow
                    .padding(.bottom, Spacing.xs)
                control
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .leading:
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                titleRow
                    .fixedSize()
                    .frame(minWidth: Sizing.detailLabelWidth, alignment: .trailing)
                VStack(alignment: .leading, spacing: 0) {
                    control
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var hasFooter: Bool {
        error != nil || hint != nil || characterCount != nil
    }

    // MARK: Pieces

    private var titleRow: some View {
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
            if showsOptionalMark {
                Text("Optional", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            titleAccessory()
        }
    }

    private var control: some View {
        content()
            .environment(\.formFieldIsInvalid, error != nil)
            .accessibilityHint(Text(error ?? hint ?? ""))
    }

    /// The hint or the error, with the character count trailing. Animated on
    /// its own, so the control's own changes aren't retimed with it.
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Group {
                if let error {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                        BlissSymbol("exclamationmark.circle.fill")
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
            if let characterCount {
                Text(verbatim: "\(characterCount.current.formatted()) / \(characterCount.maximum.formatted())")
                    .font(Typography.captionSmall.monospacedDigit())
                    .foregroundStyle(characterCount.current > characterCount.maximum ? AnyShapeStyle(Danger.danger500) : AnyShapeStyle(.secondary))
                    .accessibilityLabel(Text("\(characterCount.current) of \(characterCount.maximum) characters", bundle: .module))
            }
        }
        // The footer's own gap, so an empty footer takes no room.
        .padding(.top, hasFooter ? Spacing.xs : 0)
        .animation(Animations.feedback, value: error)
    }
}

extension FormField where Accessory == EmptyView {
    /// A field with nothing after its title.
    /// - Parameters:
    ///   - title: The label above the control.
    ///   - hint: Help text under the control, shown while there's no error.
    ///   - error: The problem with the value; nil when it's fine. Replaces the
    ///     hint and tints the control's line.
    ///   - isRequired: Marks the title with a red asterisk.
    ///   - showsOptionalMark: Writes "Optional" after the title.
    ///   - labelPlacement: The title above the control, or in a column before it.
    ///   - characterCount: "12 / 80" under the control's trailing edge.
    ///   - content: The control.
    public init(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        error: LocalizedStringKey? = nil,
        isRequired: Bool = false,
        showsOptionalMark: Bool = false,
        labelPlacement: FormFieldLabelPlacement = .above,
        characterCount: (current: Int, maximum: Int)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title,
            hint: hint,
            error: error,
            isRequired: isRequired,
            showsOptionalMark: showsOptionalMark,
            labelPlacement: labelPlacement,
            characterCount: characterCount,
            content: content,
            titleAccessory: { EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("Form field", traits: .fixedLayout(width: 420, height: 360)) {
    @Previewable @State var email = "ada@example"
    @Previewable @State var name = ""
    @Previewable @State var bio = "Designer"
    VStack(alignment: .leading, spacing: Spacing.lg) {
        FormField("Name", hint: "Shown on your receipts.", isRequired: true) {
            TextField("Name", text: $name).textFieldStyle(.largePadded)
        }
        FormField("Email", hint: "We only use it for receipts.", error: email.contains("@") && email.contains(".") ? nil : "Enter a full address, like ada@example.com") {
            TextField("Email", text: $email).textFieldStyle(.largePadded)
        }
        FormField("Port", hint: "1 to 65535", labelPlacement: .leading) {
            NumberField("Port", value: .constant(2222), in: 1...65_535)
        }
        FormField("Bio", showsOptionalMark: true, characterCount: (bio.count, 80)) {
            TextField("Bio", text: $bio).textFieldStyle(.largePadded)
        } titleAccessory: {
            InfoButton(text: "Shown on your public profile.")
        }
    }
    .padding(Spacing.xl)
}
