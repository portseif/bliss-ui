//
//  ShortcutHintService.swift
//  BlissUI
//
//  Holding ⌘ or ⌃ shows each shortcut as a small key pill on the control it
//  triggers (`.shortcutHint(_:)`). The hold has to last
//  `revealDelay` so a quick ⌘N never flashes them; releasing, a key press or a
//  click hides them, and they stay down until the modifier is let go, so ⌘1
//  then ⌘2 doesn't bring them back between presses.
//

import AppKit
import SwiftUI

@Observable
public final class ShortcutHintService {
    public static let shared = ShortcutHintService()

    /// Whether the hint pills are showing.
    public private(set) var isShowingHints = false

    /// How long ⌘ or ⌃ must be held before the hints show.
    public static let revealDelay: TimeInterval = 0.4

    /// Return true while hints shouldn't appear at all — a command palette
    /// that owns the keys, say. Set by the host app.
    @ObservationIgnored public var isSuppressed: () -> Bool = { false }
    /// Return true while ⌃ is reserved for something else, like a terminal
    /// view that has focus. Set by the host app.
    @ObservationIgnored public var controlKeyIsReserved: () -> Bool = { false }

    @ObservationIgnored private var eventMonitor: Any?
    @ObservationIgnored private var resignActiveObserver: NSObjectProtocol?
    @ObservationIgnored private var pendingReveal: DispatchWorkItem?
    /// A key or click landed while the modifier was down: the user is acting,
    /// not looking. Cleared when every modifier is released.
    @ObservationIgnored private var isSuppressedUntilRelease = false

    private init() {}

    /// Installs the modifier monitor. Called by the first hint that appears, so
    /// nothing is watched until a hinted control is on screen (never under XCTest).
    public func startIfNeeded() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }
        // ⌘Tab hands the release to another app, so it never reaches us.
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideHints(suppressingUntilRelease: false) }
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            // A shortcut (⌘1 then ⌘2) or a click while hints are up hides them
            // until every modifier is released. A plain click or keystroke with
            // no modifier held suppresses nothing — it used to, and since no
            // release followed, the next held ⌘ showed no hints.
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let holdsHintModifier = modifiers.contains(.command) || modifiers.contains(.control)
            hideHints(suppressingUntilRelease: holdsHintModifier || isShowingHints || pendingReveal != nil)
            return
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let holdsCommand = modifiers.contains(.command)
        // ⌃ alone is how a terminal types ⌃C, ⌃R and friends; don't pop hints
        // over a shell someone is typing into (`controlKeyIsReserved`).
        let holdsControl = modifiers.contains(.control) && !controlKeyIsReserved()
        guard holdsCommand || holdsControl else {
            hideHints(suppressingUntilRelease: false)
            return
        }
        scheduleReveal()
    }

    private func scheduleReveal() {
        // Not while the host suppresses them — a command palette, say: its field
        // has the keys (⌃A, ⌃E edit the text), and the pills would land on
        // controls under it.
        guard !isShowingHints, !isSuppressedUntilRelease, pendingReveal == nil,
              !isSuppressed()
        else { return }
        let reveal = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingReveal = nil
            guard !isSuppressed() else { return }
            withAnimation(Animations.hover) { self.isShowingHints = true }
        }
        pendingReveal = reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDelay, execute: reveal)
    }

    private func hideHints(suppressingUntilRelease: Bool) {
        isSuppressedUntilRelease = suppressingUntilRelease
        pendingReveal?.cancel()
        pendingReveal = nil
        guard isShowingHints else { return }
        withAnimation(Animations.hover) { isShowingHints = false }
    }
}
