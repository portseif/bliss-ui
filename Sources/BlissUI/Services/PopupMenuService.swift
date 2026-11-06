//
//  PopupMenuService.swift
//  BlissUI
//
//  Singleton that shows custom popup menus at arbitrary screen points.
//  Used for right-click / context menus where:
//    1. The menu must appear at the cursor location.
//    2. Only one menu can be visible at a time (showing a new one closes
//       any previous one).
//
//  Pairs with `.onSecondaryClick` for the right-click trigger, and with the
//  `QuickActionMenuItem` / `QuickActionFlyoutRow` rows, which pick up the
//  popup's arrow-key navigation on their own.
//

import AppKit
import SwiftUI

@MainActor
public final class PopupMenuService {
    public static let shared = PopupMenuService()

    private var panel: NSPanel?
    /// Drives the open panel's exit (`MenuPresentationMotion`).
    private var animationState: MenuAnimationState?
    private var dismissMonitor: Any?
    private var escapeMonitor: Any?
    /// Keeps the window under the popup from scrolling while it's open (`MenuScrollLock`).
    private var scrollLockMonitor: Any?
    /// The open popup's arrow-key navigation.
    private var navigator: PopupMenuNavigator?
    private var resignActiveObserver: NSObjectProtocol?
    /// Padding inside the hosting view to allow the drop shadow to render.
    private let shadowPadding: CGFloat = 32

    private init() {}

    /// Show the supplied content as a popup positioned with its top-left
    /// (visible) corner at `screenPoint` (in screen coordinates). Closes any
    /// existing popup first.
    public func show<Content: View>(at screenPoint: NSPoint, @ViewBuilder content: () -> Content) {
        hide()

        let animationState = MenuAnimationState()
        self.animationState = animationState
        let navigator = PopupMenuNavigator()
        self.navigator = navigator
        let wrapped = AnyView(
            content()
                .environment(navigator)
                .modifier(PopupChrome(
                    shadowPadding: shadowPadding,
                    animationState: animationState,
                    // Right-clicking the next row right after the last menu went
                    // appears at once (see `MenuMotion.opensInstantly`).
                    animatesIn: !MenuMotion.opensInstantly
                ))
        )

        let hostingView = NSHostingView(rootView: wrapped)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // shadow is drawn inside the SwiftUI chrome
        // Top-most within the app, not the whole system: a child of the window
        // it opened over, at that window's level (`.floating` put it over other
        // apps' windows too). Its fly-out submenus hang off it the same way.
        let parentWindow = Self.window(under: screenPoint) ?? NSApp.keyWindow ?? NSApp.mainWindow
        panel.level = parentWindow?.level ?? .normal
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.transient, .ignoresCycle]
        // Detached panels don't inherit the app's overridden color scheme, so
        // stamp the resolved appearance — otherwise the material renders in the
        // system appearance (e.g. dark while the app is forced light).
        panel.appearance = Self.resolvedAppearance()

        // NSPanel uses bottom-left origin; we want the visible top-left of
        // the menu (after stripping shadow padding) to land at screenPoint.
        let panelOrigin = NSPoint(
            x: screenPoint.x - shadowPadding,
            y: screenPoint.y - hostingView.fittingSize.height + shadowPadding
        )
        panel.setFrameOrigin(panelOrigin)
        clampToScreen(panel: panel, near: screenPoint)
        parentWindow?.addChildWindow(panel, ordered: .above)
        // A borderless non-activating panel can't become key; keys reach it
        // through the local monitor below.
        panel.orderFront(nil)

        self.panel = panel
        installDismissMonitor()
        installEscapeMonitor()
        if let parentWindow { scrollLockMonitor = MenuScrollLock.install(over: parentWindow) }
        // Switching apps closes it for good: `hidesOnDeactivate` alone only hides
        // the panel, so it came back on return and the click that brought
        // the app back was swallowed as a dismiss.
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { PopupMenuService.shared.hide() }
        }
    }

    /// The frontmost of the app's windows under a right-click — the one clicked,
    /// which isn't always the key window (a right-click doesn't make one key).
    private static func window(under screenPoint: NSPoint) -> NSWindow? {
        NSApp.orderedWindows.first { window in
            !(window is NSPanel) && window.isVisible && window.frame.contains(screenPoint)
        }
    }

    /// Closes the open popup, if any (it animates out).
    public func hide() {
        // Clear the stored panel synchronously and animate a captured local, so a
        // `show()` right after this (right-clicking another row) can't have its
        // new panel torn down by this one's fade completing.
        removeDismissMonitor()
        guard let panel else { return }
        let animationState = self.animationState
        self.panel = nil
        self.animationState = nil
        navigator = nil
        MenuMotion.noteClosing()

        // Runs from the close animation's completion and from the fallback below;
        // whichever is first takes the panel down. Clearing the completion and the
        // content breaks the cycle (panel → hosting view → animation state →
        // completion → panel) that kept every closed popup alive.
        func remove() {
            animationState?.onCloseAnimationComplete = nil
            guard panel.contentView != nil else { return }
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.contentView = nil
        }
        guard let animationState else {
            remove()
            return
        }
        animationState.onCloseAnimationComplete = { remove() }
        animationState.isClosing = true
        // Fallback in case the completion never fires — just past `menuClose`.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { remove() }
    }

    // MARK: - Helpers

    /// The appearance matching the app's color-scheme override, or nil to
    /// follow the system (which is also what the app shows when set to
    /// "System"). Mirrors what the tooltip + floating-menu panels do.
    private static func resolvedAppearance() -> NSAppearance? {
        let raw = UserDefaults.standard.string(forKey: BlissAppearance.Keys.colorScheme)
        switch ColorSchemeOption(rawValue: raw ?? ColorSchemeOption.system.rawValue) {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }

    /// Keep the panel inside the screen the cursor is on. If the panel would
    /// overflow horizontally or vertically, shift it back into bounds.
    private func clampToScreen(panel: NSPanel, near screenPoint: NSPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) })
                ?? NSScreen.main else { return }

        var frame = panel.frame
        let visible = screen.visibleFrame

        if frame.maxX > visible.maxX {
            frame.origin.x = visible.maxX - frame.width
        }
        if frame.minX < visible.minX {
            frame.origin.x = visible.minX
        }
        if frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }
        if frame.maxY > visible.maxY {
            frame.origin.y = visible.maxY - frame.height
        }
        panel.setFrame(frame, display: false)
    }

    private func installDismissMonitor() {
        // Left-click outside the popup dismisses it AND is consumed (returns nil),
        // so the dismissing click only closes the menu — it does NOT also activate
        // whatever is underneath (e.g. opening the row it landed on). Clicks inside the
        // popup, or inside one of its fly-out submenus (child panels, so their
        // `parent` chain leads back here), pass through so submenu picks still work.
        // Right-clicks are intentionally NOT in the mask — a right-click on another
        // row triggers its SecondaryClickGesture, which replaces this popup.
        dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if let eventWindow = event.window, Self.isPopup(eventWindow, orDescendantOf: panel) {
                return event
            }
            DispatchQueue.main.async { [weak self] in
                self?.hide()
            }
            return nil
        }
    }

    /// Whether `window` is the popup panel or one of its descendant child windows
    /// (its fly-out submenus attach via `addChildWindow`, so their
    /// `parent` chain leads back to the popup panel).
    private static func isPopup(_ window: NSWindow, orDescendantOf root: NSWindow) -> Bool {
        var current: NSWindow? = window
        while let candidate = current {
            if candidate === root { return true }
            current = candidate.parent
        }
        return false
    }

    private func removeDismissMonitor() {
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dismissMonitor = nil
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
        }
        escapeMonitor = nil
        if let monitor = scrollLockMonitor {
            NSEvent.removeMonitor(monitor)
        }
        scrollLockMonitor = nil
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
        resignActiveObserver = nil
    }

    /// A popup opened from the keyboard (⌃Return / ⇧F10) starts on its first
    /// row, so the keys have somewhere to go. Call right after `show` when your
    /// own shortcut opened it (`.onSecondaryClick` already does).
    public func highlightFirstRowForKeyboard() {
        navigator?.focusFirstRowWhenReady()
    }

    /// Esc closes the popup, like the dropdown menus and sheets. Consumed so it
    /// doesn't also dismiss whatever is underneath. The other keys drive the
    /// popup's rows (`PopupMenuNavigator`).
    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.panel != nil else { return event }
            if event.keyCode == 53 {
                self.hide()
                return nil
            }
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let navigator = self.navigator,
                  navigator.handle(event)
            else { return event }
            FocusVisibilityService.shared.noteKeyboardInput()
            return nil
        }
    }
}

// MARK: - Keyboard navigation

/// Arrow-key navigation for a right-click popup and its fly-outs. The popup's
/// rows (`QuickActionMenuItem`, `QuickActionFlyoutRow`) register with the
/// navigator in their environment and report where they sit, so the keys follow
/// the rows on screen: ↓ / Tab and ↑ / Shift-Tab move the highlight, Return or
/// Space runs the row, → (or Return on a fly-out row) opens its submenu and ←
/// leaves it. A fly-out row hands its submenu a navigator of its own; rows
/// outside a popup see none and keep their menu's own keys.
@MainActor
@Observable
final class PopupMenuNavigator {
    struct Row {
        var minY: CGFloat = 0
        let activate: () -> Void
        /// A fly-out row: opens its submenu and returns that submenu's navigator.
        var openSubmenu: (() -> PopupMenuNavigator)? = nil
        var closeSubmenu: (() -> Void)? = nil
    }

    private(set) var focusedRowID: UUID?

    @ObservationIgnored private var rows: [UUID: Row] = [:]
    /// The fly-out the keys are in, and the row that opened it.
    @ObservationIgnored private var openChild: (navigator: PopupMenuNavigator, rowID: UUID)?
    /// For a fly-out's navigator: the popup's, and the row this fly-out hangs
    /// off, so the pointer moving into the fly-out takes the keys with it.
    @ObservationIgnored weak var parent: PopupMenuNavigator?
    @ObservationIgnored var parentRowID: UUID?
    /// Opened from the keyboard: highlight the first row once the rows are in.
    @ObservationIgnored private var focusesFirstRowWhenReady = false

    func register(_ id: UUID, row: Row) {
        rows[id] = row
        guard focusesFirstRowWhenReady else { return }
        focusesFirstRowWhenReady = false
        // The rest of the rows and their positions land in this same pass.
        DispatchQueue.main.async { [weak self] in self?.focusFirstRow() }
    }

    func updatePosition(_ id: UUID, minY: CGFloat) {
        rows[id]?.minY = minY
    }

    func unregister(_ id: UUID) {
        rows[id] = nil
        if focusedRowID == id { focusedRowID = nil }
    }

    /// The pointer moved onto a row: the highlight goes with it (so Return runs
    /// the row under the pointer, and no second row stays lit), a fly-out the
    /// keys opened elsewhere is no longer where they are, and inside a fly-out
    /// the keys follow the pointer in. The ring waits for the next key press.
    func notePointerHover(_ id: UUID) {
        focusedRowID = id
        if let openChild, openChild.rowID != id { self.openChild = nil }
        if let parent, let parentRowID { parent.adoptOpenChild(self, rowID: parentRowID) }
        FocusVisibilityService.shared.notePointerInput()
    }

    /// A fly-out closed some other way (Esc in it, the pointer): the keys come
    /// back to this menu.
    func submenuDidClose(_ rowID: UUID) {
        if openChild?.rowID == rowID { openChild = nil }
    }

    private func adoptOpenChild(_ child: PopupMenuNavigator, rowID: UUID) {
        openChild = (child, rowID)
        focusedRowID = rowID
    }

    /// Handles a key press; false lets it through.
    func handle(_ event: NSEvent) -> Bool {
        if let openChild {
            if event.keyCode == 123 {  // ← leaves the fly-out
                rows[openChild.rowID]?.closeSubmenu?()
                self.openChild = nil
                return true
            }
            return openChild.navigator.handle(event)
        }
        let isTab = event.keyCode == 48
        let isShiftTab = isTab && event.modifierFlags.contains(.shift)
        if event.keyCode == 125 || (isTab && !isShiftTab) {
            move(by: 1)
            return true
        }
        if event.keyCode == 126 || isShiftTab {
            move(by: -1)
            return true
        }
        switch event.keyCode {
        case 124:  // →
            return openFocusedSubmenu()
        case 36, 76, 49:  // Return, keypad Enter, Space
            // Consumed even with no row highlighted: it would otherwise reach the
            // focused control under the popup (and open the row behind it).
            guard let id = focusedRowID, let row = rows[id] else { return true }
            if row.openSubmenu != nil { return openFocusedSubmenu() }
            row.activate()
            return true
        default:
            return false
        }
    }

    private var orderedRowIDs: [UUID] {
        rows.sorted { $0.value.minY < $1.value.minY }.map(\.key)
    }

    private func move(by delta: Int) {
        let ids = orderedRowIDs
        guard !ids.isEmpty else { return }
        let next: Int
        if let focusedRowID, let current = ids.firstIndex(of: focusedRowID) {
            next = (current + delta + ids.count) % ids.count
        } else {
            next = delta > 0 ? 0 : ids.count - 1
        }
        focusedRowID = ids[next]
    }

    private func openFocusedSubmenu() -> Bool {
        guard let id = focusedRowID, let open = rows[id]?.openSubmenu else { return false }
        let submenu = open()
        submenu.focusFirstRowWhenReady()
        openChild = (submenu, id)
        return true
    }

    func focusFirstRowWhenReady() {
        if rows.isEmpty {
            focusesFirstRowWhenReady = true
        } else {
            focusFirstRow()
        }
    }

    private func focusFirstRow() {
        focusedRowID = orderedRowIDs.first
    }
}

// MARK: - Chrome wrapper

/// Card chrome that wraps caller-provided menu content. Matches
/// `FloatingMenuContentWrapper` exactly (same `radiusLarge` corner + themed
/// surface) so a popup and its fly-out submenu — which renders through
/// `floatingMenu` — read as the same surface. 1pt border + soft shadow; layout
/// includes `shadowPadding` so the shadow has room to render outside the card.
private struct PopupChrome: ViewModifier {
    let shadowPadding: CGFloat
    let animationState: MenuAnimationState
    let animatesIn: Bool

    private let cornerRadius: CGFloat = Sizing.radiusLarge

    /// Solid themed elevated color when a color theme is active (menus match the
    /// theme), else the vibrant material for the Default theme — identical to
    /// `FloatingMenuContentWrapper.surface`.
    private var surface: AnyShapeStyle {
        if ThemeColors.activePalette != nil {
            return AnyShapeStyle(Color.controlBackground)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            // The same open/close as every menu, grown from the top-leading
            // corner — where the cursor that opened it is.
            .modifier(MenuPresentationMotion(anchor: .topLeading, animatesIn: animatesIn, animationState: animationState))
            .padding(shadowPadding)
    }
}
