//
//  Tooltip.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/4/25.
//

import AppKit
import SwiftUI

// MARK: - Environment Key for Disabling Tooltips

private struct TooltipsDisabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether `.tooltip` modifiers in this subtree stay quiet (see `tooltipsDisabled(_:)`).
    public var tooltipsDisabled: Bool {
        get { self[TooltipsDisabledKey.self] }
        set { self[TooltipsDisabledKey.self] = newValue }
    }
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

// MARK: - Tooltip Configuration

/// Configuration options for tooltip sizing behavior
public nonisolated struct TooltipConfiguration: Equatable, Sendable {
    /// Maximum width of the tooltip content
    public var maxWidth: CGFloat = 250
    /// Maximum height before scrolling is enabled
    public var maxHeight: CGFloat = 200
    /// Horizontal padding inside the tooltip
    public var horizontalPadding: CGFloat = 12
    /// Vertical padding inside the tooltip
    public var verticalPadding: CGFloat = 10
    /// When true, the tooltip accepts mouse interaction: hovering it keeps it
    /// open (so the cursor can travel from the source into the tooltip), and
    /// it can host clickable action buttons. Default tooltips stay click-through.
    public var interactive: Bool = false

    public init(
        maxWidth: CGFloat = 250,
        maxHeight: CGFloat = 200,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 10,
        interactive: Bool = false
    ) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.interactive = interactive
    }

    // Every preset uses the tight (10h/5v) padding — tooltips read compact by
    // default; the presets differ only in width envelope.
    public static let `default` = TooltipConfiguration(horizontalPadding: 10, verticalPadding: 5)
    public static let compact = TooltipConfiguration(maxWidth: 180, maxHeight: 120, horizontalPadding: 10, verticalPadding: 5)
    public static let wide = TooltipConfiguration(maxWidth: 320, maxHeight: 250, horizontalPadding: 10, verticalPadding: 5)
    /// Tight single-line tooltip for icon buttons (sidebar rows, toolbar items).
    public static let iconHint = TooltipConfiguration(
        maxWidth: 200,
        maxHeight: 44,
        horizontalPadding: 10,
        verticalPadding: 5
    )
}

// MARK: - Tooltip Window Controller

/// Manages a floating tooltip window that appears above all content
final class TooltipWindowController: NSObject {
    static let shared = TooltipWindowController()

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

    /// Delay before the first tooltip in a session appears. Prevents accidental
    /// activation when the cursor merely passes over a target.
    private let initialDelay: TimeInterval = 0.5
    /// Window of time after a tooltip closes during which subsequent tooltips
    /// appear instantly with no fade-in. Lets users sweep across icon rows
    /// without the cumulative half-second penalty per icon.
    private let groupGrace: TimeInterval = 0.4

    /// True while a tooltip is on-screen OR within `groupGrace` of the last
    /// dismissal. Callers use this to decide whether to delay/animate.
    private var groupActive: Bool {
        if tooltipWindow != nil { return true }
        if let last = lastDismissedAt {
            return Date().timeIntervalSince(last) < groupGrace
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
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hide()
        }

        // Also monitor local mouse events within our app. Scrolling dismisses
        // too — the content under the tooltip is about to move, which is how
        // tooltips end up floating detached from their target.
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { [weak self] event in
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

        // First tooltip in a session — delay to filter out cursor sweeps.
        let workItem = DispatchWorkItem { [weak self, weak anchorView] in
            guard let self, let anchorView else { return }
            self.show(content: content, configuration: configuration, anchoredTo: anchorView, position: position, colorScheme: colorScheme, animated: true)
        }
        pendingShow = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay, execute: workItem)
    }

    func cancelPendingShow() {
        pendingShow?.cancel()
        pendingShow = nil
    }

    func show<Content: View>(
        content: Content,
        configuration: TooltipConfiguration,
        anchoredTo anchorView: NSView,
        position: TooltipPosition,
        colorScheme: ColorScheme,
        animated: Bool = true
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
        // isn't pointing at.
        let cursor = NSEvent.mouseLocation
        guard anchorRect.insetBy(dx: -4, dy: -4).contains(cursor) else { return }

        // Replacing an existing tooltip: drop it instantly. Fading the old one
        // while the new one pops in looks janky during group-active swaps.
        hide(animated: false)

        interactiveTooltip = configuration.interactive

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
        // `tooltipShadowPadding` so the visible content still lands at the
        // intended offset from the anchor. (Must be the cached measurement —
        // `fittingSize` is dead after the `sizingOptions` clear above.)
        let tooltipSize = measuredSize
        let pad = tooltipShadowPadding

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
        let controlLimit: CGFloat = 72
        let edgeSlack: CGFloat = 48
        let cursorBox: CGFloat = 24
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
        let edgeCap: CGFloat = 24
        func clamped(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            min(max(value, lower), upper)
        }
        // The centering axis gets a looser sanity band — being centered a bit
        // off reads fine; being centered 50+pt off does not.
        let centerCap: CGFloat = 48
        let centerX = clamped(rect.midX, cursor.x - centerCap, cursor.x + centerCap)
        let centerY = clamped(rect.midY, cursor.y - centerCap, cursor.y + centerCap)

        var origin: NSPoint
        switch position {
        case .above:
            // Anchor's top edge: at or above the cursor, within reach.
            let edgeY = clamped(rect.maxY, cursor.y, cursor.y + edgeCap)
            origin = NSPoint(x: centerX - tooltipSize.width / 2, y: edgeY + 8 - pad)
        case .below:
            // Anchor's bottom edge: at or below the cursor, within reach.
            let edgeY = clamped(rect.minY, cursor.y - edgeCap, cursor.y)
            origin = NSPoint(x: centerX - tooltipSize.width / 2, y: edgeY - tooltipSize.height - 8 + pad)
        case .leading:
            // Right edge of visible tooltip sits to the left of the anchor
            let edgeX = clamped(rect.minX, cursor.x - edgeCap, cursor.x)
            origin = NSPoint(x: edgeX - tooltipSize.width - 8 + pad, y: centerY - tooltipSize.height / 2)
        case .trailing:
            // Left edge of visible tooltip sits to the right of the anchor
            let edgeX = clamped(rect.maxX, cursor.x, cursor.x + edgeCap)
            origin = NSPoint(x: edgeX + 8 - pad, y: centerY - tooltipSize.height / 2)
        }

        // Keep the tooltip on the anchor's screen — NSScreen.main is the key
        // window's screen, which isn't necessarily where the anchor lives.
        if let screen = hostWindow.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame

            // Adjust horizontal position
            if origin.x < screenFrame.minX {
                origin.x = screenFrame.minX + 4
            } else if origin.x + tooltipSize.width > screenFrame.maxX {
                origin.x = screenFrame.maxX - tooltipSize.width - 4
            }

            // Adjust vertical position
            if origin.y < screenFrame.minY {
                origin.y = screenFrame.minY + 4
            } else if origin.y + tooltipSize.height > screenFrame.maxY {
                origin.y = screenFrame.maxY - tooltipSize.height - 4
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
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
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
        // itself), so only the movement/death checks apply to them.
        if !interactiveTooltip {
            let cursor = NSEvent.mouseLocation
            if !raw.insetBy(dx: -4, dy: -4).contains(cursor) {
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
    func scheduleHide(grace: TimeInterval = 0.25) {
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

        // The menus' close (`Animations.menuClose`): the same strong ease-out
        // curve and 0.12s, so tooltips and menus leave alike.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        })
    }
}

// MARK: - Tooltip Content View

/// Transparent padding around the tooltip content so the drop-shadow has room
/// to render outside the rounded-rect bounds without being clipped by the
/// NSHostingView / NSPanel frame. Positioning math in `TooltipWindowController`
/// subtracts this value so the visible content still appears where expected.
let tooltipShadowPadding: CGFloat = 16

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
        .textSelection(.enabled)
        .padding(.horizontal, configuration.horizontalPadding)
        .padding(.vertical, configuration.verticalPadding)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 0.5)
        }
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
        // From 0.96 on the menus' open curve, so a tooltip and a menu arrive
        // the same way (0.85 popped harder than anything beside it).
        .scaleEffect(isAppeared || prefersReducedMotion ? 1.0 : 0.96, anchor: scaleAnchor)
        .opacity(isAppeared ? 1.0 : 0.0)
        .padding(tooltipShadowPadding)
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
    public static func copy(_ string: String, label: String = String(localized: "Copy")) -> TooltipAction {
        TooltipAction(icon: "doc.on.doc", label: label, confirmation: String(localized: "Copied")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }
}

/// Pill button used inside interactive tooltips. Plain styling that reads well
/// over the tooltip's material background, with optional tap confirmation.
private struct TooltipActionButton: View {
    let action: TooltipAction
    @State private var confirmed = false
    @State private var isHovered = false

    var body: some View {
        Button {
            action.action()
            guard action.confirmation != nil else { return }
            withAnimation(Animations.feedback) { confirmed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(Animations.feedback) { confirmed = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: confirmed ? "checkmark" : action.icon)
                Text(confirmed ? (action.confirmation ?? action.label) : action.label)
            }
            .font(Typography.labelSmall)
            .foregroundStyle(confirmed ? Success.success500 : Color.primary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.12 : 0.06))
            }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous))
        }
        // The tooltip's panel never takes key focus, so a Tab stop here could
        // never be reached.
        .buttonStyle(.plain)
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
    ///   - maxWidth: Maximum width before text wraps (default: 250)
    public func tooltip(_ text: LocalizedStringKey, position: TooltipPosition = .above, maxWidth: CGFloat = 250) -> some View {
        tooltip(configuration: TooltipConfiguration(maxWidth: maxWidth), position: position) {
            Text(text)
        }
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
        maxWidth: CGFloat = 320,
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

// MARK: - Previews

#Preview("Basic Tooltips") {
    VStack(spacing: 40) {
        Button("Hover me") {}
            .tooltip("This is a tooltip")

        Image(systemName: "gear")
            .font(.title)
            .tooltip("Settings")

        Text("Quarterly Report.pdf")
            .font(.headline)
            .tooltip {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quarterly Report.pdf")
                        .font(.caption).bold()
                    Text("PDF document - 2.4 MB - Modified today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }
    .padding(100)
}

#Preview("Long Text Tooltip") {
    VStack(spacing: 40) {
        Text("Short text")
            .tooltip("Brief tip")

        Text("Medium text")
            .tooltip("This tooltip has medium-length text that should wrap nicely within the max width constraint without causing any overflow issues.")

        Text("Long text (scrollable)")
            .tooltip(configuration: .default) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extended Information")
                        .font(.caption).bold()
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }
    .padding(100)
}

#Preview("Configuration Variants") {
    HStack(spacing: 60) {
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
    .padding(100)
}
