//
//  KanbanBoard.swift
//  BlissUI
//
//  Columns of cards that drag within a column or into another one, the other
//  cards sliding to make room, the way `ReorderableList` does it: the whole
//  card is the drag surface, the dragged card lifts and follows the pointer,
//  and on release the binding is rearranged. Every card is a Tab stop: ⌥↑ / ⌥↓
//  move it in its column, ⌥← / ⌥→ to the neighbouring column, and VoiceOver
//  gets the four moves as actions.
//
//  Card and column frames are measured only while nothing is being dragged —
//  a card's geometry includes its own offset, so measuring mid-drag would
//  chase the slide and never settle.
//

import SwiftUI

// MARK: - Column

/// One column of a `KanbanBoard`: a title, its cards in order, and an
/// optional color dot before the title.
public nonisolated struct KanbanColumn<Card: Identifiable>: Identifiable {
    public var id: String
    public var title: String
    public var cards: [Card]
    /// A dot before the title; nil for none.
    public var color: Color?

    /// - Parameters:
    ///   - id: Identifies the column in `onMove`.
    ///   - title: The header, shown as-is.
    ///   - cards: The cards, top to bottom.
    ///   - color: A dot before the title (a status mark); nil for none.
    public init(id: String, title: String, cards: [Card], color: Color? = nil) {
        self.id = id
        self.title = title
        self.cards = cards
        self.color = color
    }
}

// MARK: - Board

/// Columns of draggable cards bound to the columns' contents.
///
/// ```swift
/// KanbanBoard(columns: $columns, onMove: { task, from, to in log(task, from, to) }) { task in
///     Text(verbatim: task.title)
/// } columnFooter: { column in
///     Button("Add card") { add(to: column) }.buttonStyle(GhostButtonStyle(compact: true))
/// }
/// ```
///
/// The board scrolls horizontally when its columns don't fit. Under Reduce
/// Motion cards jump into place instead of sliding.
public struct KanbanBoard<Card: Identifiable, CardContent: View, ColumnFooter: View>: View {
    @Binding private var columns: [KanbanColumn<Card>]
    private let columnWidth: CGFloat
    private let onMove: ((Card, String, String) -> Void)?
    private let card: (Card) -> CardContent
    private let columnFooter: (KanbanColumn<Card>) -> ColumnFooter

    /// Column and card frames in the board's space, measured while nothing is dragged.
    @State private var columnFrames: [String: CGRect] = [:]
    @State private var cardFrames: [Card.ID: CGRect] = [:]
    @State private var drag: KanbanDrag<Card.ID>?
    @State private var coordinateSpaceID = UUID()
    @FocusState private var focusedCard: Card.ID?

    /// - Parameters:
    ///   - columns: The columns and their cards; a drag or a keyboard move rearranges them.
    ///   - columnWidth: Every column's width.
    ///   - onMove: Called after a card lands in another column, with the
    ///     card and the two column ids.
    ///   - card: The content of one card (the board draws the card around it).
    ///   - columnFooter: Content under a column's cards (an "Add card" row).
    public init(
        columns: Binding<[KanbanColumn<Card>]>,
        columnWidth: CGFloat = 260,
        onMove: ((_ card: Card, _ from: String, _ to: String) -> Void)? = nil,
        @ViewBuilder card: @escaping (Card) -> CardContent,
        @ViewBuilder columnFooter: @escaping (KanbanColumn<Card>) -> ColumnFooter
    ) {
        self._columns = columns
        self.columnWidth = columnWidth
        self.onMove = onMove
        self.card = card
        self.columnFooter = columnFooter
    }

    /// The slide and settle; none under Reduce Motion.
    private var motion: Animation? {
        prefersReducedMotion ? nil : Animations.selection
    }

    /// How far cards shift to make room: the dragged card's height plus the gap.
    private var shift: CGFloat {
        guard let drag else { return 0 }
        return (cardFrames[drag.cardID]?.height ?? 0) + Spacing.sm
    }

    public var body: some View {
        ScrollViewWithThinIndicator(.horizontal) {
            HStack(alignment: .top, spacing: Spacing.md) {
                ForEach(columns) { column in
                    columnView(column)
                        // The column holding the dragged card draws over its neighbours.
                        .zIndex(drag?.sourceColumn == column.id ? 1 : 0)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named(coordinateSpaceID))
                        } action: { frame in
                            if drag == nil { columnFrames[column.id] = frame }
                        }
                }
            }
            .padding(Spacing.xxs)
            .coordinateSpace(.named(coordinateSpaceID))
        }
    }

    // MARK: - Column

    private func columnView(_ column: KanbanColumn<Card>) -> some View {
        let isDropTarget = drag != nil && drag?.targetColumn == column.id && column.cards.isEmpty
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            columnHeader(column)
            ForEach(Array(column.cards.enumerated()), id: \.element.id) { index, item in
                cardView(item, in: column, at: index)
            }
            if column.cards.isEmpty {
                KanbanEmptySlot(isTargeted: isDropTarget)
            }
            columnFooter(column)
        }
        .padding(Spacing.sm)
        .frame(width: columnWidth)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }

    private func columnHeader(_ column: KanbanColumn<Card>) -> some View {
        HStack(spacing: Spacing.xs) {
            if let color = column.color {
                Circle()
                    .fill(color)
                    .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                    .accessibilityHidden(true)
            }
            Text(verbatim: column.title)
                .font(Typography.bodySmallSemibold)
                .lineLimit(1)
            Spacer(minLength: Spacing.sm)
            Badge(count: column.cards.count)
                .badgeStyle(.secondary)
                .badgeSize(.small)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.top, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Card

    private func cardView(_ item: Card, in column: KanbanColumn<Card>, at index: Int) -> some View {
        let isDragging = drag?.cardID == item.id
        return KanbanCardCell(
            isDragging: isDragging,
            isBoardDragging: drag != nil,
            offset: offset(forCard: item.id, in: column.id, at: index),
            content: { card(item) }
        )
        .pointerStyle(isDragging ? .grabActive : .grabIdle)
        .gesture(dragGesture(for: item.id, in: column.id, at: index))
        .focusable()
        .focused($focusedCard, equals: item.id)
        .focusEffectDisabled()
        .focusRing(isFocused: focusedCard == item.id, cornerRadius: Sizing.radiusMedium)
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            // Plain arrows keep their meaning; ⌥ moves the card.
            guard press.modifiers.contains(.option) else { return .ignored }
            switch press.key {
            case .upArrow: move(item.id, rows: -1)
            case .downArrow: move(item.id, rows: 1)
            case .leftArrow: move(item.id, columns: -1)
            default: move(item.id, columns: 1)
            }
            return .handled
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(coordinateSpaceID))
        } action: { frame in
            // Only at rest: mid-drag the frame carries the card's offset.
            if drag == nil { cardFrames[item.id] = frame }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Move up", bundle: .module)) { move(item.id, rows: -1) }
        .accessibilityAction(named: Text("Move down", bundle: .module)) { move(item.id, rows: 1) }
        .accessibilityAction(named: Text("Move left", bundle: .module)) { move(item.id, columns: -1) }
        .accessibilityAction(named: Text("Move right", bundle: .module)) { move(item.id, columns: 1) }
    }

    private func dragGesture(for cardID: Card.ID, in columnID: String, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(coordinateSpaceID))
            .onChanged { value in
                if drag == nil {
                    drag = KanbanDrag(cardID: cardID, sourceColumn: columnID, sourceIndex: index)
                }
                guard drag?.cardID == cardID else { return }
                updateDrag(location: value.location, translation: value.translation)
            }
            .onEnded { _ in
                finishDrag()
            }
    }

    // MARK: - Drag state

    private func updateDrag(location: CGPoint, translation: CGSize) {
        guard let current = drag, let frame = cardFrames[current.cardID] else { return }
        // The card follows the pointer at once; the targets below may animate.
        drag?.translation = translation

        let targetColumn = columnID(atX: location.x) ?? current.targetColumn
        let draggedCenterY = frame.midY + translation.height
        let targetIndex = insertionIndex(in: targetColumn, forCenterY: draggedCenterY, excluding: current.cardID)
        guard targetColumn != current.targetColumn || targetIndex != current.targetIndex else { return }
        withAnimation(motion) {
            drag?.targetColumn = targetColumn
            drag?.targetIndex = targetIndex
        }
    }

    /// The column under `x`, or the nearest one when the pointer is between
    /// or past them.
    private func columnID(atX x: CGFloat) -> String? {
        if let hit = columns.first(where: { distance(fromX: x, to: columnFrames[$0.id]) == 0 }) {
            return hit.id
        }
        return columns.min { lhs, rhs in
            distance(fromX: x, to: columnFrames[lhs.id]) < distance(fromX: x, to: columnFrames[rhs.id])
        }?.id
    }

    private func distance(fromX x: CGFloat, to frame: CGRect?) -> CGFloat {
        guard let frame else { return .infinity }
        if x < frame.minX { return frame.minX - x }
        if x > frame.maxX { return x - frame.maxX }
        return 0
    }

    /// Where the dragged card lands in a column: after every other card whose
    /// center it has passed.
    private func insertionIndex(in columnID: String, forCenterY centerY: CGFloat, excluding cardID: Card.ID) -> Int {
        guard let column = columns.first(where: { $0.id == columnID }) else { return 0 }
        var index = 0
        for item in column.cards where item.id != cardID {
            if let frame = cardFrames[item.id], frame.midY < centerY { index += 1 }
        }
        return index
    }

    private func finishDrag() {
        guard let drag,
              let sourceColumn = columns.firstIndex(where: { $0.id == drag.sourceColumn }),
              let targetColumn = columns.firstIndex(where: { $0.id == drag.targetColumn }),
              columns[sourceColumn].cards.indices.contains(drag.sourceIndex)
        else {
            self.drag = nil
            return
        }
        let moved = columns[sourceColumn].cards[drag.sourceIndex]
        let crossesColumns = sourceColumn != targetColumn
        withAnimation(motion) {
            if crossesColumns {
                columns[sourceColumn].cards.remove(at: drag.sourceIndex)
                let insertAt = min(drag.targetIndex, columns[targetColumn].cards.count)
                columns[targetColumn].cards.insert(moved, at: insertAt)
            } else if drag.targetIndex != drag.sourceIndex {
                let toOffset = drag.targetIndex > drag.sourceIndex ? drag.targetIndex + 1 : drag.targetIndex
                columns[sourceColumn].cards.move(fromOffsets: IndexSet(integer: drag.sourceIndex), toOffset: toOffset)
            }
            self.drag = nil
        }
        if crossesColumns { onMove?(moved, drag.sourceColumn, drag.targetColumn) }
    }

    /// The dragged card follows the pointer; cards in its old column close
    /// its gap, cards in its new column make room, and within one column the
    /// cards between its old and new slot slide past it.
    private func offset(forCard cardID: Card.ID, in columnID: String, at index: Int) -> CGSize {
        guard let drag else { return .zero }
        if cardID == drag.cardID { return drag.translation }
        let shift = shift
        if columnID == drag.sourceColumn && columnID == drag.targetColumn {
            if drag.sourceIndex < index && index <= drag.targetIndex { return CGSize(width: 0, height: -shift) }
            if drag.targetIndex <= index && index < drag.sourceIndex { return CGSize(width: 0, height: shift) }
        } else if columnID == drag.sourceColumn {
            if index > drag.sourceIndex { return CGSize(width: 0, height: -shift) }
        } else if columnID == drag.targetColumn {
            if index >= drag.targetIndex { return CGSize(width: 0, height: shift) }
        }
        return .zero
    }

    // MARK: - Keyboard moves

    private func location(of cardID: Card.ID) -> (column: Int, index: Int)? {
        for (columnIndex, column) in columns.enumerated() {
            if let index = column.cards.firstIndex(where: { $0.id == cardID }) {
                return (columnIndex, index)
            }
        }
        return nil
    }

    /// Moves a card up or down within its column.
    private func move(_ cardID: Card.ID, rows delta: Int) {
        guard let place = location(of: cardID) else { return }
        let destination = place.index + delta
        guard columns[place.column].cards.indices.contains(destination) else { return }
        withAnimation(motion) {
            columns[place.column].cards.move(fromOffsets: IndexSet(integer: place.index), toOffset: delta > 0 ? destination + 1 : destination)
        }
        focusedCard = cardID
    }

    /// Moves a card to the neighbouring column, keeping its position (clamped).
    private func move(_ cardID: Card.ID, columns delta: Int) {
        guard let place = location(of: cardID) else { return }
        let destinationColumn = place.column + delta
        guard columns.indices.contains(destinationColumn) else { return }
        let moved = columns[place.column].cards[place.index]
        withAnimation(motion) {
            columns[place.column].cards.remove(at: place.index)
            let insertAt = min(place.index, columns[destinationColumn].cards.count)
            columns[destinationColumn].cards.insert(moved, at: insertAt)
        }
        focusedCard = cardID
        onMove?(moved, columns[place.column].id, columns[destinationColumn].id)
    }
}

extension KanbanBoard where ColumnFooter == EmptyView {
    /// A board with nothing under a column's cards.
    public init(
        columns: Binding<[KanbanColumn<Card>]>,
        columnWidth: CGFloat = 260,
        onMove: ((_ card: Card, _ from: String, _ to: String) -> Void)? = nil,
        @ViewBuilder card: @escaping (Card) -> CardContent
    ) {
        self.init(columns: columns, columnWidth: columnWidth, onMove: onMove, card: card, columnFooter: { _ in EmptyView() })
    }
}

// MARK: - Drag state

/// A drag in progress: which card, where it came from, where it would land.
private struct KanbanDrag<CardID: Hashable> {
    let cardID: CardID
    let sourceColumn: String
    let sourceIndex: Int
    var targetColumn: String
    var targetIndex: Int
    var translation: CGSize = .zero

    init(cardID: CardID, sourceColumn: String, sourceIndex: Int) {
        self.cardID = cardID
        self.sourceColumn = sourceColumn
        self.sourceIndex = sourceIndex
        self.targetColumn = sourceColumn
        self.targetIndex = sourceIndex
    }
}

// MARK: - Card cell

/// One card: the caller's content on the raised surface with a hairline,
/// the neutral hover wash, and lifted (shadow, a hair larger) while dragged.
private struct KanbanCardCell<Content: View>: View {
    let isDragging: Bool
    let isBoardDragging: Bool
    let offset: CGSize
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
    }

    private var showsHover: Bool {
        isHovering && !isBoardDragging
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background {
                shape.fill(Color.controlBackground)
                shape.fill(RowTint.hover(scheme)).opacity(showsHover ? 1 : 0)
            }
            .overlay {
                shape.strokeBorder(Color.menuBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(isDragging ? 0.14 : 0), radius: 10, y: 3)
            .scaleEffect(isDragging ? 1.01 : 1)
            .contentShape(shape)
            .onHover { isHovering = $0 }
            .animation(Animations.hover, value: showsHover)
            .animation(Animations.hover, value: isDragging)
            .offset(offset)
            .zIndex(isDragging ? 1 : 0)
    }
}

// MARK: - Empty slot

/// The drop target an empty column keeps, so there's somewhere to land.
private struct KanbanEmptySlot: View {
    let isTargeted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
            .strokeBorder(isTargeted ? Color.accent : Color.menuBorder, style: StrokeStyle(lineWidth: 1, dash: [4]))
            .frame(maxWidth: .infinity, minHeight: 56)
            .animation(Animations.hover, value: isTargeted)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

private struct KanbanPreviewTask: Identifiable {
    let id: Int
    let title: String
    let tag: String
    let assignee: String
}

#Preview("Kanban board", traits: .fixedLayout(width: 860, height: 420)) {
    @Previewable @State var columns = [
        KanbanColumn(id: "todo", title: "To do", cards: [
            KanbanPreviewTask(id: 1, title: "Write the release notes", tag: "Docs", assignee: "Ada Lovelace"),
            KanbanPreviewTask(id: 2, title: "Audit focus rings", tag: "A11y", assignee: "Grace Hopper"),
            KanbanPreviewTask(id: 3, title: "Tune the sheet spring", tag: "Motion", assignee: "Alan Turing"),
        ], color: Grey.grey500),
        KanbanColumn(id: "doing", title: "In progress", cards: [
            KanbanPreviewTask(id: 4, title: "Ship the Low Glare theme", tag: "Themes", assignee: "Katherine Johnson"),
        ], color: Warning.warning500),
        KanbanColumn(id: "done", title: "Done", cards: [
            KanbanPreviewTask(id: 5, title: "Polish the onboarding card", tag: "Design", assignee: "Ada Lovelace"),
            KanbanPreviewTask(id: 6, title: "Fix the table shimmer", tag: "Bug", assignee: "Grace Hopper"),
        ], color: Success.success500),
    ]
    KanbanBoard(columns: $columns) { task in
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: task.title)
                .font(Typography.bodySmall)
            HStack(spacing: Spacing.sm) {
                Badge(.verbatim(task.tag)).badgeStyle(.secondary).badgeSize(.small)
                Spacer(minLength: 0)
                Avatar(name: task.assignee, size: .small)
            }
        }
    } columnFooter: { _ in
        Button {} label: {
            Label { Text("Add card") } icon: { Image(systemName: "plus") }
        }
        .buttonStyle(GhostButtonStyle(compact: true))
    }
    .padding(Spacing.lg)
}
