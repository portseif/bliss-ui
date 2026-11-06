//
//  InspectorSplit.swift
//  BlissUI
//
//  Content with a resizable inspector on its trailing side. Pinned, the
//  inspector docks and the content shrinks to make room; unpinned, it's a
//  drawer over the content with a dim behind it (click the dim or press Esc to
//  close). Either way the leading edge is a grip: drag it to resize, between a
//  minimum and a maximum, and the width can persist under a key you pass.
//
//  Not the native `.inspector()`: that one is a fixed sidebar style with no
//  drawer mode, and it can't take the app's surfaces.
//

import SwiftUI

/// Content plus a resizable trailing inspector, docked or as a drawer.
///
/// ```swift
/// @State private var showsInspector = true
/// @AppStorage("inspectorPinned") private var pinsInspector = true
///
/// InspectorSplit(
///     isPresented: $showsInspector,
///     isPinned: $pinsInspector,
///     widthStorageKey: "inspectorWidth"
/// ) {
///     DocumentView()
/// } inspector: {
///     DocumentInspector()
/// }
/// ```
///
/// The inspector stays mounted while hidden (slid off and out of the Tab loop
/// and VoiceOver), so its scroll position and state survive closing it and
/// switching between pinned and unpinned.
public struct InspectorSplit<Content: View, Inspector: View>: View {
    @Binding private var isPresented: Bool
    @Binding private var isPinned: Bool
    private let minWidth: CGFloat
    private let maxWidth: CGFloat
    private let widthStorageKey: String?
    private let content: Content
    private let inspector: Inspector

    /// The committed width (what a drag ends on, and what's persisted).
    @State private var width: CGFloat
    /// The live width while the grip is dragged, and where the drag started.
    @State private var dragWidth: CGFloat?
    @State private var dragStartWidth: CGFloat?
    @State private var containerWidth: CGFloat = 0
    @State private var isGripActive = false

    // The bindings, mirrored into state that changes in its own animated
    // transaction: the caller may flip them without an animation (an
    // `@AppStorage` toggle bypasses the transaction), and a value-keyed
    // `.animation` here would retime everything else that changed with them.
    @State private var showsPanel: Bool
    @State private var showsDim: Bool
    @State private var reservesSpace: Bool

    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - isPresented: Whether the inspector shows.
    ///   - isPinned: Docked beside the content (it shrinks) or a drawer over it.
    ///   - idealWidth: The width before the user resizes it.
    ///   - minWidth: The narrowest the grip goes.
    ///   - maxWidth: The widest the grip goes; it also never leaves the content
    ///     less than a sliver of the window.
    ///   - widthStorageKey: A `UserDefaults` key to keep the width under —
    ///     readable with `@AppStorage` — or nil to forget it.
    ///   - content: The main view.
    ///   - inspector: The trailing panel's contents.
    public init(
        isPresented: Binding<Bool>,
        isPinned: Binding<Bool> = .constant(true),
        idealWidth: CGFloat = 280,
        minWidth: CGFloat = 220,
        maxWidth: CGFloat = 480,
        widthStorageKey: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder inspector: () -> Inspector
    ) {
        self._isPresented = isPresented
        self._isPinned = isPinned
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.widthStorageKey = widthStorageKey
        self.content = content()
        self.inspector = inspector()
        // Read here, not captured once at launch: a theme change re-IDs the
        // tree and builds this again, and it should come back at the width the
        // user last dragged to.
        let storedWidth = widthStorageKey.flatMap { UserDefaults.standard.object(forKey: $0) as? Double }
        _width = State(initialValue: InspectorSplitMetrics.clampedWidth(
            storedWidth.map { CGFloat($0) } ?? idealWidth,
            minWidth: minWidth,
            maxWidth: maxWidth,
            containerWidth: nil
        ))
        let presented = isPresented.wrappedValue
        let pinned = isPinned.wrappedValue
        _showsPanel = State(initialValue: presented)
        _showsDim = State(initialValue: presented && !pinned)
        _reservesSpace = State(initialValue: presented && pinned)
    }

    /// The width on screen: the drag's while dragging, and never more than
    /// the container leaves room for.
    private var currentWidth: CGFloat {
        InspectorSplitMetrics.clampedWidth(
            dragWidth ?? width,
            minWidth: minWidth,
            maxWidth: maxWidth,
            containerWidth: containerWidth
        )
    }

    /// `+1` toward the trailing edge on screen. The drag is measured in the
    /// window, which a right-to-left layout doesn't mirror; offsets are in the
    /// view's own coordinates, which it does, so they need no sign.
    private var trailingSign: CGFloat { layoutDirection == .rightToLeft ? -1 : 1 }

    public var body: some View {
        let panelWidth = currentWidth
        ZStack(alignment: .trailing) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, reservesSpace ? panelWidth : 0)

            // The drawer's dim: always there, faded in and out, so its removal
            // animates (an `if` + `.transition` in a ZStack pops).
            Color.black
                .opacity(showsDim ? Self.dimOpacity : 0)
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }
                .allowsHitTesting(showsDim)
                .accessibilityHidden(true)

            panel(width: panelWidth)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .onChange(of: isPresented) { _, _ in syncWithBindings() }
        .onChange(of: isPinned) { _, _ in syncWithBindings() }
        .background {
            // Esc closes the drawer. The button exists only while it's open,
            // so the key is free for everything else the rest of the time.
            if showsDim {
                Button { isPresented = false } label: { EmptyView() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .hidden()
            }
        }
    }

    // MARK: Panel

    private static var dimOpacity: Double { 0.22 }
    private static var shadowRadius: CGFloat { Spacing.lg }

    private func panel(width panelWidth: CGFloat) -> some View {
        // Slid off past its own shadow while hidden; under Reduce Motion it
        // only fades.
        let hiddenOffset = showsPanel || prefersReducedMotion ? 0 : panelWidth + Self.shadowRadius * 2
        return inspector
            .frame(width: panelWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.controlBackground)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.menuBorder)
                    .frame(width: 1)
            }
            .shadow(color: Color.black.opacity(showsDim ? 0.16 : 0), radius: Self.shadowRadius)
            .overlay(alignment: .leading) { grip }
            .offset(x: hiddenOffset)
            .opacity(showsPanel ? 1 : 0)
            .allowsHitTesting(showsPanel)
            // Hidden, it stays mounted off-screen: keep its controls out of the
            // Tab loop and VoiceOver.
            .disabled(!showsPanel)
            .accessibilityHidden(!showsPanel)
    }

    // MARK: Grip

    private static var gripWidth: CGFloat { Spacing.sm }

    /// A strip straddling the inspector's leading edge: drag it to resize. The
    /// cursor is a pointer style, not a push/pop, which could stay stuck when
    /// the panel closed under the pointer. The drag is measured in the window,
    /// not the strip, because the strip moves with the edge it drags (measured
    /// locally the motion fed back and jittered).
    private var grip: some View {
        Color.clear
            .frame(width: Self.gripWidth)
            .frame(maxHeight: .infinity)
            .overlay {
                Capsule()
                    .fill(Color.primary.opacity(0.25))
                    .frame(width: 3, height: Sizing.controlLarge)
                    .opacity(isGripActive || dragWidth != nil ? 1 : 0)
                    .animation(Animations.hover, value: isGripActive || dragWidth != nil)
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { isGripActive = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = width }
                        // Toward the leading side widens the inspector.
                        dragWidth = start - value.translation.width * trailingSign
                    }
                    .onEnded { _ in
                        commit(width: dragWidth ?? width)
                        dragWidth = nil
                        dragStartWidth = nil
                    }
            )
            // Straddle the edge.
            .offset(x: -Self.gripWidth / 2)
            // In a hidden-title-bar window the grip can reach up into the title
            // bar band, where a press would drag the window instead.
            .windowDragDisabled()
            .accessibilityElement()
            .accessibilityLabel(Text("Inspector width", bundle: .module))
            .accessibilityValue(Text(verbatim: "\(Int(currentWidth))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: commit(width: currentWidth + Self.keyboardStep)
                case .decrement: commit(width: currentWidth - Self.keyboardStep)
                @unknown default: break
                }
            }
    }

    /// How far one VoiceOver increment moves the edge.
    private static var keyboardStep: CGFloat { Spacing.xl }

    private func commit(width proposed: CGFloat) {
        let clamped = InspectorSplitMetrics.clampedWidth(proposed, minWidth: minWidth, maxWidth: maxWidth, containerWidth: containerWidth)
        width = clamped
        if let widthStorageKey {
            UserDefaults.standard.set(Double(clamped), forKey: widthStorageKey)
        }
    }

    // MARK: Toggle motion

    /// Opening, closing, pinning and unpinning, on the pane spring. Under
    /// Reduce Motion the panel only fades (no slide, see `panel`) and the
    /// content snaps to its new width instead of resizing across the window.
    private func syncWithBindings() {
        let presented = isPresented
        let pinned = isPinned
        withAnimation(Animations.pane) {
            showsPanel = presented
            showsDim = presented && !pinned
        }
        if prefersReducedMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { reservesSpace = presented && pinned }
        } else {
            withAnimation(Animations.pane) { reservesSpace = presented && pinned }
        }
    }
}

// MARK: - Metrics

enum InspectorSplitMetrics {
    /// The content keeps at least this much beside a pinned inspector (and the
    /// dim stays clickable beside a drawer).
    static let minimumContentWidth: CGFloat = Spacing.xxxxxl

    /// `proposed`, between `minWidth` and `maxWidth`, and — once the container
    /// is measured — narrow enough to leave the content its minimum. When the
    /// container is too small for even `minWidth`, `minWidth` wins.
    static func clampedWidth(
        _ proposed: CGFloat,
        minWidth: CGFloat,
        maxWidth: CGFloat,
        containerWidth: CGFloat?
    ) -> CGFloat {
        var upperBound = max(minWidth, maxWidth)
        if let containerWidth, containerWidth > 0 {
            upperBound = min(upperBound, max(minWidth, containerWidth - minimumContentWidth))
        }
        return min(max(proposed, minWidth), upperBound).rounded()
    }
}

// MARK: - Preview

private struct InspectorSplitPreviewHost: View {
    @State private var showsInspector = true
    @State private var pinsInspector = true

    var body: some View {
        InspectorSplit(isPresented: $showsInspector, isPinned: $pinsInspector, idealWidth: 220, minWidth: 180) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle("Inspector", isOn: $showsInspector).toggleStyle(.flatSwitch(showsLabel: true))
                Toggle("Pinned", isOn: $pinsInspector).toggleStyle(.flatSwitch(showsLabel: true))
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        } inspector: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(verbatim: "Details").font(Typography.headingSmall)
                DetailRow(label: "Owner", value: "Ada Lovelace")
                DetailRow(label: "Updated", value: "Today")
                Spacer()
            }
            .padding(Spacing.lg)
        }
        .background(Color.contentAreaBackground)
    }
}

#Preview(traits: .fixedLayout(width: 640, height: 320)) {
    InspectorSplitPreviewHost()
}
