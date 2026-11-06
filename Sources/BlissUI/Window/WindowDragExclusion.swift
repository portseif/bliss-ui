//
//  WindowDragExclusion.swift
//  BlissUI
//
//  Keeps presses on custom title-bar controls from dragging a hidden-title-bar
//  window, and lets a modal sheet's scrim drag it instead.
//

import AppKit
import SwiftUI

/// Custom title-bar controls (SwiftUI buttons with custom styles) aren't
/// recognized by SwiftUI's window-drag opt-out, so a press on them drags the
/// hidden-title-bar window. A `.background` `mouseDownCanMoveWindow` view can't
/// fix it (the button's own backing view is the hit-test target), and a reactive
/// mouse-down monitor can't either: when the region under the cursor reports
/// `mouseDownCanMoveWindow == true`, the **Window Server** runs the drag and the
/// mouse-down is never delivered to the app, so the monitor never fires.
///
/// So we flip `window.isMovable` **proactively on hover**: while the cursor sits
/// over any registered no-drag region, the window is already non-movable, so a
/// press there can't start a server drag. A per-window counter handles
/// overlapping regions and the cursor sweeping between clusters; the empty
/// title-bar area keeps `isMovable == true` and stays draggable. A separate
/// modal-draggable override (used by `appSheet`) forces `isMovable == true`
/// while a sheet is up — the dimmed backdrop becomes a window drag handle, so it
/// must win over any no-drag region that happens to sit under the scrim.
@MainActor
final class WindowDragExclusion {
    static let shared = WindowDragExclusion()

    private struct State {
        weak var window: NSWindow?
        var hoverCount = 0    // registered no-drag regions currently under the cursor
        var modalDraggable = false
    }

    private var states: [ObjectIdentifier: State] = [:]

    private func key(_ window: NSWindow) -> ObjectIdentifier { ObjectIdentifier(window) }

    /// Cursor entered a no-drag region in `window`.
    func enterNoDrag(_ window: NSWindow) {
        var state = states[key(window)] ?? State(window: window)
        state.window = window
        state.hoverCount += 1
        states[key(window)] = state
        apply(state)
    }

    /// Cursor left a no-drag region in `window`.
    func exitNoDrag(_ window: NSWindow) {
        guard var state = states[key(window)] else { return }
        state.hoverCount = max(0, state.hoverCount - 1)
        states[key(window)] = state
        apply(state)
    }

    /// Forces `window` movable while `draggable` (a modal app sheet is up), so the
    /// backdrop can drag the window even where a no-drag region sits under it.
    func setModalDraggable(_ window: NSWindow, _ draggable: Bool) {
        var state = states[key(window)] ?? State(window: window)
        state.window = window
        state.modalDraggable = draggable
        states[key(window)] = state
        apply(state)
    }

    private func apply(_ state: State) {
        state.window?.isMovable = state.modalDraggable ? true : (state.hoverCount == 0)
    }
}

/// Tracks the cursor over its (and thus its SwiftUI host's) frame and toggles the
/// window's drag-exclusion hover count, so a press here can't move the window.
struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragBlockingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragBlockingView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }

        /// Whether the cursor is currently counted as inside this region — guards
        /// against double counting across `updateTrackingAreas` rebuilds.
        private var isInside = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
            // The tracking area is rebuilt on resize/move; if the cursor is
            // already inside (e.g. a cluster shifted under a stationary cursor),
            // sync the entered state so dragging stays disabled.
            syncEnteredState()
        }

        override func mouseEntered(with event: NSEvent) {
            setInside(true)
        }

        override func mouseExited(with event: NSEvent) {
            setInside(false)
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            // Balance the count when detaching while the cursor is inside.
            if isInside, let window {
                isInside = false
                WindowDragExclusion.shared.exitNoDrag(window)
            }
            super.viewWillMove(toWindow: newWindow)
        }

        private func syncEnteredState() {
            guard let window else { return }
            let inside = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
            setInside(inside)
        }

        private func setInside(_ inside: Bool) {
            guard inside != isInside, let window else { return }
            isInside = inside
            if inside {
                WindowDragExclusion.shared.enterNoDrag(window)
            } else {
                WindowDragExclusion.shared.exitNoDrag(window)
            }
        }
    }
}

/// While `active` (a modal app sheet is up), forces the host window movable so
/// the backdrop can drag it — overriding any no-drag hover region that happens to
/// sit under the scrim (`isMovable` gates ALL dragging, so without this a press
/// over a title-bar button beneath the scrim wouldn't drag). The actual drag
/// hit-region is `WindowDragSurface` on the scrim itself.
struct WindowModalDraggable: NSViewRepresentable {
    var active: Bool

    func makeNSView(context: Context) -> NSView { OverrideView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? OverrideView)?.apply(active: active)
    }

    final class OverrideView: NSView {
        private var active = false

        func apply(active: Bool) {
            self.active = active
            if let window { WindowDragExclusion.shared.setModalDraggable(window, active) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply(active: active)
        }
    }
}

/// A transparent surface that lets a press-drag move the window (the per-view
/// `mouseDownCanMoveWindow` opt-in the Window Server honors) while still
/// consuming plain clicks so controls underneath stay inert. Used as the
/// `appSheet` backdrop so the dimmed scrim doubles as a window drag handle.
/// Requires the window to be movable — see `WindowModalDraggable`.
struct WindowDragSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}

extension View {
    /// Marks the view's region non-draggable so a press here doesn't move the
    /// window. Use for custom title-bar controls.
    public func windowDragDisabled() -> some View {
        background(WindowDragBlocker())
    }

    /// While `active`, keeps the window movable so the modal `appSheet` backdrop
    /// (a `WindowDragSurface`) can drag it, despite no-drag regions beneath it.
    public func windowModalDraggable(_ active: Bool) -> some View {
        background(WindowModalDraggable(active: active))
    }
}
