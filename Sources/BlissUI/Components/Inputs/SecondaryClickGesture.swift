//
//  SecondaryClickGesture.swift
//  BlissUI
//
//  Detects right-click / control-click on a SwiftUI view via a window-level
//  NSEvent monitor. The monitor fires on `.rightMouseDown` and checks whether
//  the cursor was inside the view's frame; if so, the action runs and the
//  event is consumed (returning nil from the monitor closure).
//
//  This approach works around SwiftUI's hit-testing eating right-click events
//  before they reach an `NSClickGestureRecognizer` — used to trigger custom
//  popup menus instead of the default macOS `.contextMenu`.
//

import AppKit
import SwiftUI

struct SecondaryClickGesture: NSViewRepresentable {
    let action: (NSPoint) -> Void
    var anchor: SecondaryClickAnchor? = nil

    func makeNSView(context: Context) -> NSView {
        let view = MonitorHostView()
        view.action = action
        anchor?.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorHostView)?.action = action
    }

    /// Transparent NSView that installs a window-level event monitor on
    /// attach. Hit-test returns nil so clicks still pass through to the
    /// SwiftUI views above; the monitor catches right-clicks before they're
    /// dispatched and consumes them when the click lands inside this view's
    /// frame, passing the cursor location (in screen coordinates) to the
    /// action so a popup menu can be positioned at the cursor.
    private final class MonitorHostView: NSView {
        var action: ((NSPoint) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            // Control-click arrives as a left click with the control flag (AppKit
            // only maps it to a menu inside `menu(for:)`), so match it here too —
            // the one-button-mouse / trackpad-without-two-finger way in.
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
                guard let self,
                      let window = self.window,
                      event.window === window else { return event }
                if event.type == .leftMouseDown && !event.modifierFlags.contains(.control) { return event }

                let locationInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    let screenRect = window.convertToScreen(
                        NSRect(origin: event.locationInWindow, size: .zero)
                    )
                    let screenPoint = screenRect.origin
                    DispatchQueue.main.async { [weak self] in
                        self?.action?(screenPoint)
                    }
                    return nil  // consume — prevents underlying handlers
                }
                return event
            }
        }

        override func removeFromSuperview() {
            removeMonitor()
            super.removeFromSuperview()
        }

        deinit { removeMonitor() }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        // Pass clicks through to underlying views — we only observe via the
        // monitor, never claim hits.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// Where the view sits on screen, for opening its menu from the keyboard.
@MainActor
final class SecondaryClickAnchor {
    weak var view: NSView?

    /// Just under the view's leading edge, in screen coordinates (the popup puts
    /// its top-leading corner there).
    func menuPoint() -> NSPoint? {
        guard let view, let window = view.window else { return nil }
        let screenRect = window.convertToScreen(view.convert(view.bounds, to: nil))
        return NSPoint(x: screenRect.minX + Spacing.md, y: screenRect.minY)
    }
}

private struct SecondaryClickModifier: ViewModifier {
    let action: (NSPoint) -> Void

    @State private var anchor = SecondaryClickAnchor()

    /// ⇧F10, the context-menu key on other platforms (and in apps like VS Code).
    private static let f10 = KeyEquivalent(Character(UnicodeScalar(NSF10FunctionKey)!))

    func body(content: Content) -> some View {
        content
            .background(SecondaryClickGesture(action: action, anchor: anchor))
            // The keyboard way in: while this view or something in it has focus,
            // ⌃Return or ⇧F10 opens the menu under its leading edge. A plain
            // Return passes on (to the focused control or the sheet).
            .onKeyPress(keys: [.return, Self.f10], phases: .down) { press in
                // F10 also carries the function-key flag, so compare only these.
                let modifiers = press.modifiers.intersection([.shift, .control, .option, .command])
                let opensMenu = press.key == .return ? modifiers == .control : modifiers == .shift
                guard opensMenu, let point = anchor.menuPoint() else { return .ignored }
                action(point)
                PopupMenuService.shared.highlightFirstRowForKeyboard()
                return .handled
            }
    }
}

extension View {
    /// Trigger an action on right-click / control-click without using the
    /// default `.contextMenu` (which forces native macOS styling). The closure
    /// receives the cursor location in screen coordinates so the caller can
    /// position a popup at the click site. From the keyboard, ⌃Return or ⇧F10
    /// does the same while the view or something in it has focus, with a point
    /// under the view's leading edge.
    public func onSecondaryClick(perform action: @escaping (NSPoint) -> Void) -> some View {
        modifier(SecondaryClickModifier(action: action))
    }
}
