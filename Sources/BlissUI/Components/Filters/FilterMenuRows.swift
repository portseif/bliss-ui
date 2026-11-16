//
//  FilterMenuRows.swift
//  BlissUI
//
//  Rows for filter and display menus hosted in a `floatingMenu`: a section
//  header, a checkbox row (a facet with its count, or a column toggle), a radio
//  row (a sort or grouping choice), a plain pick row, and the typed-query
//  header a type-to-filter menu shows. Every row sits on the one menu-row
//  chrome (`MenuRowHighlight`): `Spacing.menuRowPaddingH` / `menuRowPaddingV`,
//  `Sizing.radiusDefault`, the shared hover fill under the pointer or on the
//  row the menu's keys are on, and the shared focus ring on that row.
//
//  The rows are `.plain` buttons on purpose: a menu panel can't take key
//  focus, so the menu's own key monitor moves `isFocused` and runs the row
//  (`onActivate` for menus that stay open, `onSelect` for a pick).
//

import SwiftUI

// MARK: - Row chrome

/// The one menu-row chrome: inset, hover or keyboard highlight, ring and hit
/// shape. `tint` washes a destructive row in its status color instead of the
/// neutral fill.
struct MenuRowHighlight: ViewModifier {
    let isFocused: Bool
    var tint: Color? = nil

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var fill: Color {
        guard isHovering || isFocused else { return .clear }
        if let tint { return StatusWash.fill(tint, scheme) }
        return RowTint.hover(scheme)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.menuRowPaddingH)
            .padding(.vertical, Spacing.menuRowPaddingV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(fill)
            }
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
            .onHover { hovering in
                isHovering = hovering
                // The highlight follows the pointer in these menus, so the
                // ring waits for the next key press.
                if hovering { FocusVisibilityService.shared.notePointerInput() }
            }
    }
}

extension View {
    /// The menu rows' shared inset, highlight and ring.
    func menuRowHighlight(isFocused: Bool, tint: Color? = nil) -> some View {
        modifier(MenuRowHighlight(isFocused: isFocused, tint: tint))
    }
}

/// A row's secondary line, under its title.
private struct MenuRowDetail: View {
    let detail: LocalizedStringKey

    var body: some View {
        Text(detail)
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

// MARK: - Section header

/// A small caption over a group of menu rows ("Status", "Sort by"), with an
/// optional trailing slot (a count, a Clear link).
public struct FilterMenuSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let trailing: () -> Trailing

    /// - Parameters:
    ///   - title: Looked up in your app's strings, like `Text("…")`.
    ///   - trailing: Sits on the trailing edge of the caption's line.
    public init(_ title: LocalizedStringKey, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(Typography.labelXSmall)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.menuRowPaddingH)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.hairline)
    }
}

extension FilterMenuSectionHeader where Trailing == EmptyView {
    /// - Parameter title: Looked up in your app's strings, like `Text("…")`.
    public init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Check row

/// A checkbox row: a filter facet with its live count, or a column toggle when
/// `count` is nil. Menus of these stay open — pass `onActivate` returning
/// `.keepOpen` so Return and Space toggle the focused row.
public struct FilterCheckRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let count: Int?
    let isOn: Bool
    /// The menu's arrow-key highlight.
    let isFocused: Bool
    let color: Color?
    let systemImage: String?
    let action: () -> Void

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - detail: A second line under the title.
    ///   - count: Rows the facet would match, trailing; nil hides it.
    ///   - isOn: Whether the box is checked.
    ///   - isFocused: The menu's arrow-key highlight (its `focusedIndex`).
    ///   - color: A status dot before the title (or the tint of `systemImage`).
    ///   - systemImage: An SF Symbol before the title.
    ///   - action: Toggles the facet.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        count: Int? = nil,
        isOn: Bool,
        isFocused: Bool = false,
        color: Color? = nil,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.count = count
        self.isOn = isOn
        self.isFocused = isFocused
        self.color = color
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                CheckboxGlyph(isOn: isOn)
                if systemImage != nil || color != nil {
                    IconGlyph(name: systemImage ?? IconItem.statusDotName, color: color ?? .secondary, size: Sizing.iconTiny)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail {
                        MenuRowDetail(detail: detail)
                    }
                }
                Spacer(minLength: Spacing.md)
                if let count {
                    Text(count, format: .number)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .menuRowHighlight(isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .interactiveCursor()
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - Radio row

/// A radio row: one choice of a single-select group (sort by, group by). The
/// menu stays open like a checkbox menu; picking a row moves the dot.
public struct DisplayRadioRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let isOn: Bool
    /// The menu's arrow-key highlight.
    let isFocused: Bool
    let systemImage: String?
    let keyHint: String?
    let action: () -> Void

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - detail: A second line under the title ("Newest first").
    ///   - isOn: Whether this is the group's current choice.
    ///   - isFocused: The menu's arrow-key highlight (its `focusedIndex`).
    ///   - systemImage: An SF Symbol before the title.
    ///   - keyHint: A shortcut shown trailing as a key cap ("⌘1").
    ///   - action: Picks this choice.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        isOn: Bool,
        isFocused: Bool = false,
        systemImage: String? = nil,
        keyHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.isOn = isOn
        self.isFocused = isFocused
        self.systemImage = systemImage
        self.keyHint = keyHint
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
                if let systemImage {
                    IconGlyph(name: systemImage, color: .secondary, size: Sizing.iconTiny)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let detail {
                        MenuRowDetail(detail: detail)
                    }
                }
                Spacer(minLength: Spacing.md)
                if let keyHint {
                    ShortcutKey(keyHint, compact: true)
                        .accessibilityHidden(true)
                }
            }
            .menuRowHighlight(isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .interactiveCursor()
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

// MARK: - Pick row

/// A menu row sized and tinted like `FloatingMenuPicker`'s rows: an optional
/// leading mark, the title, and an optional trailing mark (a checkmark, a
/// count, a shortcut). Its highlight is the shared menu-row one: under the
/// pointer, or on `isFocused`, which the menu's keys set — set the menu's
/// focused index from the row's hover too, as `FloatingMenuPicker` does, so
/// Return runs the row under the pointer.
///
/// ```swift
/// FilterMenuRow(.verbatim(field.title), isFocused: focusedIndex == index) {
///     pick(field)
/// } leading: {
///     Image(systemName: field.icon)
/// }
/// .onHover { if $0 { focusedIndex = index } }
/// ```
public struct FilterMenuRow<Leading: View, Trailing: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let isFocused: Bool
    let isSelected: Bool
    let isDestructive: Bool
    let action: () -> Void
    let leading: () -> Leading
    let trailing: () -> Trailing

    /// - Parameters:
    ///   - title: Looked up in your app's strings; wrap data in `.verbatim(_:)`.
    ///   - detail: A second line under the title.
    ///   - isFocused: The menu's highlight — its `focusedIndex`, which hover sets.
    ///   - isSelected: Tells VoiceOver the row is chosen (a ticked value, the current operator).
    ///   - isDestructive: Sets the title in the danger mark and washes the row
    ///     in it under the pointer ("Remove filter").
    ///   - action: Runs the row.
    ///   - leading: A mark before the title — a checkbox, an icon.
    ///   - trailing: A mark after the title — a checkmark, a count, a shortcut.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        isFocused: Bool,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.isFocused = isFocused
        self.isSelected = isSelected
        self.isDestructive = isDestructive
        self.action = action
        self.leading = leading
        self.trailing = trailing
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                leading()
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(isDestructive ? AnyShapeStyle(Danger.danger500) : AnyShapeStyle(.primary))
                        .lineLimit(1)
                    if let detail {
                        MenuRowDetail(detail: detail)
                    }
                }
                Spacer(minLength: Spacing.md)
                trailing()
            }
            .menuRowHighlight(isFocused: isFocused, tint: isDestructive ? Danger.danger500 : nil)
        }
        .buttonStyle(.plain)
        .interactiveCursor()
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

extension FilterMenuRow where Trailing == EmptyView {
    /// A row with a leading mark and nothing trailing.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        isFocused: Bool,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading
    ) {
        self.init(title, detail: detail, isFocused: isFocused, isSelected: isSelected, isDestructive: isDestructive, action: action, leading: leading) { EmptyView() }
    }
}

extension FilterMenuRow where Leading == EmptyView {
    /// A row with a trailing mark and nothing leading.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        isFocused: Bool,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(title, detail: detail, isFocused: isFocused, isSelected: isSelected, isDestructive: isDestructive, action: action, leading: { EmptyView() }, trailing: trailing)
    }
}

extension FilterMenuRow where Leading == EmptyView, Trailing == EmptyView {
    /// A row with no marks.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        isFocused: Bool,
        isSelected: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(title, detail: detail, isFocused: isFocused, isSelected: isSelected, isDestructive: isDestructive, action: action, leading: { EmptyView() }, trailing: { EmptyView() })
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
    let resultCount: Int?
    let showsIcon: Bool

    /// - Parameters:
    ///   - query: What's been typed so far, shown as-is.
    ///   - placeholder: Shown until something is typed; looked up in your app's
    ///     strings, wrap data in `.verbatim(_:)`.
    ///   - showsNoMatches: Adds a "No matches" line under the hairline.
    ///   - resultCount: How many rows the query left, trailing; nil hides it.
    ///   - showsIcon: The magnifier before the query.
    public init(
        query: String,
        placeholder: LocalizedStringKey,
        showsNoMatches: Bool = false,
        resultCount: Int? = nil,
        showsIcon: Bool = true
    ) {
        self.query = query
        self.placeholder = placeholder
        self.showsNoMatches = showsNoMatches
        self.resultCount = resultCount
        self.showsIcon = showsIcon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: Spacing.xs) {
                if showsIcon {
                    Image(systemName: "magnifyingglass")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
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
                if let resultCount {
                    Spacer(minLength: Spacing.sm)
                    Text(resultCount, format: .number)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, Spacing.menuRowPaddingH)
            .padding(.vertical, Spacing.menuRowPaddingV)

            Divider()
                .padding(.vertical, Spacing.hairline)

            if showsNoMatches {
                Text("No matches", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.menuRowPaddingH)
                    .padding(.vertical, Spacing.menuRowPaddingV)
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
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            FilterMenuSearchHeader(query: "", placeholder: "Filter…")
            FilterMenuRow("Status", isFocused: true) {} leading: {
                Image(systemName: "circle.dashed")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: Sizing.iconDefault)
            }
            FilterMenuSectionHeader("Status")
            FilterCheckRow("Running", count: 4, isOn: running, color: Success.success500) { running.toggle() }
            FilterCheckRow("Stopped", count: 2, isOn: stopped, color: Grey.grey400) { stopped.toggle() }
            FilterMenuSectionHeader("Sort by")
            DisplayRadioRow("Name", isOn: sortByName, keyHint: "⌘1") { sortByName = true }
            DisplayRadioRow("Last updated", detail: "Newest first", isOn: !sortByName) { sortByName = false }
            FilterMenuRow("Remove filter", isFocused: false, isDestructive: true) {}
        }
        .padding(Spacing.menuPadding)
        .frame(width: Sizing.menuMinWidth + Spacing.xxxl)
    }
}

#Preview("Filter menu rows", traits: .fixedLayout(width: 260, height: 340)) {
    FilterMenuRowsPreview()
}
