//
//  BlissTable.swift
//  BlissUI
//
//  A flat, Linear-style data table: a caption header with sortable columns over
//  hairline-divided rows that share the list rows' rounded hover fill. Optional
//  checkbox selection (shift-click picks a range), a tap action per row, and a
//  right-click hook. Pair it with `SelectionBar` for bulk actions.
//
//  Cells are plain views: the `cells` closure returns one view per column, in
//  column order, and `BlissTableRowLayout` gives each its column's width — the
//  header uses the same layout, so labels always sit over their cells.
//

import SwiftUI

// MARK: - Columns

/// How wide a column is.
public enum BlissTableColumnWidth: Hashable, Sendable {
    /// Exactly this wide.
    case fixed(CGFloat)
    /// A share of the width left after fixed columns, never below `minimum`.
    /// In a table with `autoSizeColumns`, its content's width instead — see there.
    case flexible(minimum: CGFloat = 0)
}

/// One column of a `BlissTable`: its header, width, alignment and — when it
/// sorts — how two rows compare.
public struct BlissTableColumn<Row>: Identifiable {
    public let id: String
    public let title: String
    public var width: BlissTableColumnWidth
    public var alignment: HorizontalAlignment
    /// Ascending order (`areInIncreasingOrder`); nil for a column that doesn't sort.
    var comparator: ((Row, Row) -> Bool)?

    /// A column. `title` is looked up in your app's strings, like `Text("…")`.
    public init(
        _ title: String,
        id: String? = nil,
        width: BlissTableColumnWidth = .flexible(),
        alignment: HorizontalAlignment = .leading,
        sortedBy comparator: ((Row, Row) -> Bool)? = nil
    ) {
        self.id = id ?? title
        self.title = title
        self.width = width
        self.alignment = alignment
        self.comparator = comparator
    }

    /// A column that sorts by a comparable value of the row.
    public init<Value: Comparable>(
        _ title: String,
        id: String? = nil,
        width: BlissTableColumnWidth = .flexible(),
        alignment: HorizontalAlignment = .leading,
        sortedBy value: KeyPath<Row, Value>
    ) {
        self.init(title, id: id, width: width, alignment: alignment) { $0[keyPath: value] < $1[keyPath: value] }
    }

    public var isSortable: Bool { comparator != nil }
}

/// The column a table is sorted by, and which way.
public struct BlissTableSort: Hashable, Sendable {
    public var columnID: String
    public var ascending: Bool

    public init(columnID: String, ascending: Bool = true) {
        self.columnID = columnID
        self.ascending = ascending
    }
}

// MARK: - Table

/// A data table with sortable columns, optional checkbox selection and row taps.
///
/// ```swift
/// BlissTable(people, columns: [
///     BlissTableColumn("Name", sortedBy: \Person.name),
///     BlissTableColumn("Role", width: .fixed(120)),
///     BlissTableColumn("Joined", width: .fixed(110), alignment: .trailing, sortedBy: \Person.joined),
/// ], selection: $selected, onOpen: { open($0) }) { person in
///     Text(person.name)
///     Badge(person.role)
///     TimeAgoLabel(date: person.joined)
/// }
/// ```
///
/// Rows sit in an eager `VStack`: a `LazyVStack` re-evaluates row frames while
/// its width animates (a sidebar collapsing) and shifts on-screen rows by a
/// sub-pixel. Pass `isLazy: true` for long tables that never animate width.
/// The table doesn't scroll on its own — put it in a `ScrollViewWithThinIndicator`.
/// `pinsHeader: true` keeps the header at the top of that scroll view while the
/// rows scroll under it. The rows stay eager there too, unless `isLazy`.
///
/// `autoSizeColumns: true` sizes the flexible columns to their content (the
/// widest cell or header label) instead of splitting the room evenly. Short
/// columns — badges, dates — hug their content; when the table runs out of
/// room, the widest columns give way first and text truncates, so no column
/// collapses to nothing.
public struct BlissTable<Row: Identifiable, Cells: View>: View {
    private let rows: [Row]
    private let columns: [BlissTableColumn<Row>]
    private let selection: Binding<Set<Row.ID>>?
    private let externalSort: Binding<BlissTableSort?>?
    private let isLazy: Bool
    private let pinsHeader: Bool
    private let autoSizeColumns: Bool
    private let contentInset: CGFloat
    private let onOpen: ((Row) -> Void)?
    private let onSecondaryClick: ((Row, NSPoint) -> Void)?
    private let cells: (Row) -> Cells

    @State private var internalSort: BlissTableSort?
    /// The row a shift-click range starts from.
    @State private var selectionAnchor: Row.ID?
    /// Each column's widest cell, when `autoSizeColumns`.
    @State private var columnSizer = BlissTableColumnSizer()

    /// - Parameters:
    ///   - rows: The rows, in their unsorted order.
    ///   - columns: Header, width and sorting per column, in display order.
    ///   - selection: Shows a checkbox column bound to these IDs; nil hides it.
    ///   - sortOrder: The sort to show and change; nil keeps it inside the table,
    ///     starting from `initialSort`.
    ///   - initialSort: The first sort when the table owns it.
    ///   - isLazy: Builds rows as they scroll into view.
    ///   - pinsHeader: Keeps the header at the top of the enclosing scroll view,
    ///     on the content surface, while rows scroll under it. Only the header
    ///     sits in a lazy stack (pinning needs one); the rows stay eager unless
    ///     `isLazy`. Turn off the scroll view's `showFadeMask`: the mask would
    ///     fade the header too, and the rows would show through it.
    ///   - autoSizeColumns: Sizes flexible columns to their widest cell or
    ///     header label: short ones hug their content, and when the table is
    ///     too narrow the widest give way first (never below their minimum).
    ///     Fixed columns keep their width.
    ///   - contentInset: Space on each side of the rows' hover fill.
    ///   - onOpen: A click on a row (outside its checkbox and buttons).
    ///   - onSecondaryClick: A right- or control-click on a row, with the screen point.
    ///   - cells: One view per column, in column order.
    public init(
        _ rows: [Row],
        columns: [BlissTableColumn<Row>],
        selection: Binding<Set<Row.ID>>? = nil,
        sortOrder: Binding<BlissTableSort?>? = nil,
        initialSort: BlissTableSort? = nil,
        isLazy: Bool = false,
        pinsHeader: Bool = false,
        autoSizeColumns: Bool = false,
        contentInset: CGFloat = Spacing.xl,
        onOpen: ((Row) -> Void)? = nil,
        onSecondaryClick: ((Row, NSPoint) -> Void)? = nil,
        @ViewBuilder cells: @escaping (Row) -> Cells
    ) {
        self.rows = rows
        self.columns = columns
        self.selection = selection
        self.externalSort = sortOrder
        self.isLazy = isLazy
        self.pinsHeader = pinsHeader
        self.autoSizeColumns = autoSizeColumns
        self.contentInset = contentInset
        self.onOpen = onOpen
        self.onSecondaryClick = onSecondaryClick
        self.cells = cells
        _internalSort = State(initialValue: initialSort)
    }

    public var body: some View {
        tableBody
            .onChange(of: autoSizeColumns ? rows.map(\.id) : []) { _, rowIDs in
                // Rows that left (a filter, a deletion) stop counting toward the widths.
                columnSizer.keep(only: Set(rowIDs.map(AnyHashable.init)).union([BlissTableColumnSizer.headerSource]))
            }
    }

    @ViewBuilder
    private var tableBody: some View {
        let sortedRows = self.sortedRows
        if pinsHeader {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // One eager child, not a lazy row each: lazy rows are
                    // re-measured and rebuilt off screen on every frame of a
                    // width animation, which stalled a sidebar collapse for
                    // seconds on a 100-row table.
                    if isLazy {
                        rowList(sortedRows)
                    } else {
                        VStack(alignment: .leading, spacing: 0) { rowList(sortedRows) }
                    }
                } header: {
                    // Opaque, so rows scrolling under it don't show through. The
                    // content surface alone is a translucent wash on Tahoe dark;
                    // over the shell it matches the pane it sits on.
                    header(sortedRows)
                        .background {
                            ZStack {
                                Color.appShell
                                Color.contentAreaBackground
                            }
                        }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header(sortedRows)
                if isLazy {
                    LazyVStack(alignment: .leading, spacing: 0) { rowList(sortedRows) }
                } else {
                    VStack(alignment: .leading, spacing: 0) { rowList(sortedRows) }
                }
            }
        }
    }

    private func header(_ sortedRows: [Row]) -> some View {
        var header = BlissTableHeader(
            columns: columns,
            sortOrder: sortBinding,
            selectionState: selectionState(for: sortedRows),
            contentInset: contentInset,
            onToggleAll: { toggleAll(sortedRows) }
        )
        if autoSizeColumns {
            header.contentWidths = columnSizer.contentWidths
            header.measureColumn = { [columnSizer] column, width in
                columnSizer.record(width, column: column, from: BlissTableColumnSizer.headerSource)
            }
        }
        return header
    }

    @ViewBuilder
    private func rowList(_ sortedRows: [Row]) -> some View {
        DividedForEach(sortedRows) { row in
            BlissTableRow(
                columns: columns,
                isSelected: selection?.wrappedValue.contains(row.id) ?? false,
                showsCheckbox: selection != nil,
                contentWidths: autoSizeColumns ? columnSizer.contentWidths : nil,
                measureColumn: autoSizeColumns ? { [columnSizer] column, width in
                    columnSizer.record(width, column: column, from: AnyHashable(row.id))
                } : nil,
                onToggleSelection: { toggleSelection(row, in: sortedRows) },
                onOpen: onOpen.map { handler in { handler(row) } },
                onSecondaryClick: onSecondaryClick.map { handler in { point in handler(row, point) } }
            ) {
                cells(row)
            }
            .padding(.horizontal, contentInset)
        } separator: {
            // Dividers span the row's content, not its hover fill.
            Divider().padding(.horizontal, contentInset + Spacing.sm)
        }
    }

    // MARK: Sorting

    private var sortBinding: Binding<BlissTableSort?> {
        externalSort ?? $internalSort
    }

    private var sortedRows: [Row] {
        guard let sort = sortBinding.wrappedValue,
              let comparator = columns.first(where: { $0.id == sort.columnID })?.comparator
        else { return rows }
        let ascending = rows.sorted(by: comparator)
        return sort.ascending ? ascending : ascending.reversed()
    }

    // MARK: Selection

    private func selectionState(for sortedRows: [Row]) -> BlissTableHeader<Row>.SelectionState? {
        guard let selection else { return nil }
        if sortedRows.isEmpty { return .empty }
        let selectedCount = sortedRows.filter { selection.wrappedValue.contains($0.id) }.count
        if selectedCount == sortedRows.count { return .allSelected }
        return selectedCount == 0 ? .unselected : .partial
    }

    private func toggleAll(_ sortedRows: [Row]) {
        guard let selection else { return }
        withAnimation(Animations.selection) {
            if selectionState(for: sortedRows) == .allSelected {
                selection.wrappedValue.subtract(sortedRows.map(\.id))
                selectionAnchor = nil
            } else {
                selection.wrappedValue.formUnion(sortedRows.map(\.id))
                selectionAnchor = sortedRows.last?.id
            }
        }
    }

    /// A click toggles one row; a shift-click adds every row between it and
    /// the last one clicked, in the order on screen.
    private func toggleSelection(_ row: Row, in sortedRows: [Row]) {
        guard let selection else { return }
        let extendsRange = NSEvent.modifierFlags.contains(.shift)
        withAnimation(Animations.selection) {
            if extendsRange,
               let anchor = selectionAnchor,
               let anchorIndex = sortedRows.firstIndex(where: { $0.id == anchor }),
               let clickedIndex = sortedRows.firstIndex(where: { $0.id == row.id }) {
                let range = min(anchorIndex, clickedIndex)...max(anchorIndex, clickedIndex)
                selection.wrappedValue.formUnion(sortedRows[range].map(\.id))
            } else {
                if selection.wrappedValue.contains(row.id) {
                    selection.wrappedValue.remove(row.id)
                } else {
                    selection.wrappedValue.insert(row.id)
                }
                selectionAnchor = row.id
            }
        }
    }
}

// MARK: - Header

/// The caption header over a `BlissTable`: a select-all checkbox, sortable
/// titles with a chevron, on a darker band. `BlissTable` draws one;
/// use this directly to pin the header above a scroll view.
public struct BlissTableHeader<Row>: View {
    public enum SelectionState: Sendable {
        /// No row selected.
        case unselected
        /// Some rows selected.
        case partial
        /// Every row selected.
        case allSelected
        /// No rows to select.
        case empty
    }

    private let columns: [BlissTableColumn<Row>]
    @Binding private var sortOrder: BlissTableSort?
    private let selectionState: SelectionState?
    private let contentInset: CGFloat
    private let onToggleAll: () -> Void
    /// The table's measured column content, when it autosizes columns.
    var contentWidths: [CGFloat]?
    /// Reports each label's natural width, when the table autosizes columns.
    var measureColumn: ((Int, CGFloat) -> Void)?

    @Environment(\.colorScheme) private var scheme

    /// - Parameter selectionState: nil hides the checkbox column.
    public init(
        columns: [BlissTableColumn<Row>],
        sortOrder: Binding<BlissTableSort?>,
        selectionState: SelectionState? = nil,
        contentInset: CGFloat = Spacing.xl,
        onToggleAll: @escaping () -> Void = {}
    ) {
        self.columns = columns
        self._sortOrder = sortOrder
        self.selectionState = selectionState
        self.contentInset = contentInset
        self.onToggleAll = onToggleAll
    }

    public var body: some View {
        HStack(spacing: BlissTableMetrics.columnSpacing) {
            if let selectionState {
                Button(action: onToggleAll) {
                    CheckboxGlyph(isOn: selectionState == .allSelected)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium, outset: -2))
                .frame(width: BlissTableMetrics.checkboxWidth, alignment: .leading)
                .disabled(selectionState == .empty)
                .accessibilityLabel(Text("Select all", bundle: .module))
                .accessibilityAddTraits(selectionState == .allSelected ? [.isSelected] : [])
            }
            BlissTableRowLayout(columns: columns.map(\.width), contentWidths: contentWidths) {
                ForEach(columns) { column in
                    title(for: column)
                        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: column.alignment, vertical: .center))
                }
                if let measureColumn {
                    BlissTableColumnProbes(count: columns.count, report: measureColumn)
                }
            }
        }
        .font(Typography.caption)
        .foregroundStyle(.tertiary)
        // The rows' content inset (outer inset + each row's own padding), so
        // the labels line up over their columns.
        .padding(.horizontal, contentInset + Spacing.sm)
        .padding(.vertical, Spacing.sm)
        // A darker band behind the labels, as wide as the rows' hover fill, so
        // the header reads as its own strip above the rows.
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(bandFill)
                .padding(.horizontal, contentInset)
        }
    }

    /// Black, not `RowTint`'s primary: primary would lighten it in dark mode.
    private var bandFill: Color {
        if prefersIncreasedContrast { return Color.black.opacity(scheme == .dark ? 0.4 : 0.1) }
        return Color.black.opacity(scheme == .dark ? 0.22 : 0.05)
    }

    @ViewBuilder
    private func title(for column: BlissTableColumn<Row>) -> some View {
        if column.isSortable {
            Button {
                if sortOrder?.columnID == column.id {
                    sortOrder?.ascending.toggle()
                } else {
                    sortOrder = BlissTableSort(columnID: column.id)
                }
            } label: {
                HStack(spacing: 3) {
                    Text(LocalizedStringKey(column.title))
                        .lineLimit(1)
                    if let sortOrder, sortOrder.columnID == column.id {
                        Image(systemName: sortOrder.ascending ? "chevron.up" : "chevron.down")
                            .font(Typography.captionTiny)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 3))
            .accessibilityHint(Text("Sorts by this column", bundle: .module))
        } else {
            Text(LocalizedStringKey(column.title))
                .lineLimit(1)
        }
    }
}

// MARK: - Row

/// One table row: checkbox, then the cells laid out by column, on the list
/// rows' rounded fill (hover, and a step stronger when selected).
private struct BlissTableRow<Row, Cells: View>: View {
    let columns: [BlissTableColumn<Row>]
    let isSelected: Bool
    let showsCheckbox: Bool
    let contentWidths: [CGFloat]?
    let measureColumn: ((Int, CGFloat) -> Void)?
    let onToggleSelection: () -> Void
    let onOpen: (() -> Void)?
    let onSecondaryClick: ((NSPoint) -> Void)?
    @ViewBuilder let cells: () -> Cells

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: BlissTableMetrics.columnSpacing) {
            if showsCheckbox {
                Button(action: onToggleSelection) {
                    CheckboxGlyph(isOn: isSelected)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium, outset: -2))
                .frame(width: BlissTableMetrics.checkboxWidth, alignment: .leading)
                .accessibilityLabel(Text("Select row", bundle: .module))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
            cellArea
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.listRowPadding)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(backgroundFill)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .modifier(SecondaryClickIfNeeded(action: onSecondaryClick))
    }

    @ViewBuilder
    private var cellArea: some View {
        let layout = BlissTableRowLayout(
            columns: columns.map(\.width),
            alignments: columns.map(\.alignment),
            contentWidths: contentWidths
        ) {
            cells()
            if let measureColumn {
                BlissTableColumnProbes(count: columns.count, report: measureColumn)
            }
        }
        if let onOpen {
            layout
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                // A Tab stop that Space opens, as a layer behind the cells so
                // buttons inside a cell keep their own focus.
                .keyboardTapTarget(cornerRadius: Sizing.radiusDefault, bleed: 0, perform: onOpen)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onOpen() }
        } else {
            layout.frame(maxWidth: .infinity)
        }
    }

    private var backgroundFill: Color {
        if isSelected { return RowTint.selected(scheme) }
        return isHovering ? RowTint.hover(scheme) : .clear
    }
}

/// `.onSecondaryClick` only when the table was given a handler, so rows
/// without one install no event monitor.
private struct SecondaryClickIfNeeded: ViewModifier {
    let action: ((NSPoint) -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onSecondaryClick(perform: action)
        } else {
            content
        }
    }
}

// MARK: - Layout

enum BlissTableMetrics {
    static let columnSpacing: CGFloat = Spacing.md
    static let checkboxWidth: CGFloat = 22
}

/// Places its subviews side by side at their column widths: fixed columns get
/// their width, flexible ones split what's left (each at least its minimum).
/// Subview N goes in column N; extra subviews get no room.
///
/// With `contentWidths` (a table's `autoSizeColumns`), each flexible column
/// starts at its content's width instead: room to spare is shared evenly, and
/// when there's too little, the widest columns are capped at one common width
/// (never below their minimum) so the narrow ones keep their content.
public struct BlissTableRowLayout: Layout {
    public var columns: [BlissTableColumnWidth]
    public var alignments: [HorizontalAlignment]
    public var spacing: CGFloat
    /// The widest content per column; nil splits flexible columns evenly.
    public var contentWidths: [CGFloat]?

    public init(
        columns: [BlissTableColumnWidth],
        alignments: [HorizontalAlignment] = [],
        spacing: CGFloat = Spacing.md,
        contentWidths: [CGFloat]? = nil
    ) {
        self.columns = columns
        self.alignments = alignments
        self.spacing = spacing
        self.contentWidths = contentWidths
    }

    /// Integer widths, so a row of equal columns lines up exactly with the
    /// header (fractional widths anti-alias unevenly).
    func widths(for totalWidth: CGFloat) -> [CGFloat] {
        guard !columns.isEmpty else { return [] }
        let gaps = spacing * CGFloat(columns.count - 1)
        var fixedTotal: CGFloat = 0
        var flexibleMinimums: [CGFloat] = []
        var flexibleContent: [CGFloat] = []
        for (index, column) in columns.enumerated() {
            switch column {
            case .fixed(let width):
                fixedTotal += width
            case .flexible(let minimum):
                flexibleMinimums.append(minimum)
                flexibleContent.append(contentWidths.flatMap { index < $0.count ? $0[index] : nil } ?? 0)
            }
        }
        let remaining = max(0, totalWidth - fixedTotal - gaps)
        let flexibleWidths: [CGFloat]
        if contentWidths != nil {
            flexibleWidths = Self.fittedWidths(content: flexibleContent, minimums: flexibleMinimums, available: remaining)
        } else {
            let share = flexibleMinimums.isEmpty ? 0 : (remaining / CGFloat(flexibleMinimums.count)).rounded(.down)
            flexibleWidths = flexibleMinimums.map { max($0, share) }
        }
        var nextFlexible = flexibleWidths.makeIterator()
        return columns.map { column in
            switch column {
            case .fixed(let width): return width
            case .flexible: return nextFlexible.next() ?? 0
            }
        }
    }

    /// Flexible widths from their content: content plus an even share of any
    /// room left, or — when the content doesn't fit — the widest capped at the
    /// one width that makes the total fit, each kept at its minimum.
    static func fittedWidths(content: [CGFloat], minimums: [CGFloat], available: CGFloat) -> [CGFloat] {
        guard !content.isEmpty else { return [] }
        let wanted = zip(content, minimums).map { max($0, $1) }
        let wantedTotal = wanted.reduce(0, +)
        if wantedTotal <= available {
            let extra = ((available - wantedTotal) / CGFloat(wanted.count)).rounded(.down)
            return wanted.map { ($0 + extra).rounded(.down) }
        }
        func total(cappedAt cap: CGFloat) -> CGFloat {
            zip(wanted, minimums).reduce(0) { $0 + max($1.1, min($1.0, cap)) }
        }
        var low: CGFloat = 0
        var high = wanted.max() ?? 0
        for _ in 0..<30 {
            let middle = (low + high) / 2
            if total(cappedAt: middle) <= available { low = middle } else { high = middle }
        }
        // The search closes in from below; snap to the whole point when it fits.
        let cap = total(cappedAt: low.rounded(.up)) <= available ? low.rounded(.up) : low.rounded(.down)
        return zip(wanted, minimums).map { max($1, min($0, cap)).rounded(.down) }
    }

    private func naturalWidth() -> CGFloat {
        columns.enumerated().reduce(CGFloat(0)) { total, entry in
            switch entry.element {
            case .fixed(let width):
                return total + width
            case .flexible(let minimum):
                let content = contentWidths.flatMap { entry.offset < $0.count ? $0[entry.offset] : nil } ?? 0
                return total + max(minimum, content)
            }
        } + spacing * CGFloat(max(columns.count - 1, 0))
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? naturalWidth()
        let columnWidths = widths(for: width)
        var height: CGFloat = 0
        for (index, subview) in subviews.filter({ $0[ColumnProbeKey.self] == nil }).enumerated() where index < columnWidths.count {
            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidths[index], height: proposal.height))
            height = max(height, size.height)
        }
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cells = subviews.filter { $0[ColumnProbeKey.self] == nil }
        let columnWidths = widths(for: bounds.width)
        var x = bounds.minX
        for (index, subview) in cells.enumerated() {
            guard index < columnWidths.count else {
                subview.place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .leading, proposal: .zero)
                continue
            }
            let width = columnWidths[index]
            let alignment = index < alignments.count ? alignments[index] : .leading
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: bounds.height))
            let originX: CGFloat
            switch alignment {
            case .trailing: originX = x + width - size.width
            case .center: originX = x + (width - size.width) / 2
            default: originX = x
            }
            subview.place(
                at: CGPoint(x: originX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
        // Each probe is as wide as its cell would like to be, so it can report
        // that width (see `BlissTableColumnProbes`).
        for probe in subviews {
            guard let column = probe[ColumnProbeKey.self] else { continue }
            var idealWidth = column < cells.count ? cells[column].sizeThatFits(.unspecified).width : 0
            if !idealWidth.isFinite { idealWidth = 0 }
            probe.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: min(idealWidth, 4000), height: 0))
        }
    }
}

// MARK: - Column autosizing

/// Marks a `BlissTableColumnProbes` subview with its column.
private nonisolated struct ColumnProbeKey: LayoutValueKey {
    static let defaultValue: Int? = nil
}

/// Zero-height views that `BlissTableRowLayout` sizes to each cell's natural
/// width, so the width can be read back with `onGeometryChange` (a layout
/// can't report values itself).
struct BlissTableColumnProbes: View {
    let count: Int
    let report: (Int, CGFloat) -> Void

    var body: some View {
        ForEach(0..<count, id: \.self) { column in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { report(column, $0) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .layoutValue(key: ColumnProbeKey.self, value: column)
        }
    }
}

/// The widest cell per column, across the header and every row that reported.
/// Ideal widths don't change with the table's width, so a resize or a sidebar
/// animation reports nothing new.
@Observable
final class BlissTableColumnSizer {
    static let headerSource = AnyHashable("BlissTableColumnSizer.header")

    private(set) var contentWidths: [CGFloat] = []
    @ObservationIgnored private var widthsBySource: [AnyHashable: [Int: CGFloat]] = [:]

    func record(_ width: CGFloat, column: Int, from source: AnyHashable) {
        let rounded = width.rounded(.up)
        let previous = widthsBySource[source]?[column]
        guard previous != rounded else { return }
        widthsBySource[source, default: [:]][column] = rounded
        let currentMaximum = column < contentWidths.count ? contentWidths[column] : 0
        if rounded > currentMaximum {
            var widths = contentWidths
            while widths.count <= column { widths.append(0) }
            widths[column] = rounded
            contentWidths = widths
        } else if previous == currentMaximum {
            // The widest cell got narrower: find the new widest.
            recompute()
        }
    }

    /// Forgets sources (rows) no longer in the table.
    func keep(only sources: Set<AnyHashable>) {
        let countBefore = widthsBySource.count
        widthsBySource = widthsBySource.filter { sources.contains($0.key) }
        if widthsBySource.count != countBefore { recompute() }
    }

    private func recompute() {
        var maxima: [CGFloat] = []
        for widths in widthsBySource.values {
            for (column, width) in widths {
                while maxima.count <= column { maxima.append(0) }
                maxima[column] = max(maxima[column], width)
            }
        }
        if maxima != contentWidths { contentWidths = maxima }
    }
}

// MARK: - Preview

private struct TablePreviewPerson: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let commits: Int
}

private struct BlissTablePreviewHost: View {
    @State private var selection: Set<UUID> = []
    private let people = [
        TablePreviewPerson(name: "Ada Lovelace", role: "Engineer", commits: 412),
        TablePreviewPerson(name: "Grace Hopper", role: "Lead", commits: 980),
        TablePreviewPerson(name: "Alan Turing", role: "Research", commits: 133),
        TablePreviewPerson(name: "Katherine Johnson", role: "Analyst", commits: 271),
    ]

    var body: some View {
        BlissTable(
            people,
            columns: [
                BlissTableColumn("Name", sortedBy: \TablePreviewPerson.name),
                BlissTableColumn("Role", width: .fixed(110)),
                BlissTableColumn("Commits", width: .fixed(80), alignment: .trailing, sortedBy: \TablePreviewPerson.commits),
            ],
            selection: $selection,
            initialSort: BlissTableSort(columnID: "Name"),
            onOpen: { _ in }
        ) { person in
            Text(verbatim: person.name)
                .font(Typography.bodySmall)
            Badge(LocalizedStringKey(person.role))
            Text(verbatim: "\(person.commits)")
                .font(Typography.codeSmall)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.md)
    }
}

#Preview(traits: .fixedLayout(width: 560, height: 260)) {
    BlissTablePreviewHost()
}
