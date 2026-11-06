//
//  FocusVisibilityService.swift
//  BlissUI
//
//  When focus rings show, and what Return does to the control a ring is on.
//

import AppKit
import SwiftUI

/// Focus rings show only after keyboard input, like the web's `:focus-visible`.
/// A click gives a control focus too, and a ring on every clicked button read as
/// a selected state. A key press turns rings on (not a ⌘ / ⌃ / ⌥ shortcut, and
/// not Return); a mouse press turns them off. Text inputs show theirs on a click
/// as well (`focusRing(showsOnPointerFocus: true)`), as browsers do.
///
/// It also makes Return press the control a ring is on, as Space does. Return
/// goes to the control only while its ring shows, no menu is open over the
/// window, and focus sits on a SwiftUI control — AppKit's first responder is then
/// SwiftUI's private `KeyViewProxy`, never a text field or an AppKit text view.
/// Otherwise Return stays the sheet's default action. The control receives a
/// Space press, so everything that answers Space answers Return with no code of
/// its own. Installed from the first focus ring's `onAppear`.
@MainActor
@Observable
public final class FocusVisibilityService {
    public static let shared = FocusVisibilityService()

    /// Whether the last input was the keyboard, so focus rings show.
    public private(set) var showsFocusRings = false

    /// Controls with a keyboard-only ring that have focus right now.
    @ObservationIgnored private var focusedControls = Set<UUID>()
    @ObservationIgnored private var eventMonitor: Any?
    /// A Return key-down went to the focused control as Space, so its repeats
    /// and its key-up go the same way.
    @ObservationIgnored private var isRedirectingReturn = false

    private init() {}

    /// Installs the key and mouse monitor. `focusRing` calls it on appear, so
    /// an app only needs it to track input before any ring is on screen.
    public func startIfNeeded() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    /// A menu's own key monitor consumes the arrow and Tab presses that move its
    /// highlight, so this monitor may never see them; the menu reports them.
    public func noteKeyboardInput() {
        if !showsFocusRings { showsFocusRings = true }
    }

    /// Hovering a menu whose highlight follows the pointer: the ring would chase
    /// the cursor, so it goes until the next key press.
    public func notePointerInput() {
        if showsFocusRings { showsFocusRings = false }
    }

    func noteFocus(_ isFocused: Bool, control: UUID) {
        if isFocused {
            focusedControls.insert(control)
        } else {
            focusedControls.remove(control)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if showsFocusRings { showsFocusRings = false }
            return event
        case .keyDown, .keyUp:
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            if Self.isReturn(event) {
                return redirectingReturn(event)
            }
            if event.type == .keyDown, !showsFocusRings { showsFocusRings = true }
            return event
        default:
            return event
        }
    }

    private func redirectingReturn(_ event: NSEvent) -> NSEvent {
        if event.type == .keyDown, !event.isARepeat {
            isRedirectingReturn = showsFocusRings
                && !focusedControls.isEmpty
                && Self.focusIsOnSwiftUIControl(in: event.window)
                && !Self.hasOpenMenu(over: event.window)
        }
        guard isRedirectingReturn else { return event }
        if event.type == .keyUp { isRedirectingReturn = false }
        return Self.spacePress(like: event) ?? event
    }

    /// Return or the keypad's Enter.
    private static func isReturn(_ event: NSEvent) -> Bool {
        event.keyCode == 36 || event.keyCode == 76
    }

    private static func focusIsOnSwiftUIControl(in window: NSWindow?) -> Bool {
        guard let responder = window?.firstResponder else { return false }
        return String(describing: type(of: responder)) == "KeyViewProxy"
    }

    /// Floating menus and right-click popups are child panels of their window,
    /// and they run their own keys (Return picks the focused row).
    private static func hasOpenMenu(over window: NSWindow?) -> Bool {
        window?.childWindows?.contains { $0.isVisible && $0 is NSPanel } ?? false
    }

    private static func spacePress(like event: NSEvent) -> NSEvent? {
        NSEvent.keyEvent(
            with: event.type,
            location: event.locationInWindow,
            modifierFlags: event.modifierFlags,
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: event.isARepeat,
            keyCode: 49
        )
    }
}
