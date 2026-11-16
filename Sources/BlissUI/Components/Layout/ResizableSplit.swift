//
//  ResizableSplit.swift
//  BlissUI
//
//  Two panes side by side with a divider the user drags: the resizable
//  sidebar (or trailing panel) every Mac app has. The resized pane's width is
//  the caller's binding, clamped to a range and never so wide that the other
//  pane loses its minimum, and it can persist under a `UserDefaults` key.
//  The divider is a Tab stop too: ←/→ nudge it, Home/End send it to the ends.
//
//  Same mechanics as `InspectorSplit`'s grip (drag measured in the window,
//  `InspectorSplitMetrics` for the clamp, a pointer style rather than a
//  push/pop cursor), so the two feel identical.
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
public struct ResizableSplit<Leading: View, Trailing: View>: View {
    @Binding private var width: CGFloat
    private let range: ClosedRange<CGFloat>
    private let resizes: HorizontalEdge
    private let persistenceKey: String?
    /// The width the caller started with: what a double-click returns to.
    private let initialWidth: CGFloat
    private let leading: Leading
    private let trailing: Trailing

    /// The live width while the divider is dragged, and where the drag started.
    @State private var dragWidth: CGFloat?
    @State private var dragStartWidth: CGFloat?
    @State private var containerWidth: CGFloat = 0
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - width: The resizable pane's width.
    ///   - range: The narrowest and widest the pane goes; it also never leaves
    ///     the other pane less than a sliver.
    ///   - resizes: Which pane the width applies to; the other takes the rest.
    ///   - persistenceKey: A `UserDefaults` key to keep the width under
    ///     (readable with `@AppStorage`). On appear the stored width replaces
    ///     the binding's value.
    ///   - leading: The pane on the leading side.
    ///   - trailing: The pane on the trailing side.
    public init(
        width: Binding<CGFloat>,
        in range: ClosedRange<CGFloat> = Sizing.sidebarMinWidth...Sizing.sidebarMaxWidth,
        resizes: HorizontalEdge = .leading,
        persistenceKey: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._width = width
        self.range = range
        self.resizes = resizes
        self.persistenceKey = persistenceKey
        self.initialWidth = width.wrappedValue
        self.leading = leading()
        self.trailing = trailing()
    }

    // MARK: Width

    /// The width on screen: the drag's while dragging, clamped to the range
    /// and to what the container leaves the other pane.
    private var currentWidth: CGFloat {
        clamped(dragWidth ?? width)
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

    /// The divider's hit area: a few points either side of the hairline.
    private static var hitWidth: CGFloat { Spacing.sm + 1 }
    /// One keyboard step; ⇧ multiplies it by ten.
    private static var keyboardStep: CGFloat { Spacing.sm }
    /// How far one VoiceOver increment moves the divider.
    private static var adjustableStep: CGFloat { Spacing.xl }

    private var isDragging: Bool { dragWidth != nil }

    private var hairlineColor: Color {
        if isDragging { return Color.accent }
        if isHovering { return Color.primary.opacity(0.25) }
        return Color.menuBorder
    }

    /// A strip straddling the panes' edge: a hairline that thickens under the
    /// pointer and turns accent while dragged. The cursor is a pointer style,
    /// not a push/pop, which could stay stuck if the panes change under it.
    private var divider: some View {
        Color.clear
            .frame(width: Self.hitWidth)
            .frame(maxHeight: .infinity)
            .overlay {
                Rectangle()
                    .fill(hairlineColor)
                    .frame(width: isDragging || isHovering ? 2 : 1)
                    .animation(Animations.hover, value: isDragging || isHovering)
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { isHovering = $0 }
            .gesture(dragGesture)
            .onTapGesture(count: 2) { commit(width: initialWidth) }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .focusRingCapsule(isFocused: isFocused)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
                move(press.key, isLarge: press.modifiers.contains(.shift))
                return .handled
            }
            // In a hidden-title-bar window the divider reaches up into the
            // title bar band, where a press would drag the window instead.
            .windowDragDisabled()
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(Text(verbatim: "\(Int(currentWidth))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: commit(width: currentWidth + Self.adjustableStep)
                case .decrement: commit(width: currentWidth - Self.adjustableStep)
                @unknown default: break
                }
            }
    }

    private var accessibilityLabel: Text {
        isResizingLeading ? Text("Sidebar width", bundle: .module) : Text("Inspector width", bundle: .module)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let start = dragStartWidth ?? width
                if dragStartWidth == nil { dragStartWidth = width }
                dragWidth = start + value.translation.width * trailingSign
            }
            .onEnded { _ in
                commit(width: dragWidth ?? width)
                dragWidth = nil
                dragStartWidth = nil
            }
    }

    // MARK: Keys

    /// ←/→ move the divider on screen (so → always goes right, whichever pane
    /// resizes); Home and End send it to the range's ends.
    private func move(_ key: KeyEquivalent, isLarge: Bool) {
        let step = Self.keyboardStep * (isLarge ? 10 : 1)
        // `trailingSign` already turns a rightward move into a width change.
        switch key {
        case .rightArrow: commit(width: currentWidth + step * trailingSign)
        case .leftArrow: commit(width: currentWidth - step * trailingSign)
        case .home: commit(width: range.lowerBound)
        default: commit(width: range.upperBound)
        }
    }

    // MARK: Commit

    private func commit(width proposed: CGFloat) {
        let clamped = clamped(proposed)
        width = clamped
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
    @State private var destination = SplitPreviewDestination.today

    var body: some View {
        ResizableSplit(width: $sidebarWidth, in: 160...320) {
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
                Text(verbatim: "Today").font(Typography.headingMedium)
                Text(verbatim: "Drag the divider, or Tab to it and use the arrow keys.")
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
