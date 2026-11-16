//
//  SplitGrip.swift
//  BlissUI
//
//  The divider `ResizableSplit` and `InspectorSplit` share, so the two feel
//  identical: a strip straddling the panes' edge with a hairline that
//  thickens under the pointer and turns accent while dragged, a drag measured
//  in the window (the strip moves with the edge it drags, so measured locally
//  the motion fed back and jittered), a pointer style rather than a push/pop
//  cursor (which could stay stuck if the panes change under it), and a Tab
//  stop: ←/→ nudge it (⇧ for ten times the step), Home/End send it to the
//  ends, a double-click resets it, and VoiceOver adjusts it.
//

import SwiftUI

/// What the user asked a split's grip to do, for the host to turn into a
/// width (it knows which pane resizes and which way is wider).
enum SplitGripMove {
    /// Toward the trailing edge on screen (→, or a VoiceOver increment).
    case trailing(isLarge: Bool)
    /// Toward the leading edge on screen (←, or a VoiceOver decrement).
    case leading(isLarge: Bool)
    /// Home: the range's narrow end.
    case start
    /// End: the range's wide end.
    case end
}

/// The splits' shared metrics.
enum SplitGripMetrics {
    /// The hit area: an odd width, so the 1pt hairline centers on a pixel.
    static let hitWidth: CGFloat = Spacing.sm + 1
    /// One keyboard step; ⇧ multiplies it by ten.
    static let keyboardStep: CGFloat = Spacing.sm
    static let largeStepMultiplier: CGFloat = 10
    /// How far one VoiceOver increment moves the edge.
    static let adjustableStep: CGFloat = Spacing.xl
    /// The hairline while the pointer is over it.
    static let hoverOpacity: Double = 0.25
    /// A drag past a pane's minimum by this much collapses it.
    static let collapseDistance: CGFloat = Spacing.xxxl
}

struct SplitGrip: View {
    /// Whether the host is mid-drag (the hairline turns accent).
    let isDragging: Bool
    /// Draws the hairline; off when the pane draws its own edge.
    var showsHairline = true
    /// What VoiceOver calls it ("Sidebar width").
    let label: Text
    /// The width VoiceOver reads.
    let value: CGFloat
    /// The drag's translation along the window's x, as it changes.
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    /// A keyboard or VoiceOver move.
    let onMove: (SplitGripMove) -> Void
    /// A double-click; nil when there's nothing to reset to.
    var onReset: (() -> Void)? = nil

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var hairlineColor: Color {
        if isDragging { return Color.accent }
        if isHovering { return Color.primary.opacity(SplitGripMetrics.hoverOpacity) }
        return Color.menuBorder
    }

    var body: some View {
        Color.clear
            .frame(width: SplitGripMetrics.hitWidth)
            .frame(maxHeight: .infinity)
            .overlay {
                if showsHairline {
                    Rectangle()
                        .fill(hairlineColor)
                        .frame(width: isDragging || isHovering ? Spacing.hairline : 1)
                        .animation(Animations.hover, value: isDragging || isHovering)
                }
            }
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { onDragChanged($0.translation.width) }
                    .onEnded { _ in onDragEnded() }
            )
            .onTapGesture(count: 2) { onReset?() }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .focusRingCapsule(isFocused: isFocused)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
                let isLarge = press.modifiers.contains(.shift)
                switch press.key {
                case .rightArrow: onMove(.trailing(isLarge: isLarge))
                case .leftArrow: onMove(.leading(isLarge: isLarge))
                case .home: onMove(.start)
                default: onMove(.end)
                }
                return .handled
            }
            // In a hidden-title-bar window the divider reaches up into the
            // title bar band, where a press would drag the window instead.
            .windowDragDisabled()
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(Text(verbatim: "\(Int(value))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onMove(.trailing(isLarge: false))
                case .decrement: onMove(.leading(isLarge: false))
                @unknown default: break
                }
            }
    }
}
