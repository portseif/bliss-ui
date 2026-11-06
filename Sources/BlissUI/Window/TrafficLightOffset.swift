//
//  TrafficLightOffset.swift
//  BlissUI
//
//  Moves the traffic lights in a hidden-title-bar window and keeps them there
//  through every title-bar layout, live resizes included.
//

import AppKit
import ObjectiveC
import SwiftUI

/// Moves a window's traffic lights by an offset, so they sit centered in a
/// custom title bar rather than at macOS's natural (higher) spot.
///
/// AppKit places the three buttons from `NSThemeFrame`'s private
/// `_closeButtonOrigin` (minimize and zoom are laid out from it, so overriding
/// their origins too would stack the offset 2× and 3×) and re-runs that
/// placement on every title-bar layout — including each step of a live resize
/// that grows the window's height. Moving the buttons' view after AppKit placed
/// them (didResize, frame observers, viewWillDraw and re-parenting were all
/// tried) was undone on every one of those steps, so the lights jumped back to
/// the natural spot mid-drag and snapped over on release. Answering the origin
/// itself puts every layout on the offset, with nothing to undo. The buttons
/// stay inside the 32pt `.hiddenTitleBar` title bar view and take clicks at
/// all four corners.
///
/// Only windows passed to `apply(to:offset:)` move. Full screen (the buttons
/// live in the toolbar overlay there) and a right-to-left title bar keep
/// AppKit's own spot. There's no public API for this as of the macOS 27 SDK; if
/// a release drops the method or changes its `{CGPoint=dd}` signature, the
/// swap is skipped and the lights sit at the default spot — nothing breaks.
public enum TrafficLightOffset {
    /// (3, −6): centered in a 52pt custom title bar.
    public nonisolated static let defaultOffset = CGPoint(x: 3, y: -6)

    private static var windowKey: UInt8 = 0
    private static var isInstalled = false

    /// Offsets `window`'s traffic lights. Calling it again with a new offset
    /// moves them there.
    public static func apply(to window: NSWindow, offset: CGPoint = defaultOffset) {
        installIfNeeded()
        let stored = (objc_getAssociatedObject(window, &windowKey) as? NSValue)?.pointValue
        guard stored != offset else { return }
        objc_setAssociatedObject(window, &windowKey, NSValue(point: offset), .OBJC_ASSOCIATION_RETAIN)
        // The buttons were placed before the window was marked; place them again.
        placeButtons(in: window)
    }

    /// Returns `window`'s traffic lights to AppKit's spot.
    public static func remove(from window: NSWindow) {
        guard objc_getAssociatedObject(window, &windowKey) != nil else { return }
        objc_setAssociatedObject(window, &windowKey, nil, .OBJC_ASSOCIATION_RETAIN)
        placeButtons(in: window)
    }

    /// Has AppKit lay the buttons out again now (through the offset). Leaving
    /// full screen needs it: nothing else re-lays them out once the style mask
    /// drops `.fullScreen`.
    public static func placeButtons(in window: NSWindow) {
        let updateButtonPositions = NSSelectorFromString("_updateButtonPositions")
        if let frameView = window.contentView?.superview, frameView.responds(to: updateButtonPositions) {
            frameView.perform(updateButtonPositions)
        }
    }

    private static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true
        typealias OriginFunction = @convention(c) (NSView, Selector) -> CGPoint
        let selector = NSSelectorFromString("_closeButtonOrigin")
        guard let themeFrame = NSClassFromString("NSThemeFrame"),
              let method = class_getInstanceMethod(themeFrame, selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding).hasPrefix("{CGPoint=dd}") else { return }
        let original = unsafeBitCast(method_getImplementation(method), to: OriginFunction.self)
        let offsetOrigin: @convention(block) (NSView) -> CGPoint = { frameView in
            let origin = original(frameView, selector)
            guard let window = frameView.window,
                  let offset = (objc_getAssociatedObject(window, &windowKey) as? NSValue)?.pointValue,
                  !window.styleMask.contains(.fullScreen),
                  window.windowTitlebarLayoutDirection == .leftToRight else { return origin }
            return CGPoint(x: origin.x + offset.x, y: origin.y + offset.y)
        }
        method_setImplementation(method, imp_implementationWithBlock(offsetOrigin))
    }
}

// MARK: - SwiftUI

/// Applies the offset once the view lands in its window, and re-places the
/// buttons when the window leaves full screen.
private struct TrafficLightOffsetView: NSViewRepresentable {
    let offset: CGPoint

    func makeNSView(context: Context) -> TrafficLightAnchorView {
        let view = TrafficLightAnchorView()
        view.offset = offset
        return view
    }

    func updateNSView(_ nsView: TrafficLightAnchorView, context: Context) {
        nsView.offset = offset
    }

    final class TrafficLightAnchorView: NSView {
        var offset: CGPoint = TrafficLightOffset.defaultOffset {
            didSet { if let window { TrafficLightOffset.apply(to: window, offset: offset) } }
        }
        private var exitFullScreenObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let exitFullScreenObserver { NotificationCenter.default.removeObserver(exitFullScreenObserver) }
            exitFullScreenObserver = nil
            guard let window else { return }
            TrafficLightOffset.apply(to: window, offset: offset)
            exitFullScreenObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main
            ) { [weak window] _ in
                MainActor.assumeIsolated {
                    if let window { TrafficLightOffset.placeButtons(in: window) }
                }
            }
        }
    }
}

extension View {
    /// Moves this window's traffic lights by `offset` and keeps them there
    /// through resizes, key changes and full screen. For a window with
    /// `.windowStyle(.hiddenTitleBar)`; `.blissWindowChrome()` includes it.
    public func trafficLightOffset(_ offset: CGPoint = TrafficLightOffset.defaultOffset) -> some View {
        background(TrafficLightOffsetView(offset: offset))
    }
}
