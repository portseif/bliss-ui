//
//  ResizableSplit.swift
//  BlissUI
//
//  Two panes side by side with a divider the user drags: the resizable
//  sidebar (or trailing panel) every Mac app has. The resized pane's width is
//  the caller's binding, clamped to a range and never so wide that the other
//  pane loses its minimum, and it can persist under a `UserDefaults` key.
//  The divider is the shared `SplitGrip`, so it's a Tab stop too: ←/→ nudge
//  it, Home/End send it to the ends.
//
//  Same mechanics as `InspectorSplit` (one grip, `InspectorSplitMetrics` for
//  the clamp), so the two feel identical.
//

import SwiftUI

/// Two panes with a draggable divider; the width of one is yours to keep.
///
/// ```swift
/// @State private var sidebarWidth: CGFloat = 240
///
/// ResizableSplit(width: $sidebarWidth, persistenceKey: "sidebarWidth") {
///     Sidebar(selection: $destination) { … }
/// } trailing: {
///     ContentView()
/// }
/// ```
///
/// Drag the divider, or Tab to it and press ←/→ (⇧ for ten times the step)
/// or Home/End; a double-click puts the width back where it started. With a
/// `persistenceKey` the stored width wins over the binding's value on appear.
/// With `isCollapsed`, dragging well past the minimum folds the pane away.
public struct ResizableSplit<Leading: View, Trailing: View>: View {
    @Binding private var width: CGFloat
    private let range: ClosedRange<CGFloat>
    private let resizes: HorizontalEdge
    private let persistenceKey: String?
    private let isCollapsed: Binding<Bool>?
    private let showsDivider: Bool
    /// The width the caller started with: what a double-click returns to.
    private let initialWidth: CGFloat
    private let leading: Leading
    private let trailing: Trailing

    /// The live width while the divider is dragged, and where the drag started.
    @State private var dragWidth: CGFloat?
    @State private var dragStartWidth: CGFloat?
    @State private var containerWidth: CGFloat = 0

    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - width: The resizable pane's width.
    ///   - range: The narrowest and widest the pane goes; it also never leaves
    ///     the other pane less than a sliver.
    ///   - resizes: Which pane the width applies to; the other takes the rest.
    ///   - persistenceKey: A `UserDefaults` key to keep the width under
    ///     (readable with `@AppStorage`). On appear the stored width replaces
    ///     the binding's value.
    ///   - isCollapsed: Whether the resizable pane is folded away. A drag past
    ///     the minimum folds it; dragging the divider back out, or setting it
    ///     false (a `SidebarToggleButton`), brings it back at its width.
    ///   - showsDivider: The hairline between the panes; off when a pane draws
    ///     its own edge (`Sidebar` on `appShell`). The grip still works.
    ///   - leading: The pane on the leading side.
    ///   - trailing: The pane on the trailing side.
    public init(
        width: Binding<CGFloat>,
        in range: ClosedRange<CGFloat> = Sizing.sidebarMinWidth...Sizing.sidebarMaxWidth,
        resizes: HorizontalEdge = .leading,
        persistenceKey: String? = nil,
        isCollapsed: Binding<Bool>? = nil,
        showsDivider: Bool = true,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._width = width
        self.range = range
        self.resizes = resizes
        self.persistenceKey = persistenceKey
        self.isCollapsed = isCollapsed
        self.showsDivider = showsDivider
        self.initialWidth = width.wrappedValue
        self.leading = leading()
        self.trailing = trailing()
    }

    // MARK: Width

    private var collapsed: Bool { isCollapsed?.wrappedValue ?? false }

    /// The width on screen: nothing while collapsed; the drag's while
    /// dragging, clamped to the range and to what the container leaves the
    /// other pane.
    private var currentWidth: CGFloat {
        if collapsed && dragWidth == nil { return 0 }
        return clamped(dragWidth ?? width)
    }

    private func clamped(_ proposed: CGFloat) -> CGFloat {
        InspectorSplitMetrics.clampedWidth(
            proposed,
            minWidth: range.lowerBound,
            maxWidth: range.upperBound,
            containerWidth: containerWidth
        )
    }

    /// How a move toward the trailing edge on screen changes the width: it
    /// widens a leading pane and narrows a trailing one. The drag is measured
    /// in the window, which a right-to-left layout doesn't mirror.
    private var trailingSign: CGFloat {
        let paneSign: CGFloat = resizes == .leading ? 1 : -1
        let layoutSign: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        return paneSign * layoutSign
    }

    private var isResizingLeading: Bool { resizes == .leading }

    // MARK: Body

    public var body: some View {
        let paneWidth = currentWidth
        HStack(spacing: 0) {
            leading
                .frame(width: isResizingLeading ? paneWidth : nil)
                .frame(maxWidth: isResizingLeading ? nil : .infinity, maxHeight: .infinity)
                .clipped()
            divider
            trailing
                .frame(width: isResizingLeading ? nil : paneWidth)
                .frame(maxWidth: isResizingLeading ? .infinity : nil, maxHeight: .infinity)
                .clipped()
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .onAppear(perform: restoreStoredWidth)
    }

    // MARK: Divider

    private var divider: some View {
        SplitGrip(
            isDragging: dragWidth != nil,
            showsHairline: showsDivider,
            label: isResizingLeading ? Text("Sidebar width", bundle: .module) : Text("Inspector width", bundle: .module),
            value: currentWidth,
            onDragChanged: { translation in
                let start = dragStartWidth ?? (collapsed ? 0 : width)
                if dragStartWidth == nil { dragStartWidth = start }
                let proposed = start + translation * trailingSign
                if let isCollapsed {
                    // Well past the minimum folds the pane; back out unfolds it.
                    let folds = proposed < range.lowerBound - SplitGripMetrics.collapseDistance
                    if folds != isCollapsed.wrappedValue {
                        withAnimation(Animations.pane) { isCollapsed.wrappedValue = folds }
                    }
                    dragWidth = folds ? nil : proposed
                } else {
                    dragWidth = proposed
                }
            },
            onDragEnded: {
                if !collapsed { commit(width: dragWidth ?? width) }
                dragWidth = nil
                dragStartWidth = nil
            },
            onMove: move,
            onReset: { commit(width: initialWidth) }
        )
    }

    // MARK: Keys

    /// ←/→ move the divider on screen (so → always goes right, whichever pane
    /// resizes); Home and End send it to the range's ends. A move unfolds a
    /// collapsed pane.
    private func move(_ move: SplitGripMove) {
        switch move {
        case .trailing(let isLarge): commit(width: currentWidth + step(isLarge) * trailingSign)
        case .leading(let isLarge): commit(width: currentWidth - step(isLarge) * trailingSign)
        case .start: commit(width: range.lowerBound)
        case .end: commit(width: range.upperBound)
        }
    }

    private func step(_ isLarge: Bool) -> CGFloat {
        SplitGripMetrics.keyboardStep * (isLarge ? SplitGripMetrics.largeStepMultiplier : 1)
    }

    // MARK: Commit

    private func commit(width proposed: CGFloat) {
        let clamped = clamped(proposed)
        width = clamped
        if let isCollapsed, isCollapsed.wrappedValue {
            withAnimation(Animations.pane) { isCollapsed.wrappedValue = false }
        }
        if let persistenceKey {
            UserDefaults.standard.set(Double(clamped), forKey: persistenceKey)
        }
    }

    /// The stored width wins over the binding's value: the pane comes back
    /// where the user last dragged it, including after a theme change re-IDs
    /// the tree and builds this again.
    private func restoreStoredWidth() {
        guard let persistenceKey,
              let stored = UserDefaults.standard.object(forKey: persistenceKey) as? Double,
              stored > 0 else { return }
        let clamped = clamped(CGFloat(stored))
        if clamped != width { width = clamped }
    }
}

// MARK: - Preview

private enum SplitPreviewDestination: Hashable {
    case inbox, today, projects
}

private struct ResizableSplitPreviewHost: View {
    @State private var sidebarWidth: CGFloat = 220
    @State private var isCollapsed = false
    @State private var destination = SplitPreviewDestination.today

    var body: some View {
        ResizableSplit(width: $sidebarWidth, in: 160...320, isCollapsed: $isCollapsed) {
            Sidebar(selection: $destination) {
                SidebarSection {
                    SidebarRow("Inbox", icon: "tray", value: SplitPreviewDestination.inbox, count: 4)
                    SidebarRow("Today", icon: "sun.max", value: SplitPreviewDestination.today)
                    SidebarRow("Projects", icon: "folder", value: SplitPreviewDestination.projects)
                }
            }
            .background(Color.appShell)
        } trailing: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    SidebarToggleButton(isCollapsed: $isCollapsed)
                    Text(verbatim: "Today").font(Typography.headingMedium)
                }
                Text(verbatim: "Drag the divider, or Tab to it and use the arrow keys. Drag it well past the edge to fold the sidebar.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(Int(sidebarWidth)) pt")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.contentAreaBackground)
        }
    }
}

#Preview(traits: .fixedLayout(width: 640, height: 300)) {
    ResizableSplitPreviewHost()
}
