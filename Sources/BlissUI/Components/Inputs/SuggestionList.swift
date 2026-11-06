//
//  SuggestionList.swift
//  BlissUI
//
//  The suggestion dropdown `ComboBox` and `TokenField` share: ranking a query
//  against the candidates, the highlight the keys move, and the rows drawn in
//  a floating panel under the field.
//
//  The field keeps window focus the whole time — a floating panel can't become
//  key — so the field handles ↑ / ↓ / Tab / Return itself and the panel only
//  draws. The list is opened with the plain `floatingMenu(isPresented:)`
//  overload: its key monitor has no rows to step (`itemCount` 0), so it passes
//  every key through to the field except Esc, which closes the list.
//

import SwiftUI

// MARK: - Ranking

/// Orders suggestions by how well they match what was typed. Pure, so it's
/// unit-tested on its own.
nonisolated enum SuggestionRanking {
    /// Case- and diacritic-insensitive, like Spotlight.
    static let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// How well `title` matches `query`, lower is better: 0 the whole title,
    /// 1 a prefix of it, 2 the start of a later word, 3 anywhere inside. nil
    /// for no match. Surrounding whitespace in the query is ignored.
    static func score(_ title: String, query: String) -> Int? {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return 0 }
        if title.compare(needle, options: compareOptions) == .orderedSame { return 0 }
        if title.range(of: needle, options: compareOptions.union(.anchored)) != nil { return 1 }
        if wordMatch(in: title, needle: needle) != nil { return 2 }
        if title.range(of: needle, options: compareOptions) != nil { return 3 }
        return nil
    }

    /// The candidates that match, best first; ties keep their given order. An
    /// empty query keeps every candidate in order. (The `isEmpty` guard matters:
    /// `"".localizedCaseInsensitiveContains` is false.)
    static func rank<Item>(_ candidates: [Item], query: String, title: (Item) -> String) -> [Item] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return candidates }
        return candidates.enumerated()
            .compactMap { offset, item in score(title(item), query: query).map { (score: $0, offset: offset, item: item) } }
            .sorted { ($0.score, $0.offset) < ($1.score, $1.offset) }
            .map(\.item)
    }

    /// The part of `title` a row emphasizes: the earliest word start that
    /// matches, else the first match anywhere.
    static func matchRange(in title: String, query: String) -> Range<String.Index>? {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return nil }
        if let prefix = title.range(of: needle, options: compareOptions.union(.anchored)) { return prefix }
        return wordMatch(in: title, needle: needle) ?? title.range(of: needle, options: compareOptions)
    }

    /// A match that begins where a word does (after a space, dash, slash…).
    private static func wordMatch(in title: String, needle: String) -> Range<String.Index>? {
        var previous: Character?
        for index in title.indices {
            let character = title[index]
            defer { previous = character }
            guard let previous, !(previous.isLetter || previous.isNumber), character.isLetter || character.isNumber else { continue }
            if let range = title.range(of: needle, options: compareOptions.union(.anchored), range: index..<title.endIndex) {
                return range
            }
        }
        return nil
    }
}

// MARK: - Model

/// What the open list shows and which row the keys are on. A reference the
/// field and the panel both observe: the panel's content is built once, when
/// it opens, so it reads this live instead of a snapshot.
@Observable
final class SuggestionListModel<Item: Hashable> {
    var isPresented = false
    /// The rows shown, best first, at most `limit` of them.
    private(set) var matches: [Item] = []
    /// Matches past the cap, summarized under the rows.
    private(set) var hiddenCount = 0
    /// What the rows emphasize.
    private(set) var query = ""
    var highlightedIndex: Int?
    /// Only a highlight the keys moved carries the focus ring: one the pointer
    /// put there would chase the cursor, and the first match a restricted list
    /// lands on wasn't chosen by anyone.
    private(set) var highlightMovedByKeyboard = false

    var highlightedItem: Item? {
        guard let highlightedIndex, matches.indices.contains(highlightedIndex) else { return nil }
        return matches[highlightedIndex]
    }

    /// Re-ranks for `query`. `highlightsFirstMatch` lands on the top row (a
    /// list restricted to its options, where Return should pick it); otherwise
    /// nothing is highlighted until the keys or the pointer move.
    func update(_ candidates: [Item], query: String, limit: Int, highlightsFirstMatch: Bool, title: (Item) -> String) {
        let ranked = SuggestionRanking.rank(candidates, query: query, title: title)
        let cap = max(1, limit)
        matches = Array(ranked.prefix(cap))
        hiddenCount = max(0, ranked.count - cap)
        self.query = query
        highlightedIndex = highlightsFirstMatch && !matches.isEmpty ? 0 : nil
        highlightMovedByKeyboard = false
    }

    /// ↓ / ↑ (and Tab / Shift-Tab): steps the highlight, wrapping at the ends.
    /// From no highlight, ↓ lands on the first row and ↑ on the last.
    func moveHighlight(by delta: Int) {
        guard !matches.isEmpty else { return }
        let count = matches.count
        if let highlightedIndex {
            self.highlightedIndex = ((highlightedIndex + delta) % count + count) % count
        } else {
            highlightedIndex = delta >= 0 ? 0 : count - 1
        }
        highlightMovedByKeyboard = true
    }

    /// Puts the highlight on a row: without a ring for the pointer or the
    /// current value a list opens on, with one when a key put it there.
    func highlight(_ index: Int?, byKeyboard: Bool = false) {
        highlightedIndex = index
        highlightMovedByKeyboard = byKeyboard && index != nil
    }

    func close() {
        isPresented = false
        highlight(nil)
    }
}

// MARK: - List Content

/// The rows in the floating panel: menu rows like `FloatingMenuPicker`'s, the
/// typed text emphasized in each, a checkmark on the current value, and a
/// "+ N more..." line when the cap hides matches.
struct SuggestionListContent<Item: Hashable>: View {
    let model: SuggestionListModel<Item>
    /// The field's width, so the list lines up under it.
    let width: CGFloat
    /// Shows "No matches" for an empty list instead of nothing (a list
    /// restricted to its options says why Return won't take the text).
    var showsNoMatches = false
    /// The current value's title, checked in the list.
    var currentTitle: String? = nil
    let title: (Item) -> String
    let onPick: (Item) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(model.matches.enumerated()), id: \.offset) { index, item in
                row(item, index: index)
            }
            if model.matches.isEmpty, showsNoMatches {
                footnote(Text("No matches", bundle: .module))
            }
            if model.hiddenCount > 0 {
                footnote(Text("+ \(model.hiddenCount) more...", bundle: .module))
            }
        }
        .padding(Spacing.menuPadding)
        .frame(width: width, alignment: .leading)
    }

    private func row(_ item: Item, index: Int) -> some View {
        let itemTitle = title(item)
        let isHighlighted = model.highlightedIndex == index
        let isCurrent = itemTitle == currentTitle
        return Button {
            onPick(item)
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(emphasized(itemTitle))
                    .font(Typography.bodySmall)
                    .foregroundStyle(textColor(isCurrent: isCurrent))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: Spacing.sm)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(Typography.labelSmall)
                        .foregroundStyle(checkmarkColor)
                }
            }
            // The menu rows' compact padding (≈ a native menu row).
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isHighlighted ? RowTint.hover(colorScheme) : Color.clear)
            )
            // `showsOnPointerFocus` because the row tracks its own keyboard
            // state: the field keeps real focus the whole time.
            .focusRing(
                isFocused: isHighlighted && model.highlightMovedByKeyboard,
                cornerRadius: Sizing.radiusDefault,
                showsOnPointerFocus: true
            )
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        }
        // Menu-panel rows stay `.plain`: the panel never takes focus, and the
        // field runs the keys.
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { model.highlight(index) }
        }
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    private func footnote(_ text: Text) -> some View {
        text
            .font(Typography.captionSmall)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)
    }

    /// The title with the typed text in the semibold face (the same 13pt).
    private func emphasized(_ itemTitle: String) -> AttributedString {
        var attributed = AttributedString(itemTitle)
        guard let range = SuggestionRanking.matchRange(in: itemTitle, query: model.query),
              let lower = AttributedString.Index(range.lowerBound, within: attributed),
              let upper = AttributedString.Index(range.upperBound, within: attributed)
        else { return attributed }
        attributed[lower..<upper].font = Typography.labelMediumBold
        return attributed
    }

    /// `FloatingMenuPicker`'s row text: full strength for the current value,
    /// a step back for the rest.
    private func textColor(isCurrent: Bool) -> Color {
        if isCurrent { return colorScheme == .dark ? .white : .primary }
        return colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    private var checkmarkColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)
    }
}
