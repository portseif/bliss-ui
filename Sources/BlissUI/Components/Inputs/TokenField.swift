//
//  TokenField.swift
//  BlissUI
//
//  A tag input: chips with a ✕ that wrap inside the input box, ahead of a text
//  field that fills the rest of the last line.
//
//  - Return or a comma turns the typed text into a token; a paste splits on
//    commas and newlines. A duplicate (same title, any case) isn't added — the
//    chip it repeats flashes instead.
//  - Backspace in an empty field selects the last token, a second removes it;
//    ← / → move the selection between tokens (→ past the last one goes back to
//    typing). The field keeps keyboard focus throughout, so the whole input is
//    one Tab stop — like `NSTokenField`, its tokens aren't Tab stops of their own.
//  - Optional suggestions in a floating list under the box (`SuggestionList`),
//    and optional validation: an invalid token stays, tinted `Danger`, with a
//    mark so the state isn't carried by color alone.
//

import Accessibility
import SwiftUI

// MARK: - Parsing

/// How typed and pasted text becomes tokens. Pure, so it's unit-tested on its own.
nonisolated enum TokenParsing {
    /// A comma or any line break ends a token.
    static func isSeparator(_ character: Character) -> Bool {
        character == "," || character.isNewline
    }

    /// The trimmed, non-empty pieces of `text` between separators.
    static func titles(in text: String) -> [String] {
        let pieces = split(text)
        return pieces.complete + trimmedNonEmpty([pieces.remainder])
    }

    /// The pieces before the last separator (trimmed, non-empty), and the raw
    /// text after it — still being typed.
    static func split(_ text: String) -> (complete: [String], remainder: String) {
        var complete: [String] = []
        var current = ""
        for character in text {
            if isSeparator(character) {
                complete += trimmedNonEmpty([current])
                current = ""
            } else {
                current.append(character)
            }
        }
        return (complete, current)
    }

    /// What an edit of the field commits, or nil when it holds no separator.
    /// A typed comma commits the text before it and keeps typing after it; a
    /// paste (more than one character arriving at once) commits all of it.
    static func commit(from oldText: String, to newText: String) -> (titles: [String], draft: String)? {
        guard newText.contains(where: isSeparator) else { return nil }
        let pieces = split(newText)
        if newText.count - oldText.count > 1 {
            return (pieces.complete + trimmedNonEmpty([pieces.remainder]), "")
        }
        return (pieces.complete, pieces.remainder)
    }

    /// The index of the token with this title, compared case-insensitively.
    static func indexOfDuplicate(_ title: String, in titles: [String]) -> Int? {
        titles.firstIndex { $0.compare(title, options: .caseInsensitive) == .orderedSame }
    }

    /// `candidates` appended to `existing`, skipping any whose title is already
    /// there (or earlier in the batch). `duplicates` are the existing indices
    /// that were repeated, for the field to flash.
    static func appending<Token>(
        _ candidates: [Token],
        to existing: [Token],
        title: (Token) -> String
    ) -> (tokens: [Token], duplicates: [Int]) {
        var tokens = existing
        var titles = existing.map(title)
        var duplicates: [Int] = []
        for candidate in candidates {
            let candidateTitle = title(candidate)
            if let duplicate = indexOfDuplicate(candidateTitle, in: titles) {
                duplicates.append(duplicate)
                continue
            }
            tokens.append(candidate)
            titles.append(candidateTitle)
        }
        return (tokens, duplicates)
    }

    private static func trimmedNonEmpty(_ pieces: [String]) -> [String] {
        pieces
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Token Field

/// A tag input bound to an array of tokens: chips with a ✕ wrapping inside the
/// input box, Return or a comma to add, paste to add a list.
///
/// ```swift
/// TokenField("Add a label", tokens: $labels, suggestions: ["Design", "Bug", "Docs"])
///
/// TokenField("Invite by email", tokens: $emails, isValid: { $0.contains("@") })
/// ```
///
/// For your own token type, say how text becomes a token (nil rejects it) and
/// how a token reads:
///
/// ```swift
/// TokenField("Assign", tokens: $people, suggestions: team,
///            title: \.name, makeToken: { name in team.first { $0.name == name } })
/// ```
///
/// Backspace in an empty field selects the last token and a second removes
/// it; ← / → move between tokens. With suggestions, ↓ opens the list, ↑ / ↓
/// (or Tab) move through it and Return picks; Esc closes it.
public struct TokenField<Token: Hashable>: View {
    @Binding private var tokens: [Token]
    private let placeholder: LocalizedStringKey
    private let suggestions: [Token]
    private let maxSuggestions: Int
    private let title: (Token) -> String
    private let makeToken: (String) -> Token?
    private let isValid: (Token) -> Bool

    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool
    /// The token ← / → / Backspace have selected; the field keeps focus.
    @State private var selectedIndex: Int?
    /// The chip a duplicate entry repeated, flashing briefly.
    @State private var flashedIndex: Int?
    @State private var flashGeneration = 0
    @State private var list = SuggestionListModel<Token>()
    @State private var boxWidth: CGFloat = 0

    /// - Parameters:
    ///   - placeholder: Shown while there are no tokens; also the field's
    ///     accessibility label. Looked up in your app's strings.
    ///   - tokens: The tokens, in order.
    ///   - suggestions: Offered under the field as you type (those already
    ///     added are left out). Empty for none.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    ///   - title: How a token reads on its chip.
    ///   - makeToken: Turns entered text into a token; nil rejects it.
    ///   - isValid: False tints a token `Danger` (it's still added).
    public init(
        _ placeholder: LocalizedStringKey,
        tokens: Binding<[Token]>,
        suggestions: [Token] = [],
        maxSuggestions: Int = 8,
        title: @escaping (Token) -> String,
        makeToken: @escaping (String) -> Token?,
        isValid: @escaping (Token) -> Bool = { _ in true }
    ) {
        self.placeholder = placeholder
        self._tokens = tokens
        self.suggestions = suggestions
        self.maxSuggestions = maxSuggestions
        self.title = title
        self.makeToken = makeToken
        self.isValid = isValid
    }

    public var body: some View {
        TokenFlowLayout(spacing: Spacing.xxs, minimumFieldWidth: 64) {
            ForEach(Array(chipIDs.enumerated()), id: \.element) { index, chipID in
                TokenChip(
                    title: title(chipID.token),
                    isInvalid: !isValid(chipID.token),
                    isSelected: selectedIndex == index,
                    isFlashing: flashedIndex == index,
                    onSelect: {
                        selectedIndex = index
                        isFieldFocused = true
                    },
                    onRemove: { removeToken(at: index) }
                )
                .transition(.motion(.scale(scale: 0.85).combined(with: .opacity)))
            }
            field
        }
        // Concentric with the box: chip radius (4) = box radius (8) − inset (4).
        .padding(Spacing.xxs)
        .frame(maxWidth: .infinity, minHeight: Sizing.controlDefault, alignment: .leading)
        .contentShape(Rectangle())
        // A click on the box between chips types into the field.
        .onTapGesture { isFieldFocused = true }
        .inputBox(isFocused: isFieldFocused, cornerRadius: Sizing.radiusMedium)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth = $0 }
        .background(alignment: .bottom) { suggestionAnchor }
        .onChange(of: draft) { oldText, newText in handleDraftChange(from: oldText, to: newText) }
        .onChange(of: isFieldFocused) { _, focused in
            guard !focused else { return }
            // Leaving the field keeps what was typed.
            commitDraft()
            list.close()
            selectedIndex = nil
        }
        .onChange(of: tokens) { _, newTokens in
            if let selectedIndex, selectedIndex >= newTokens.count { self.selectedIndex = nil }
        }
    }

    // MARK: Field

    private var field: some View {
        // An empty prompt, not nil, once there are tokens: with no prompt the
        // field shows its label as the placeholder.
        TextField(text: $draft, prompt: tokens.isEmpty ? Text(placeholder) : Text(verbatim: "")) {
            Text(placeholder)
        }
        .textFieldStyle(.plain)
        .font(Typography.bodySmall)
        .focused($isFieldFocused)
        .padding(.horizontal, Spacing.xxs)
        .onKeyPress { press in handleKey(press) }
        .accessibilityActions {
            if !suggestions.isEmpty {
                Button {
                    _ = openSuggestions()
                } label: {
                    Text("Show Suggestions", bundle: .module)
                }
            }
        }
    }

    /// The suggestion list hangs off a zero-height strip along the box's bottom
    /// edge: a click anywhere in the box (the field, a chip) then counts as
    /// outside the menu, which closes it, rather than as its trigger, which
    /// would hide it while it still reads as open.
    private var suggestionAnchor: some View {
        Color.clear
            .frame(height: 0)
            .floatingMenu(isPresented: $list.isPresented, xPosition: .leading, yPosition: .below, menuGap: Spacing.xxs) {
                SuggestionListContent(model: list, width: max(boxWidth, 160), title: title) { token in
                    pick(token)
                }
            }
    }

    // MARK: Tokens

    /// Stable chip identities: a token plus which occurrence of it this is, so
    /// a binding that holds a repeat still gets unique IDs.
    private var chipIDs: [TokenChipID<Token>] {
        var seen: [Token: Int] = [:]
        return tokens.map { token in
            let occurrence = seen[token, default: 0]
            seen[token] = occurrence + 1
            return TokenChipID(token: token, occurrence: occurrence)
        }
    }

    /// Suggestions not already added.
    private var availableSuggestions: [Token] {
        let added = tokens.map(title)
        return suggestions.filter { TokenParsing.indexOfDuplicate(title($0), in: added) == nil }
    }

    private var tokenAnimation: Animation? {
        prefersReducedMotion ? nil : Animations.selection
    }

    private func insert(_ candidates: [Token]) {
        guard !candidates.isEmpty else { return }
        let result = TokenParsing.appending(candidates, to: tokens, title: title)
        if result.tokens.count != tokens.count {
            withAnimation(tokenAnimation) { tokens = result.tokens }
        }
        if let duplicate = result.duplicates.last { flash(duplicate) }
    }

    private func insertTitles(_ titles: [String]) {
        insert(titles.compactMap(makeToken))
    }

    private func removeToken(at index: Int) {
        guard tokens.indices.contains(index) else { return }
        selectedIndex = nil
        _ = withAnimation(tokenAnimation) { tokens.remove(at: index) }
    }

    /// Adds what's typed. Returns false when there was nothing to add.
    @discardableResult
    private func commitDraft() -> Bool {
        let titles = TokenParsing.titles(in: draft)
        guard !titles.isEmpty else { return false }
        draft = ""
        insertTitles(titles)
        return true
    }

    private func pick(_ token: Token) {
        list.close()
        draft = ""
        insert([token])
    }

    /// The repeated chip lights up for a moment (a fade, so Reduce Motion keeps it).
    private func flash(_ index: Int) {
        flashGeneration += 1
        let generation = flashGeneration
        withAnimation(Animations.hover) { flashedIndex = index }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard generation == flashGeneration else { return }
            withAnimation(Animations.hover) { flashedIndex = nil }
        }
    }

    // MARK: Editing

    private func handleDraftChange(from oldText: String, to newText: String) {
        guard newText != oldText else { return }
        if let commit = TokenParsing.commit(from: oldText, to: newText) {
            draft = commit.draft
            insertTitles(commit.titles)
            return
        }
        // A token never starts with a blank (the space typed after a comma).
        if oldText.isEmpty, !newText.isEmpty, newText.allSatisfy(\.isWhitespace) {
            draft = ""
            return
        }
        guard isFieldFocused else { return }
        refreshSuggestions()
    }

    /// Re-ranks for the typed text: the list shows while there's text that
    /// matches, and closes when the field is emptied.
    private func refreshSuggestions() {
        guard !suggestions.isEmpty else { return }
        list.update(availableSuggestions, query: draft, limit: maxSuggestions, highlightsFirstMatch: false, title: title)
        if draft.trimmingCharacters(in: .whitespaces).isEmpty || list.matches.isEmpty {
            list.close()
        } else {
            list.isPresented = true
        }
    }

    /// ↓ in a closed list: opens it on the first match. False when there's
    /// nothing to offer.
    private func openSuggestions() -> Bool {
        list.update(availableSuggestions, query: draft, limit: maxSuggestions, highlightsFirstMatch: false, title: title)
        guard !list.matches.isEmpty else { return false }
        list.isPresented = true
        list.moveHighlight(by: 1)
        announceHighlight()
        return true
    }

    private func select(_ index: Int?) {
        selectedIndex = index
    }

    /// The field's keys. Token keys (Backspace, ← / →) act only on plain
    /// presses; with ⌘ / ⌥ / ⇧ they stay the field's own editing keys.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let isPlain = press.modifiers.isDisjoint(with: [.command, .option, .control, .shift])
        switch press.key {
        case .downArrow where isPlain:
            if list.isPresented {
                list.moveHighlight(by: 1)
                announceHighlight()
                return .handled
            }
            return openSuggestions() ? .handled : .ignored
        case .upArrow where isPlain && list.isPresented:
            list.moveHighlight(by: -1)
            announceHighlight()
            return .handled
        // Tab and Shift-Tab (which arrives as the back-tab character) step
        // through an open list, as they do in every menu.
        case .tab where list.isPresented, KeyEquivalent("\u{19}") where list.isPresented:
            list.moveHighlight(by: press.modifiers.contains(.shift) || press.key == KeyEquivalent("\u{19}") ? -1 : 1)
            announceHighlight()
            return .handled
        case .return where isPlain:
            if list.isPresented, let token = list.highlightedItem {
                pick(token)
                return .handled
            }
            list.close()
            return commitDraft() ? .handled : .ignored
        case .escape where isPlain:
            if selectedIndex != nil {
                select(nil)
                return .handled
            }
            if !draft.isEmpty {
                draft = ""
                return .handled
            }
            return .ignored
        case .delete where isPlain, .backspace where isPlain:
            if let selectedIndex {
                removeToken(at: selectedIndex)
                return .handled
            }
            if draft.isEmpty, !tokens.isEmpty {
                select(tokens.count - 1)
                return .handled
            }
            return .ignored
        case .deleteForward where isPlain:
            if let selectedIndex {
                removeToken(at: selectedIndex)
                return .handled
            }
            return .ignored
        case .leftArrow where isPlain:
            if let selectedIndex {
                select(max(0, selectedIndex - 1))
                return .handled
            }
            if draft.isEmpty, !tokens.isEmpty {
                select(tokens.count - 1)
                return .handled
            }
            return .ignored
        case .rightArrow where isPlain:
            guard let selectedIndex else { return .ignored }
            select(selectedIndex + 1 < tokens.count ? selectedIndex + 1 : nil)
            return .handled
        default:
            // Typing over a selected token drops the selection and types.
            if selectedIndex != nil, !press.characters.isEmpty { select(nil) }
            return .ignored
        }
    }

    /// VoiceOver can't see the floating list move, so it hears the row.
    private func announceHighlight() {
        guard let token = list.highlightedItem else { return }
        AccessibilityNotification.Announcement(title(token)).post()
    }
}

extension TokenField where Token == String {
    /// A tag input over plain strings.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while there are no tokens; also the field's
    ///     accessibility label. Looked up in your app's strings.
    ///   - tokens: The tokens, in order.
    ///   - suggestions: Offered under the field as you type. Empty for none.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    ///   - isValid: False tints a token `Danger` (it's still added).
    public init(
        _ placeholder: LocalizedStringKey,
        tokens: Binding<[String]>,
        suggestions: [String] = [],
        maxSuggestions: Int = 8,
        isValid: @escaping (String) -> Bool = { _ in true }
    ) {
        self.init(
            placeholder,
            tokens: tokens,
            suggestions: suggestions,
            maxSuggestions: maxSuggestions,
            title: { $0 },
            makeToken: { $0 },
            isValid: isValid
        )
    }
}

extension KeyEquivalent {
    /// The character the Delete (backspace) key types on a Mac, U+007F —
    /// what a `KeyPress` for it carries. SwiftUI's `.delete` is U+0008, so
    /// `onKeyPress(.delete)` alone never sees the key.
    static let backspace = KeyEquivalent("\u{7F}")
}

/// A chip's identity: the token and which repeat of it this is.
private struct TokenChipID<Token: Hashable>: Hashable {
    let token: Token
    let occurrence: Int
}

// MARK: - Chip

/// One token: `Badge`'s secondary look with a ✕, or — invalid — a `Danger`
/// wash like the status chips' (`Badge`'s own `.error` fill is the saturated
/// ramp tone in light mode, which the red label doesn't read on). The ✕ isn't
/// a Tab stop — the field's Backspace and ← / → reach every token — and
/// VoiceOver removes a token with the chip's own action.
private struct TokenChip: View {
    let title: String
    let isInvalid: Bool
    let isSelected: Bool
    let isFlashing: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isRemoveHovered = false

    private var style: BadgeStyle {
        guard isInvalid else { return .secondary }
        let isDark = colorScheme == .dark
        let mark = Danger.danger500.legibleOnDark(colorScheme)
        return .custom(
            text: mark,
            icon: mark,
            background: Danger.tint.opacity(isDark ? 0.2 : 0.1),
            border: Danger.tint.opacity(isDark ? 0.4 : 0.3)
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
    }

    private var removeLabel: String {
        String(localized: "Remove \(title)", bundle: .module)
    }

    var body: some View {
        HStack(spacing: Spacing.hairline) {
            if isInvalid {
                Image(systemName: "exclamationmark.circle")
                    .font(Typography.labelXSmall)
                    .foregroundStyle(style.iconColor(for: colorScheme))
            }
            Text(verbatim: title)
                .font(Typography.caption)
                .foregroundStyle(style.textColor(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.middle)
            removeButton
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.hairline)
        .padding(.vertical, Spacing.hairline)
        .background {
            shape.fill(style.backgroundColor(for: colorScheme))
            shape.fill(RowTint.selected(colorScheme)).opacity(isFlashing ? 1 : 0)
        }
        .overlay {
            shape.strokeBorder(style.borderColor(for: colorScheme), lineWidth: 1)
        }
        // The selected token carries the ring; it shows whether the keys or a
        // click selected it, since the field keeps the real focus.
        .focusRing(isFocused: isSelected, cornerRadius: Sizing.radiusSmall, showsOnPointerFocus: true)
        .contentShape(shape)
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(isInvalid ? Text("Invalid", bundle: .module) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(named: Text(verbatim: removeLabel), onRemove)
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(Typography.labelXTinySemibold)
                .foregroundStyle(style.iconColor(for: colorScheme))
                .frame(width: Sizing.iconSmall, height: Sizing.iconSmall)
                .background {
                    Circle().fill(isRemoveHovered ? RowTint.selected(colorScheme) : Color.clear)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isRemoveHovered = $0 }
        .animation(Animations.hover, value: isRemoveHovered)
        .accessibilityLabel(Text(verbatim: removeLabel))
    }
}

// MARK: - Layout

/// `FlowLayout`, except the last subview — the text field — stretches over
/// the rest of its line, and wraps onto a line of its own when less than
/// `minimumFieldWidth` is left. Items in a line are centered on each other
/// (a chip is taller than the field's text). `FlowLayout` places every child
/// at its ideal size, which can't express a field that fills what's left.
struct TokenFlowLayout: Layout {
    var spacing: CGFloat
    var minimumFieldWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat?, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = width ?? .infinity
        var frames = [CGRect](repeating: .zero, count: subviews.count)
        var lines: [[Int]] = [[]]
        var lineHeights: [CGFloat] = [0]
        var x: CGFloat = 0
        var widest: CGFloat = 0

        func wrap() {
            x = 0
            lines.append([])
            lineHeights.append(0)
        }

        for index in subviews.indices {
            let subview = subviews[index]
            let size: CGSize
            if index == subviews.count - 1 {
                if x > 0, maxWidth - x < minimumFieldWidth { wrap() }
                let fieldWidth = maxWidth.isFinite
                    ? maxWidth - x
                    : max(minimumFieldWidth, subview.sizeThatFits(.unspecified).width)
                size = CGSize(width: fieldWidth, height: subview.sizeThatFits(ProposedViewSize(width: fieldWidth, height: nil)).height)
            } else {
                let ideal = subview.sizeThatFits(.unspecified)
                // A token longer than the box truncates to its width.
                size = ideal.width > maxWidth
                    ? CGSize(width: maxWidth, height: subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)).height)
                    : ideal
                if x > 0, x + size.width > maxWidth { wrap() }
            }
            frames[index] = CGRect(origin: CGPoint(x: x, y: 0), size: size)
            lines[lines.count - 1].append(index)
            lineHeights[lineHeights.count - 1] = max(lineHeights[lineHeights.count - 1], size.height)
            x += size.width + spacing
            widest = max(widest, x - spacing)
        }

        var y: CGFloat = 0
        for (line, height) in zip(lines, lineHeights) {
            for index in line {
                frames[index].origin.y = y + (height - frames[index].height) / 2
            }
            y += height + spacing
        }
        let height = max(0, y - spacing)
        return (CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: height), frames)
    }
}

// MARK: - Preview

private struct TokenFieldPreviewHost: View {
    @State private var labels = ["Design", "Engineering", "not a label!"]
    @State private var emails: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            TokenField(
                "Add a label",
                tokens: $labels,
                suggestions: ["Design", "Engineering", "Marketing", "Docs", "Bug", "Research"],
                isValid: { !$0.contains("!") }
            )
            TokenField("Invite by email", tokens: $emails, isValid: { $0.contains("@") })
        }
        .padding(Spacing.xl)
    }
}

#Preview(traits: .fixedLayout(width: 420, height: 180)) {
    TokenFieldPreviewHost()
}
