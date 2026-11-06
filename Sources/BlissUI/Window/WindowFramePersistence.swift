//
//  WindowFramePersistence.swift
//  BlissUI
//
//  Saves a window's frame as it moves and resizes, and restores it on launch.
//

import AppKit
import SwiftUI

/// Notification observers removed together (when their window closes).
private nonisolated final class WindowObserverTokens: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    func add(_ token: NSObjectProtocol) {
        lock.lock()
        tokens.append(token)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        let removing = tokens
        tokens = []
        lock.unlock()
        removing.forEach(NotificationCenter.default.removeObserver)
    }
}

/// Saves and restores a window's frame while `BlissAppearance.Keys.saveWindowLocation`
/// is on (the default). A saved frame that's no longer on any screen is ignored.
struct WindowFramePersistence: NSViewRepresentable {
    @AppStorage(BlissAppearance.Keys.saveWindowLocation) private var saveWindowLocation = true

    /// The `UserDefaults` key the frame is stored under; give each window its own.
    var frameKey = BlissAppearance.Keys.mainWindowFrame

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            // Restore saved frame if setting is enabled
            if saveWindowLocation,
               let frameString = UserDefaults.standard.string(forKey: frameKey) {
                let frame = NSRectFromString(frameString)
                // Validate the frame is on a visible screen
                if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                    window.setFrame(frame, display: true)
                }
            }

            // Observe window move/resize to save frame. The window is held weakly
            // and the observers are removed when it closes: held strongly with
            // their tokens dropped, every closed main window stayed in memory.
            let observers = WindowObserverTokens()
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                observers.add(NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak window] _ in
                    MainActor.assumeIsolated {
                        if let window { saveFrame(window) }
                    }
                })
            }
            observers.add(NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                observers.removeAll()
            })
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func saveFrame(_ window: NSWindow) {
        guard saveWindowLocation else { return }
        let frameString = NSStringFromRect(window.frame)
        UserDefaults.standard.set(frameString, forKey: frameKey)
    }
}

extension View {
    /// Restores this window's last frame and saves it as it moves and resizes.
    /// Give each kind of window its own `key`.
    public func persistsWindowFrame(key: String = BlissAppearance.Keys.mainWindowFrame) -> some View {
        background(WindowFramePersistence(frameKey: key))
    }
}
