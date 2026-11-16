//
//  MultiSelectPicker.swift
//  BlissUI
//
//  The pick-many counterpart of `FloatingMenuPicker`: the trigger shows the
//  picked options as chips (the token field's), and its menu is a list of
//  check rows that stays open while you pick. Typing while the menu is open
//  filters the rows, as in the single picker; a Clear row empties the pick.
//

import SwiftUI

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
    public init(
        _ title: String,
        selection: Binding<Set<Option>>,
        options: [Option],
        optionTitle: @escaping (Option) -> String,
        optionIcon: ((Option) -> String)? = nil,
        placeholder: String? = nil,
        showsTitle: Bool = true,
        maximumChips: Int = 3
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.optionTitle = optionTitle
        self.optionIcon = optionIcon
        self.placeholder = placeholder
        self.showsTitle = showsTitle
        self.maximumChips = max(maximumChips, 1)
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

    /// The rows the keys walk: the visible options, then Clear while something
    /// is picked.
    private var itemCount: Int {
        visibleOptions.count + (selection.isEmpty ? 0 : 1)
    }

    private var accessibilityValue: String {
        let titles = selectedOptions.map(optionTitle)
        return titles.isEmpty ? String(localized: "None", bundle: .module) : titles.joined(separator: ", ")
    }

    public var body: some View {
        HStack {
            if showsTitle && !title.isEmpty {
                Text(verbatim: title)
                Spacer()
            }
            Button {
                showingMenu.toggle()
            } label: {
                HStack(spacing: Spacing.inlineSpacing) {
                    triggerContent
                    Image(systemName: "chevron.up.chevron.down")
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
                    focusedIndex = filteredOptions(for: query).isEmpty ? nil : 0
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
                    optionTitle: optionTitle,
                    optionIcon: optionIcon
                )
            }
            .onChange(of: showingMenu) { _, isOpen in
                if !isOpen { typedQuery = "" }
            }
        }
    }

    /// The chips, or the placeholder while nothing is picked.
    @ViewBuilder
    private var triggerContent: some View {
        if selectedOptions.isEmpty {
            Text(verbatim: placeholder ?? title)
        } else {
            HStack(spacing: Spacing.xxs) {
                ForEach(selectedOptions.prefix(maximumChips), id: \.self) { option in
                    TokenChip(title: optionTitle(option)) { selection.remove(option) }
                }
                if selectedOptions.count > maximumChips {
                    Badge(.verbatim("+\(selectedOptions.count - maximumChips)"))
                        .badgeStyle(.secondary)
                        .badgeSize(.small)
                }
            }
        }
    }

    /// Space / Return on a menu row: toggles the option, or clears on the
    /// Clear row past the last option.
    private func activate(_ index: Int) {
        let visible = visibleOptions
        if visible.indices.contains(index) {
            toggle(visible[index])
        } else if index == visible.count, !selection.isEmpty {
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
}

// MARK: - Menu content

/// The menu's rows: a check row per visible option and, while something is
/// picked, a Clear row under a hairline. A `View` struct with bindings, since
/// the floating menu snapshots its content at open.
struct MultiSelectMenuContent<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Set<Option>
    @Binding var focusedIndex: Int?
    /// Type-to-filter query. MUST be a binding — the menu panel snapshots its
    /// content at open time, so only binding reads stay live while it's open.
    @Binding var filterQuery: String
    let optionTitle: (Option) -> String
    let optionIcon: ((Option) -> String)?

    /// Filtered HERE (off the live binding) so the open panel re-renders as
    /// the user types. The `isEmpty` guard is load-bearing.
    private var visibleOptions: [Option] {
        guard !filterQuery.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(filterQuery) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            FilterMenuSearchHeader(
                query: filterQuery,
                placeholder: .verbatim(String(localized: "Type to filter", bundle: .module)),
                showsNoMatches: visibleOptions.isEmpty
            )
            ForEach(Array(visibleOptions.enumerated()), id: \.offset) { index, option in
                row(option, index: index)
            }
            if !selection.isEmpty {
                Divider()
                    .padding(.vertical, Spacing.hairline)
                clearRow(index: visibleOptions.count)
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: 200)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func row(_ option: Option, index: Int) -> some View {
        let isOn = selection.contains(option)
        return FilterMenuRow(.verbatim(optionTitle(option)), isFocused: focusedIndex == index, isSelected: isOn) {
            toggle(option)
        } leading: {
            CheckboxGlyph(isOn: isOn)
            if let optionIcon {
                Image(systemName: optionIcon(option))
                    .font(Typography.caption)
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
            Image(systemName: "xmark.circle")
                .font(Typography.caption)
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

#Preview("Multi-select picker", traits: .fixedLayout(width: 480, height: 160)) {
    @Previewable @State var teams: Set<String> = ["Design", "Engineering"]
    @Previewable @State var regions: Set<String> = []
    VStack(spacing: Spacing.lg) {
        MultiSelectPicker("Teams", selection: $teams, options: ["Design", "Engineering", "Marketing", "Docs", "Support"], optionTitle: { $0 }, optionIcon: { _ in "person.2" })
        MultiSelectPicker("Regions", selection: $regions, options: ["Europe", "Americas", "Asia Pacific"], optionTitle: { $0 }, placeholder: "Any region")
    }
    .padding(Spacing.xl)
}
