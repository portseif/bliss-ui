//
//  OutlineList.swift
//  BlissUI
//
//  A tree of rows — a file browser, grouped settings, nested projects — with
//  a disclosure chevron per parent, one indent per level, and the flat list
//  rows' hover and selection fills. The list is one Tab stop with a roving
//  focused row: ↑ / ↓ move it, → expands (or steps into the children), ←
//  collapses (or steps up to the parent), Home / End jump, Space or Return
//  selects. Expansion is the caller's state (`expanded`), so it can be
//  persisted or driven from a search.
//

import SwiftUI

// MARK: - Outline List

/// A tree of rows with disclosure chevrons, bound to a selection and the set
/// of expanded parents.
///
/// ```swift
/// OutlineList(folders, children: \.children, selection: $selectedID, expanded: $expandedIDs) { folder in
///     Label(folder.name, systemImage: folder.children == nil ? "doc" : "folder")
/// }
/// ```
///
/// The row closure draws the row's content; the chevron, indent, hover and
/// selection fills are the list's. Rows stack flush in a `VStack` — put the
/// list in a `ScrollViewWithThinIndicator` when it can grow tall.
public struct OutlineList<Item: Identifiable, Row: View>: View {
    private let items: [Item]
    private let children: KeyPath<Item, [Item]?>
    @Binding private var selection: Item.ID?
    @Binding private var expanded: Set<Item.ID>
    private let indent: CGFloat
    private let row: (Item) -> Row

    @FocusState private var isFocused: Bool
    /// The row the keys are on, once the list has keyboard focus.
    @State private var focusedID: Item.ID?

    /// - Parameters:
    ///   - items: The top-level rows.
    ///   - children: An item's children; nil marks a leaf (an empty array is a
    ///     parent with nothing in it yet, still shown with a chevron).
    ///   - selection: The selected row's id.
    ///   - expanded: The ids of the open parents.
    ///   - indent: How far each level steps in.
    ///   - row: The row's content for an item.
    public init(
        _ items: [Item],
        children: KeyPath<Item, [Item]?>,
        selection: Binding<Item.ID?>,
        expanded: Binding<Set<Item.ID>>,
        indent: CGFloat = Spacing.lg,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.items = items
        self.children = children
        self._selection = selection
        self._expanded = expanded
        self.indent = indent
        self.row = row
    }

    // MARK: Visible rows

    private struct VisibleRow {
        let item: Item
        let depth: Int
        let parentID: Item.ID?
        let hasChildren: Bool
        let isExpanded: Bool
    }

    /// The rows on screen, top to bottom: every top-level item and, under each
    /// expanded parent, its children.
    private var visibleRows: [VisibleRow] {
        var rows: [VisibleRow] = []
        func append(_ items: [Item], depth: Int, parentID: Item.ID?) {
            for item in items {
                let kids = item[keyPath: children]
                let isExpanded = kids != nil && expanded.contains(item.id)
                rows.append(VisibleRow(item: item, depth: depth, parentID: parentID, hasChildren: kids != nil, isExpanded: isExpanded))
                if isExpanded, let kids { append(kids, depth: depth + 1, parentID: item.id) }
            }
        }
        append(items, depth: 0, parentID: nil)
        return rows
    }

    // MARK: Body

    public var body: some View {
        let rows = visibleRows
        VStack(spacing: 0) {
            ForEach(rows, id: \.item.id) { visible in
                OutlineRowView(
                    depth: visible.depth,
                    indent: indent,
                    hasChildren: visible.hasChildren,
                    isExpanded: visible.isExpanded,
                    isSelected: selection == visible.item.id,
                    hasKeyboardFocus: isFocused && focusedID == visible.item.id,
                    onToggle: { toggle(visible.item.id) },
                    onSelect: {
                        focusedID = visible.item.id
                        selection = visible.item.id
                    }
                ) {
                    row(visible.item)
                }
                .transition(.motion(.opacity))
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow, .home, .end], phases: [.down, .repeat]) { press in
            move(press.key, in: rows)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
            step(press.key, in: rows)
            return .handled
        }
        // Key-down only: a held key would select again and again.
        .onKeyPress(keys: [.space, .return], phases: .down) { _ in
            guard let focusedID else { return .ignored }
            selection = focusedID
            return .handled
        }
        .onChange(of: isFocused) { _, focused in
            // Tab lands on the selected row, else the first.
            if focused, focusedID == nil || !rows.contains(where: { $0.item.id == focusedID }) {
                focusedID = selection ?? rows.first?.item.id
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Keys

    private func toggle(_ id: Item.ID) {
        withAnimation(Animations.disclosure) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }

    private func move(_ key: KeyEquivalent, in rows: [VisibleRow]) {
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex { $0.item.id == focusedID }
        let next: Int
        switch key {
        case .upArrow: next = max((current ?? rows.count) - 1, 0)
        case .downArrow: next = min((current ?? -1) + 1, rows.count - 1)
        case .home: next = 0
        default: next = rows.count - 1
        }
        focusedID = rows[next].item.id
    }

    /// → opens a closed parent, or steps into an open one's first child; ←
    /// closes an open parent, or steps up to the row's parent.
    private func step(_ key: KeyEquivalent, in rows: [VisibleRow]) {
        guard let index = rows.firstIndex(where: { $0.item.id == focusedID }) else {
            focusedID = rows.first?.item.id
            return
        }
        let visible = rows[index]
        if key == .rightArrow {
            if visible.hasChildren && !visible.isExpanded {
                toggle(visible.item.id)
            } else if visible.isExpanded, index + 1 < rows.count, rows[index + 1].parentID == visible.item.id {
                focusedID = rows[index + 1].item.id
            }
        } else {
            if visible.isExpanded {
                toggle(visible.item.id)
            } else if let parentID = visible.parentID {
                focusedID = parentID
            }
        }
    }
}

// MARK: - Row

/// One row of an `OutlineList`: the indent, the chevron (or its space), the
/// content, and the shared hover / selection fill.
private struct OutlineRowView<Content: View>: View {
    let depth: Int
    let indent: CGFloat
    let hasChildren: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let hasKeyboardFocus: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var fill: Color {
        if isSelected { return RowTint.selected(colorScheme) }
        return isHovering ? RowTint.hover(colorScheme) : Color.clear
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Color.clear
                .frame(width: CGFloat(depth) * indent, height: 1)
                .accessibilityHidden(true)
            chevron
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 1)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                .fill(fill)
        }
        .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous))
        .focusRing(isFocused: hasKeyboardFocus, cornerRadius: Sizing.radiusDefault)
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        .animation(Animations.selection, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityAction(.default, onSelect)
        .modifier(OutlineToggleAccessibility(hasChildren: hasChildren, isExpanded: isExpanded, onToggle: onToggle))
    }

    /// The disclosure chevron, rotated open; a leaf keeps its space so rows at
    /// one level line up.
    @ViewBuilder
    private var chevron: some View {
        if hasChildren {
            Button(action: onToggle) {
                Image(systemName: "chevron.right")
                    .font(Typography.captionSmallSemibold)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(Animations.disclosure, value: isExpanded)
                    .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
                .accessibilityHidden(true)
        }
    }
}

/// A parent row says whether it's open and offers Expand / Collapse; a leaf
/// adds nothing.
private struct OutlineToggleAccessibility: ViewModifier {
    let hasChildren: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if hasChildren {
            content
                .accessibilityValue(isExpanded ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))
                .accessibilityAction(named: isExpanded ? Text("Collapse", bundle: .module) : Text("Expand", bundle: .module), onToggle)
        } else {
            content
        }
    }
}

// MARK: - Preview

private struct OutlinePreviewNode: Identifiable {
    let id: String
    let name: String
    let icon: String
    var children: [OutlinePreviewNode]? = nil
}

#Preview("Outline list", traits: .fixedLayout(width: 320, height: 300)) {
    @Previewable @State var selection: String? = "readme"
    @Previewable @State var expanded: Set<String> = ["sources", "components"]
    let tree = [
        OutlinePreviewNode(id: "sources", name: "Sources", icon: "folder", children: [
            OutlinePreviewNode(id: "components", name: "Components", icon: "folder", children: [
                OutlinePreviewNode(id: "badge", name: "Badge.swift", icon: "swift"),
                OutlinePreviewNode(id: "sidebar", name: "Sidebar.swift", icon: "swift"),
            ]),
            OutlinePreviewNode(id: "themes", name: "Themes", icon: "folder", children: []),
        ]),
        OutlinePreviewNode(id: "tests", name: "Tests", icon: "folder", children: [
            OutlinePreviewNode(id: "badge-tests", name: "BadgeTests.swift", icon: "swift"),
        ]),
        OutlinePreviewNode(id: "readme", name: "README.md", icon: "doc.text"),
    ]
    OutlineList(tree, children: \.children, selection: $selection, expanded: $expanded) { node in
        Label {
            Text(verbatim: node.name).font(Typography.bodySmall)
        } icon: {
            Image(systemName: node.icon).foregroundStyle(.secondary)
        }
    }
    .padding(Spacing.md)
}
