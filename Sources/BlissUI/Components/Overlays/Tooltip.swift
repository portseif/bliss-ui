//
//  Tooltip.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/4/25.
//

import AppKit
import SwiftUI

// MARK: - Environment Key for Disabling Tooltips

extension EnvironmentValues {
    /// Whether `.tooltip` modifiers in this subtree stay quiet (see `tooltipsDisabled(_:)`).
    @Entry public var tooltipsDisabled: Bool = false
}

extension View {
    /// Silences every tooltip in this subtree — and hides one already up — while
    /// `disabled` is true (e.g. while a drag or an inline edit is in progress).
    public func tooltipsDisabled(_ disabled: Bool = true) -> some View {
        environment(\.tooltipsDisabled, disabled)
    }
}

// MARK: - Tooltip Position

/// Which side of its source view a tooltip appears on.
public nonisolated enum TooltipPosition: Sendable {
    case above
    case below
    case leading
    case trailing
}

// MARK: - Tooltip Metrics

/// The sizes and timings every tooltip shares.
public nonisolated enum TooltipMetrics {
    /// The widest a tooltip's text runs before wrapping.
    public static let maxWidth: CGFloat = 250
    /// The tallest a tooltip gets before its content scrolls.
    public static let maxHeight: CGFloat = 200
    /// The `.compact` preset's envelope.
    public static let compactMaxWidth: CGFloat = 180
    public static let compactMaxHeight: CGFloat = 120
    /// The `.wide` preset's envelope, and the actions tooltip's width.
    public static let wideMaxWidth: CGFloat = 320
    public static let wideMaxHeight: CGFloat = 250
    /// The `.iconHint` preset's envelope: one line.
    public static let iconHintMaxWidth: CGFloat = 200
    public static let iconHintMaxHeight: CGFloat = 44
    /// The text's inset: the menu rows' (`Spacing.menuRowPaddingH` / `V`),
    /// restated here because a configuration is built off the main actor.
    public static let horizontalPadding: CGFloat = 10
    public static let verticalPadding: CGFloat = 5
    /// The gap between the tooltip and the view it points at.
    @MainActor static var anchorOffset: CGFloat { Spacing.sm }
    /// How close to a screen's edge a tooltip may sit.
    @MainActor static var screenInset: CGFloat { Spacing.xxs }
    /// Delay before the first tooltip in a session appears. Prevents accidental
    /// activation when the cursor merely passes over a target.
    static let initialDelay: TimeInterval = 0.5
    /// Window of time after a tooltip closes during which subsequent tooltips
    /// appear instantly with no fade-in. Lets users sweep across icon rows
    /// without the cumulative half-second penalty per icon.
    static let groupGrace: TimeInterval = 0.4
    /// How long an interactive tooltip stays after the cursor leaves its source,
    /// so the cursor can cross into it.
    static let hideGrace: TimeInterval = 0.25
    /// How long an action's confirmation ("Copied") shows.
    static let confirmationDuration: TimeInterval = 1.2
    /// How far outside its target the cursor may be and still count as on it.
    static let cursorTolerance: CGFloat = 4
    /// Anchor-rect sanity limits: a control taller or wider than this, or with
    /// an edge farther from the cursor than `edgeSlack`, is an inflated parent
    /// frame, and that axis collapses to `cursorBox` around the cursor.
    static let controlLimit: CGFloat = 72
    static let edgeSlack: CGFloat = 48
    static let cursorBox: CGFloat = 24
    /// How far the offset edge may sit from the cursor, and the centering axis.
    static let edgeCap: CGFloat = 24
    static let centerCap: CGFloat = 48
    /// How often an on-screen tooltip re-checks its target.
    static let anchorWatchInterval: TimeInterval = 1.0 / 30.0
}

/// How long a tooltip waits before it shows.
public nonisolated enum TooltipDelay: Sendable {
    /// The usual half second, skipped within a group of tooltips.
    case standard
    /// At once — a chart callout, a key-hint pill.
    case none
}

// MARK: - Tooltip Configuration

/// Configuration options for tooltip sizing behavior
public nonisolated struct TooltipConfiguration: Equatable, Sendable {
    /// Maximum width of the tooltip content
    public var maxWidth: CGFloat = TooltipMetrics.maxWidth
    /// Maximum height before scrolling is enabled
    public var maxHeight: CGFloat = TooltipMetrics.maxHeight
    /// Horizontal padding inside the tooltip
    public var horizontalPadding: CGFloat = TooltipMetrics.horizontalPadding
    /// Vertical padding inside the tooltip
    public var verticalPadding: CGFloat = TooltipMetrics.verticalPadding
    /// When true, the tooltip accepts mouse interaction: hovering it keeps it
    /// open (so the cursor can travel from the source into the tooltip), and
    /// it can host clickable action buttons. Default tooltips stay click-through.
    public var interactive: Bool = false
    /// How long the tooltip waits before it shows.
    public var delay: TooltipDelay = .standard

    public init(
        maxWidth: CGFloat = TooltipMetrics.maxWidth,
        maxHeight: CGFloat = TooltipMetrics.maxHeight,
        horizontalPadding: CGFloat = TooltipMetrics.horizontalPadding,
        verticalPadding: CGFloat = TooltipMetrics.verticalPadding,
        interactive: Bool = false,
        delay: TooltipDelay = .standard
    ) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.interactive = interactive
        self.delay = delay
    }

    // Every tooltip uses the menu-row inset — the init's defaults, so the text
    // overloads that build their own configuration read the same; the presets
    // differ only in width envelope.
    public static let `default` = TooltipConfiguration()
    public static let compact = TooltipConfiguration(maxWidth: TooltipMetrics.compactMaxWidth, maxHeight: TooltipMetrics.compactMaxHeight)
    public static let wide = TooltipConfiguration(maxWidth: TooltipMetrics.wideMaxWidth, maxHeight: TooltipMetrics.wideMaxHeight)
    /// Tight single-line tooltip for icon buttons (sidebar rows, toolbar items).
    public static let iconHint = TooltipConfiguration(maxWidth: TooltipMetrics.iconHintMaxWidth, maxHeight: TooltipMetrics.iconHintMaxHeight)
}

// MARK: - Tooltip Window Controller

/// Manages a floating tooltip window that appears above all content
final class TooltipWindowController: NSObject {
    static let shared = TooltipWindowController()

    /// The app-wide click and scroll monitors, kept for the app's lifetime.
    /// Held so they're owned (a dropped token reads as a leak).
    private var globalClickMonitor: Any?
    private var localEventMonitor: Any?

    private var tooltipWindow: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var pendingShow: DispatchWorkItem?
    private var pendingHide: DispatchWorkItem?
    private var lastDismissedAt: Date?
    /// While a tooltip is on screen, its anchor view + last-known screen frame,
    /// re-checked by `anchorWatchTimer` so the tooltip follows a target that
    /// moves (animated layout, `scrollTo`, sheet morphs — none of which emit
    /// the scroll/click events the monitors see) and dies when the cursor is
    /// no longer on the target. This is what keeps tooltips from stranding.
    private weak var trackedAnchorView: NSView?
    private var trackedAnchorRect: NSRect = .zero
    private var anchorWatchTimer: Timer?
    /// Whether the on-screen tooltip accepts mouse interaction (hover-to-keep-open
    /// + clickable action buttons). Drives the click-monitor and hover behavior.
    private var interactiveTooltip = false
    /// Whether the on-screen tooltip was shown by code (`.tooltip(_:isPresented:)`)
    /// rather than hover: it stays until its binding drops, wherever the cursor is.
    private var pinnedTooltip = false

    /// True while a tooltip is on-screen OR within `groupGrace` of the last
    /// dismissal. Callers use this to decide whether to delay/animate.
    private var groupActive: Bool {
        if tooltipWindow != nil { return true }
        if let last = lastDismissedAt {
            return Date().timeIntervalSince(last) < TooltipMetrics.groupGrace
        }
        return false
    }

    private override init() {
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        // Hide tooltips when app loses focus
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // Hide tooltips when app is deactivated (another app comes to front)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didHideNotification,
            object: nil
        )

        // Hide tooltips when a different window becomes key
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        // Hide tooltips when a window is about to close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        // Hide tooltips on any mouse click (left, right, or other)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hide()
        }

        // Also monitor local mouse events within our app. Scrolling dismisses
        // too — the content under the tooltip is about to move, which is how
        // tooltips end up floating detached from their target.
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            // Events inside an interactive tooltip drive its action buttons /
            // its own scroll view — don't dismiss on those. Everything else
            // dismisses as usual.
            if self.interactiveTooltip, let window = event.window, window === self.tooltipWindow {
                return event
            }
            self.hide()
            if event.type == .scrollWheel {
                // Scrolling ends the tooltip session outright: content is in
                // motion, so the next hover should earn the full initial delay
                // again instead of popping instantly off the group grace.
                self.lastDismissedAt = nil
            }
            return event
        }
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        hide()
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // An interactive tooltip panel becoming key (e.g. the user clicked one of
        // its action buttons) must NOT dismiss itself.
        if let window = notification.object as? NSWindow, window === tooltipWindow { return }
        // Hide tooltip when any other window becomes key (focus changes)
        hide()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        hide()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Hover-in entry point. Handles the delay-vs-instant decision based on
    /// group activity so callers don't have to.
    ///
    /// The anchor VIEW (not a frozen point) is what's captured: its frame is
    /// re-resolved when the tooltip actually presents, so a target that moved
    /// during the initial delay (scroll, layout settling, a panel sliding in)
    /// can't strand the tooltip at a stale location.
    func requestShow<Content: View>(
        content: Content,
        configuration: TooltipConfiguration,
        anchoredTo anchorView: NSView,
        position: TooltipPosition,
        colorScheme: ColorScheme
    ) {
        cancelPendingShow()
        // Re-entering the source (or arriving from the tooltip) cancels any
        // grace-period dismissal that was queued on hover-out.
        cancelScheduledHide()

        if groupActive {
            // Mid-session — replace any current tooltip instantly, no animation.
            show(content: content, configuration: configuration, anchoredTo: anchorView, position: position, colorScheme: colorScheme, animated: false)
            return
        }

        // A tooltip that waits for nothing (a chart callout) shows at once.
        if configuration.delay == .none {
            show(content: content, configuration: configuration, anchoredTo: anchorView, position: position, colorScheme: colorScheme, animated: true)
            return
        }

        // First tooltip in a session — delay to filter out cursor sweeps.
        let workItem = DispatchWorkItem { [weak self, weak anchorView] in
            guard let self, let anchorView else { return }
            self.show(content: content, configuration: configuration, anchoredTo: anchorView, position: position, colorScheme: colorScheme, animated: true)
        }
        pendingShow = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + TooltipMetrics.initialDelay, execute: workItem)
    }

    func cancelPendingShow() {
        pendingShow?.cancel()
        pendingShow = nil
    }

    /// - Parameter pinned: Shown by code rather than hover: the cursor needn't
    ///   be on the anchor, and the tooltip stays until `hide()`.
    func show<Content: View>(
        content: Content,
        configuration: TooltipConfiguration,
        anchoredTo anchorView: NSView,
        position: TooltipPosition,
        colorScheme: ColorScheme,
        animated: Bool = true,
        pinned: Bool = false
    ) {
        // Resolve the anchor's frame NOW, at presentation time. Between hover
        // and the delayed show the target can move (content scrolled, layout
        // settled, a panel animated) — positioning from a hover-time snapshot
        // is what produced tooltips floating in empty space.
        guard let hostWindow = anchorView.window, hostWindow.isVisible else { return }
        let anchorRect = hostWindow.convertToScreen(anchorView.convert(anchorView.bounds, to: nil))
        guard anchorRect.width > 0, anchorRect.height > 0 else { return }

        // If the cursor is no longer over the target (it moved away and the
        // hover-exit was missed), don't show a tooltip for a control the user
        // isn't pointing at. A pinned tooltip anchors to the rect itself.
        let tolerance = TooltipMetrics.cursorTolerance
        let cursor = pinned ? NSPoint(x: anchorRect.midX, y: anchorRect.midY) : NSEvent.mouseLocation
        guard pinned || anchorRect.insetBy(dx: -tolerance, dy: -tolerance).contains(cursor) else { return }

        // Replacing an existing tooltip: drop it instantly. Fading the old one
        // while the new one pops in looks janky during group-active swaps.
        hide(animated: false)

        interactiveTooltip = configuration.interactive
        pinnedTooltip = pinned

        let tooltipView = TooltipContentView(
            content: content,
            configuration: configuration,
            position: position,
            animated: animated,
            // Interactive tooltips report their own hover so the cursor can
            // travel from the source into the tooltip without it dismissing.
            onHoverChange: configuration.interactive
                ? { [weak self] hovering in
                    if hovering { self?.cancelScheduledHide() }
                    else { self?.scheduleHide() }
                  }
                : nil
        )

        let hostingView = NSHostingView(rootView: AnyView(tooltipView))
        // Measure ONCE, up front, and use `measuredSize` for everything below.
        // Two reasons this must stay a single cached read:
        // 1. THE root cause of tooltips floating off their targets (`.above`
        //    way too high, `.below` riding up over its button): an
        //    NSHostingView used as a window's contentView installs Auto Layout
        //    sizing constraints (`sizingOptions` defaults to intrinsic-size
        //    options) that RESIZE THE PANEL when SwiftUI runs a late layout
        //    pass — the content view's height-measuring preference fires right
        //    after display. The panel grew with its bottom edge pinned and the
        //    pill floated up inside the taller window, while the anchor math
        //    was verifiably correct (traced: honest 28×28 anchor rects, cursor
        //    inside). Clearing `sizingOptions` severs that channel — the panel
        //    stays at exactly the frame we place.
        // 2. Once `sizingOptions` is cleared, `fittingSize` no longer reports
        //    the content size — a later re-read returns garbage. Sizing the
        //    panel from a second `fittingSize` call after the clear is what
        //    briefly shipped zero-sized/misplaced tooltips.
        let measuredSize = hostingView.fittingSize
        hostingView.setFrameSize(measuredSize)
        hostingView.sizingOptions = []

        let window = NSPanel(
            contentRect: NSRect(origin: .zero, size: measuredSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        // SwiftUI draws its own shadow inside TooltipContentView; letting AppKit
        // draw a window shadow in addition traces the alpha channel of the
        // SwiftUI shadow and produces a dotted halo around the tooltip.
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Interactive tooltips must receive mouse events so their buttons work
        // and hover keeps them open; default tooltips stay fully click-through.
        window.ignoresMouseEvents = !configuration.interactive
        // Don't steal key focus when an action button is clicked — a
        // nonactivating panel that only becomes key if it truly needs to keeps
        // the main window key (and avoids the didBecomeKey auto-dismiss).
        window.becomesKeyOnlyIfNeeded = true
        // Detached panels don't inherit the app's overridden color scheme, so
        // stamp the resolved scheme here — otherwise the tooltip falls back to
        // the system appearance (e.g. a dark bubble while the app is in light).
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = hostingView

        // Position the window. `tooltipSize` includes the transparent shadow
        // padding applied inside TooltipContentView; shift the window origin by
        // `PanelMetrics.shadowInset` so the visible content still lands at the
        // intended offset from the anchor. (Must be the cached measurement —
        // `fittingSize` is dead after the `sizingOptions` clear above.)
        let tooltipSize = measuredSize
        let pad = PanelMetrics.shadowInset
        let gap = TooltipMetrics.anchorOffset

        // The anchor frame comes from SwiftUI's `.background` plumbing and is NOT
        // reliably the control's own bounds — a `.position`ed view reports its
        // whole parent, and some containers hand back their own frame, so a 30pt
        // icon button can arrive as a 150pt block. Clamping only the centering
        // axis isn't enough: the OFFSET axis reads an edge (`maxY` for `.above`),
        // so an inflated rect throws the bubble far off in exactly the direction
        // it's pushed. The cursor is the one dependable signal for what's being
        // pointed at (the guard above verified it's inside the anchor), so
        // distrust the rect on two grounds per axis: it's too BIG to be a
        // control, or one of its EDGES sits farther from the cursor than a real
        // control could put it (a small button's edge is never ~50pt from a
        // cursor that's on it — that's an inflated parent frame, and it's what
        // made tooltips float way too high: `.above` reads the inflated maxY).
        // Either way, collapse that axis to a small box on the cursor. Ordinary
        // buttons and rows pass both tests and anchor to their real geometry.
        let controlLimit = TooltipMetrics.controlLimit
        let edgeSlack = TooltipMetrics.edgeSlack
        let cursorBox = TooltipMetrics.cursorBox
        var rect = anchorRect
        if rect.height > controlLimit
            || rect.maxY - cursor.y > edgeSlack
            || cursor.y - rect.minY > edgeSlack {
            rect = NSRect(x: rect.minX, y: cursor.y - cursorBox / 2, width: rect.width, height: cursorBox)
        }
        if rect.width > controlLimit
            || rect.maxX - cursor.x > edgeSlack
            || cursor.x - rect.minX > edgeSlack {
            rect = NSRect(x: cursor.x - cursorBox / 2, y: rect.minY, width: cursorBox, height: rect.height)
        }

        // HARD CAP on the offset edge — the last line of defense, and the one
        // that can't be fooled. Anchor rects have arrived shifted UP by large,
        // varying amounts (an `.above` tooltip floating way over its button; a
        // `.below` one riding up onto it), and every rect-based heuristic can be
        // slipped. But physics can't: the pointer is ON the control (guarded
        // above), so the control's top edge lies AT or slightly ABOVE the
        // cursor, its bottom edge AT or slightly BELOW — never the reverse, and
        // never far away. Clamp the edge each position offsets from into that
        // directionally-correct band around the cursor. Honest anchors pass
        // through untouched; shifted ones degrade to hugging the pointer.
        // A pinned tooltip trusts its rect: the cursor is nowhere near.
        let edgeCap: CGFloat = pinned ? .greatestFiniteMagnitude : TooltipMetrics.edgeCap
        func clamped(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            min(max(value, lower), upper)
        }
        // The centering axis gets a looser sanity band — being centered a bit
        // off reads fine; being centered 50+pt off does not.
        let centerCap: CGFloat = pinned ? .greatestFiniteMagnitude : TooltipMetrics.centerCap
        let centerX = clamped(rect.midX, cursor.x - centerCap, cursor.x + centerCap)
        let centerY = clamped(rect.midY, cursor.y - centerCap, cursor.y + centerCap)

        var origin: NSPoint
        switch position {
        case .above:
            // Anchor's top edge: at or above the cursor, within reach.
            let edgeY = clamped(rect.maxY, cursor.y, cursor.y + edgeCap)
            origin = NSPoint(x: centerX - tooltipSize.width / 2, y: edgeY + gap - pad)
        case .below:
            // Anchor's bottom edge: at or below the cursor, within reach.
            let edgeY = clamped(rect.minY, cursor.y - edgeCap, cursor.y)
            origin = NSPoint(x: centerX - tooltipSize.width / 2, y: edgeY - tooltipSize.height - gap + pad)
        case .leading:
            // Right edge of visible tooltip sits to the left of the anchor
            let edgeX = clamped(rect.minX, cursor.x - edgeCap, cursor.x)
            origin = NSPoint(x: edgeX - tooltipSize.width - gap + pad, y: centerY - tooltipSize.height / 2)
        case .trailing:
            // Left edge of visible tooltip sits to the right of the anchor
            let edgeX = clamped(rect.maxX, cursor.x, cursor.x + edgeCap)
            origin = NSPoint(x: edgeX + gap - pad, y: centerY - tooltipSize.height / 2)
        }

        // Keep the tooltip on the anchor's screen — NSScreen.main is the key
        // window's screen, which isn't necessarily where the anchor lives.
        if let screen = hostWindow.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let inset = TooltipMetrics.screenInset

            // Adjust horizontal position
            if origin.x < screenFrame.minX {
                origin.x = screenFrame.minX + inset
            } else if origin.x + tooltipSize.width > screenFrame.maxX {
                origin.x = screenFrame.maxX - tooltipSize.width - inset
            }

            // Adjust vertical position
            if origin.y < screenFrame.minY {
                origin.y = screenFrame.minY + inset
            } else if origin.y + tooltipSize.height > screenFrame.maxY {
                origin.y = screenFrame.maxY - tooltipSize.height - inset
            }
        }

        window.setFrameOrigin(origin)

        // The scale + opacity spring animation lives inside TooltipContentView so it
        // can be anchored to the edge nearest the source view. The window itself is
        // shown at full opacity.
        window.alphaValue = 1
        window.orderFront(nil)

        self.tooltipWindow = window
        self.hostingView = hostingView
        startAnchorWatch(anchorView: anchorView, rawAnchorRect: anchorRect)
    }

    // MARK: Anchor watchdog

    /// Begin re-validating the visible tooltip against its anchor. The stored
    /// rect is the RAW (unclamped) anchor frame — movement is applied as a pure
    /// translation of the tooltip window, so whatever clamped relationship
    /// `show()` computed is preserved while the target drifts.
    private func startAnchorWatch(anchorView: NSView, rawAnchorRect: NSRect) {
        trackedAnchorView = anchorView
        trackedAnchorRect = rawAnchorRect
        anchorWatchTimer?.invalidate()
        let timer = Timer(timeInterval: TooltipMetrics.anchorWatchInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.anchorWatchTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        anchorWatchTimer = timer
    }

    private func stopAnchorWatch() {
        anchorWatchTimer?.invalidate()
        anchorWatchTimer = nil
        trackedAnchorView = nil
    }

    private func anchorWatchTick() {
        guard let window = tooltipWindow else {
            stopAnchorWatch()
            return
        }
        // Anchor deallocated, detached, or its window hidden — nothing to point
        // at anymore.
        guard let anchor = trackedAnchorView,
              let host = anchor.window, host.isVisible else {
            hide(animated: false)
            return
        }
        let raw = host.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        guard raw.width > 0, raw.height > 0 else {
            hide(animated: false)
            return
        }

        // Non-interactive tooltips die the moment the cursor is no longer over
        // the target — catches missed hover-exits and content that reflowed out
        // from under the cursor. Interactive tooltips own their dismissal via
        // the hover-grace machinery (the cursor is allowed to be on the tooltip
        // itself), and a pinned one its binding, so only the movement/death
        // checks apply to them.
        if !interactiveTooltip && !pinnedTooltip {
            let cursor = NSEvent.mouseLocation
            let tolerance = TooltipMetrics.cursorTolerance
            if !raw.insetBy(dx: -tolerance, dy: -tolerance).contains(cursor) {
                hide()
                return
            }
        }

        // Target moved (animated layout, programmatic scroll, window drag) —
        // carry the tooltip along by the same delta.
        if raw.origin != trackedAnchorRect.origin {
            let dx = raw.minX - trackedAnchorRect.minX
            let dy = raw.minY - trackedAnchorRect.minY
            window.setFrameOrigin(NSPoint(
                x: window.frame.origin.x + dx,
                y: window.frame.origin.y + dy
            ))
        }
        trackedAnchorRect = raw
    }

    /// Queue a grace-period dismissal. Used by interactive tooltips on hover-out
    /// so the cursor can cross the small gap between the source and the tooltip
    /// (or between action buttons) without it vanishing. Cancelled if the cursor
    /// re-enters the source or the tooltip within the grace window.
    func scheduleHide(grace: TimeInterval = TooltipMetrics.hideGrace) {
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + grace, execute: work)
    }

    func cancelScheduledHide() {
        pendingHide?.cancel()
        pendingHide = nil
    }

    func hide(animated: Bool = true) {
        // Cancel any pending delayed show first — even if no tooltip is on
        // screen right now, hide() should kill a queued one (e.g., user moves
        // off the target before the 500ms delay fires).
        cancelPendingShow()
        cancelScheduledHide()
        stopAnchorWatch()
        interactiveTooltip = false
        pinnedTooltip = false

        guard let window = tooltipWindow else { return }

        // Clear the singleton reference synchronously so any subsequent show()
        // can create a fresh tooltip without the async fade-out completion
        // wiping out the new window's reference.
        tooltipWindow = nil
        hostingView = nil
        // Stamp the dismissal so the next hover within `groupGrace` skips the
        // initial delay and animation.
        lastDismissedAt = Date()

        if !animated {
            window.orderOut(nil)
            return
        }

        // The menus' close (`Animations.menuClose`), so tooltips and menus
        // leave alike. The panel is AppKit's: it fades on the token's curve.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = MenuCloseCurve.duration
            context.timingFunction = MenuCloseCurve.timingFunction
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        })
    }
}

/// `Animations.menuClose` for an AppKit animation group — the token is a
/// SwiftUI `Animation`, which can't drive `NSAnimationContext`.
enum MenuCloseCurve {
    static let duration: TimeInterval = 0.12
    static var timingFunction: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1) }
}

// MARK: - Tooltip Content View

private struct TooltipContentView<Content: View>: View {
    let content: Content
    let configuration: TooltipConfiguration
    let position: TooltipPosition
    let animated: Bool
    /// Set for interactive tooltips: reports hover over the whole tooltip window
    /// (including its transparent shadow padding) so the controller can keep it
    /// open while the cursor is on it.
    let onHoverChange: ((Bool) -> Void)?

    @State private var contentHeight: CGFloat = 0
    /// Starts true when `animated == false` so the first render lands at full
    /// scale/opacity with no transition (used for instant mid-session swaps).
    @State private var isAppeared: Bool

    init(
        content: Content,
        configuration: TooltipConfiguration,
        position: TooltipPosition,
        animated: Bool,
        onHoverChange: ((Bool) -> Void)? = nil
    ) {
        self.content = content
        self.configuration = configuration
        self.position = position
        self.animated = animated
        self.onHoverChange = onHoverChange
        self._isAppeared = State(initialValue: !animated)
    }

    private var needsScrolling: Bool {
        contentHeight > configuration.maxHeight
    }

    /// Scale outward from the edge nearest the source view so the tooltip looks
    /// like it's popping out from its anchor.
    private var scaleAnchor: UnitPoint {
        switch position {
        case .above: return .bottom
        case .below: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }

    var body: some View {
        Group {
            if needsScrolling {
                ScrollView(.vertical, showsIndicators: true) {
                    content
                        .frame(maxWidth: configuration.maxWidth, alignment: .leading)
                }
                .frame(width: configuration.maxWidth)
                .frame(maxHeight: configuration.maxHeight)
            } else {
                // WRAP at maxWidth, don't truncate: `fixedSize(horizontal: true)`
                // laid text out at its single-line ideal width and the frame cap
                // then ellipsized it. Vertical fixedSize keeps the wrapped height
                // honest; short text still hugs (the panel measures fittingSize,
                // where `.frame(maxWidth:)` reports the content's ideal width).
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: configuration.maxWidth, alignment: .leading)
            }
        }
        .font(Typography.captionSmall)
        // Its own window, so it doesn't inherit the app's text color: take the
        // theme's here.
        .foregroundStyle(Color.textPrimary)
        .textSelection(.enabled)
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, configuration.verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(PanelSurface.fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .elevation(.panel)
        .background {
            // Measure actual content height (same layout as the visible copy)
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: configuration.maxWidth, alignment: .leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ContentHeightPreferenceKey.self, value: geometry.size.height)
                    }
                )
                .hidden()
        }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            contentHeight = height
        }
        // Apply scale+opacity to the visible tooltip card (anchor refers to the
        // card's edges, not the padded area), THEN add transparent shadow padding.
        // From the menus' entrance scale on their open curve, so a tooltip and
        // a menu arrive the same way (0.85 popped harder than anything beside it).
        .scaleEffect(isAppeared || prefersReducedMotion ? 1.0 : MenuPresentationMotion.entranceScale, anchor: scaleAnchor)
        .opacity(isAppeared ? 1.0 : 0.0)
        .padding(PanelMetrics.shadowInset)
        // Track hover across the entire window (incl. the transparent shadow
        // padding) so moving the cursor onto the tooltip keeps it open. No-op
        // for non-interactive tooltips (callback nil + window ignores mouse).
        .contentShape(Rectangle())
        .onHover { onHoverChange?($0) }
        .onAppear {
            guard animated, !isAppeared else { return }
            withAnimation(Animations.menuOpen) {
                isAppeared = true
            }
        }
    }
}

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier<TooltipContent: View>: ViewModifier {
    let tooltipContent: () -> TooltipContent
    let configuration: TooltipConfiguration
    let position: TooltipPosition

    @Environment(\.tooltipsDisabled) private var tooltipsDisabled
    @State private var isHovering = false

    init(
        configuration: TooltipConfiguration = .default,
        position: TooltipPosition = .above,
        @ViewBuilder tooltipContent: @escaping () -> TooltipContent
    ) {
        self.configuration = configuration
        self.position = position
        self.tooltipContent = tooltipContent
    }

    func body(content: Content) -> some View {
        content
            .background(
                TooltipAnchorView(
                    isHovering: $isHovering,
                    position: position,
                    configuration: configuration,
                    tooltipContent: tooltipContent
                )
            )
            .onHover { hovering in
                // Don't show tooltips if disabled
                guard !tooltipsDisabled else {
                    isHovering = false
                    TooltipWindowController.shared.hide()
                    return
                }

                if hovering {
                    isHovering = true
                } else {
                    isHovering = false
                    // Interactive tooltips get a grace period so the cursor can
                    // travel from the source onto the tooltip itself; entering
                    // the tooltip cancels the dismissal.
                    if configuration.interactive {
                        TooltipWindowController.shared.scheduleHide()
                    } else {
                        TooltipWindowController.shared.hide()
                    }
                }
            }
            .onChange(of: tooltipsDisabled) { _, disabled in
                if disabled {
                    isHovering = false
                    TooltipWindowController.shared.hide()
                }
            }
            .onDisappear {
                isHovering = false
                TooltipWindowController.shared.hide()
            }
    }
}

/// NSViewRepresentable that gets the actual screen coordinates for tooltip positioning
private struct TooltipAnchorView<TooltipContent: View>: NSViewRepresentable {
    @Binding var isHovering: Bool
    let position: TooltipPosition
    let configuration: TooltipConfiguration
    let tooltipContent: () -> TooltipContent

    /// Tracks the previous hover state so show() is only called on the
    /// false→true transition, not on every SwiftUI re-render while hovering.
    /// Without this, clicking a button (which causes a re-render) would
    /// immediately re-show the tooltip that hide() just dismissed.
    ///
    /// `final` + explicit empty `deinit` — workaround for a Swift 6.2.4
    /// release-optimizer crash in `EarlyPerfInliner` while attempting to
    /// inline this type's implicit deinit on the macOS 26 SDK. Providing
    /// an explicit deinit (even an empty one) gives the optimizer a
    /// concrete function body to operate on and avoids the crash.
    final class Coordinator {
        var wasHovering = false
        deinit {}
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let justStartedHovering = isHovering && !context.coordinator.wasHovering
        context.coordinator.wasHovering = isHovering

        guard justStartedHovering else { return }
        guard nsView.window != nil else { return }

        // requestShow handles the delay-vs-instant decision based on whether
        // we're inside an active tooltip session (see `groupActive` on the
        // controller). The controller re-resolves this view's frame at
        // presentation time — passing the view, not a point, is what keeps
        // tooltips glued to targets that move between hover and show.
        TooltipWindowController.shared.requestShow(
            content: tooltipContent(),
            configuration: configuration,
            anchoredTo: nsView,
            position: position,
            colorScheme: context.environment.colorScheme
        )
    }
}

// MARK: - Interactive Tooltip Actions

/// A small action surfaced inside an interactive tooltip (e.g. "Copy").
public struct TooltipAction: Identifiable {
    public let id = UUID()
    /// SF Symbol name.
    public let icon: String
    public let label: String
    /// Optional transient confirmation shown after tapping (e.g. "Copied"),
    /// briefly swapping the icon for a checkmark.
    public var confirmation: String? = nil
    public let action: () -> Void

    public init(icon: String, label: String, confirmation: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.confirmation = confirmation
        self.action = action
    }

    /// Convenience for the common "copy this string" action.
    public static func copy(_ string: String, label: String = String(localized: "Copy", bundle: .blissUI)) -> TooltipAction {
        TooltipAction(icon: "doc.on.doc", label: label, confirmation: String(localized: "Copied", bundle: .module)) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }
}

/// Pill button used inside interactive tooltips. Plain styling that reads well
/// over the tooltip's material background, with optional tap confirmation.
private struct TooltipActionButton: View {
    let action: TooltipAction
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            action.action()
            guard action.confirmation != nil else { return }
            withAnimation(Animations.feedback) { confirmed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + TooltipMetrics.confirmationDuration) {
                withAnimation(Animations.feedback) { confirmed = false }
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: confirmed ? "checkmark" : action.icon)
                Text(confirmed ? (action.confirmation ?? action.label) : action.label)
            }
            .font(Typography.labelSmall)
            .foregroundStyle(confirmed ? Success.success500 : Color.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .fill(isHovered ? RowTint.hover(colorScheme) : Color.restingFill)
            }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous))
        }
        // The tooltip's panel never takes key focus, so a Tab stop here could
        // never be reached.
        .buttonStyle(.plain)
        .interactiveCursor()
        .onHover { isHovered = $0 }
    }
}

/// Default content for an interactive tooltip: optional text above a row of
/// action buttons.
private struct InteractiveTooltipBody: View {
    let text: String?
    let actions: [TooltipAction]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let text, !text.isEmpty {
                Text(text)
                    .font(Typography.captionSmall)
                    .textSelection(.enabled)
            }

            if !actions.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(actions) { TooltipActionButton(action: $0) }
                }
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a tooltip with custom content
    /// - Parameters:
    ///   - configuration: Tooltip sizing configuration (optional)
    ///   - position: Where to position the tooltip relative to the element (default: above)
    ///   - content: ViewBuilder closure providing tooltip content
    public func tooltip<T: View>(
        configuration: TooltipConfiguration = .default,
        position: TooltipPosition = .above,
        @ViewBuilder _ content: @escaping () -> T
    ) -> some View {
        modifier(TooltipModifier(configuration: configuration, position: position, tooltipContent: content))
    }

    /// Adds a simple text tooltip
    /// - Parameters:
    ///   - text: The tooltip text
    ///   - position: Where to position the tooltip relative to the element (default: above)
    ///   - maxWidth: Maximum width before text wraps (default: `TooltipMetrics.maxWidth`)
    public func tooltip(_ text: LocalizedStringKey, position: TooltipPosition = .above, maxWidth: CGFloat = TooltipMetrics.maxWidth) -> some View {
        tooltip(configuration: TooltipConfiguration(maxWidth: maxWidth), position: position) {
            Text(text)
        }
    }

    /// A text tooltip with the control's shortcut after it, as a key pill:
    /// "Hide Sidebar ⌃⌘S".
    /// - Parameters:
    ///   - text: The tooltip text.
    ///   - shortcut: The key, as the user reads it ("⌃⌘S").
    ///   - position: Which side of the view the tooltip sits on.
    public func tooltip(_ text: LocalizedStringKey, shortcut: String, position: TooltipPosition = .above) -> some View {
        tooltip(configuration: .default, position: position) {
            HStack(spacing: Spacing.xs) {
                Text(text)
                ShortcutKey(shortcut, compact: true)
            }
        }
    }

    /// A two-line tooltip: a title over a secondary detail (a file's name over
    /// its size and date).
    /// - Parameters:
    ///   - title: The first line.
    ///   - detail: The second line, in the secondary color.
    ///   - position: Which side of the view the tooltip sits on.
    public func tooltip(_ title: LocalizedStringKey, detail: LocalizedStringKey, position: TooltipPosition = .above) -> some View {
        tooltip(configuration: .default, position: position) {
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(Typography.captionSmallSemibold)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A tooltip shown by code rather than hover — a "Copied" confirmation on
    /// the button that copied. It stays while `isPresented` is true, wherever
    /// the pointer is; a click anywhere or `isPresented` dropping hides it.
    /// - Parameters:
    ///   - text: The tooltip text.
    ///   - isPresented: Whether the tooltip is up.
    ///   - position: Which side of the view the tooltip sits on.
    public func tooltip(_ text: LocalizedStringKey, isPresented: Binding<Bool>, position: TooltipPosition = .above) -> some View {
        modifier(PinnedTooltipModifier(isPresented: isPresented, position: position) { Text(text) })
    }

    /// Adds an interactive tooltip with custom content. Unlike the standard
    /// tooltip, this one stays open while the cursor is over it, so it can host
    /// clickable controls. Build the content with buttons as needed.
    public func interactiveTooltip<T: View>(
        configuration: TooltipConfiguration = .default,
        position: TooltipPosition = .above,
        @ViewBuilder _ content: @escaping () -> T
    ) -> some View {
        var config = configuration
        config.interactive = true
        return modifier(TooltipModifier(configuration: config, position: position, tooltipContent: content))
    }

    /// Adds an interactive tooltip showing optional text plus a row of action
    /// buttons (e.g. a copy button). Hovering the tooltip keeps it open so the
    /// buttons are clickable.
    public func tooltip(
        _ text: String?,
        position: TooltipPosition = .above,
        maxWidth: CGFloat = TooltipMetrics.wideMaxWidth,
        actions: [TooltipAction]
    ) -> some View {
        interactiveTooltip(
            configuration: TooltipConfiguration(maxWidth: maxWidth),
            position: position
        ) {
            InteractiveTooltipBody(text: text, actions: actions)
        }
    }
}

// MARK: - Pinned tooltip

/// `.tooltip(_:isPresented:)`: shows the tooltip through the controller when the
/// binding turns on and hides it when it turns off.
private struct PinnedTooltipModifier<TooltipContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let position: TooltipPosition
    @ViewBuilder let tooltipContent: () -> TooltipContent

    func body(content: Content) -> some View {
        content
            .background(PinnedTooltipAnchorView(isPresented: isPresented, position: position, tooltipContent: tooltipContent))
            .onChange(of: isPresented) { _, presented in
                if !presented { TooltipWindowController.shared.hide() }
            }
            .onDisappear { if isPresented { TooltipWindowController.shared.hide() } }
    }
}

private struct PinnedTooltipAnchorView<TooltipContent: View>: NSViewRepresentable {
    let isPresented: Bool
    let position: TooltipPosition
    let tooltipContent: () -> TooltipContent

    final class Coordinator {
        var wasPresented = false
        deinit {}
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let justPresented = isPresented && !context.coordinator.wasPresented
        context.coordinator.wasPresented = isPresented
        guard justPresented, nsView.window != nil else { return }
        let colorScheme = context.environment.colorScheme
        // The first pass can land before the view is in the window's layout.
        DispatchQueue.main.async {
            TooltipWindowController.shared.show(
                content: tooltipContent(),
                configuration: .default,
                anchoredTo: nsView,
                position: position,
                colorScheme: colorScheme,
                animated: true,
                pinned: true
            )
        }
    }
}

// MARK: - Previews

#Preview("Basic Tooltips", traits: .fixedLayout(width: 420, height: 320)) {
    VStack(spacing: Spacing.xxl) {
        Button("Hover me") {}
            .buttonStyle(SecondaryButtonStyle(compact: true))
            .tooltip("This is a tooltip")

        Button {} label: { Image(systemName: "gear") }
            .buttonStyle(ToolbarIconButtonStyle())
            .tooltip("Settings", shortcut: "⌘,")

        Text("Quarterly Report.pdf")
            .font(Typography.bodySmallSemibold)
            .tooltip("Quarterly Report.pdf", detail: "PDF document · 2.4 MB · Modified today")
    }
    .padding(Spacing.xxxxxl)
}

#Preview("Long Text Tooltip", traits: .fixedLayout(width: 420, height: 320)) {
    VStack(spacing: Spacing.xxl) {
        Text("Short text")
            .tooltip("Brief tip")

        Text("Medium text")
            .tooltip("This tooltip has medium-length text that should wrap nicely within the max width constraint without causing any overflow issues.")

        Text("Long text (scrollable)")
            .tooltip(configuration: .default) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Extended Information")
                        .font(Typography.captionSmallSemibold)
                    Text("""
                    This is a very long tooltip that contains multiple paragraphs of text. \
                    It demonstrates how the tooltip handles overflow content by enabling scrolling.

                    When content exceeds the maxHeight, a ScrollView is automatically enabled \
                    so users can read all the information without the tooltip becoming too tall.

                    This behavior ensures tooltips remain usable and don't obscure too much of \
                    the underlying interface while still providing complete information.

                    The scrollbar indicator appears when needed, providing a visual cue that \
                    there's more content below.
                    """)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
    }
    .padding(Spacing.xxxxxl)
}

#Preview("Configuration Variants", traits: .fixedLayout(width: 520, height: 240)) {
    HStack(spacing: Spacing.xxxl) {
        Text("Compact")
            .tooltip(configuration: .compact) {
                Text("Compact tooltip with limited width")
            }

        Text("Default")
            .tooltip(configuration: .default) {
                Text("Default tooltip sizing")
            }

        Text("Wide")
            .tooltip(configuration: .wide) {
                Text("Wide tooltip allows for more content horizontally before wrapping occurs")
            }
    }
    .padding(Spacing.xxxxxl)
}
