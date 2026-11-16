//
//  CommandPalette.swift
//  BlissUI
//
//  A ⌘K command palette: one card — a search field, the matching commands in
//  sections, and a legend of the scope prefixes — over a blurred, dimmed page.
//  `.commandPalette(isPresented:commands:)` presents it; `CommandPalette` is the
//  card on its own, to embed or show inline.
//
//  Keyboard: ↑ / ↓ (and Tab / Shift-Tab) move, Return runs, Esc clears the query
//  and then closes. The field keeps real focus the whole time, so the selected
//  row draws its own focus ring, and only after the keys moved it.
//
//  The card appears at once with no grow — ⌘K is a keyboard action, used all
//  day — and only the page behind it eases (`Animations.paletteBackdrop`).
//

import AppKit
import SwiftUI

// MARK: - Palette

/// The command palette's card: a search field over the commands that match it,
/// ranked, in your sections, with Recent first while nothing is typed.
///
/// Present it with `.commandPalette(isPresented:commands:)`; use the view itself
/// to embed the card somewhere else.
///
/// ```swift
/// CommandPalette(commands: sections, query: $query) { isShowingPalette = false }
/// ```
public struct CommandPalette: View {
    private let sections: [CommandPaletteSection]
    @Binding private var query: String
    private let placeholder: String?
    private let recentsKey: String?
    private let focusesFieldOnAppear: Bool
    private let compact: Bool
    private let showsLegend: Bool
    private let noResultsText: LocalizedStringKey?
    private let onDismiss: () -> Void
    /// The results list's cap, before it scrolls. The modal passes less when the
    /// window is short.
    var maxResultsHeight: CGFloat = CommandPaletteMetrics.maxResultsHeight

    @Environment(\.colorScheme) private var scheme
    @FocusState private var fieldFocused: Bool
    @State private var selectedIndex = 0
    @State private var hoverIndex: Int?
    // True only for keyboard-driven selection changes, so hovering a row doesn't
    // trigger the auto-scroll (which would shift the whole list under the cursor).
    @State private var scrollToSelection = false
    // The selection was last moved with the keys (arrows / Tab), so the selected
    // row carries the focus ring; hovering or typing hands it back to the fill.
    @State private var selectionMovedByKeyboard = false

    /// - Parameters:
    ///   - commands: The sections, in the order they're listed.
    ///   - query: The search text.
    ///   - placeholder: The field's prompt, shown as is; "Search or jump to…" when nil.
    ///   - recentsKey: The `UserDefaults` key the recent picks are kept under
    ///     (palettes sharing a key share them); nil keeps no recents.
    ///   - focusesFieldOnAppear: Puts the keyboard in the field when the card
    ///     appears. Off for a card embedded in a page, which shouldn't take the
    ///     keys from the page as it opens.
    ///   - compact: A tighter card — the field at the label size, rows a step
    ///     shorter — for a card embedded in a page.
    ///   - showsLegend: The footer of prefixes and keys; off for an app with no
    ///     prefixes, or an embedded card.
    ///   - noResultsText: What an empty result list says ("No projects match");
    ///     the library's "No results" when nil.
    ///   - onDismiss: Esc on an empty field, or a command ran.
    public init(
        commands: [CommandPaletteSection],
        query: Binding<String>,
        placeholder: String? = nil,
        recentsKey: String? = "bliss.commandPalette.recents",
        focusesFieldOnAppear: Bool = true,
        compact: Bool = false,
        showsLegend: Bool = true,
        noResultsText: LocalizedStringKey? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.sections = commands
        self._query = query
        self.placeholder = placeholder
        self.recentsKey = recentsKey
        self.focusesFieldOnAppear = focusesFieldOnAppear
        self.compact = compact
        self.showsLegend = showsLegend
        self.noResultsText = noResultsText
        self.onDismiss = onDismiss
    }

    private var recents: CommandPaletteRecents? {
        recentsKey.map(CommandPaletteRecents.store(for:))
    }

    private var resultSections: [CommandPaletteResultSection] {
        CommandPaletteSearch.results(
            for: query,
            in: sections,
            recentIDs: recents?.commandIDs ?? [],
            recentTitle: String(localized: "Recent", bundle: .module)
        )
    }

    /// Every listed command in keyboard order.
    private var listedCommands: [CommandPaletteCommand] {
        resultSections.flatMap(\.commands)
    }

    /// The card's corners: the floating-panel radius every detached card shares.
    private var cornerRadius: CGFloat { Sizing.radiusLarge }

    public var body: some View {
        let rows = CommandPaletteSearch.displayRows(for: resultSections)
        VStack(spacing: 0) {
            field
            Divider()
            results(rows)
            if showsLegend {
                Divider()
                legendFooter
            }
        }
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PanelSurface.fill)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        // Raised like a sheet: it floats over a blurred page.
        .elevation(.sheet)
        .onAppear {
            guard focusesFieldOnAppear else { return }
            fieldFocused = true
            // The first pass can land before the field is in the window.
            DispatchQueue.main.async { fieldFocused = true }
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
            selectionMovedByKeyboard = false
        }
        // Arrow / return / escape handling while the field owns focus.
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        // Tab and Shift-Tab step through the results like ↓ and ↑ instead of
        // moving focus out from under the palette. Shift-Tab arrives as the
        // back-tab character.
        .onKeyPress(keys: [.tab, KeyEquivalent("\u{19}")], phases: .down) { press in
            moveSelection(press.modifiers.contains(.shift) || press.key == KeyEquivalent("\u{19}") ? -1 : 1)
            return .handled
        }
        .onKeyPress(.return) {
            runSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            if !query.isEmpty { query = "" } else { onDismiss() }
            return .handled
        }
    }

    // MARK: Field

    private var placeholderText: String {
        placeholder ?? String(localized: "Search or jump to…", bundle: .module)
    }

    /// The field's type: a step up from the rows, or the label size when compact.
    private var fieldFont: Font {
        compact ? Typography.labelMedium : Typography.bodyMedium
    }

    private var field: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(fieldFont)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholderText, text: $query)
                .textFieldStyle(.plain)
                .font(fieldFont)
                .focused($fieldFocused)
                .onSubmit { runSelected() }

            // The mouse's way out; the key itself is handled above, so a query
            // clears before Esc closes.
            Button(action: onDismiss) {
                ShortcutKey("esc")
            }
            .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall))
            .accessibilityLabel(Text("Close", bundle: .module))
        }
        // The card is the box: a field's inset, at the regular tier.
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, compact ? Spacing.fieldPaddingV : Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
    }

    // MARK: Results

    private func results(_ rows: [CommandPaletteDisplayRow]) -> some View {
        ScrollViewReader { proxy in
            // Hugs short result lists ("No results", a few rows) and only scrolls
            // past the cap; the edge fades appear once it does. A plain scroll is
            // height-greedy and always stood at the cap.
            AutoHeightScroll(showFadeMask: true, maxHeight: maxResultsHeight) {
                VStack(alignment: .leading, spacing: Spacing.hairline) {
                    if rows.isEmpty {
                        noResults
                            .font(Typography.bodySmall)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Spacing.sm)
                    } else {
                        ForEach(rows) { row in
                            switch row {
                            case .header(_, let title):
                                sectionHeader(title)
                            case .command(let command, let index):
                                commandRow(command, index: index).id(index)
                            }
                        }
                    }
                }
                .padding(Spacing.xs)
            }
            // Takes the list's own height. A `.frame(maxHeight:)` here grew to
            // its cap whenever the overlay offered more room and centered a
            // short list inside the gap.
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: selectedIndex) { _, index in
                // Only follow keyboard navigation; hover sets selectedIndex too but
                // must not scroll the list out from under the pointer.
                guard scrollToSelection else { return }
                scrollToSelection = false
                withAnimation(prefersReducedMotion ? nil : Animations.selection) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    /// The app's own empty line, else the library's.
    @ViewBuilder
    private var noResults: some View {
        if let noResultsText {
            Text(noResultsText)
        } else {
            Text("No results", bundle: .module)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Typography.labelXSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private func commandRow(_ command: CommandPaletteCommand, index: Int) -> some View {
        let isSelected = index == selectedIndex
        let isHovered = hoverIndex == index
        return HStack(spacing: Spacing.sm) {
            Group {
                if let icon = command.icon {
                    // The row's glyph at the label size, like a sidebar row's.
                    IconGlyph(name: icon, color: command.iconColor ?? .secondary, size: FontSize.footnote)
                }
            }
            .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(verbatim: command.title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle = command.subtitle {
                    Text(verbatim: subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailingAffordance(command, isSelected: isSelected)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, compact ? Spacing.xxs : Spacing.navRowPaddingV)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                .fill(isSelected ? RowTint.selected(scheme) : (isHovered ? RowTint.hover(scheme) : Color.clear))
        }
        // `showsOnPointerFocus` because this row tracks its own keyboard state
        // (the field keeps real focus the whole time).
        .focusRing(isFocused: isSelected && selectionMovedByKeyboard, cornerRadius: Sizing.radiusDefault, showsOnPointerFocus: true)
        .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        .onHover { hovering in
            if hovering {
                hoverIndex = index
                selectedIndex = index
                selectionMovedByKeyboard = false
            } else if hoverIndex == index {
                hoverIndex = nil
            }
        }
        // A bare tap, not `rowTapAction`: that adds a Tab stop, and a row that
        // took focus would take it from the field. The keys reach the rows
        // through the field instead; VoiceOver gets the button below.
        .onTapGesture { run(command) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(.default) { run(command) }
    }

    /// Trailing slot: the row's shortcut, else its type tag, when unselected,
    /// crossfading to a "Run ↵" affordance when selected. Both share one ZStack
    /// slot so selecting / hovering a row never reflows it.
    private func trailingAffordance(_ command: CommandPaletteCommand, isSelected: Bool) -> some View {
        ZStack(alignment: .trailing) {
            if let shortcut = command.shortcut {
                ShortcutKey(shortcut)
                    .opacity(isSelected ? 0 : 1)
            } else if let tag = command.tag {
                Text(verbatim: tag)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .opacity(isSelected ? 0 : 1)
            }
            HStack(spacing: Spacing.xxs) {
                Text("Run", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                ShortcutKey("↵")
            }
            .opacity(isSelected ? 1 : 0)
            .accessibilityHidden(true)
        }
    }

    // MARK: Legend

    /// A prefix in the legend and the section it narrows to.
    private struct LegendEntry: Hashable {
        let prefix: String
        let title: String
    }

    /// One legend entry per prefix, titled by the first section that declares it.
    private var legendEntries: [LegendEntry] {
        var seen = Set<String>()
        return sections.compactMap { section in
            guard let prefix = section.prefix, seen.insert(prefix).inserted else { return nil }
            return LegendEntry(prefix: prefix, title: section.title)
        }
    }

    /// The scope legend — each prefix and the section it narrows to — and the
    /// keys. The active prefix lights up, so it doubles as a hint and a live
    /// mode indicator. Narrow, the keys go first.
    private var legendFooter: some View {
        let activePrefix = CommandPaletteSearch.scope(of: query, prefixes: sections.compactMap(\.prefix)).prefix
        return ViewThatFits(in: .horizontal) {
            legendRow(activePrefix: activePrefix, showsKeys: true)
            legendRow(activePrefix: activePrefix, showsKeys: false)
        }
        .font(Typography.captionSmall)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func legendRow(activePrefix: String?, showsKeys: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            if !legendEntries.isEmpty {
                Text("Type", bundle: .module)
                ForEach(legendEntries, id: \.prefix) { entry in
                    legendBadge(entry.prefix, isActive: entry.prefix == activePrefix)
                        .padding(.leading, Spacing.xxs)
                    Text(verbatim: entry.title)
                }
            }
            Spacer(minLength: Spacing.sm)
            if showsKeys {
                ShortcutKey("↑↓")
                Text("Move", bundle: .module)
                ShortcutKey("↵")
                    .padding(.leading, Spacing.xxs)
                Text("Run", bundle: .module)
            }
        }
        .lineLimit(1)
    }

    /// A prefix in the legend: the small neutral pill, lit in the accent wash
    /// while its scope is active.
    private func legendBadge(_ prefix: String, isActive: Bool) -> some View {
        Badge(.verbatim(prefix))
            .badgeStyle(isActive ? .primary : .secondary)
            .badgeSize(.small)
            .badgeShape(.roundedRect)
    }

    // MARK: Actions

    private func moveSelection(_ delta: Int) {
        guard let moved = CommandPaletteSearch.movedSelection(from: selectedIndex, by: delta, count: listedCommands.count) else { return }
        scrollToSelection = true
        selectedIndex = moved
        hoverIndex = nil
        selectionMovedByKeyboard = true
    }

    private func runSelected() {
        let commands = listedCommands
        guard commands.indices.contains(selectedIndex) else { return }
        run(commands[selectedIndex])
    }

    /// Records it, closes the palette, then runs it — so what it opens (a sheet,
    /// another page) lands on a page that's no longer behind the palette.
    private func run(_ command: CommandPaletteCommand) {
        if command.recordsRecent { recents?.record(command.id) }
        query = ""
        onDismiss()
        command.action()
    }
}

// MARK: - Presentation

/// Where the palette's card sits in the window.
public nonisolated enum CommandPalettePlacement: Sendable {
    /// A fifth of the way down, like Linear's.
    case top
    /// Centered, like Spotlight's.
    case center
}

/// The palette's sizes.
public enum CommandPaletteMetrics {
    /// The results list's cap before it scrolls.
    public static let maxResultsHeight: CGFloat = 394
    /// The narrowest the card gets in a narrow window.
    static let minimumWidth: CGFloat = 300
    /// The results list never shrinks below this, even in a short window.
    static let minimumResultsHeight: CGFloat = 120
    /// The field, the footer and the dividers around the list — what the card
    /// needs besides its results.
    static let chromeHeight: CGFloat = 84
    /// How far down the window a `.top` card sits.
    static let topFraction: CGFloat = 0.2
}

extension View {
    /// Presents a command palette over this view while `isPresented` is true:
    /// the view blurs and dims behind the card and is out of the keyboard's and
    /// VoiceOver's reach, like under an app sheet; a click on it closes the
    /// palette. Apply it high in the window (inside `.appSheetHost()`, so ⌘K
    /// does nothing under a sheet).
    ///
    /// - Parameters:
    ///   - isPresented: Whether the palette shows. ⌘K and the palette's own
    ///     keys set it.
    ///   - commands: The sections, in the order they're listed.
    ///   - shortcut: Toggles the palette; nil binds no key.
    ///   - placeholder: The field's prompt, shown as is; "Search or jump to…" when nil.
    ///   - recentsKey: The `UserDefaults` key the recent picks are kept under;
    ///     nil keeps no recents.
    ///   - width: The card's widest; a window with a sidebar and a narrow
    ///     content pane wants less than `Sizing.commandPaletteWidth`.
    ///   - placement: A fifth of the way down the window, or centered.
    ///   - compact: A tighter card (see `CommandPalette`).
    ///   - showsLegend: The footer of prefixes and keys.
    ///   - noResultsText: What an empty result list says.
    public func commandPalette(
        isPresented: Binding<Bool>,
        commands: [CommandPaletteSection],
        shortcut: KeyboardShortcut? = KeyboardShortcut("k", modifiers: .command),
        placeholder: String? = nil,
        recentsKey: String? = "bliss.commandPalette.recents",
        width: CGFloat = Sizing.commandPaletteWidth,
        placement: CommandPalettePlacement = .top,
        compact: Bool = false,
        showsLegend: Bool = true,
        noResultsText: LocalizedStringKey? = nil
    ) -> some View {
        modifier(CommandPaletteModifier(
            isPresented: isPresented,
            sections: commands,
            shortcut: shortcut,
            placeholder: placeholder,
            recentsKey: recentsKey,
            width: width,
            placement: placement,
            compact: compact,
            showsLegend: showsLegend,
            noResultsText: noResultsText
        ))
    }

    /// A command palette of one untitled section.
    public func commandPalette(
        isPresented: Binding<Bool>,
        commands: [CommandPaletteCommand],
        shortcut: KeyboardShortcut? = KeyboardShortcut("k", modifiers: .command),
        placeholder: String? = nil,
        recentsKey: String? = "bliss.commandPalette.recents",
        width: CGFloat = Sizing.commandPaletteWidth,
        placement: CommandPalettePlacement = .top,
        compact: Bool = false,
        showsLegend: Bool = true,
        noResultsText: LocalizedStringKey? = nil
    ) -> some View {
        commandPalette(
            isPresented: isPresented,
            commands: [CommandPaletteSection("", commands: commands)],
            shortcut: shortcut,
            placeholder: placeholder,
            recentsKey: recentsKey,
            width: width,
            placement: placement,
            compact: compact,
            showsLegend: showsLegend,
            noResultsText: noResultsText
        )
    }
}

private struct CommandPaletteModifier: ViewModifier {
    @Binding var isPresented: Bool
    let sections: [CommandPaletteSection]
    let shortcut: KeyboardShortcut?
    let placeholder: String?
    let recentsKey: String?
    let width: CGFloat
    let placement: CommandPalettePlacement
    let compact: Bool
    let showsLegend: Bool
    let noResultsText: LocalizedStringKey?

    @State private var query = ""

    func body(content: Content) -> some View {
        content
            // Modal for the keyboard and VoiceOver too, not just the mouse: Tab
            // can't walk into the page behind, and its shortcuts can't fire.
            .disabled(isPresented)
            .accessibilityHidden(isPresented)
            // Scoped to the blur: a value-keyed `.animation` here would also
            // retime whatever the picked command changes on the page.
            .animation(Animations.paletteBackdrop) { page in
                page.blur(radius: isPresented ? Scrim.backdropBlur : 0)
            }
            .overlay { paletteLayer }
            // Outside the part the palette disables, so ⌘K closes it again — but
            // inside whatever disables this view (a sheet), where it doesn't fire.
            .background { shortcutButton }
            .onChange(of: isPresented) { _, presented in
                if !presented { query = "" }
            }
    }

    private var paletteLayer: some View {
        GeometryReader { proxy in
            // A `.top` card sits a fifth of the way down; a `.center` one gets
            // the whole height to center in.
            let top = placement == .top ? max(Spacing.xxxl, proxy.size.height * CommandPaletteMetrics.topFraction) : 0
            let spareHeight = placement == .top
                ? proxy.size.height - top - CommandPaletteMetrics.chromeHeight - Spacing.xl
                : proxy.size.height - CommandPaletteMetrics.chromeHeight - Spacing.xxl * 2
            ZStack(alignment: placement == .top ? .top : .center) {
                // The dim, which also takes the click that closes it. Always
                // mounted so it can fade.
                Color.black.opacity(isPresented ? Scrim.opacity : 0)
                    .contentShape(Rectangle())
                    .allowsHitTesting(isPresented)
                    .onTapGesture { isPresented = false }
                    .animation(Animations.paletteBackdrop, value: isPresented)

                if isPresented {
                    CommandPalette(
                        commands: sections,
                        query: $query,
                        placeholder: placeholder,
                        recentsKey: recentsKey,
                        compact: compact,
                        showsLegend: showsLegend,
                        noResultsText: noResultsText,
                        onDismiss: { isPresented = false }
                    )
                    .resultsHeight(max(CommandPaletteMetrics.minimumResultsHeight, min(CommandPaletteMetrics.maxResultsHeight, spareHeight)))
                    .frame(width: max(CommandPaletteMetrics.minimumWidth, min(width, proxy.size.width - Spacing.xxl * 2)))
                    .padding(.top, top)
                    .accessibilityAddTraits(.isModal)
                    // At once, even inside an animated transaction.
                    .transition(.identity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // The whole host, title-bar band included, so the dim covers (and
        // blocks) the controls up there too.
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var shortcutButton: some View {
        if let shortcut {
            Button { isPresented.toggle() } label: { EmptyView() }
                .keyboardShortcut(shortcut)
                .focusable(false)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

extension CommandPalette {
    /// The same palette with a different cap on its results list.
    fileprivate func resultsHeight(_ height: CGFloat) -> CommandPalette {
        var palette = self
        palette.maxResultsHeight = height
        return palette
    }
}

// MARK: - Preview

private enum CommandPalettePreviewData {
    static let sections: [CommandPaletteSection] = [
        CommandPaletteSection("Go to", prefix: "#", commands: [
            CommandPaletteCommand(id: "inbox", title: "Inbox", icon: "tray", shortcut: "⌘1") {},
            CommandPaletteCommand(id: "today", title: "Today", icon: "sun.max", shortcut: "⌘2") {},
            CommandPaletteCommand(id: "settings", title: "Settings", icon: "gearshape", shortcut: "⌘,") {},
        ]),
        CommandPaletteSection("Projects", prefix: "@", showsWithoutQuery: false, maxResults: 5, commands: [
            CommandPaletteCommand(id: "apollo", title: "Apollo", subtitle: "~/Developer/apollo", icon: IconItem.statusDotName, iconColor: Success.success500, tag: "Open") {},
            CommandPaletteCommand(id: "borealis", title: "Borealis", subtitle: "~/Developer/borealis", icon: IconItem.statusDotName, iconColor: Grey.grey400, tag: "Open") {},
        ]),
        CommandPaletteSection("Actions", prefix: ">", commands: [
            CommandPaletteCommand(id: "new-project", title: "New project", subtitle: "Start from a template", icon: "plus.circle", shortcut: "⌘N", keywords: ["create", "add"]) {},
            CommandPaletteCommand(id: "new-filter", title: "New filter", subtitle: "A saved view", icon: "line.3.horizontal.decrease", tag: "New") {},
        ]),
    ]
}

#Preview(traits: .fixedLayout(width: 640, height: 460)) {
    @Previewable @State var query = "new"
    CommandPalette(commands: CommandPalettePreviewData.sections, query: $query, recentsKey: nil, onDismiss: {})
        .padding(Spacing.xl)
}
