//
//  FilterMenuRows.swift
//  BlissUI
//
//  Rows for filter and display menus hosted in a `floatingMenu`: a section
//  header, a checkbox row (a facet with its count, or a column toggle), a radio
//  row (a sort or grouping choice), a plain pick row, and the typed-query
//  header a type-to-filter menu shows. Each draws the shared hover fill and,
//  on the row the menu's keys are on, the shared focus ring.
//
//  The rows are `.plain` buttons on purpose: a menu panel can't take key
//  focus, so the menu's own key monitor moves `isFocused` and runs the row
//  (`onActivate` for menus that stay open, `onSelect` for a pick).
//

import SwiftUI

// MARK: - Section header

/// A small caption over a group of menu rows ("Status", "Sort by").
public struct FilterMenuSectionHeader: View {
    let title: LocalizedStringKey

    /// - Parameter title: Looked up in your app's strings, like `Text("…")`.
    public init(_ title: LocalizedStringKey) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(Typography.labelTiny)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.hairline)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Check row

/// A checkbox row: a filter facet with its live count, or a column toggle when
/// `count` is nil. Menus of these stay open — pass `onActivate` returning
/// `.keepOpen` so Return and Space toggle the focused row.
public struct FilterCheckRow: View {
    let title: LocalizedStringKey
    let count: Int?
    let isOn: Bool
    /// The menu's arrow-key highlight.
    let isFocused: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - count: Rows the facet would match, trailing; nil hides it.
    ///   - isOn: Whether the box is checked.
    ///   - isFocused: The menu's arrow-key highlight (its `focusedIndex`).
    ///   - action: Toggles the facet.
    public init(
        _ title: LocalizedStringKey,
        count: Int? = nil,
        isOn: Bool,
        isFocused: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.isOn = isOn
        self.isFocused = isFocused
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                CheckboxGlyph(isOn: isOn)
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.md)
                if let count {
                    Text(count, format: .number)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isHovering || isFocused ? RowTint.hover(scheme) : Color.clear)
            }
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .onHover { isHovering = $0 }
    }
}

// MARK: - Radio row

/// A radio row: one choice of a single-select group (sort by, group by). The
/// menu stays open like a checkbox menu; picking a row moves the dot.
public struct DisplayRadioRow: View {
    let title: LocalizedStringKey
    let isOn: Bool
    /// The menu's arrow-key highlight.
    let isFocused: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - isOn: Whether this is the group's current choice.
    ///   - isFocused: The menu's arrow-key highlight (its `focusedIndex`).
    ///   - action: Picks this choice.
    public init(
        _ title: LocalizedStringKey,
        isOn: Bool,
        isFocused: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isOn = isOn
        self.isFocused = isFocused
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                RadioGlyph(isOn: isOn)
                    // The checkbox's width, so titles line up when a menu mixes
                    // radio and checkbox rows (Sort by over Columns).
                    .frame(width: Sizing.iconSmall, height: Sizing.iconSmall)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isHovering || isFocused ? RowTint.hover(scheme) : Color.clear)
            }
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .onHover { isHovering = $0 }
    }
}

// MARK: - Pick row

/// A menu row sized and tinted like `FloatingMenuPicker`'s rows: an optional
/// leading mark, then the title. Its highlight is `isFocused` alone, so the
/// pointer and the keys share one: set the menu's focused index from the
/// row's hover, as `FloatingMenuPicker` does.
///
/// ```swift
/// FilterMenuRow(.verbatim(field.title), isFocused: focusedIndex == index) {
///     pick(field)
/// } leading: {
///     Image(systemName: field.icon)
/// }
/// .onHover { if $0 { focusedIndex = index } }
/// ```
public struct FilterMenuRow<Leading: View>: View {
    let title: LocalizedStringKey
    let isFocused: Bool
    let isSelected: Bool
    let action: () -> Void
    let leading: () -> Leading

    @Environment(\.colorScheme) private var scheme

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - isFocused: The menu's highlight — its `focusedIndex`, which hover sets.
    ///   - isSelected: Tells VoiceOver the row is chosen (a ticked value, the current operator).
    ///   - action: Runs the row.
    ///   - leading: A mark before the title — a checkbox, an icon, a check.
    public init(
        _ title: LocalizedStringKey,
        isFocused: Bool,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.title = title
        self.isFocused = isFocused
        self.isSelected = isSelected
        self.action = action
        self.leading = leading
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                leading()
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.md)
            }
            // Tighter than the button padding tokens — menu rows read better
            // compact (≈ standard macOS menu row height).
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isFocused ? RowTint.hover(scheme) : Color.clear)
            }
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        // The highlight follows the pointer in these menus, so the ring waits
        // for the next key press.
        .onHover { if $0 { FocusVisibilityService.shared.notePointerInput() } }
    }
}

extension FilterMenuRow where Leading == EmptyView {
    /// A row with no leading mark.
    public init(
        _ title: LocalizedStringKey,
        isFocused: Bool,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(title, isFocused: isFocused, isSelected: isSelected, action: action) { EmptyView() }
    }
}

// MARK: - Search header

/// The typed query of a type-to-filter menu, or its placeholder before
/// anything is typed, over a hairline — and "No matches" when the query
/// empties the list. Typing goes to the floating menu's typeahead
/// (`onTypeahead:`): its detached panel can't host a focused text field, so
/// this header echoes what's been typed.
public struct FilterMenuSearchHeader: View {
    let query: String
    let placeholder: LocalizedStringKey
    let showsNoMatches: Bool

    /// - Parameters:
    ///   - query: What's been typed so far, shown as-is.
    ///   - placeholder: Shown until something is typed; looked up in your app's
    ///     strings, wrap data in `.verbatim(_:)`.
    ///   - showsNoMatches: Adds a "No matches" line under the hairline.
    public init(query: String, placeholder: LocalizedStringKey, showsNoMatches: Bool = false) {
        self.query = query
        self.placeholder = placeholder
        self.showsNoMatches = showsNoMatches
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Group {
                    if query.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(verbatim: query)
                            .foregroundStyle(.primary)
                    }
                }
                .font(Typography.bodySmall)
                .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)

            Divider()
                .padding(.vertical, Spacing.hairline)

            if showsNoMatches {
                Text("No matches", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.xs - 1)
            }
        }
    }
}

// MARK: - Previews

private struct FilterMenuRowsPreview: View {
    @State private var running = true
    @State private var stopped = false
    @State private var sortByName = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            FilterMenuSearchHeader(query: "", placeholder: "Filter…")
            FilterMenuRow("Status", isFocused: true) {} leading: {
                Image(systemName: "circle.dashed")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: Sizing.iconDefault)
            }
            FilterMenuSectionHeader("Status")
            FilterCheckRow("Running", count: 4, isOn: running) { running.toggle() }
            FilterCheckRow("Stopped", count: 2, isOn: stopped) { stopped.toggle() }
            FilterMenuSectionHeader("Sort by")
            DisplayRadioRow("Name", isOn: sortByName) { sortByName = true }
            DisplayRadioRow("Last updated", isOn: !sortByName) { sortByName = false }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 220)
    }
}

#Preview("Filter menu rows", traits: .fixedLayout(width: 260, height: 300)) {
    FilterMenuRowsPreview()
}
