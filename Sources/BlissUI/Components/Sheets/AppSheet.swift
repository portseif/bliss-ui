//
//  AppSheet.swift
//  BlissUI
//
//  A custom modal-sheet presentation that matches the app's chrome instead of
//  the system sheet window. On macOS 26 (Tahoe) the system draws sheets with a
//  large Liquid Glass corner radius that has no public override, so to give
//  every sheet the same app-matching look (the `radiusLarge` floating-panel
//  chrome) we present content as a centered card over a dim scrim, hosted once
//  at the window root (same pattern as `ToastService` / `PopupMenuService`).
//
//  Because this isn't a real sheet window, SwiftUI's `@Environment(\.dismiss)`
//  doesn't work for the content — use `@Environment(\.appSheetDismiss)` instead
//  (it's a plain `() -> Void`, so existing `dismiss()` call sites are unchanged;
//  only the property declaration swaps).
//

import AppKit
import SwiftUI

// MARK: - Dismiss environment

private struct AppSheetDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Dismisses the enclosing `appSheet`. Replaces `\.dismiss` for content
    /// presented through the custom overlay (a real `DismissAction` only drives
    /// system presentations). Callable as `dismiss()`.
    public var appSheetDismiss: () -> Void {
        get { self[AppSheetDismissKey.self] }
        set { self[AppSheetDismissKey.self] = newValue }
    }

    /// The max height the sheet card can occupy (window − margins). Sheets use it
    /// (via `AppSheetScaffold`) to cap their scrollable content so a fixed header
    /// and footer stay pinned and only the middle scrolls. A sheet presented with
    /// `scrollsItsOwnContent` reads it to size itself.
    public var appSheetMaxHeight: CGFloat {
        get { self[AppSheetMaxHeightKey.self] }
        set { self[AppSheetMaxHeightKey.self] = newValue }
    }
}

private struct AppSheetMaxHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 600
}

// MARK: - Presenter

/// Owns the stack of presented app sheets. Singleton so any call site can push
/// into the single window-root host. Mirrors the app's other overlay services.
@MainActor
@Observable
final class AppSheetPresenter {
    static let shared = AppSheetPresenter()
    private init() {}

    struct Entry: Identifiable {
        let id: UUID
        let make: () -> AnyView
        let onDismiss: () -> Void
        /// When true the card hugs the content's own width (e.g. a creation
        /// wizard that sizes itself per step) instead of filling the standard
        /// envelope. Use for sheets that set their own fixed width.
        var sizesToContent = false
        /// The sheet takes an exact height (≤ `appSheetMaxHeight`) and scrolls its
        /// own areas between a pinned header and footer (e.g. a multi-step
        /// wizard), so the card shows it as is, with no scroll around it: a
        /// fitting sheet inside the card's scroll could still be scrolled.
        var scrollsItsOwnContent = false
        /// Where the user clicked to open the sheet, in window coordinates
        /// (top-left origin). The card scales out from / collapses back to this
        /// point so open/close feels anchored to the trigger.
        var openLocation: CGPoint? = nil
        /// Drives the card's animate-out; the entry stays mounted through the
        /// spring so the exit (scale + drift + fade) is visible before removal.
        var isDismissing = false
    }

    private(set) var stack: [Entry] = []

    func present<C: View>(
        id: UUID,
        onDismiss: @escaping () -> Void,
        sizesToContent: Bool = false,
        scrollsItsOwnContent: Bool = false,
        content: @escaping () -> C
    ) {
        var entry = Entry(id: id, make: { AnyView(content()) }, onDismiss: onDismiss, sizesToContent: sizesToContent)
        entry.scrollsItsOwnContent = scrollsItsOwnContent
        if let index = stack.firstIndex(where: { $0.id == id }) {
            // Already showing (or mid-dismiss) — refresh content + cancel exit, but
            // keep the original open location so a content refresh doesn't re-anchor.
            entry.openLocation = stack[index].openLocation
            stack[index] = entry
        } else {
            entry.openLocation = Self.isPresentingFromClick ? Self.currentClickLocationInWindow() : nil
            stack.append(entry)
        }
    }

    /// Whether the event that led here is a click. A sheet opened from the
    /// keyboard (⌘N) or a menu grows from the card's center instead of from
    /// wherever the pointer happens to rest.
    private static var isPresentingFromClick: Bool {
        switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }

    /// The mouse location at present time, converted to the key window's top-left
    /// coordinate space (matching the sheet host's GeometryReader). nil if there's
    /// no key window.
    private static func currentClickLocationInWindow() -> CGPoint? {
        guard let window = NSApp.keyWindow else { return nil }
        let screenPoint = NSEvent.mouseLocation            // screen, bottom-left origin
        let frame = window.frame
        let xInWindow = screenPoint.x - frame.minX
        let yFromBottom = screenPoint.y - frame.minY
        return CGPoint(x: xInWindow, y: frame.height - yFromBottom)   // flip to top-left
    }

    func dismiss(id: UUID) {
        guard let index = stack.firstIndex(where: { $0.id == id }), !stack[index].isDismissing else { return }
        // Phase 1: flag the exit so the card animates out (property-driven).
        stack[index].isDismissing = true
        // Phase 2: remove once the exit spring has played.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.exitDuration) { [weak self] in
            self?.stack.removeAll { $0.id == id }
        }
    }

    /// Closes every open sheet, topmost first, through each one's own binding
    /// (so the presenting view's state resets as if its ✕ were pressed).
    func dismissAll() {
        for entry in stack.reversed() where !entry.isDismissing {
            entry.onDismiss()
            dismiss(id: entry.id)
        }
    }

    /// How long the exit (`Animations.sheetClose`) runs before the entry is removed.
    private static let exitDuration: TimeInterval = 0.22
}

// MARK: - Host

/// The window-root host that renders the sheet stack: a dim scrim plus a
/// centered card with the app surface, `radiusLarge` corners, a hairline, and a
/// shadow. Attach once via `.appSheetHost()`.
struct AppSheetContainer: View {
    /// Shifts the card's horizontal centering right by this much (half of it,
    /// really) — pass the sidebar width so sheets center over the CONTENT pane,
    /// matching toasts. 0 = window-centered.
    var leadingInset: CGFloat = 0
    @State private var presenter = AppSheetPresenter.shared

    /// Standard sheet width envelope. Content sizes within this range; height is
    /// auto (capped to the window so tall content can't overflow).
    static let minWidth: CGFloat = 420
    static let maxWidth: CGFloat = 640
    /// Breathing room kept around the card inside the window — the card's max
    /// height is the window height minus this on top and bottom (window − 94px).
    private static let windowMargin: CGFloat = 47

    var body: some View {
        GeometryReader { geo in
            // The card clamps its own width (default or override) to this —
            // measured against the CONTENT pane, not the full window, so an
            // inset card never overflows the right edge.
            let availableWidth = geo.size.width - leadingInset - Self.windowMargin * 2
            let maxH = geo.size.height - Self.windowMargin * 2
            // Only the top sheet takes keys and VoiceOver: a lower one's Esc /
            // Return shortcuts would otherwise fire first (the earliest control
            // with a shortcut wins), closing or saving the sheet underneath.
            let topEntryID = presenter.stack.last(where: { !$0.isDismissing })?.id
            ZStack {
                ForEach(presenter.stack) { entry in
                    AppSheetCard(
                        entry: entry,
                        availableWidth: availableWidth,
                        maxHeight: maxH,
                        windowSize: geo.size,
                        leadingInset: leadingInset
                    )
                    .disabled(entry.id != topEntryID)
                    .accessibilityHidden(entry.id != topEntryID)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // Span the FULL window, including the title-bar band. Without this the
        // GeometryReader respects the top safe area, so `geo.size` (and the frame
        // above) exclude the custom title bar — the scrim still paints up there
        // via its own `.ignoresSafeArea()`, but hit-testing is clipped to this
        // frame, so clicks on the title-bar toolbar buttons fall through. Ignoring the safe area here makes the hittable region cover the
        // whole window so the scrim actually blocks those controls.
        .ignoresSafeArea()
        // Don't intercept window input when nothing is presented — nor while the
        // last sheet animates out, so a click right after Esc lands.
        .allowsHitTesting(presenter.stack.contains { !$0.isDismissing })
    }
}

/// One presented sheet: a dim scrim + the centered card. Animated via properties
/// (`scaleEffect` / `offset` / `opacity`) rather than `.transition`, because
/// geometric transitions get swallowed inside a `ZStack` `ForEach` here (the
/// same reason other stacked overlays animate this way).
private struct AppSheetCard: View {
    let entry: AppSheetPresenter.Entry
    let availableWidth: CGFloat
    let maxHeight: CGFloat
    let windowSize: CGSize
    /// Centering shift — the card centers over the content pane (right of the
    /// sidebar), not the whole window. See `AppSheetContainer.leadingInset`.
    var leadingInset: CGFloat = 0
    @State private var appeared = false
    @State private var contentSize: CGSize = .zero

    /// Shown once mounted, hidden again the moment the exit is flagged.
    private var isVisible: Bool { appeared && !entry.isDismissing }

    private var sheetContent: some View {
        entry.make()
            .environment(\.appSheetDismiss, entry.onDismiss)
            .environment(\.appSheetMaxHeight, maxHeight)
    }
    /// Standard fill width, clamped to the window.
    private var cardMaxWidth: CGFloat {
        min(AppSheetContainer.maxWidth, availableWidth)
    }

    /// Scale origin: the point the user clicked to open, expressed in the card's
    /// own unit space (the card is centered in the window). The sheet grows out of
    /// that point on open and collapses back into it on close — origin-aware intent.
    /// Falls back to center before the card has measured its size.
    private var scaleAnchor: UnitPoint {
        guard let location = entry.openLocation, contentSize.width > 0, contentSize.height > 0 else {
            return .center
        }
        // The leading padding shifts the card's center right by inset/2.
        let cardLeft = (windowSize.width - contentSize.width + leadingInset) / 2
        let cardTop = (windowSize.height - contentSize.height) / 2
        return UnitPoint(
            x: (location.x - cardLeft) / contentSize.width,
            y: (location.y - cardTop) / contentSize.height
        )
    }

    var body: some View {
        ZStack {
            // Dim scrim — blocks interaction with the content behind (modal).
            // No tap-to-dismiss, matching macOS sheets.
            // Visual dim only — hit-testing + window dragging live on the
            // `WindowDragSurface` below it, so the backdrop both blocks clicks to
            // whatever is underneath AND lets a press-drag move the window.
            Rectangle()
                .fill(Color.black.opacity(0.32))
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(isVisible ? 1 : 0)

            WindowDragSurface()
                .ignoresSafeArea()

            // The sheet card. Matches `ToastNotification`: scale-from-0.95 +
            // fade + a slight downward enter / upward exit drift.
            //
            // Auto-height: the card hugs the content and only scrolls when the
            // content exceeds `maxHeight` (window − 94px). `AutoHeightScroll`
            // measures the content and renders at an EXACT height — a plain
            // `.frame(maxHeight:)` here would expand to fill, since this ZStack
            // proposes the full window height (the dead-space bug).
            Group {
                if entry.scrollsItsOwnContent {
                    // Its exact height already fits; only its own areas scroll.
                    sheetContent
                } else {
                    AutoHeightScroll(
                        maxHeight: maxHeight,
                        hugsWidth: entry.sizesToContent,
                        // The morph lives on the scroll's OWN resize (its size lands via a
                        // preference → state set, outside the trigger's transaction) — so
                        // the card transitions on growth no matter what caused it, not only
                        // when the trigger was wrapped in withAnimation. Gated on `appeared`
                        // so the pre-entrance fill→hug settle stays instant/off-screen.
                        resizeAnimation: appeared ? Animations.sheetMorph : nil
                    ) {
                        sheetContent
                    }
                }
            }
                // Standard sheets fill the envelope width (the scroll is constrained
                // here, since a scroll view is horizontally greedy); self-sizing
                // sheets hug their own width via `hugsWidth` above.
                .frame(
                    minWidth: entry.sizesToContent ? nil : AppSheetContainer.minWidth,
                    maxWidth: entry.sizesToContent ? nil : cardMaxWidth
                )
                .background(Color.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 28, x: 0, y: 14)
                // Measured for the click-point scale anchor. The resize morph itself
                // is owned by the AutoHeightScroll's `resizeAnimation` above (an
                // after-the-fact `.animation(value:)` here can't catch growth whose
                // trigger wasn't animated — the geometry has already changed).
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: {
                    contentSize = $0
                }
                // Grow out of / collapse back into the click point (origin-aware),
                // so open and close feel anchored to the trigger. A touch smaller at
                // rest than the centered 0.95 so the expansion reads clearly; the
                // exit shrinks less (0.97), since it's quicker and on the way out.
                .scaleEffect(isVisible || prefersReducedMotion ? 1 : (entry.isDismissing ? 0.97 : 0.9), anchor: scaleAnchor)
                .accessibilityAddTraits(.isModal)
                .opacity(isVisible ? 1 : 0)
                // Center over the content pane (right of the sidebar), matching
                // toasts — not the whole window.
                .padding(.leading, leadingInset)
        }
        .animation(isVisible ? Animations.sheet : Animations.sheetClose, value: isVisible)
        .onAppear {
            // Defer the entrance two runloops so the auto-height/width measurement
            // settles first (the scroll fills full width on its first frame, then
            // measures and hugs). Holding the card hidden until then means the
            // resize happens off-screen — the card animates in already sized, so
            // you never see the width snap from 100%.
            DispatchQueue.main.async {
                DispatchQueue.main.async { appeared = true }
            }
        }
    }
}

extension View {
    /// Mounts the app-sheet host. Apply once, high in the window root so sheets
    /// overlay everything. Also lightly blurs the content behind a presented
    /// sheet (faded in/out with the same spring) to focus the modal.
    /// `leadingInset` shifts the cards' centering to sit over the content pane
    /// (pass the sidebar width).
    public func appSheetHost(leadingInset: CGFloat = 0) -> some View {
        modifier(AppSheetHostModifier(leadingInset: leadingInset))
    }
}

// MARK: - Scaffold (fixed header + scrollable content + fixed footer)

/// The standard sheet layout: a pinned header, a scrollable content region, and a
/// pinned footer. Only the content scrolls — and only when it would push the sheet
/// past the window cap; otherwise the whole sheet hugs its content. The content
/// scroll is capped to `window − header − footer` (both measured), so the header
/// and footer never move. Build a sheet as:
/// ```
/// AppSheetScaffold {
///     SheetHeader(title: …, onDismiss: dismiss)
/// } content: {
///     // form sections
/// } footer: {
///     // action buttons
/// }
/// .frame(width: 620)   // content-sized sheets set their width
/// ```
public struct AppSheetScaffold<Header: View, Content: View, Footer: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    public init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    @Environment(\.appSheetMaxHeight) private var windowMaxHeight
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    /// Height left for the scrollable content after the fixed chrome. The `+ 2`
    /// covers the two dividers.
    private var availableForContent: CGFloat {
        max(120, windowMaxHeight - headerHeight - footerHeight - 2)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            Divider()

            AutoHeightScroll(
                showFadeMask: true,
                maxHeight: availableForContent,
                indicatorTopPadding: 0,
                indicatorBottomPadding: 0,
                // Content reveals (disclosures, dynamic rows) morph the scroll —
                // and the pinned footer rides the growth instead of jumping.
                resizeAnimation: Animations.sheetMorph
            ) {
                content
            }

            Divider()

            footer
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
    }
}

private struct AppSheetHostModifier: ViewModifier {
    var leadingInset: CGFloat = 0
    @State private var presenter = AppSheetPresenter.shared

    /// True only while a sheet is actively presented — drops the moment its exit
    /// is flagged so the blur recedes in sync with the card's animate-out.
    private var hasActiveSheet: Bool { presenter.stack.contains { !$0.isDismissing } }

    func body(content: Content) -> some View {
        content
            // Modal for the keyboard and VoiceOver too, not just the mouse: Tab
            // can't walk out of the sheet into the blurred page, and the page's
            // Esc / Return shortcuts (a docked panel, a page button) can't beat
            // the sheet's own.
            .disabled(hasActiveSheet)
            .accessibilityHidden(hasActiveSheet)
            // Subtle by design: paired with the dim scrim, a small radius reads
            // as focus without the cost of a heavy full-window blur each frame.
            .blur(radius: hasActiveSheet ? 6 : 0)
            .animation(hasActiveSheet ? Animations.sheet : Animations.sheetClose, value: hasActiveSheet)
            .overlay(AppSheetContainer(leadingInset: leadingInset))
            // The scrim blocks clicks behind the sheet, but we WANT the dimmed
            // backdrop to drag the window (nicer than a dead modal). This makes
            // the window movable by its background while a sheet is up, so a
            // press-drag on the scrim moves the app; clicks stay blocked.
            .windowModalDraggable(hasActiveSheet)
    }
}

// MARK: - Presentation modifiers

private struct AppSheetBoolModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: () -> SheetContent
    let sizesToContent: Bool
    var scrollsItsOwnContent = false
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { if isPresented { present() } }
            .onChange(of: isPresented) { _, presented in
                if presented { present() } else { AppSheetPresenter.shared.dismiss(id: id) }
            }
            .onDisappear { AppSheetPresenter.shared.dismiss(id: id) }
    }

    private func present() {
        AppSheetPresenter.shared.present(
            id: id,
            onDismiss: { isPresented = false },
            sizesToContent: sizesToContent,
            scrollsItsOwnContent: scrollsItsOwnContent,
            content: sheetContent
        )
    }
}

private struct AppSheetItemModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let sheetContent: (Item) -> SheetContent
    let sizesToContent: Bool
    var scrollsItsOwnContent = false
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { present() }
            .onChange(of: item?.id) { _, _ in present() }
            .onDisappear { AppSheetPresenter.shared.dismiss(id: id) }
    }

    private func present() {
        if let item {
            AppSheetPresenter.shared.present(
                id: id,
                onDismiss: { self.item = nil },
                sizesToContent: sizesToContent,
                scrollsItsOwnContent: scrollsItsOwnContent
            ) {
                sheetContent(item)
            }
        } else {
            AppSheetPresenter.shared.dismiss(id: id)
        }
    }
}

extension View {
    /// Presents `content` as a custom app sheet while `isPresented` is true.
    /// Drop-in for `.sheet(isPresented:)`; the content dismisses via
    /// `\.appSheetDismiss`. Set `contentSized` for sheets that size their own
    /// width (the card hugs them instead of filling the standard envelope), and
    /// `scrollsItsOwnContent` for one with an exact height that scrolls its own
    /// areas (the card then puts no scroll around it).
    public func appSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        contentSized: Bool = false,
        scrollsItsOwnContent: Bool = false,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(AppSheetBoolModifier(
            isPresented: isPresented,
            sheetContent: content,
            sizesToContent: contentSized,
            scrollsItsOwnContent: scrollsItsOwnContent
        ))
    }

    /// Presents a custom app sheet for a non-nil `item`. Drop-in for
    /// `.sheet(item:)`; the content dismisses via `\.appSheetDismiss`.
    /// Set `contentSized` for sheets that size their own width, and
    /// `scrollsItsOwnContent` as above.
    public func appSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        contentSized: Bool = false,
        scrollsItsOwnContent: Bool = false,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(AppSheetItemModifier(
            item: item,
            sheetContent: content,
            sizesToContent: contentSized,
            scrollsItsOwnContent: scrollsItsOwnContent
        ))
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 720, height: 520)) {
    @Previewable @State var isPresented = true

    ZStack {
        Color.appShell.ignoresSafeArea()

        VStack(spacing: Spacing.md) {
            Text("Window content")
                .font(Typography.headingMedium)
            Button("Show Sheet") { isPresented = true }
                .buttonStyle(PrimaryButtonStyle(compact: true))
        }
    }
    .appSheetHost()
    .appSheet(isPresented: $isPresented) {
        SheetContentPreview()
    }
}

private struct SheetContentPreview: View {
    @Environment(\.appSheetDismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SheetHeader(
                title: "App Sheet",
                subtitle: "A centered card over a dim scrim with app-matching chrome",
                icon: "rectangle.center.inset.filled",
                onDismiss: dismiss
            )

            Text(
                "Content here dismisses via the appSheetDismiss environment value instead of the system dismiss action."
            )
            .font(Typography.bodyMedium)
            .foregroundStyle(Color.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
        .padding(Spacing.xl)
    }
}
