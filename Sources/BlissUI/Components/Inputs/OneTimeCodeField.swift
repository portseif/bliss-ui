//
//  OneTimeCodeField.swift
//  BlissUI
//
//  A verification code typed into a row of boxes, one character each. One
//  real text field holds the code (hidden, so typing, Backspace, paste and the
//  Tab stop all work as in any field) and the boxes draw it: the box the next
//  character lands in shows the ring. Pasting "123 456" keeps the digits.
//

import SwiftUI

/// A one-time code entry: a row of boxes over one hidden text field.
///
/// ```swift
/// OneTimeCodeField(code: $code) { code in verify(code) }
/// ```
public struct OneTimeCodeField: View {
    private let title: LocalizedStringKey?
    @Binding private var code: String
    private let length: Int
    private let groupSize: Int?
    private let allowsLetters: Bool
    private let onComplete: ((String) -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field; "Verification code" by default.
    ///   - code: The characters typed so far, at most `length`.
    ///   - length: How many characters the code has.
    ///   - groupSize: A gap after every `groupSize` boxes ("123 456"); nil for none.
    ///   - allowsLetters: Accept letters (uppercased) as well as digits.
    ///   - onComplete: Called with the code once the last box fills.
    public init(
        _ title: LocalizedStringKey? = nil,
        code: Binding<String>,
        length: Int = 6,
        groupSize: Int? = 3,
        allowsLetters: Bool = false,
        onComplete: ((String) -> Void)? = nil
    ) {
        self.title = title
        self._code = code
        self.length = max(length, 1)
        self.groupSize = groupSize
        self.allowsLetters = allowsLetters
        self.onComplete = onComplete
    }

    /// The box the next character goes in; the last one once the code is full.
    private var activeIndex: Int {
        min(code.count, length - 1)
    }

    public var body: some View {
        ZStack {
            // The real field: it holds the code and takes the keys and the Tab
            // stop, drawn nowhere.
            TextField(text: $code, prompt: nil) {
                if let title { Text(title) } else { Text("Verification code", bundle: .module) }
            }
            .textFieldStyle(.plain)
            .focused($isFocused)
            .focusEffectDisabled()
            .autocorrectionDisabled()
            .opacity(0)
            .frame(width: 1, height: 1)
            .onChange(of: code) { _, newValue in
                sanitize(newValue)
            }

            HStack(spacing: Spacing.xs) {
                ForEach(0..<length, id: \.self) { index in
                    if let groupSize, index > 0, index.isMultiple(of: groupSize) {
                        Rectangle()
                            .fill(Color.menuBorder)
                            .frame(width: Spacing.sm, height: 1)
                    }
                    box(at: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
            .opacity(isEnabled ? 1 : 0.5)
            .accessibilityHidden(true)
        }
        .fixedSize()
    }

    private func box(at index: Int) -> some View {
        let isActive = isFocused && index == activeIndex
        let character = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
        return ZStack {
            Text(verbatim: character)
                .font(Typography.headingMedium.monospacedDigit())
                .foregroundStyle(.primary)
            // The caret, in the box the next character fills.
            if isActive && character.isEmpty {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.accent)
                    .frame(width: 1.5, height: 18)
            }
        }
        .frame(width: 36, height: 40)
        .inputBox(isFocused: isActive, cornerRadius: Sizing.radiusDefault)
    }

    /// Keeps only the characters the code takes, at most `length` of them, and
    /// reports a full code once.
    private func sanitize(_ newValue: String) {
        var accepted = newValue.filter { character in
            character.isNumber || (allowsLetters && character.isLetter)
        }
        if allowsLetters { accepted = accepted.uppercased() }
        if accepted.count > length { accepted = String(accepted.prefix(length)) }
        if accepted != newValue {
            code = accepted
            return
        }
        if accepted.count == length { onComplete?(accepted) }
    }
}

// MARK: - Preview

#Preview("One-time code", traits: .fixedLayout(width: 360, height: 160)) {
    @Previewable @State var code = "42"
    @Previewable @State var pairing = ""
    VStack(spacing: Spacing.lg) {
        OneTimeCodeField(code: $code)
        OneTimeCodeField(code: $pairing, length: 4, groupSize: nil, allowsLetters: true)
    }
    .padding(Spacing.xl)
}
