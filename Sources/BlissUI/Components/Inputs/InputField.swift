//
//  InputField.swift
//  BlissUI
//
//  The boxed text field with accessories: a leading icon or slot, a clear
//  button that shows while there's text and the pointer or focus is on the
//  field, a keyboard hint (⌘K) that hides once the field is focused, a loading
//  spinner, and a trailing slot for anything else (a unit, a menu). The box is
//  `.inputBox`, so it matches every hand-built input and goes red inside a
//  `FormField` with an error.
//

import SwiftUI

/// A boxed text field with a leading icon, clear button, keyboard hint,
/// loading state, and leading and trailing slots.
///
/// ```swift
/// InputField("Search", text: $query, systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
/// InputField("Domain", text: $domain, isLoading: isChecking) {
///     Text(".dev").foregroundStyle(.secondary)
/// }
/// InputField("Site", text: $host) {
///     Text("https://").foregroundStyle(.secondary)
/// } trailing: {
///     Text(".dev").foregroundStyle(.secondary)
/// }
/// ```
///
/// Esc clears a clearable field; `.onSubmit` on the field fires on Return as
/// it does for any `TextField`. A read-only field shows its text selectable
/// in the same box, without the dimmed look of `.disabled`.
public struct InputField<Leading: View, Trailing: View>: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    private let prompt: Text?
    private let systemImage: String?
    private let isClearable: Bool
    private let keyboardHint: String?
    private let isLoading: Bool
    private let isReadOnly: Bool
    private let leading: Leading
    private let trailing: Trailing

    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - text: The field's text.
    ///   - prompt: Placeholder while the field is empty.
    ///   - systemImage: A leading SF Symbol; accent while focused.
    ///   - isClearable: A clear button while there's text and the pointer or
    ///     focus is on the field; Esc clears too.
    ///   - keyboardHint: The shortcut that focuses the field ("⌘K"), shown
    ///     until it has focus. Display only: bind the key in your app.
    ///   - isLoading: A spinner in the trailing position (a lookup in flight).
    ///   - isReadOnly: Selectable, not editable (an endpoint, a generated ID).
    ///   - leading: Anything before the text (a "$", a "https://", a chip).
    ///   - trailing: Anything after the text (a unit, a small menu).
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        systemImage: String? = nil,
        isClearable: Bool = false,
        keyboardHint: String? = nil,
        isLoading: Bool = false,
        isReadOnly: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.systemImage = systemImage
        self.isClearable = isClearable
        self.keyboardHint = keyboardHint
        self.isLoading = isLoading
        self.isReadOnly = isReadOnly
        self.leading = leading()
        self.trailing = trailing()
    }

    private var showsClear: Bool {
        isClearable && !isReadOnly && !text.isEmpty && (isHovering || isFocused)
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage {
                BlissSymbol(systemImage)
                    .font(Typography.labelMedium)
                    .foregroundStyle(isFocused ? Color.accent : Color.textTertiary)
                    .accessibilityHidden(true)
            }

            leading

            if isReadOnly {
                // Selectable, not editable, in the field's own type.
                Text(verbatim: text)
                    .font(Typography.labelMedium)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text(verbatim: text))
            } else {
                TextField(title, text: $text, prompt: prompt)
                    .textFieldStyle(.plain)
                    .font(Typography.labelMedium)
                    .focused($isFocused)
                    .focusEffectDisabled()
                    .onKeyPress(.escape) {
                        guard isClearable, !text.isEmpty else { return .ignored }
                        clear()
                        return .handled
                    }
            }

            if isLoading {
                ThinkingSpinner(size: Sizing.iconTiny)
                    .accessibilityLabel(Text("Loading", bundle: .module))
            }

            if isClearable && !isReadOnly {
                // Mounted even while hidden, so the layout never jumps; disabled
                // while hidden, or Tab would land on it unseen.
                Button(action: clear) {
                    BlissSymbol("xmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: Sizing.inlineIconButton, height: Sizing.inlineIconButton)
                }
                .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
                .opacity(showsClear ? 1 : 0)
                .disabled(!showsClear)
                .allowsHitTesting(showsClear)
                .accessibilityLabel(Text("Clear", bundle: .module))
            }

            if let keyboardHint {
                ShortcutKey(keyboardHint, compact: true)
                    .opacity(isFocused ? 0 : 1)
                    .accessibilityHidden(true)
            }

            trailing
        }
        .padding(.horizontal, Spacing.fieldPaddingH)
        .frame(minHeight: Sizing.controlDefault)
        .inputBox(isFocused: isFocused)
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: showsClear)
        .animation(Animations.hover, value: isFocused)
        .accessibilityElement(children: .contain)
    }

    private func clear() {
        text = ""
        isFocused = true
    }
}

extension InputField where Leading == EmptyView {
    /// A field with a trailing slot and nothing before the text.
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        systemImage: String? = nil,
        isClearable: Bool = false,
        keyboardHint: String? = nil,
        isLoading: Bool = false,
        isReadOnly: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(title, text: text, prompt: prompt, systemImage: systemImage, isClearable: isClearable, keyboardHint: keyboardHint, isLoading: isLoading, isReadOnly: isReadOnly) {
            EmptyView()
        } trailing: {
            trailing()
        }
    }
}

extension InputField where Leading == EmptyView, Trailing == EmptyView {
    /// A field with nothing around the text.
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        systemImage: String? = nil,
        isClearable: Bool = false,
        keyboardHint: String? = nil,
        isLoading: Bool = false,
        isReadOnly: Bool = false
    ) {
        self.init(title, text: text, prompt: prompt, systemImage: systemImage, isClearable: isClearable, keyboardHint: keyboardHint, isLoading: isLoading, isReadOnly: isReadOnly) {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Input field", traits: .fixedLayout(width: 420, height: 240)) {
    @Previewable @State var query = "focus ring"
    @Previewable @State var domain = "bliss"
    @Previewable @State var name = ""
    VStack(spacing: Spacing.md) {
        InputField("Search", text: $query, prompt: Text("Search components"), systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
        InputField("Domain", text: $domain, isLoading: true) {
            Text(verbatim: "https://")
                .font(Typography.labelMedium)
                .foregroundStyle(.secondary)
        } trailing: {
            Text(verbatim: ".dev")
                .font(Typography.labelMedium)
                .foregroundStyle(.secondary)
        }
        InputField("Name", text: $name, prompt: Text("Project name"))
        InputField("Endpoint", text: .constant("https://api.example.com/v2"), isReadOnly: true)
    }
    .padding(Spacing.xl)
}
