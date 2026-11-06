//
//  ShellBackdrop.swift
//  BlissUI
//
//  An opaque shell behind the whole window, title-bar band included, re-asserted
//  across every activation change SwiftUI resets it on.
//

import AppKit
import SwiftUI

/// A plain opaque fill view. Inserted as the backmost view of the window's
/// frame view so it spans the *entire* window — including the title-bar band —
/// behind SwiftUI's hosting view. Wherever SwiftUI draws nothing (the
/// transparent title-bar band), this shows through instead of the see-through
/// window backing. Immune to SwiftUI's `isOpaque`/`backgroundColor` resets.
final class ShellBackdropView: NSView {
    var fillColor: NSColor = .windowBackgroundColor {
        didSet { needsDisplay = true }
    }
    override var isOpaque: Bool { true }

    // The fill is the layer's background color, never a drawn bitmap. Drawing it
    // in `draw(_:)` gave this window-sized view a window-sized backing store at
    // every size, and a live resize piled them up: ~230MB of graphics memory
    // during a drag, handed back a few seconds after it ended. Measured in a
    // throwaway window: drawn 262MB right after a resize, layer color 25MB.
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        // Resolved here, under the view's effective appearance, so a dynamic
        // shell color follows light / dark.
        layer?.backgroundColor = fillColor.cgColor
    }

    /// Insert (or recolor) the backmost shell backdrop in `window`'s frame
    /// view, plus set the opaque shell backing. The backdrop covers the whole
    /// window including the title-bar band, so the top edge reads the shell
    /// color in every theme and active state — no band, no seam, no bleed.
    static func apply(to window: NSWindow) {
        let shell = NSColor(Color.appShell)
        window.isOpaque = true
        window.backgroundColor = shell
        // `.windowStyle(.hiddenTitleBar)` owns the title bar now — content fills
        // to the top with no native title-bar material. This just keeps the
        // window opaque with the shell color as the backing behind everything.
        guard let contentView = window.contentView,
              let frameView = contentView.superview else { return }

        let backdrop: ShellBackdropView
        if let existing = frameView.subviews.compactMap({ $0 as? ShellBackdropView }).first {
            backdrop = existing
            backdrop.fillColor = shell
        } else {
            backdrop = ShellBackdropView(frame: frameView.bounds)
            backdrop.wantsLayer = true
            backdrop.fillColor = shell
            backdrop.autoresizingMask = [.width, .height]
        }
        backdrop.frame = frameView.bounds

        // RE-ASSERT THE Z-ORDER EVERY TIME, not just on creation. This view is
        // OPAQUE and fills the whole frame, so if it ever ends up above the
        // hosting view it paints over the entire app — a solid shell-colored
        // rectangle with a fully populated (but invisible) accessibility tree.
        // Changing the window's style mask makes AppKit rebuild the NSThemeFrame
        // and re-add its subviews in ITS order, which is exactly what the
        // post-onboarding chrome restore does — verified live: the backdrop sat
        // at index 2, above both the hosting view and the titlebar container.
        // `relativeTo: nil` + `.below` means "below all siblings" (bottom).
        if frameView.subviews.first !== backdrop {
            backdrop.removeFromSuperview()
            frameView.addSubview(backdrop, positioned: .below, relativeTo: nil)
        }
    }
}

// MARK: - Window Opacity Enforcer

/// Keeps the window's title-bar band matching the content: an opaque shell
/// backdrop behind everything, re-asserted across activation changes.
///
/// Uses `viewDidMoveToWindow` (the reliable "now attached to a window" hook)
/// rather than a `DispatchQueue.main.async { view.window }` dance — the latter
/// can fire before the view is in a window and then silently no-op forever.
/// SwiftUI's `WindowGroup` also resets `isOpaque`/`backgroundColor` on
/// activation changes, so re-assert on every key/main/occlusion change. The
/// re-assert is deferred a runloop tick so it lands after SwiftUI's own
/// deactivation handling.
struct WindowOpacityEnforcer: NSViewRepresentable {
    /// The traffic-light offset to keep, or nil to leave them at AppKit's spot.
    var trafficLightOffset: CGPoint? = TrafficLightOffset.defaultOffset

    func makeNSView(context: Context) -> NSView {
        let view = WindowConfiguratorView()
        view.trafficLightOffset = trafficLightOffset
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowConfiguratorView)?.trafficLightOffset = trafficLightOffset
    }
}

private final class WindowConfiguratorView: NSView {
    private var observersInstalled = false
    var trafficLightOffset: CGPoint? = TrafficLightOffset.defaultOffset {
        didSet {
            guard oldValue != trafficLightOffset, let window else { return }
            applyTrafficLights(to: window)
        }
    }

    private func applyTrafficLights(to window: NSWindow) {
        if let trafficLightOffset {
            TrafficLightOffset.apply(to: window, offset: trafficLightOffset)
        } else {
            TrafficLightOffset.remove(from: window)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        ShellBackdropView.apply(to: window)
        applyTrafficLights(to: window)

        guard !observersInstalled else { return }
        observersInstalled = true
        let triggers: [NSNotification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification
        ]
        for name in triggers {
            NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak window] notification in
                MainActor.assumeIsolated {
                    guard let window else { return }
                    ShellBackdropView.apply(to: window)
                    // The offset stands down in full screen; nothing else re-lays
                    // the buttons out once the mask drops `.fullScreen`.
                    if notification.name == NSWindow.didExitFullScreenNotification {
                        TrafficLightOffset.placeButtons(in: window)
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI

extension View {
    /// The BlissUI window shell for a `.windowStyle(.hiddenTitleBar)` window:
    /// content fills to the top, the title-bar band reads the theme's shell
    /// color in every active state (no band, no seam, no desktop bleed), and
    /// the traffic lights sit at `trafficLightOffset` (nil keeps AppKit's spot).
    /// Put it once on the window's root view.
    ///
    /// Don't also insert `.titled` / `.fullSizeContentView` /
    /// `titlebarAppearsTransparent` yourself — they fight `.hiddenTitleBar`
    /// and bring back the opaque inactive title-bar material.
    public func blissWindowChrome(trafficLightOffset: CGPoint? = TrafficLightOffset.defaultOffset) -> some View {
        background(WindowOpacityEnforcer(trafficLightOffset: trafficLightOffset))
    }
}

/// Window-chrome calls for AppKit code that changes a window behind SwiftUI's
/// back.
public enum WindowChrome {
    /// Puts the opaque shell backdrop back underneath everything. Call it after
    /// changing a window's style mask yourself: AppKit rebuilds the theme frame
    /// in its own order, and an opaque backdrop left above the hosting view
    /// paints over the whole app (a blank window with a full accessibility tree).
    public static func applyShellBackdrop(to window: NSWindow) {
        ShellBackdropView.apply(to: window)
    }
}
