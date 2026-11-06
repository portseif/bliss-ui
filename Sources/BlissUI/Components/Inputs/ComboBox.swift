//
//  ComboBox.swift
//  BlissUI
//
//  A text field with a ranked suggestion list under it, in a floating panel
//  while the field keeps window focus (`SuggestionList`).
//
//  - ↑ / ↓ (and Tab / Shift-Tab while the list is open) move the highlight;
//    only a row the keys moved to carries the focus ring. Return picks it.
//  - Esc closes the list, a second Esc clears the field.
//  - Free text (`text:`) keeps whatever is typed; restricted (`selection:`)
//    takes only an option — the top match is highlighted so Return picks it,
//    and text that matches none goes back to the current option on leaving.
//

import Accessibility
import SwiftUI

/// A text field with a filtered, ranked suggestion list under it.
///
/// ```swift
/// // Free text, with suggestions
/// ComboBox("City", text: $city, suggestions: ["Berlin", "Lisbon", "Tokyo"])
///
/// // Restricted to the options
/// ComboBox("Assignee", selection: $assignee, options: team, title: \.name)
/// ```
///
/// Typing opens the list; ↓ or the chevron opens it with every option.
public struct ComboBox<Option: Hashable>: View {
    private enum Mode {
        /// The field's text is the value; a pick fills it with the option's title.
        case freeText(Binding<String>, onPick: ((Option) -> Void)?)
        /// The value is one of the options; the field's text is a search.
        case restricted(Binding<Option?>)
    }

    private let placeholder: LocalizedStringKey
    private let mode: Mode
    private let options: [Option]
    private let maxSuggestions: Int
    private let title: (Option) -> String

    /// What's in the field: the bound text (free) or the search (restricted).
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool
    @State private var list = SuggestionListModel<Option>()
    @State private var boxWidth: CGFloat = 0
    /// Text this view wrote into the field itself (a pick, a clear, a revert):
    /// that edit isn't typing, so it mustn't reopen the list.
    @State private var draftWrittenHere: String?

    /// Free text: the field's text is the value, and the options are suggestions.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while the field is empty; also its accessibility
    ///     label. Looked up in your app's strings.
    ///   - text: The field's text.
    ///   - options: The suggestions, ranked against what's typed.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    ///   - title: How an option reads (and the text a pick writes).
    ///   - onPick: Called when a suggestion is picked, after `text` is set.
    public init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        options: [Option],
        maxSuggestions: Int = 8,
        title: @escaping (Option) -> String,
        onPick: ((Option) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self.mode = .freeText(text, onPick: onPick)
        self.options = options
        self.maxSuggestions = maxSuggestions
        self.title = title
    }

    /// Restricted: the value is one of the options, and typing searches them.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while nothing is chosen; also the field's
    ///     accessibility label. Looked up in your app's strings.
    ///   - selection: The chosen option; nil for none (Esc twice clears it).
    ///   - options: The options, ranked against what's typed.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    ///   - title: How an option reads.
    public init(
        _ placeholder: LocalizedStringKey,
        selection: Binding<Option?>,
        options: [Option],
        maxSuggestions: Int = 8,
        title: @escaping (Option) -> String
    ) {
        self.placeholder = placeholder
        self.mode = .restricted(selection)
        self.options = options
        self.maxSuggestions = maxSuggestions
        self.title = title
    }

    private var isRestricted: Bool {
        if case .restricted = mode { return true }
        return false
    }

    /// The text the value reads as: the bound text, or the chosen option's title.
    private var valueText: String {
        switch mode {
        case .freeText(let text, _): text.wrappedValue
        case .restricted(let selection): selection.wrappedValue.map(title) ?? ""
        }
    }

    private var cornerRadius: CGFloat {
        isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            TextField(text: $draft, prompt: Text(placeholder)) {
                Text(placeholder)
            }
            .textFieldStyle(.plain)
            .font(Typography.bodySmall)
            .focused($isFieldFocused)
            .onKeyPress { press in handleKey(press) }
            .accessibilityAction(named: Text("Show Suggestions", bundle: .module)) { openList() }

            disclosureButton
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: Sizing.controlDefault, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { isFieldFocused = true }
        .inputBox(isFocused: isFieldFocused, cornerRadius: cornerRadius)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boxWidth = $0 }
        .background(alignment: .bottom) { suggestionAnchor }
        .onAppear { setDraft(valueText) }
        .onChange(of: valueText) { _, newValue in
            // The value changed from outside: show it, unless it's a
            // restricted search being typed.
            if !isFieldFocused || !isRestricted { setDraft(newValue) }
        }
        .onChange(of: draft) { _, newText in handleDraftChange(newText) }
        .onChange(of: isFieldFocused) { _, focused in
            guard !focused else { return }
            list.close()
            if isRestricted { commitRestrictedText() }
        }
    }

    // MARK: Pieces

    /// Opens or closes the list with the pointer. Part of the field's one
    /// control, like `NSComboBox`'s arrow: the field's ↓ opens the list from
    /// the keyboard and VoiceOver has the field's Show Suggestions action, so
    /// it isn't a Tab stop of its own.
    private var disclosureButton: some View {
        Button {
            // While the list is open, the click outside it closes the list
            // and is swallowed; this runs only to open.
            isFieldFocused = true
            openList()
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(Typography.labelXSmall)
                .foregroundStyle(.tertiary)
                .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityHidden(true)
    }

    /// The list hangs off a zero-height strip along the box's bottom edge, so
    /// a click in the field counts as outside the menu (which closes it)
    /// rather than as its trigger (which hides it but leaves it "open").
    private var suggestionAnchor: some View {
        Color.clear
            .frame(height: 0)
            .floatingMenu(isPresented: $list.isPresented, xPosition: .leading, yPosition: .below, menuGap: Spacing.xxs) {
                SuggestionListContent(
                    model: list,
                    width: max(boxWidth, 160),
                    showsNoMatches: isRestricted,
                    currentTitle: isRestricted ? valueText : nil,
                    title: title
                ) { option in
                    pick(option)
                }
            }
    }

    // MARK: List

    /// Re-ranks for `query`; a restricted list lands on its top match.
    private func refresh(query: String) {
        list.update(options, query: query, limit: maxSuggestions, highlightsFirstMatch: isRestricted, title: title)
    }

    /// ↓, the chevron or VoiceOver: every option (or the matches for typed
    /// free text), on the current value when it's listed.
    private func openList() {
        let showsEverything = isRestricted ? draft == valueText : draft.isEmpty
        refresh(query: showsEverything ? "" : draft)
        guard isRestricted || !list.matches.isEmpty else { return }
        list.isPresented = true
        if let current = list.matches.firstIndex(where: { title($0) == valueText }) {
            list.highlight(current)
        }
    }

    /// Sets the field's text from code rather than the keyboard.
    private func setDraft(_ text: String) {
        guard draft != text else { return }
        draftWrittenHere = text
        draft = text
    }

    private func handleDraftChange(_ newText: String) {
        if let written = draftWrittenHere {
            draftWrittenHere = nil
            if written == newText {
                if case .freeText(let text, _) = mode, text.wrappedValue != newText { text.wrappedValue = newText }
                return
            }
        }
        if case .freeText(let text, _) = mode, text.wrappedValue != newText {
            text.wrappedValue = newText
        }
        // Only typing opens the list, not a value set from outside.
        guard isFieldFocused else { return }
        refresh(query: newText)
        if isRestricted {
            list.isPresented = true
        } else if newText.isEmpty || list.matches.isEmpty {
            list.close()
        } else {
            list.isPresented = true
        }
    }

    private func pick(_ option: Option) {
        list.close()
        let optionTitle = title(option)
        setDraft(optionTitle)
        switch mode {
        case .freeText(let text, let onPick):
            text.wrappedValue = optionTitle
            onPick?(option)
        case .restricted(let selection):
            selection.wrappedValue = option
        }
    }

    /// Restricted text on Return or leaving the field: an option's exact title
    /// (any case) picks it, an empty field clears the choice, anything else
    /// goes back to the current option.
    private func commitRestrictedText() {
        guard case .restricted(let selection) = mode else { return }
        let typed = draft.trimmingCharacters(in: .whitespaces)
        if typed.isEmpty {
            selection.wrappedValue = nil
            setDraft("")
        } else if let match = options.first(where: { title($0).compare(typed, options: .caseInsensitive) == .orderedSame }) {
            pick(match)
        } else {
            setDraft(valueText)
        }
    }

    /// Clears the field, and a restricted choice with it.
    private func clear() {
        list.close()
        setDraft("")
        if case .freeText(let text, _) = mode { text.wrappedValue = "" }
        if case .restricted(let selection) = mode { selection.wrappedValue = nil }
    }

    // MARK: Keys

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let isPlain = press.modifiers.isDisjoint(with: [.command, .option, .control, .shift])
        switch press.key {
        case .downArrow where isPlain:
            if list.isPresented {
                list.moveHighlight(by: 1)
            } else {
                openList()
                guard list.isPresented else { return .ignored }
                // Opened from the keys: the row it lands on (the current
                // value, or the first) carries the ring.
                if let index = list.highlightedIndex {
                    list.highlight(index, byKeyboard: true)
                } else {
                    list.moveHighlight(by: 1)
                }
            }
            announceHighlight()
            return .handled
        case .upArrow where isPlain && list.isPresented:
            list.moveHighlight(by: -1)
            announceHighlight()
            return .handled
        // Tab and Shift-Tab (the back-tab character) step through an open
        // list, as in every menu, instead of leaving the field under it.
        case .tab where list.isPresented, KeyEquivalent("\u{19}") where list.isPresented:
            list.moveHighlight(by: press.modifiers.contains(.shift) || press.key == KeyEquivalent("\u{19}") ? -1 : 1)
            announceHighlight()
            return .handled
        case .return where isPlain:
            if list.isPresented, let option = list.highlightedItem {
                pick(option)
                return .handled
            }
            let wasPresented = list.isPresented
            list.close()
            if isRestricted {
                commitRestrictedText()
                return .handled
            }
            // Free text keeps what's typed; Return goes on to the field's
            // `onSubmit` unless it only closed the list.
            return wasPresented ? .handled : .ignored
        case .escape where isPlain:
            // An open list takes Esc itself (the floating menu's key monitor
            // closes it), so this is the second press.
            guard !draft.isEmpty || !valueText.isEmpty else { return .ignored }
            clear()
            return .handled
        default:
            return .ignored
        }
    }

    /// VoiceOver can't see the floating list move, so it hears the row.
    private func announceHighlight() {
        guard let option = list.highlightedItem else { return }
        AccessibilityNotification.Announcement(title(option)).post()
    }
}

extension ComboBox where Option == String {
    /// Free text with string suggestions.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while the field is empty; also its accessibility
    ///     label. Looked up in your app's strings.
    ///   - text: The field's text.
    ///   - suggestions: Ranked against what's typed.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    public init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        suggestions: [String],
        maxSuggestions: Int = 8
    ) {
        self.init(placeholder, text: text, options: suggestions, maxSuggestions: maxSuggestions, title: { $0 })
    }

    /// Restricted to string options.
    ///
    /// - Parameters:
    ///   - placeholder: Shown while nothing is chosen; also the field's
    ///     accessibility label. Looked up in your app's strings.
    ///   - selection: The chosen option; nil for none.
    ///   - options: Ranked against what's typed.
    ///   - maxSuggestions: The most rows the list shows; the rest are counted.
    public init(
        _ placeholder: LocalizedStringKey,
        selection: Binding<String?>,
        options: [String],
        maxSuggestions: Int = 8
    ) {
        self.init(placeholder, selection: selection, options: options, maxSuggestions: maxSuggestions, title: { $0 })
    }
}

// MARK: - Preview

private struct ComboBoxPreviewHost: View {
    @State private var city = ""
    @State private var language: String? = "Swift"
    private let cities = ["Amsterdam", "Berlin", "Lisbon", "London", "Los Angeles", "San Francisco", "São Paulo", "Tokyo"]
    private let languages = ["C", "Go", "Kotlin", "Python", "Rust", "Swift", "TypeScript"]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ComboBox("City", text: $city, suggestions: cities)
            ComboBox("Language", selection: $language, options: languages)
        }
        .padding(Spacing.xl)
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 160)) {
    ComboBoxPreviewHost()
}
