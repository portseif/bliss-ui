//
//  MultiSelectPicker.swift
//  BlissUI
//
//  The pick-many counterpart of `FloatingMenuPicker`: the trigger shows the
//  picked options as chips (the token field's, at the small pill size so the
//  trigger keeps the compact control height), and its menu is a list of check
//  rows that stays open while you pick. Typing while the menu is open filters
//  the rows, as in the single picker; a Clear row empties the pick.
//

import SwiftUI

// MARK: - Summary

/// How a multi-select trigger shows what's picked.
public nonisolated enum MultiSelectSummary: Sendable {
    /// A chip per option, folding past `maximumChips` into "+N".
    case chips
    /// "3 selected" — for a filter bar that can't afford chips.
    case count
    /// The titles, comma-separated.
    case titles
}

// MARK: - Multi-Select Picker

/// A picker for several options at once, bound to a `Set`.
///
/// ```swift
/// MultiSelectPicker("Teams", selection: $teams, options: Team.allCases, optionTitle: \.name, optionIcon: { _ in "person.2" })
/// ```
///
/// Chips follow the options' order; past `maximumChips` the rest fold into a
/// "+N" chip. Each chip's ✕ removes its option, Backspace on the focused
/// trigger removes the last one, and Space / Return open the menu. In the
/// menu ↑↓ move, Space / Return toggle the row, typing filters, Esc closes.
public struct MultiSelectPicker<Option: Hashable>: View {
    let title: String
    @Binding var selection: Set<Option>
    let options: [Option]
    let optionTitle: (Option) -> String
    let optionIcon: ((Option) -> String)?
    let placeholder: String?
    /// Draws the title beside the trigger. Pass false where a row already shows
    /// it (a `SettingsRow`); the title still labels the trigger for VoiceOver.
    let showsTitle: Bool
    let maximumChips: Int
    let summary: MultiSelectSummary
    let showsSelectAll: Bool

    @State private var showingMenu = false
    @State private var focusedIndex: Int? = nil
    /// Live type-to-filter query while the menu is open (reset when it closes).
    @State private var typedQuery = ""

    /// - Parameters:
    ///   - title: Labels the trigger (and VoiceOver).
    ///   - selection: The picked options.
    ///   - options: Everything that can be picked, in menu order.
    ///   - optionTitle: How an option reads, on its chip and in the menu.
    ///   - optionIcon: An SF Symbol before an option's title in the menu.
    ///   - placeholder: What the trigger shows while nothing is picked; the
    ///     title when nil.
    ///   - showsTitle: Draws the title beside the trigger.
    ///   - maximumChips: Chips shown before the rest fold into "+N".
    ///   - summary: Chips, a count or the titles on the trigger.
    ///   - showsSelectAll: A "Select all" row at the top of the menu (it picks
    ///     the rows the filter shows).
    public init(
        _ title: String,
        selection: Binding<Set<Option>>,
        options: [Option],
        optionTitle: @escaping (Option) -> String,
        optionIcon: ((Option) -> String)? = nil,
        placeholder: String? = nil,
        showsTitle: Bool = true,
        maximumChips: Int = 3,
        summary: MultiSelectSummary = .chips,
        showsSelectAll: Bool = false
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.optionTitle = optionTitle
        self.optionIcon = optionIcon
        self.placeholder = placeholder
        self.showsTitle = showsTitle
        self.maximumChips = max(maximumChips, 1)
        self.summary = summary
        self.showsSelectAll = showsSelectAll
    }

    /// The picked options in the menu's order.
    private var selectedOptions: [Option] {
        options.filter { selection.contains($0) }
    }

    /// Options narrowed by the typeahead query. The `isEmpty` guard is
    /// load-bearing — `localizedCaseInsensitiveContains("")` returns false.
    private func filteredOptions(for query: String) -> [Option] {
        guard !query.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(query) }
    }

    private var visibleOptions: [Option] { filteredOptions(for: typedQuery) }

    /// Where the option rows start: after the Select all row, when there is one.
    private var optionIndexOffset: Int { showsSelectAll ? 1 : 0 }

    /// The rows the keys walk: Select all, the visible options, then Clear
    /// while something is picked.
    private var itemCount: Int {
        optionIndexOffset + visibleOptions.count + (selection.isEmpty ? 0 : 1)
    }

    private var accessibilityValue: String {
        let titles = selectedOptions.map(optionTitle)
        return titles.isEmpty ? String(localized: "None", bundle: .module) : titles.joined(separator: ", ")
    }

    public var body: some View {
        HStack {
            if showsTitle && !title.isEmpty {
                Text(verbatim: title)
                    .font(Typography.bodySmall)
                Spacer()
            }
            Button {
                showingMenu.toggle()
            } label: {
                HStack(spacing: Spacing.inlineSpacing) {
                    triggerContent
                    BlissSymbol("chevron.up.chevron.down")
                        .font(Typography.bodySmallSemibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(FloatingMenuPickerButtonStyle(isActive: showingMenu))
            // Backspace on the focused trigger drops the last chip, as in the
            // token field. Backspace arrives as U+007F (`KeyEquivalent.backspace`).
            .onKeyPress(keys: [.delete, .backspace], phases: .down) { _ in
                guard let last = selectedOptions.last else { return .ignored }
                selection.remove(last)
                return .handled
            }
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: accessibilityValue))
            .floatingMenu(
                isPresented: $showingMenu,
                itemCount: itemCount,
                focusedIndex: $focusedIndex,
                xPosition: .leading,
                yPosition: .below,
                onTypeahead: { query in
                    typedQuery = query
                    // Land focus on the first match so Space toggles it directly.
                    focusedIndex = filteredOptions(for: query).isEmpty ? nil : optionIndexOffset
                },
                onActivate: { index in
                    activate(index)
                    return .keepOpen
                }
            ) {
                MultiSelectMenuContent(
                    options: options,
                    selection: $selection,
                    focusedIndex: $focusedIndex,
                    filterQuery: $typedQuery,
                    showsSelectAll: showsSelectAll,
                    optionTitle: optionTitle,
                    optionIcon: optionIcon
                )
            }
            .onChange(of: showingMenu) { _, isOpen in
                if !isOpen { typedQuery = "" }
            }
        }
    }

    /// The chips (or the count, or the titles), or the placeholder while
    /// nothing is picked.
    @ViewBuilder
    private var triggerContent: some View {
        if selectedOptions.isEmpty {
            Text(verbatim: placeholder ?? title)
        } else {
            switch summary {
            case .chips:
                HStack(spacing: Spacing.xxs) {
                    ForEach(selectedOptions.prefix(maximumChips), id: \.self) { option in
                        TokenChip(title: optionTitle(option), size: .small) { selection.remove(option) }
                    }
                    if selectedOptions.count > maximumChips {
                        Badge(.verbatim("+\(selectedOptions.count - maximumChips)"))
                            .badgeStyle(.secondary)
                            .badgeSize(.small)
                    }
                }
            case .count:
                Text("\(selectedOptions.count) selected", bundle: .module)
            case .titles:
                Text(verbatim: selectedOptions.map(optionTitle).joined(separator: ", "))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    /// Space / Return on a menu row: Select all, toggles the option, or clears
    /// on the Clear row past the last option.
    private func activate(_ index: Int) {
        let visible = visibleOptions
        if showsSelectAll, index == 0 {
            selectAll(visible)
        } else if visible.indices.contains(index - optionIndexOffset) {
            toggle(visible[index - optionIndexOffset])
        } else if index == visible.count + optionIndexOffset, !selection.isEmpty {
            selection.removeAll()
        }
    }

    private func toggle(_ option: Option) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }

    /// Picks every visible option, or — when they're all picked — drops them.
    private func selectAll(_ visible: [Option]) {
        if visible.allSatisfy(selection.contains) {
            selection.subtract(visible)
        } else {
            selection.formUnion(visible)
        }
    }
}

// MARK: - Menu content

/// The menu's rows: a Select all row when asked, a check row per visible
/// option and, while something is picked, a Clear row under a hairline. A
/// `View` struct with bindings, since the floating menu snapshots its content
/// at open.
struct MultiSelectMenuContent<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Set<Option>
    @Binding var focusedIndex: Int?
    /// Type-to-filter query. MUST be a binding — the menu panel snapshots its
    /// content at open time, so only binding reads stay live while it's open.
    @Binding var filterQuery: String
    var showsSelectAll = false
    let optionTitle: (Option) -> String
    let optionIcon: ((Option) -> String)?

    /// Filtered HERE (off the live binding) so the open panel re-renders as
    /// the user types. The `isEmpty` guard is load-bearing.
    private var visibleOptions: [Option] {
        guard !filterQuery.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(filterQuery) }
    }

    private var optionIndexOffset: Int { showsSelectAll ? 1 : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            FilterMenuSearchHeader(
                query: filterQuery,
                placeholder: .verbatim(String(localized: "Type to filter", bundle: .module)),
                showsNoMatches: visibleOptions.isEmpty
            )
            if showsSelectAll {
                selectAllRow
            }
            ForEach(Array(visibleOptions.enumerated()), id: \.offset) { index, option in
                row(option, index: index + optionIndexOffset)
            }
            if !selection.isEmpty {
                Divider()
                    .padding(.vertical, Spacing.hairline)
                clearRow(index: visibleOptions.count + optionIndexOffset)
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: Sizing.menuMinWidth)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var selectAllRow: some View {
        let visible = visibleOptions
        let allPicked = !visible.isEmpty && visible.allSatisfy(selection.contains)
        return FilterMenuRow(.verbatim(String(localized: "Select all", bundle: .module)), isFocused: focusedIndex == 0, isSelected: allPicked) {
            if allPicked { selection.subtract(visible) } else { selection.formUnion(visible) }
        } leading: {
            CheckboxGlyph(isOn: allPicked)
        }
        .onHover { if $0 { focusedIndex = 0 } }
    }

    private func row(_ option: Option, index: Int) -> some View {
        let isOn = selection.contains(option)
        return FilterMenuRow(.verbatim(optionTitle(option)), isFocused: focusedIndex == index, isSelected: isOn) {
            toggle(option)
        } leading: {
            CheckboxGlyph(isOn: isOn)
            if let optionIcon {
                BlissSymbol(optionIcon(option))
                    .font(Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .frame(width: Sizing.iconDefault)
            }
        }
        .onHover { if $0 { focusedIndex = index } }
    }

    private func clearRow(index: Int) -> some View {
        FilterMenuRow(.verbatim(String(localized: "Clear", bundle: .module)), isFocused: focusedIndex == index) {
            selection.removeAll()
        } leading: {
            BlissSymbol("xmark.circle")
                .font(Typography.labelSmall)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.iconDefault)
        }
        .onHover { if $0 { focusedIndex = index } }
    }

    private func toggle(_ option: Option) {
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}

// MARK: - Preview

#Preview("Multi-select picker", traits: .fixedLayout(width: 480, height: 200)) {
    @Previewable @State var teams: Set<String> = ["Design", "Engineering"]
    @Previewable @State var regions: Set<String> = []
    @Previewable @State var labels: Set<String> = ["Bug", "Docs"]
    VStack(spacing: Spacing.lg) {
        MultiSelectPicker("Teams", selection: $teams, options: ["Design", "Engineering", "Marketing", "Docs", "Support"], optionTitle: { $0 }, optionIcon: { _ in "person.2" })
        MultiSelectPicker("Regions", selection: $regions, options: ["Europe", "Americas", "Asia Pacific"], optionTitle: { $0 }, placeholder: "Any region")
        MultiSelectPicker("Labels", selection: $labels, options: ["Bug", "Docs", "Feature"], optionTitle: { $0 }, summary: .count, showsSelectAll: true)
    }
    .padding(Spacing.xl)
}
