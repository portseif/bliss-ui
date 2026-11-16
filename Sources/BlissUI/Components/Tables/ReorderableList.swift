//
//  ReorderableList.swift
//  BlissUI
//
//  Flat rows the user can drag into a new order by a grip handle. The dragged
//  row lifts and follows the pointer while the others slide out of its way as
//  its center crosses theirs; on release the binding is reordered. The grip is
//  the only drag surface, so text in the row stays selectable, and it's a Tab
//  stop: ⌥↑ / ⌥↓ move the row from the keyboard, and VoiceOver gets "Move up"
//  and "Move down" actions.
//
//  Row frames are measured only while nothing is being dragged — a row's
//  geometry includes its own offset, so measuring mid-drag would chase the
//  slide and never settle.
//

import SwiftUI

/// Which side of the row carries the grip handle.
public nonisolated enum ReorderGripPlacement: Sendable {
    case leading
    case trailing
}

// MARK: - Reorderable List

/// Rows with a grip handle that drag into a new order.
///
/// ```swift
/// ReorderableList($steps, divided: true) { step in
///     Label(step.title, systemImage: step.icon)
/// }
/// ```
///
/// Rows stack flush, share the neutral hover fill, and the grip is a Tab stop:
/// ⌥↑ / ⌥↓ move the focused row. Under Reduce Motion rows jump instead of
/// sliding.
public struct ReorderableList<Item: Identifiable, Row: View>: View {
    @Binding private var items: [Item]
    private let gripPlacement: ReorderGripPlacement
    private let divided: Bool
    private let compact: Bool
    private let canMove: ((Item) -> Bool)?
    private let onMove: ((IndexSet, Int) -> Void)?
    private let row: (Item) -> Row

    /// Each row's frame in the list, measured while nothing is dragged.
    @State private var frames: [Item.ID: CGRect] = [:]
    @State private var draggingID: Item.ID?
    @State private var dragSourceIndex: Int?
    /// Where the dragged row would land if released now.
    @State private var dragTargetIndex: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var coordinateSpaceID = UUID()
    @FocusState private var focusedGrip: Item.ID?

    /// - Parameters:
    ///   - items: The rows, in order; a drag or a keyboard move reorders it.
    ///   - gripPlacement: Which side the grip handle sits on.
    ///   - divided: A hairline between rows, spanning the row content.
    ///   - compact: Tighter rows (`Spacing.xs` instead of the list row padding).
    ///   - canMove: Rows it returns false for keep their place: their grip is
    ///     hidden and disabled (a pinned default row).
    ///   - onMove: Runs after each reorder with the offsets `move(fromOffsets:toOffset:)`
    ///     was given, for a host that persists the order.
    ///   - row: The content of one row (without the grip).
    public init(
        _ items: Binding<[Item]>,
        gripPlacement: ReorderGripPlacement = .leading,
        divided: Bool = false,
        compact: Bool = false,
        canMove: ((Item) -> Bool)? = nil,
        onMove: ((IndexSet, Int) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self._items = items
        self.gripPlacement = gripPlacement
        self.divided = divided
        self.compact = compact
        self.canMove = canMove
        self.onMove = onMove
        self.row = row
    }

    /// The slide and settle; none under Reduce Motion.
    private var motion: Animation? {
        prefersReducedMotion ? nil : Animations.selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ReorderableRowCell(
                    isDragging: draggingID == item.id,
                    isListDragging: draggingID != nil,
                    offset: offset(forRowAt: index, id: item.id),
                    showsDivider: divided && index < items.count - 1,
                    gripPlacement: gripPlacement,
                    verticalPadding: compact ? Spacing.xs : Spacing.listRowPadding,
                    grip: { grip(for: item, at: index) },
                    content: { row(item) }
                )
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(coordinateSpaceID))
                } action: { frame in
                    // Only at rest: mid-drag the frame carries the row's offset.
                    if draggingID == nil { frames[item.id] = frame }
                }
            }
        }
        .coordinateSpace(.named(coordinateSpaceID))
    }

    // MARK: - Grip

    private func isMovable(_ item: Item) -> Bool {
        canMove?(item) ?? true
    }

    private func grip(for item: Item, at index: Int) -> some View {
        let isDragging = draggingID == item.id
        let isMovable = isMovable(item)
        return Image(systemName: "line.3.horizontal")
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .frame(width: Sizing.iconDefault, height: Sizing.iconDefault)
            .contentShape(Rectangle())
            .pointerStyle(isDragging ? .grabActive : .grabIdle)
            .gesture(dragGesture(for: item, at: index))
            .focusable(isMovable)
            .focused($focusedGrip, equals: item.id)
            .focusEffectDisabled()
            .focusRing(isFocused: focusedGrip == item.id, cornerRadius: Sizing.radiusSmall)
            .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                // Plain arrows keep their meaning; ⌥ moves the row.
                guard press.modifiers.contains(.option) else { return .ignored }
                move(item.id, by: press.key == .upArrow ? -1 : 1)
                return .handled
            }
            .accessibilityLabel(Text("Reorder", bundle: .module))
            .accessibilityValue(Text("\(index + 1) of \(items.count)", bundle: .module))
            .accessibilityAction(named: Text("Move up", bundle: .module)) { move(item.id, by: -1) }
            .accessibilityAction(named: Text("Move down", bundle: .module)) { move(item.id, by: 1) }
            // A pinned row keeps its layout but offers no handle: hidden, and
            // disabled so Tab never lands on it unseen.
            .opacity(isMovable ? 1 : 0)
            .disabled(!isMovable)
            .accessibilityHidden(!isMovable)
    }

    private func dragGesture(for item: Item, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: Spacing.hairline, coordinateSpace: .named(coordinateSpaceID))
            .onChanged { value in
                guard isMovable(item) else { return }
                if draggingID == nil { beginDrag(of: item.id, at: index) }
                guard draggingID == item.id else { return }
                updateDrag(translation: value.translation.height)
            }
            .onEnded { _ in
                finishDrag()
            }
    }

    // MARK: - Drag state

    private func beginDrag(of id: Item.ID, at index: Int) {
        draggingID = id
        dragSourceIndex = index
        dragTargetIndex = index
        dragTranslation = 0
    }

    private func updateDrag(translation: CGFloat) {
        dragTranslation = translation
        guard let draggingID, let frame = frames[draggingID] else { return }
        let draggedCenter = frame.midY + translation
        // The dragged row lands after every other row whose center it has passed.
        var target = 0
        for item in items where item.id != draggingID {
            if let other = frames[item.id], other.midY < draggedCenter { target += 1 }
        }
        guard target != dragTargetIndex else { return }
        withAnimation(motion) { dragTargetIndex = target }
    }

    private func finishDrag() {
        guard let source = dragSourceIndex, let target = dragTargetIndex else { return }
        withAnimation(motion) {
            if target != source {
                reorder(from: IndexSet(integer: source), to: target > source ? target + 1 : target)
            }
            draggingID = nil
            dragSourceIndex = nil
            dragTargetIndex = nil
            dragTranslation = 0
        }
    }

    private func reorder(from offsets: IndexSet, to destination: Int) {
        items.move(fromOffsets: offsets, toOffset: destination)
        onMove?(offsets, destination)
    }

    /// The dragged row follows the pointer; rows between its old and new slot
    /// slide by its height to make room.
    private func offset(forRowAt index: Int, id: Item.ID) -> CGFloat {
        guard let draggingID, let source = dragSourceIndex, let target = dragTargetIndex else { return 0 }
        if id == draggingID { return dragTranslation }
        let draggedHeight = frames[draggingID]?.height ?? 0
        if source < index && index <= target { return -draggedHeight }
        if target <= index && index < source { return draggedHeight }
        return 0
    }

    // MARK: - Keyboard move

    private func move(_ id: Item.ID, by delta: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }), isMovable(items[index]) else { return }
        let destination = index + delta
        guard items.indices.contains(destination) else { return }
        withAnimation(motion) {
            reorder(from: IndexSet(integer: index), to: delta > 0 ? destination + 1 : destination)
        }
        // The row keeps its identity, so focus stays on its grip.
        focusedGrip = id
    }
}

/// The lift a dragged row takes: a hair larger, on the lift shadow.
enum ReorderableListMetrics {
    static let liftScale: CGFloat = 1.01
}

// MARK: - Row cell

/// One row: the caller's content and the grip in a flat list row with the
/// neutral hover fill. Lifted (raised fill, shadow, a hair larger) while it's
/// the row being dragged.
private struct ReorderableRowCell<Grip: View, Content: View>: View {
    let isDragging: Bool
    let isListDragging: Bool
    let offset: CGFloat
    let showsDivider: Bool
    let gripPlacement: ReorderGripPlacement
    let verticalPadding: CGFloat
    @ViewBuilder let grip: () -> Grip
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    private var fill: Color {
        if isDragging { return Color.controlBackground }
        if isHovering && !isListDragging { return RowTint.hover(scheme) }
        return Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                if gripPlacement == .leading { grip() }
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                if gripPlacement == .trailing { grip() }
            }
            // The list-row geometry: the fill bleeds past the content, so the
            // divider below spans the content, not the fill.
            .listRowFill(fill, verticalPadding: verticalPadding)
            .lifted(isDragging)
            .scaleEffect(isDragging ? ReorderableListMetrics.liftScale : 1)
            .onHover { isHovering = $0 }
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.hover, value: isDragging)

            if showsDivider {
                Divider()
                    .opacity(isDragging ? 0 : 1)
            }
        }
        .offset(y: offset)
        .zIndex(isDragging ? 1 : 0)
    }
}

private extension View {
    /// The lift shadow only while dragged: a shadow under a clear or washed
    /// resting row would show faintly through the wash.
    @ViewBuilder
    func lifted(_ isLifted: Bool) -> some View {
        if isLifted {
            elevation(.lift)
        } else {
            self
        }
    }
}

// MARK: - Preview

private struct ReorderPreviewStep: Identifiable {
    let id: Int
    let title: String
    let icon: String
}

#Preview("Reorderable list", traits: .fixedLayout(width: 360, height: 260)) {
    @Previewable @State var steps = [
        ReorderPreviewStep(id: 1, title: "Install dependencies", icon: "shippingbox"),
        ReorderPreviewStep(id: 2, title: "Run migrations", icon: "cylinder.split.1x2"),
        ReorderPreviewStep(id: 3, title: "Build", icon: "hammer"),
        ReorderPreviewStep(id: 4, title: "Run tests", icon: "checkmark.seal"),
        ReorderPreviewStep(id: 5, title: "Deploy", icon: "paperplane"),
    ]
    ReorderableList($steps, divided: true, canMove: { $0.id != 1 }) { step in
        Label {
            Text(verbatim: step.title).font(Typography.bodySmall)
        } icon: {
            Image(systemName: step.icon)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.iconDefault)
        }
    }
    .padding(Spacing.xl)
}
