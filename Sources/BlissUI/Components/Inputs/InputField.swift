//
//  InputField.swift
//  BlissUI
//
//  The boxed text field with accessories: a leading icon, a clear button that
//  shows while there's text and the pointer or focus is on the field, a
//  keyboard hint (⌘K) that hides once the field is focused, a loading spinner,
//  and a trailing slot for anything else (a unit, a menu). The box is
//  `.inputBox`, so it matches every hand-built input and goes red inside a
//  `FormField` with an error.
//

import SwiftUI

/// A boxed text field with a leading icon, clear button, keyboard hint,
/// loading state and a trailing slot.
///
/// ```swift
/// InputField("Search", text: $query, systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
/// InputField("Domain", text: $domain, isLoading: isChecking) {
///     Text(".dev").foregroundStyle(.secondary)
/// }
/// ```
///
/// Esc clears a clearable field; `.onSubmit` on the field fires on Return as
/// it does for any `TextField`.
public struct InputField<Trailing: View>: View {
    private let title: LocalizedStringKey
    @Binding private var text: String
    private let prompt: Text?
    private let systemImage: String?
    private let isClearable: Bool
    private let keyboardHint: String?
    private let isLoading: Bool
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
    ///   - trailing: Anything after the text (a unit, a small menu).
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        systemImage: String? = nil,
        isClearable: Bool = false,
        keyboardHint: String? = nil,
        isLoading: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.systemImage = systemImage
        self.isClearable = isClearable
        self.keyboardHint = keyboardHint
        self.isLoading = isLoading
        self.trailing = trailing()
    }

    private var cornerRadius: CGFloat {
        isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault
    }

    private var showsClear: Bool {
        isClearable && !text.isEmpty && (isHovering || isFocused)
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Typography.labelMedium)
                    .foregroundStyle(isFocused ? Color.accent : Grey.grey400)
                    .accessibilityHidden(true)
            }

            TextField(title, text: $text, prompt: prompt)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .focusEffectDisabled()
                .onKeyPress(.escape) {
                    guard isClearable, !text.isEmpty else { return .ignored }
                    clear()
                    return .handled
                }

            if isLoading {
                ThinkingSpinner(size: 12, lineWidth: 1.5)
                    .accessibilityLabel(Text("Loading", bundle: .module))
            }

            if isClearable {
                // Mounted even while hidden, so the layout never jumps; disabled
                // while hidden, or Tab would land on it unseen.
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
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
        .padding(.horizontal, Spacing.sm + 2)
        .frame(minHeight: Sizing.controlDefault)
        .inputBox(isFocused: isFocused, cornerRadius: cornerRadius)
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

extension InputField where Trailing == EmptyView {
    /// A field with nothing after the text.
    public init(
        _ title: LocalizedStringKey,
        text: Binding<String>,
        prompt: Text? = nil,
        systemImage: String? = nil,
        isClearable: Bool = false,
        keyboardHint: String? = nil,
        isLoading: Bool = false
    ) {
        self.init(title, text: text, prompt: prompt, systemImage: systemImage, isClearable: isClearable, keyboardHint: keyboardHint, isLoading: isLoading) {
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Input field", traits: .fixedLayout(width: 420, height: 200)) {
    @Previewable @State var query = "focus ring"
    @Previewable @State var domain = "bliss"
    @Previewable @State var name = ""
    VStack(spacing: Spacing.md) {
        InputField("Search", text: $query, prompt: Text("Search components"), systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
        InputField("Domain", text: $domain, isLoading: true) {
            Text(verbatim: ".dev")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        InputField("Name", text: $name, prompt: Text("Project name"))
    }
    .padding(Spacing.xl)
}
