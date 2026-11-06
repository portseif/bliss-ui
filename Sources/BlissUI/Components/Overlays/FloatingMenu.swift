//
//  FloatingMenu.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/23/24.
//
//  iOS-inspired floating menus:
//  - Soft shadows with refined visual weight
//  - Opacity-based backgrounds for light/dark modes
//  - Clean spring animations
//  - Consistent 10px corner radius

import SwiftUI

// MARK: - Environment Key for Menu Active State

/// Environment key to indicate if a floating menu is currently open
struct FloatingMenuActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// Whether the floating menu attached to this view is currently presented
    public var floatingMenuActive: Bool {
        get { self[FloatingMenuActiveKey.self] }
        set { self[FloatingMenuActiveKey.self] = newValue }
    }
}

// MARK: - Menu Animation State

/// Observable state object to control menu animations from the Coordinator
@MainActor
@Observable
final class MenuAnimationState {
    var isClosing = false
    var onCloseAnimationComplete: (() -> Void)?
}

// MARK: - Menu Motion

/// The open/close timing every menu shares — floating menus, their fly-outs and
/// the right-click popups.
@MainActor
enum MenuMotion {
    /// When the last menu started closing.
    private static var lastClosedAt = Date.distantPast

    static func noteClosing() {
        lastClosedAt = Date()
    }

    /// A menu that opens right after another one closed — sweeping across
    /// sibling fly-outs, right-clicking the next row, reopening a picker —
    /// appears at once. The user is already in the menus, and animating each one
    /// in again only reads as lag (the same rule as the tooltips' warm group).
    /// So does one opened from the keyboard (Space on a trigger, → into a
    /// fly-out): keyboard actions answer at once.
    static var opensInstantly: Bool {
        Date().timeIntervalSince(lastClosedAt) < 0.3 || NSApp.currentEvent?.type == .keyDown
    }
}

// MARK: - Scroll Lock

/// While a menu is open the window under it doesn't scroll, as with a native
/// menu (its tracking loop takes the scroll wheel); scrolling the page used to
/// leave an open menu hanging where its trigger had been. Only events aimed at
/// the app window the menu opened over — the root of a fly-out's chain — are
/// dropped, so the menu's own panels and their fly-outs still scroll.
enum MenuScrollLock {
    /// The monitor to remove when the menu closes.
    static func install(over window: NSWindow) -> Any? {
        var root = window
        while let parent = root.parent { root = parent }
        return NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak root] event in
            event.window === root ? nil : event
        }
    }
}

/// How a menu comes and goes, per Emil Kowalski's rules: it grows out of the
/// corner nearest its trigger (origin-aware, never from the center), from 0.96
/// with a fade — never from nothing — on a strong ease-out, and leaves faster
/// than it came, shrinking only to 0.98 so the exit doesn't draw the eye.
/// Reduced Motion keeps the fade and drops the scale.
struct MenuPresentationMotion: ViewModifier {
    let anchor: UnitPoint
    let animatesIn: Bool
    let animationState: MenuAnimationState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAppeared: Bool
    @State private var isLeaving = false

    init(anchor: UnitPoint, animatesIn: Bool, animationState: MenuAnimationState) {
        self.anchor = anchor
        self.animatesIn = animatesIn
        self.animationState = animationState
        _isAppeared = State(initialValue: !animatesIn)
    }

    private var scale: CGFloat {
        guard !reduceMotion, !isAppeared else { return 1 }
        return isLeaving ? 0.98 : 0.96
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .opacity(isAppeared ? 1 : 0)
            .onAppear {
                guard animatesIn else { return }
                withAnimation(Animations.menuOpen) { isAppeared = true }
            }
            .onChange(of: animationState.isClosing) { _, isClosing in
                guard isClosing else { return }
                withAnimation(Animations.menuClose) {
                    isLeaving = true
                    isAppeared = false
                } completion: {
                    animationState.onCloseAnimationComplete?()
                }
            }
    }
}

// MARK: - Menu Content

private struct FloatingMenuContentWrapper<Content: View>: View {
    let content: Content
    var xPosition: FloatingMenuXPosition = .leading
    let yPosition: FloatingMenuYPosition
    var animationState: MenuAnimationState
    /// False when the menu should appear at once (see `MenuMotion.opensInstantly`).
    var animatesIn: Bool = true
    /// Set when the content is taller than the room the menu has: it scrolls
    /// inside a panel capped at this height. nil = the content at its own size.
    var maxScrollHeight: CGFloat? = nil
    /// The scroll's width — the content's own (the thumb sits in the menu's
    /// padding, so it takes no room from the rows).
    var scrollWidth: CGFloat? = nil

    @Environment(\.colorScheme) private var colorScheme
    /// Where a scrolling menu is, for its thumb. Read off the scroll view itself
    /// (`onScrollGeometryChange`): a GeometryReader inside the detached panel
    /// reports nothing, which is why `ScrollViewWithThinIndicator` can't be used.
    @State private var scrollMetrics = MenuScrollMetrics()

    // MARK: - Layout Constants
    /// Padding to accommodate shadow rendering outside panel bounds
    private let shadowPadding: CGFloat = 40
    /// Consistent corner radius
    private let cornerRadius: CGFloat = Sizing.radiusLarge

    /// The corner nearest the trigger, so the menu grows out of it: the top
    /// edge for a menu below its trigger, the bottom for one above, and the
    /// side its edge is aligned to (a fly-out's leading edge meets its row).
    private var scaleAnchor: UnitPoint {
        let x: CGFloat = switch xPosition {
        case .leading, .afterTrailing: 0
        case .center: 0.5
        case .trailing: 1
        }
        return UnitPoint(x: x, y: yPosition == .below ? 0 : 1)
    }

    /// Subtle border for definition, shared with all menu surfaces.
    private var borderColor: Color { Color.menuBorder }

    /// Surface fill: a solid themed elevated color when a color theme is active so
    /// menus match the theme; the vibrant material for the Default theme (unchanged).
    private var surface: AnyShapeStyle {
        if ThemeColors.activePalette != nil {
            return AnyShapeStyle(Color.controlBackground)
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    /// The content, scrolling when it was measured taller than its cap. The cap is
    /// a max, not a fixed height, so a typeahead filter still shrinks the panel.
    /// A scrolling menu hides the native scroller (wide and opaque when the user
    /// shows scroll bars always) and draws the app's thin thumb on a clear track.
    @ViewBuilder
    private var sizedContent: some View {
        if let maxScrollHeight {
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .background(NativeScrollerSuppressor())
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: MenuScrollMetrics.self) { geometry in
                MenuScrollMetrics(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    contentHeight: geometry.contentSize.height,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, metrics in
                scrollMetrics = metrics
            }
            .frame(width: scrollWidth)
            .frame(maxHeight: maxScrollHeight)
            .overlay(alignment: .topTrailing) {
                MenuScrollThumb(metrics: scrollMetrics)
            }
        } else {
            content
        }
    }

    var body: some View {
        let isDark = colorScheme == .dark

        sizedContent
            // Themed elevated surface (Default theme keeps the vibrant material).
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Border
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            // Soft drop shadow cast from the (now material-filled) card silhouette.
            // A separate dark caster shape would bleed through the translucent
            // material, so the shadow rides on the clipped card itself.
            .shadow(
                color: isDark ? Color.black.opacity(0.35) : Color.black.opacity(0.1),
                radius: 16,
                x: 0,
                y: 6
            )
            .shadow(
                color: isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.05),
                radius: 3,
                x: 0,
                y: 1
            )
            // Before the shadow padding, so the anchor is the card's own corner.
            .modifier(MenuPresentationMotion(anchor: scaleAnchor, animatesIn: animatesIn, animationState: animationState))
            .padding(shadowPadding)
            // Ensure the entire panel area (including the transparent shadow padding)
            // absorbs hover/click events so pointer events don't bleed through to
            // content in the main window below the floating panel.
            .contentShape(Rectangle())
    }
}

// MARK: - Scroll Thumb

/// A scrolling menu's position, from `onScrollGeometryChange`.
private struct MenuScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
}

/// The thin thumb of a menu that scrolls: no track, a small rounded thumb in
/// the menu's trailing padding, shown the whole time the menu has more rows
/// than it shows (a menu is open briefly, and the thumb is what says there's
/// more). The same look as `ScrollViewWithThinIndicator`'s, thinner.
private struct MenuScrollThumb: View {
    let metrics: MenuScrollMetrics

    private let thumbWidth: CGFloat = 4
    private let minimumHeight: CGFloat = 24
    /// Clear of the rounded corners at the ends, and of the rows at the side
    /// (the menu's padding is wider than thumb + inset).
    private let endInset: CGFloat = Spacing.menuPadding
    private let trailingInset: CGFloat = 1

    private var scrollableHeight: CGFloat { metrics.contentHeight - metrics.viewportHeight }
    private var trackHeight: CGFloat { metrics.viewportHeight - endInset * 2 }

    private var thumbHeight: CGFloat {
        guard metrics.contentHeight > 0 else { return minimumHeight }
        return min(trackHeight, max(minimumHeight, trackHeight * metrics.viewportHeight / metrics.contentHeight))
    }

    private var thumbOffset: CGFloat {
        guard scrollableHeight > 0 else { return endInset }
        let progress = min(max(metrics.offset / scrollableHeight, 0), 1)
        return endInset + progress * (trackHeight - thumbHeight)
    }

    var body: some View {
        if scrollableHeight > 1, trackHeight > minimumHeight {
            Capsule()
                .fill(Color.primary.opacity(0.35))
                .frame(width: thumbWidth, height: thumbHeight)
                .padding(.top, thumbOffset)
                .padding(.trailing, trailingInset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Menu Position

/// Horizontal position of the floating menu relative to its anchor
public nonisolated enum FloatingMenuXPosition: Sendable {
    case leading  // Left edge of menu aligns with left edge of anchor
    case center  // Menu is centered horizontally with anchor
    case trailing  // Right edge of menu aligns with right edge of anchor
    /// Menu's LEFT edge sits at the anchor's RIGHT edge — a fly-out to the trailing
    /// side that's independent of the menu's own width (so submenus can auto-width).
    case afterTrailing
}

/// What happens to a menu after `onActivate` handles its focused row: a pick
/// closes it, a checkbox toggle or a drill into a fly-out keeps it open.
public nonisolated enum FloatingMenuActivation: Sendable {
    case dismiss
    case keepOpen
}

/// Vertical position of the floating menu relative to its anchor
public nonisolated enum FloatingMenuYPosition: Sendable {
    case above  // Menu appears above the anchor
    case below  // Menu appears below the anchor
}

// MARK: - Floating Menu using Window-Level Overlay

struct FloatingMenuModifier<MenuContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let itemCount: Int
    @Binding var focusedIndex: Int?
    let onSelect: ((Int) -> Void)?
    /// Optional ← / → handlers (e.g. drill into / out of a submenu). Return true
    /// to consume the key; nil/false lets it pass through (default for all menus).
    var onMoveRight: (() -> Bool)? = nil
    var onMoveLeft: (() -> Bool)? = nil
    /// Optional type-to-filter hook. When set, printable characters typed while
    /// the menu is open build a query string (backspace edits, Esc clears before
    /// dismissing) reported here — the host filters its rows. nil (default)
    /// leaves typing untouched for every existing menu.
    var onTypeahead: ((String) -> Void)? = nil
    /// Optional Return / Space handler that decides whether the menu stays open
    /// (checkbox menus, fly-out groups). Used instead of `onSelect` when set, and
    /// the only case where Space acts on the focused row.
    var onActivate: ((Int) -> FloatingMenuActivation)? = nil
    let xPosition: FloatingMenuXPosition
    let yPosition: FloatingMenuYPosition
    let menuGap: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    @ViewBuilder let menuContent: () -> MenuContent

    func body(content: Content) -> some View {
        content
            .environment(\.floatingMenuActive, isPresented)
            .background(
                FloatingMenuAnchor(
                    isPresented: $isPresented,
                    itemCount: itemCount,
                    focusedIndex: $focusedIndex,
                    onSelect: onSelect,
                    onMoveRight: onMoveRight,
                    onMoveLeft: onMoveLeft,
                    onTypeahead: onTypeahead,
                    onActivate: onActivate,
                    xPosition: xPosition,
                    yPosition: yPosition,
                    menuGap: menuGap,
                    xOffset: xOffset,
                    yOffset: yOffset,
                    menuContent: menuContent
                )
            )
    }
}

/// Custom NSView that passes through all hit tests to allow button clicks
private class AnchorNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Pass through all hit tests - we're just an invisible anchor
        return nil
    }
}

/// NSViewRepresentable that anchors to the button and shows menu above it
private struct FloatingMenuAnchor<MenuContent: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let itemCount: Int
    @Binding var focusedIndex: Int?
    let onSelect: ((Int) -> Void)?
    var onMoveRight: (() -> Bool)? = nil
    var onMoveLeft: (() -> Bool)? = nil
    var onTypeahead: ((String) -> Void)? = nil
    var onActivate: ((Int) -> FloatingMenuActivation)? = nil
    let xPosition: FloatingMenuXPosition
    let yPosition: FloatingMenuYPosition
    let menuGap: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    @ViewBuilder let menuContent: () -> MenuContent

    func makeNSView(context: Context) -> NSView {
        let view = AnchorNSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Store reference to the anchor view
        context.coordinator.anchorView = nsView
        context.coordinator.itemCount = itemCount
        // Capture the resolved scheme now (the panel is detached and won't
        // inherit the app's overridden color scheme on its own).
        let colorScheme = context.environment.colorScheme

        // Use DispatchQueue instead of Task to ensure proper timing
        DispatchQueue.main.async {
            if self.isPresented {
                context.coordinator.showMenu(
                    content: self.menuContent(),
                    xPosition: self.xPosition,
                    menuGap: self.menuGap,
                    yPosition: self.yPosition,
                    xOffset: self.xOffset,
                    yOffset: self.yOffset,
                    colorScheme: colorScheme,
                    onDismiss: { self.isPresented = false },
                    onFocusChange: { self.focusedIndex = $0 },
                    onSelect: self.onSelect,
                    onMoveRight: self.onMoveRight,
                    onMoveLeft: self.onMoveLeft,
                    onTypeahead: self.onTypeahead,
                    onActivate: self.onActivate,
                    currentFocusedIndex: { self.focusedIndex }
                )
            } else {
                context.coordinator.hideMenu()
                self.focusedIndex = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        /// The tallest a menu gets before it scrolls — long lists (hundreds of
        /// items) otherwise ran off the screen.
        static var maxContentHeight: CGFloat { 420 }
        /// Never cap a menu shorter than this, even jammed against a screen edge.
        static var minScrollHeight: CGFloat { 120 }
        /// Clearance kept between a menu and the screen's edge.
        static var screenEdgeMargin: CGFloat { 8 }

        weak var anchorView: NSView?
        var itemCount: Int = 0
        private var menuWindow: NSPanel?
        private var dismissMonitor: Any?
        private var keyboardMonitor: Any?
        private var windowResignObserver: NSObjectProtocol?
        private var hostingView: NSHostingView<AnyView>?
        private var animationState: MenuAnimationState?
        /// Live type-to-filter query while the menu is open (typeahead menus only).
        private var typeaheadQuery = ""
        /// Anchor geometry captured at open time so the panel can be re-framed
        /// when its content resizes while open (typeahead filtering).
        private var panelPlacement: PanelPlacement?
        /// Keeps the window under the menu from scrolling while it's open.
        private var scrollLockMonitor: Any?

        struct PanelPlacement {
            let anchorFrameInWindow: NSRect
            let anchorOriginInScreen: NSPoint
            let xPosition: FloatingMenuXPosition
            let effectiveYPosition: FloatingMenuYPosition
            let menuGap: CGFloat
            let xOffset: CGFloat
            let yOffset: CGFloat
            let screenFrame: NSRect
        }

        func showMenu<Content: View>(
            content: Content,
            xPosition: FloatingMenuXPosition,
            menuGap: CGFloat,
            yPosition: FloatingMenuYPosition,
            xOffset: CGFloat,
            yOffset: CGFloat,
            colorScheme: ColorScheme,
            onDismiss: @escaping () -> Void,
            onFocusChange: @escaping (Int?) -> Void,
            onSelect: ((Int) -> Void)?,
            onMoveRight: (() -> Bool)?,
            onMoveLeft: (() -> Bool)?,
            onTypeahead: ((String) -> Void)?,
            onActivate: ((Int) -> FloatingMenuActivation)?,
            currentFocusedIndex: @escaping () -> Int?
        ) {
            // Don't recreate if already showing
            if menuWindow != nil {
                return
            }

            guard let anchorView = anchorView else {
                return
            }

            // Window might not be available immediately (especially in toolbars)
            // Wait for it to become available
            guard let parentWindow = anchorView.window else {
                // Retry after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.showMenu(
                        content: content,
                        xPosition: xPosition,
                        menuGap: menuGap,
                        yPosition: yPosition,
                        xOffset: xOffset,
                        yOffset: yOffset,
                        colorScheme: colorScheme,
                        onDismiss: onDismiss,
                        onFocusChange: onFocusChange,
                        onSelect: onSelect,
                        onMoveRight: onMoveRight,
                        onMoveLeft: onMoveLeft,
                        onTypeahead: onTypeahead,
                        onActivate: onActivate,
                        currentFocusedIndex: currentFocusedIndex
                    )
                }
                return
            }

            // Create animation state for controlling close animation
            let animationState = MenuAnimationState()
            self.animationState = animationState

            // Measure the content at its own size first.
            let measuringView = NSHostingView(rootView: AnyView(FloatingMenuContentWrapper(
                content: content,
                yPosition: yPosition,
                animationState: animationState
            )))
            let naturalSize = measuringView.fittingSize

            // Get the anchor view's frame in screen coordinates
            // First convert to window coordinates, then to screen coordinates
            let anchorFrameInWindow = anchorView.convert(anchorView.bounds, to: nil)
            let anchorOriginInScreen = parentWindow.convertPoint(toScreen: anchorFrameInWindow.origin)

            // Shadow padding added to content - need to offset positioning
            let shadowPadding: CGFloat = 40

            // The screen the anchor is on, for overflow detection
            let screen = parentWindow.screen ?? NSScreen.main ?? NSScreen.screens.first
            let screenFrame = screen?.visibleFrame ?? .zero

            // The content's own size (without shadow padding)
            let contentWidth = naturalSize.width - (shadowPadding * 2)
            let contentHeight = naturalSize.height - (shadowPadding * 2)

            // Room on each side of the anchor, short of the screen edge.
            let anchorTopInScreen = anchorOriginInScreen.y + anchorFrameInWindow.height
            let roomBelow = anchorOriginInScreen.y - menuGap - screenFrame.minY - Self.screenEdgeMargin
            let roomAbove = screenFrame.maxY - anchorTopInScreen - menuGap - Self.screenEdgeMargin

            // Keep the asked-for side when the menu fits there (capped); otherwise
            // take whichever side has more room.
            let wantedHeight = min(contentHeight, Self.maxContentHeight)
            let effectiveYPosition: FloatingMenuYPosition
            switch yPosition {
            case .below:
                effectiveYPosition = (wantedHeight <= roomBelow || roomBelow >= roomAbove) ? .below : .above
            case .above:
                effectiveYPosition = (wantedHeight <= roomAbove || roomAbove >= roomBelow) ? .above : .below
            }

            // A menu taller than its room scrolls inside a capped panel.
            let heightCap = min(Self.maxContentHeight, max(effectiveYPosition == .below ? roomBelow : roomAbove, Self.minScrollHeight))
            let scrolls = contentHeight > heightCap + 0.5

            // The menu at its final size and side (the side sets the entrance's
            // scale anchor).
            let menuView = FloatingMenuContentWrapper(
                content: content,
                xPosition: xPosition,
                yPosition: effectiveYPosition,
                animationState: animationState,
                animatesIn: !MenuMotion.opensInstantly,
                maxScrollHeight: scrolls ? heightCap : nil,
                scrollWidth: scrolls ? contentWidth : nil
            )
            let correctedHostingView = NSHostingView(rootView: AnyView(menuView))
            let menuSize = correctedHostingView.fittingSize
            correctedHostingView.setFrameSize(menuSize)
            self.hostingView = correctedHostingView

            // Capture the anchor geometry so the panel can be re-framed if its
            // content resizes while open (typeahead filtering shrinking the list).
            let placement = PanelPlacement(
                anchorFrameInWindow: anchorFrameInWindow,
                anchorOriginInScreen: anchorOriginInScreen,
                xPosition: xPosition,
                effectiveYPosition: effectiveYPosition,
                menuGap: menuGap,
                xOffset: xOffset,
                yOffset: yOffset,
                screenFrame: screenFrame
            )
            self.panelPlacement = placement

            let menuFrame = Self.menuFrame(for: placement, menuSize: menuSize)

            // Create panel window
            let panel = NSPanel(
                contentRect: menuFrame,
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false  // We draw our own shadow
            // Top-most within the app, not the whole system: the parent's own
            // level (a normal window, or the popup a fly-out hangs off), held
            // above it by the child-window link below. `.floating` put open menus
            // over other apps' windows too.
            panel.level = parentWindow.level
            panel.hidesOnDeactivate = true
            panel.contentView = correctedHostingView
            panel.isMovableByWindowBackground = false
            panel.becomesKeyOnlyIfNeeded = false  // Allow panel to become key for button clicks
            panel.acceptsMouseMovedEvents = true
            // Stamp the resolved scheme so the menu matches the app even when its
            // color scheme is overridden away from the system appearance. Using
            // the resolved environment scheme (concrete light/dark) keeps "System"
            // correct too — it just mirrors whatever the app is currently showing.
            panel.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)

            // Add click monitor for dismissal.
            // Native NSMenu behavior: a click that dismisses an open menu is "swallowed"
            // — it closes the menu and does NOT also activate whatever it landed on.
            // Cases:
            //   1. Click on the menu itself → let the menu handle its own row taps.
            //   2. Click in a descendant submenu panel (a nested `floatingMenu`
            //      anchored to one of our rows) → pass through so the child's
            //      leaf button receives the click and the child handles its own
            //      dismissal. Without this, the parent would swallow the click
            //      and the submenu item would never fire.
            //   3. Click on the anchor button → dismiss + let the click through.
            //   4. Click anywhere else → dismiss and CONSUME the event (return nil).
            dismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
                [weak self] event in
                guard let self = self,
                    let menuWindow = self.menuWindow,
                    let anchorView = self.anchorView
                else { return event }

                // Case 1: click on the menu itself — pass through so menu rows can handle taps
                if event.window === menuWindow { return event }

                // Case 2: click inside a child submenu panel — pass through.
                if let eventWindow = event.window, Self.isDescendantWindow(eventWindow, of: menuWindow) {
                    return event
                }

                // Case 3: click on the anchor button — dismiss but let the button see the click
                if let eventWindow = event.window, eventWindow === anchorView.window {
                    let anchorFrameInWindow = anchorView.convert(anchorView.bounds, to: nil)
                    if anchorFrameInWindow.contains(event.locationInWindow) {
                        self.hideMenu()
                        return event
                    }
                }

                // Case 4: click anywhere else — dismiss and swallow the click
                self.hideMenu()
                onDismiss()
                return nil
            }

            // Fresh open starts with an empty typeahead query
            typeaheadQuery = ""

            // Add keyboard monitor for arrow key navigation + type-to-filter
            keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.menuWindow != nil else { return event }
                // The highlighted row shows its focus ring after a key press.
                FocusVisibilityService.shared.noteKeyboardInput()

                let itemCount = self.itemCount

                // ↓ / ↑ step through the rows, and so do Tab / Shift-Tab: the panel
                // can't take key focus, so Tab would otherwise move focus in the
                // window underneath while the menu stays open.
                let isTab = event.keyCode == 48
                let isShiftTab = isTab && event.modifierFlags.contains(.shift)
                if event.keyCode == 125 || (isTab && !isShiftTab) {
                    guard itemCount > 0 else { return event }
                    let current = currentFocusedIndex() ?? -1
                    let next = (current + 1) % itemCount
                    onFocusChange(next)
                    return nil  // Consume the event
                }
                if event.keyCode == 126 || isShiftTab {
                    guard itemCount > 0 else { return event }
                    let current = currentFocusedIndex() ?? 0
                    let next = current <= 0 ? itemCount - 1 : current - 1
                    onFocusChange(next)
                    return nil  // Consume the event
                }

                switch event.keyCode {

                case 36, 76:  // Return or Enter (numpad)
                    guard itemCount > 0 else { return event }
                    if let index = currentFocusedIndex() {
                        if let onActivate {
                            if onActivate(index) == .keepOpen { return nil }
                        } else {
                            onSelect?(index)
                        }
                    }
                    self.hideMenu()
                    onDismiss()
                    return nil  // Consume the event

                // Space acts on the focused row only in menus that handle activation
                // themselves (a typeahead menu types the space instead). Consumed even
                // with nothing focused, so it can't fall through and press the
                // trigger button that still has keyboard focus.
                case 49 where onActivate != nil && onTypeahead == nil:
                    guard itemCount > 0 else { return event }
                    if let index = currentFocusedIndex(), let onActivate, onActivate(index) == .dismiss {
                        self.hideMenu()
                        onDismiss()
                    }
                    return nil

                case 53:  // Escape — clears an active filter first, then dismisses
                    if onTypeahead != nil, !self.typeaheadQuery.isEmpty {
                        self.typeaheadQuery = ""
                        onTypeahead?("")
                        self.scheduleTypeaheadRefit()
                        return nil
                    }
                    self.hideMenu()
                    onDismiss()
                    return nil  // Consume the event

                case 124:  // Right arrow — optional drill-in
                    if onMoveRight?() == true { return nil }
                    return event

                case 123:  // Left arrow — optional drill-out
                    if onMoveLeft?() == true { return nil }
                    return event

                case 51:  // Delete (backspace) — edit the typeahead query
                    if onTypeahead != nil, !self.typeaheadQuery.isEmpty {
                        self.typeaheadQuery.removeLast()
                        onTypeahead?(self.typeaheadQuery)
                        self.scheduleTypeaheadRefit()
                        return nil
                    }
                    return event

                default:
                    // Type-to-filter: printable characters build the query
                    guard let onTypeahead else { return event }
                    guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty
                    else { return event }
                    guard let characters = event.characters, !characters.isEmpty else { return event }
                    let isPrintable = characters.allSatisfy { character in
                        character.isLetter || character.isNumber || character.isPunctuation
                            || character.isSymbol || character == " "
                    }
                    guard isPrintable else { return event }
                    self.typeaheadQuery += characters
                    onTypeahead(self.typeaheadQuery)
                    self.scheduleTypeaheadRefit()
                    return nil  // Consume the event
                }
            }

            // Observe parent window resignation to dismiss menu when window loses focus.
            // But ignore the case where the parent resigns because our own menu panel
            // just became key — that's expected and must NOT auto-dismiss.
            windowResignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: parentWindow,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                if NSApp.keyWindow === self.menuWindow { return }
                self.hideMenu()
                onDismiss()
            }

            // Order the panel above its parent. We deliberately do NOT makeKey here:
            // the panel's styleMask (`.nonactivatingPanel`, no `.titled`) can't become
            // key, so makeKeyAndOrderFront just logged a `canBecomeKeyWindow` warning on
            // every open (amplified by nested fly-out submenus). Hover, keyboard nav, and
            // click-dismiss all run through SwiftUI `.onHover` + local NSEvent monitors,
            // which don't require a key window — so plain orderFront is behavior-identical
            // and quiet. Keeping the parent key also avoids the main window's traffic
            // lights dimming while a menu is open.
            parentWindow.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)

            self.menuWindow = panel
            scrollLockMonitor = MenuScrollLock.install(over: parentWindow)
        }

        /// Panel frame for a given placement + total menu size (content + shadow
        /// padding). Shared by the initial open and live content-resize so the
        /// anchored edge stays fixed when the menu grows/shrinks while open.
        private static func menuFrame(for placement: PanelPlacement, menuSize: CGSize) -> NSRect {
            let shadowPadding: CGFloat = 40
            let contentWidth = menuSize.width - (shadowPadding * 2)
            let anchorOriginInScreen = placement.anchorOriginInScreen
            let anchorFrameInWindow = placement.anchorFrameInWindow
            let screenFrame = placement.screenFrame

            // Calculate Y position based on effective position
            let menuY: CGFloat
            switch placement.effectiveYPosition {
            case .above:
                // Menu appears above anchor (offset by shadow padding)
                let anchorTopInScreen = anchorOriginInScreen.y + anchorFrameInWindow.height
                menuY = anchorTopInScreen + placement.menuGap - shadowPadding
            case .below:
                // Menu appears below anchor (offset by shadow padding)
                menuY = anchorOriginInScreen.y - menuSize.height - placement.menuGap + shadowPadding
            }

            // Calculate X position based on xPosition with overflow detection
            var menuX: CGFloat
            switch placement.xPosition {
            case .leading:
                // Left edge of menu aligns with left edge of anchor (offset by shadow padding)
                menuX = anchorOriginInScreen.x - shadowPadding
            case .center:
                // Center the menu horizontally with the anchor
                let anchorCenterX = anchorOriginInScreen.x + anchorFrameInWindow.width / 2
                menuX = anchorCenterX - menuSize.width / 2
            case .trailing:
                // Right edge of menu aligns with right edge of anchor (offset by shadow padding)
                let anchorRightX = anchorOriginInScreen.x + anchorFrameInWindow.width
                menuX = anchorRightX - menuSize.width + shadowPadding
            case .afterTrailing:
                // Menu's left edge sits at the anchor's right edge — width-independent,
                // so an auto-width submenu always flies out flush to the trailing side.
                let anchorRightX = anchorOriginInScreen.x + anchorFrameInWindow.width
                menuX = anchorRightX - shadowPadding
            }

            // Apply user-specified offsets
            menuX += placement.xOffset
            let finalMenuY = menuY + placement.yOffset

            // Clamp X to keep menu on screen
            let menuContentLeft = menuX + shadowPadding
            let menuContentRight = menuX + shadowPadding + contentWidth

            if menuContentLeft < screenFrame.minX {
                // Overflows left edge, shift right
                menuX = screenFrame.minX - shadowPadding
            } else if menuContentRight > screenFrame.maxX {
                // Overflows right edge, shift left
                menuX = screenFrame.maxX - contentWidth - shadowPadding
            }

            return NSRect(
                x: menuX,
                y: finalMenuY,
                width: menuSize.width,
                height: menuSize.height
            )
        }

        /// Schedule a panel refit after a typeahead mutation. The hosting view's
        /// `fittingSize` only reflects the changed SwiftUI content on the NEXT
        /// runloop (verified empirically — a synchronous read is stale), so the
        /// refit is deferred once, with a short follow-up in case the content
        /// commit lands late. (A GeometryReader-preference approach was tried
        /// and rejected: inside the detached panel it fires once with (0,0) and
        /// never reports a real size.)
        private func scheduleTypeaheadRefit() {
            DispatchQueue.main.async { [weak self] in
                self?.refitPanelToContent()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.refitPanelToContent()
            }
        }

        /// Re-frame the open panel to its content's current fitting size (the
        /// typeahead filter changed the row set). The anchored edge stays
        /// fixed: `.below` menus keep their top under the trigger, `.above`
        /// menus keep their bottom above it.
        private func refitPanelToContent() {
            guard let panel = menuWindow, let placement = panelPlacement,
                let hostingView = hostingView
            else { return }
            let menuSize = hostingView.fittingSize
            guard menuSize.width > 1, menuSize.height > 1 else { return }
            // Ignore sub-pixel noise
            guard abs(menuSize.width - panel.frame.width) > 0.5
                || abs(menuSize.height - panel.frame.height) > 0.5
            else { return }

            let newFrame = Self.menuFrame(for: placement, menuSize: menuSize)
            hostingView.setFrameSize(menuSize)
            panel.setFrame(newFrame, display: true)
        }

        func hideMenu() {
            // Remove monitors and observers immediately to prevent double-triggers
            if let monitor = dismissMonitor {
                NSEvent.removeMonitor(monitor)
                dismissMonitor = nil
            }

            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }

            if let observer = windowResignObserver {
                NotificationCenter.default.removeObserver(observer)
                windowResignObserver = nil
            }

            if let monitor = scrollLockMonitor {
                NSEvent.removeMonitor(monitor)
                scrollLockMonitor = nil
            }

            // Forget the panel now and close a captured local, so a reopen during
            // the close animation (sweeping back to a fly-out, a second click on
            // the trigger) gets a fresh panel instead of being dropped, and this
            // close can never take down the next menu. Nothing below holds
            // `self`: `deinit` runs this too, and a weak self is already nil there.
            let panel = menuWindow
            let animationState = self.animationState
            menuWindow = nil
            hostingView = nil
            self.animationState = nil
            panelPlacement = nil
            typeaheadQuery = ""
            guard let panel else { return }

            MenuMotion.noteClosing()

            // Whichever of the animation's completion and the fallback comes first
            // takes the panel down; clearing the completion and the content breaks
            // the panel → hosting view → animation state → completion cycle.
            func close() {
                animationState?.onCloseAnimationComplete = nil
                guard panel.contentView != nil else { return }
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
                panel.contentView = nil
                panel.close()
            }
            guard let animationState else {
                close()
                return
            }
            animationState.onCloseAnimationComplete = { close() }
            animationState.isClosing = true

            // Fallback in case the completion never fires, just above `menuClose`'s
            // duration so a swept-away submenu tears down promptly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { close() }
        }

        /// Whether `candidate` is `root` or a (recursive) child window of it.
        /// Used so a parent menu's dismiss monitor ignores clicks that land in
        /// a nested submenu panel (added via `addChildWindow`).
        static func isDescendantWindow(_ candidate: NSWindow, of root: NSWindow) -> Bool {
            var current: NSWindow? = candidate
            while let window = current {
                if window === root { return true }
                current = window.parent
            }
            return false
        }

        deinit {
            hideMenu()
        }
    }
}

extension View {
    /// Floating menu with keyboard navigation support
    /// - Parameters:
    ///   - xOffset: Additional horizontal offset for the menu (positive = right)
    ///   - yOffset: Additional vertical offset for the menu (positive = up)
    public func floatingMenu<Content: View>(
        isPresented: Binding<Bool>,
        itemCount: Int,
        focusedIndex: Binding<Int?>,
        xPosition: FloatingMenuXPosition = .leading,
        yPosition: FloatingMenuYPosition = .above,
        menuGap: CGFloat = 8,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        onSelect: ((Int) -> Void)? = nil,
        onMoveRight: (() -> Bool)? = nil,
        onMoveLeft: (() -> Bool)? = nil,
        onTypeahead: ((String) -> Void)? = nil,
        onActivate: ((Int) -> FloatingMenuActivation)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            FloatingMenuModifier(
                isPresented: isPresented,
                itemCount: itemCount,
                focusedIndex: focusedIndex,
                onSelect: onSelect,
                onMoveRight: onMoveRight,
                onMoveLeft: onMoveLeft,
                onTypeahead: onTypeahead,
                onActivate: onActivate,
                xPosition: xPosition,
                yPosition: yPosition,
                menuGap: menuGap,
                xOffset: xOffset,
                yOffset: yOffset,
                menuContent: content
            )
        )
    }

    /// Simple floating menu without keyboard navigation
    /// - Parameters:
    ///   - xOffset: Additional horizontal offset for the menu (positive = right)
    ///   - yOffset: Additional vertical offset for the menu (positive = up)
    public func floatingMenu<Content: View>(
        isPresented: Binding<Bool>,
        xPosition: FloatingMenuXPosition = .leading,
        yPosition: FloatingMenuYPosition = .above,
        menuGap: CGFloat = 8,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            FloatingMenuModifier(
                isPresented: isPresented,
                itemCount: 0,
                focusedIndex: .constant(nil),
                onSelect: nil,
                xPosition: xPosition,
                yPosition: yPosition,
                menuGap: menuGap,
                xOffset: xOffset,
                yOffset: yOffset,
                menuContent: content
            )
        )
    }
}

// MARK: - Preview

#Preview("Floating Menu") {
    struct PreviewWrapper: View {
        @State private var showingMenu = false

        var body: some View {
            VStack {
                Spacer()

                Button("Show Menu") {
                    showingMenu.toggle()
                }
                .padding()
                .floatingMenu(isPresented: $showingMenu) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Menu Item 1")
                        Text("Menu Item 2")
                        Text("Menu Item 3")
                    }
                    .padding()
                    .frame(width: 200)
                }

                Spacer()
                    .frame(height: 100)
            }
            .frame(width: 400, height: 400)
        }
    }

    return PreviewWrapper()
}

#Preview("Material Comparison") {
    struct MaterialBox: View {
        let title: String
        let material: Material

        @Environment(\.colorScheme) private var colorScheme


        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Menu Header")
                    .font(Typography.bodySmallSemibold)
                Divider()
                Text("Option 1")
                    .font(Typography.bodySmall)
                Text("Option 2")
                    .font(Typography.bodySmall)
                Text("Option 3")
                    .font(Typography.bodySmall)
            }
            .padding(.horizontal, Spacing.md + 2)
            .padding(.vertical, Spacing.md)
            .frame(width: 180)
            .background(
                RoundedRectangle(cornerRadius: Sizing.radiusLarge - 2, style: .continuous)
                    .fill(material)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.08), radius: 1, x: 0, y: 1)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 8, x: 0, y: 4)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 24, x: 0, y: 12)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 48, x: 0, y: 24)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge - 2, style: .continuous))
            .overlay(alignment: .bottom) {
                Text(title)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.sm)
                    .offset(y: 24)
            }
        }
    }

    return ZStack {
        // Colorful background to show material transparency
        LinearGradient(
            colors: [.blue, .purple, .pink, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        HStack(spacing: 40) {
            MaterialBox(title: "ultraThin", material: .ultraThinMaterial)
            MaterialBox(title: "thin", material: .thinMaterial)
            MaterialBox(title: "regular", material: .regularMaterial)
            MaterialBox(title: "thick", material: .thickMaterial)
        }
        .padding(60)
    }
    .frame(width: 900, height: 400)
}
