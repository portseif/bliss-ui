//
//  ThinScrollIndicator.swift
//  BlissUI
//
//  Slack-style thin scroll indicator overlay
//

import SwiftUI
import AppKit

// MARK: - Native Scroller Suppressor

/// Forces the enclosing NSScrollView to use `.overlay` scroller style, which respects
/// SwiftUI's `.scrollIndicators(.hidden)` directive. Without this, users with
/// "Show scroll bars: Always" in System Settings see the native scrollbar even when
/// SwiftUI is told to hide it.
///
/// The suppression runs SYNCHRONOUSLY from `viewDidMoveToWindow`/`Superview` (the
/// earliest hooks where the `NSScrollView` ancestor exists) rather than a deferred
/// `DispatchQueue.main.async`. The async version left a one-frame gap on every fresh
/// mount — visible as a flash of the wide legacy scroller when switching views.
struct NativeScrollerSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { SuppressorView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? SuppressorView)?.applySuppression()
    }

    private final class SuppressorView: NSView {
        /// The scroll view being kept clean, and what's watched on it.
        private weak var observedScrollView: NSScrollView?
        private var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            applySuppression()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applySuppression()
        }

        /// Suppress synchronously (pre-paint, so no flash of the wide legacy
        /// scroller) AND again on the next runloop — SwiftUI sets `scrollerStyle`
        /// back to the system default during its own layout pass *after* our
        /// synchronous set, so the deferred re-assert is what makes `.overlay`
        /// stick (otherwise both scrollbars show).
        func applySuppression() {
            suppress()
            DispatchQueue.main.async { [weak self] in self?.suppress() }
        }

        func suppress() {
            var current: NSView? = superview
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    // Only what's changed: these setters can resize the clip
                    // view, which the observers below would answer again.
                    if scrollView.scrollerStyle != .overlay {
                        scrollView.scrollerStyle = .overlay
                    }
                    if scrollView.hasVerticalScroller { scrollView.hasVerticalScroller = false }
                    if scrollView.hasHorizontalScroller { scrollView.hasHorizontalScroller = false }
                    if scrollView.verticalScroller?.isHidden == false { scrollView.verticalScroller?.isHidden = true }
                    if scrollView.horizontalScroller?.isHidden == false { scrollView.horizontalScroller?.isHidden = true }
                    observe(scrollView)
                    return
                }
                current = candidate.superview
            }
        }

        /// A scroll view mounted with short content (a sidebar before its rows
        /// load) gets the system scroller back from SwiftUI once the content
        /// outgrows it, long after the mount-time suppression ran. Re-suppress
        /// whenever the content or viewport resizes, or the system's scroller
        /// style changes (a mouse plugged in under "Automatic").
        private func observe(_ scrollView: NSScrollView) {
            guard observedScrollView !== scrollView else { return }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedScrollView = scrollView

            let center = NotificationCenter.default
            let resuppress: @Sendable (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated { self?.applySuppression() }
            }
            scrollView.postsFrameChangedNotifications = true
            observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: scrollView, queue: .main, using: resuppress))
            if let documentView = scrollView.documentView {
                documentView.postsFrameChangedNotifications = true
                observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: documentView, queue: .main, using: resuppress))
            }
            observers.append(center.addObserver(forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main, using: resuppress))
        }
    }
}

// MARK: - Scroll View with Thin Indicator

/// A `ScrollView` that hides the native scroller (even under "Show scroll bars:
/// Always") and draws a thin rounded thumb on a clear track instead, shown while
/// hovering or scrolling. Optional edge fades dissolve rows into whatever sits
/// behind the scroll.
public struct ScrollViewWithThinIndicator<Content: View>: View {
    let axes: Axis.Set
    let showFadeMask: Bool
    /// When true, content gets `.frame(minHeight: viewportHeight)` so a short
    /// content view (e.g. an `EmptyState`) fills the visible scroll area
    /// instead of hugging the top. Short rigid content stays top-aligned; long
    /// content overflows and scrolls as usual. Default `false` preserves prior
    /// behavior for existing callers.
    let fillsViewport: Bool
    /// Top/bottom inset for the scroll thumb — the thumb stops short of the
    /// viewport edges by this much (so it clears rounded window corners). Pass 0
    /// when the scroll fills a flush region (e.g. an app-sheet content area).
    let indicatorTopPadding: CGFloat
    let indicatorBottomPadding: CGFloat
    @ViewBuilder let content: () -> Content

    /// The scroll position and sizes. Only the pieces that draw from them (the
    /// thumb, the fades, the viewport fill) read it, so a scroll or a resize
    /// redraws those and never re-runs `content()`: re-running it rebuilt
    /// every row of a long table on each frame of a sidebar collapse.
    @State private var metrics = ThinScrollMetrics()

    private let indicatorWidth: CGFloat = 6
    private let indicatorMinHeight: CGFloat = 30
    /// Trailing inset — snug to the scroll view's edge.
    private let indicatorPadding: CGFloat = 2
    private let scrollCoordinateSpace = "thinScrollIndicator"
    private let fadeMaskHeight: CGFloat = 24

    public init(
        _ axes: Axis.Set = .vertical,
        showFadeMask: Bool = false,
        fillsViewport: Bool = false,
        indicatorTopPadding: CGFloat = 10,
        indicatorBottomPadding: CGFloat = 10,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showFadeMask = showFadeMask
        self.fillsViewport = fillsViewport
        self.indicatorTopPadding = indicatorTopPadding
        self.indicatorBottomPadding = indicatorBottomPadding
        self.content = content
    }

    public var body: some View {
        ScrollView(axes, showsIndicators: false) {
            content()
                // Inflate to the viewport when `fillsViewport` is on so a short
                // content view fills the visible scroll area.
                .modifier(ViewportFill(isEnabled: fillsViewport && axes.contains(.vertical), metrics: metrics))
                .background { NativeScrollerSuppressor() }
                .background { ScrollMetricsReader(metrics: metrics, coordinateSpace: scrollCoordinateSpace) }
        }
        .scrollIndicators(.hidden)
        // No rubber-band when the content already fits. SwiftUI's default
        // (.automatic) bounces macOS scroll views even at exact fit, so an
        // auto-heighted sheet card (AutoHeightScroll hugs content exactly)
        // let the WHOLE modal bounce on scroll — reading as "the modal is
        // scrollable". Overflowing content still scrolls + bounces.
        .scrollBounceBehavior(.basedOnSize)
        .coordinateSpace(.named(scrollCoordinateSpace))
        // Edge fades — an alpha MASK on the content, not a colored overlay, so
        // rows dissolve into whatever sits behind the scroll view. A colored
        // overlay needs an opaque color matching that surface, and none exists
        // for the macOS 26 dark content pane (a 25% black wash) or a themed one.
        // The thumb overlay below sits outside the mask, so it never fades.
        .modifier(ScrollEdgeFade(isEnabled: showFadeMask, metrics: metrics, height: fadeMaskHeight))
        .overlay(alignment: .trailing) {
            ThinScrollThumb(
                metrics: metrics,
                width: indicatorWidth,
                minimumHeight: indicatorMinHeight,
                trailingPadding: indicatorPadding,
                topPadding: indicatorTopPadding,
                bottomPadding: indicatorBottomPadding
            )
        }
        // Fills the space offered, content at the top leading corner, as the
        // `GeometryReader` this used to sit in did.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { metrics.viewportHeight = $0 }
        .onHover { hovering in
            metrics.isHovering = hovering
        }
    }
}

// MARK: - Scroll metrics

/// Where a `ScrollViewWithThinIndicator` is scrolled to and how big it is.
@Observable
private final class ThinScrollMetrics {
    var scrollOffset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var isScrolling = false
    var isHovering = false
    @ObservationIgnored var scrollEndTask: Task<Void, Never>?

    var needsIndicator: Bool {
        contentHeight > viewportHeight + 1
    }

    /// Top fade strength: grows over the first 20pt scrolled.
    var topFadeOpacity: Double {
        guard needsIndicator else { return 0 }
        let fadeDistance: CGFloat = 20
        return min(max(scrollOffset / fadeDistance, 0), 1)
    }

    /// Bottom fade strength: shrinks over the last 20pt before the end.
    var bottomFadeOpacity: Double {
        guard needsIndicator else { return 0 }
        let maxScroll = contentHeight - viewportHeight
        guard maxScroll > 0 else { return 0 }
        let fadeDistance: CGFloat = 20
        let distanceFromBottom = maxScroll - scrollOffset
        return min(max(distanceFromBottom / fadeDistance, 0), 1)
    }

    /// Records a new offset, shows the thumb, and hides it 0.8s after scrolling stops.
    func scrolled(to newOffset: CGFloat) {
        guard abs(newOffset - scrollOffset) > 0.5 else { return }
        scrollOffset = newOffset
        isScrolling = true
        scrollEndTask?.cancel()
        scrollEndTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            withAnimation(Animations.scrollIndicator) {
                self.isScrolling = false
            }
        }
    }
}

/// Feeds the content's height and scroll position into the metrics.
private struct ScrollMetricsReader: View {
    let metrics: ThinScrollMetrics
    let coordinateSpace: String

    var body: some View {
        GeometryReader { innerGeometry in
            Color.clear
                .onAppear {
                    metrics.contentHeight = innerGeometry.size.height
                }
                .onChange(of: innerGeometry.size.height) { _, newHeight in
                    metrics.contentHeight = newHeight
                }
                .onChange(of: innerGeometry.frame(in: .named(coordinateSpace)).minY) { _, newY in
                    metrics.scrolled(to: -newY)
                }
        }
    }
}

/// `minHeight` of the viewport on the content, when enabled.
private struct ViewportFill: ViewModifier {
    let isEnabled: Bool
    let metrics: ThinScrollMetrics

    func body(content: Content) -> some View {
        content.frame(minHeight: isEnabled ? metrics.viewportHeight : nil, alignment: .top)
    }
}

/// The thin rounded thumb, shown while hovering or scrolling.
private struct ThinScrollThumb: View {
    let metrics: ThinScrollMetrics
    let width: CGFloat
    let minimumHeight: CGFloat
    let trailingPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    private var isVisible: Bool {
        metrics.needsIndicator && (metrics.isHovering || metrics.isScrolling)
    }

    private var height: CGFloat {
        let contentHeight = metrics.contentHeight
        let viewportHeight = metrics.viewportHeight
        guard contentHeight > 0, viewportHeight > 0 else { return minimumHeight }
        let ratio = viewportHeight / contentHeight
        let calculatedHeight = viewportHeight * ratio - (topPadding + bottomPadding)
        return max(minimumHeight, min(calculatedHeight, viewportHeight - (topPadding + bottomPadding)))
    }

    private var offset: CGFloat {
        let contentHeight = metrics.contentHeight
        let viewportHeight = metrics.viewportHeight
        guard contentHeight > viewportHeight, viewportHeight > 0 else { return topPadding }
        let scrollableHeight = contentHeight - viewportHeight
        let trackHeight = viewportHeight - height - (topPadding + bottomPadding)
        guard scrollableHeight > 0, trackHeight > 0 else { return topPadding }
        let progress = min(max(metrics.scrollOffset / scrollableHeight, 0), 1)
        return topPadding + (progress * trackHeight)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(Color.primary.opacity(0.35))
            .frame(width: width, height: height)
            .padding(.top, offset)
            .padding(.trailing, trailingPadding)
            .frame(maxHeight: .infinity, alignment: .top)
            .opacity(isVisible ? 1 : 0)
            .animation(Animations.scrollIndicator, value: isVisible)
            .allowsHitTesting(false)
            .zIndex(1)
    }
}

// MARK: - Edge fade

/// Fades a scroll view's top and bottom edges by masking the content's alpha.
/// The metrics' `topFadeOpacity` / `bottomFadeOpacity` (0…1) are how strong each fade is now —
/// the top one grows as you scroll away from the top, the bottom one shrinks as
/// you reach the end — so an edge with nothing hidden past it stays crisp. The
/// mask is only applied when enabled, so a scroll without fades pays no
/// offscreen-compositing cost.
private struct ScrollEdgeFade: ViewModifier {
    let isEnabled: Bool
    let metrics: ThinScrollMetrics
    let height: CGFloat

    func body(content: Content) -> some View {
        if isEnabled {
            let topOpacity = metrics.topFadeOpacity
            let bottomOpacity = metrics.bottomFadeOpacity
            // Never animated: the strengths already follow the scroll position,
            // and an animated mask is re-rendered into a new texture on every
            // frame at every size of a live resize — ~230MB of graphics memory
            // during a drag, measured.
            content.mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(1 - topOpacity), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: height)
                    Rectangle().fill(.black)
                    LinearGradient(colors: [.black, .black.opacity(1 - bottomOpacity)], startPoint: .top, endPoint: .bottom)
                        .frame(height: height)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Auto-height scroll

private struct AutoHeightContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

/// A `ScrollViewWithThinIndicator` that auto-heights to its content: it measures
/// the content's natural height and caps the scroll to it FROM THE OUTSIDE (so the
/// component reports a bounded, non-greedy size to its parent). Short content hugs
/// (no dead-space envelope); over-tall content scrolls, bounded by whatever
/// constrains the parent — e.g. an app sheet's window cap. This is the proven
/// pattern from option sheets and settings panes, packaged for reuse so any sheet
/// can auto-height by swapping `ScrollViewWithThinIndicator` → `AutoHeightScroll`.
public struct AutoHeightScroll<Content: View>: View {
    var showFadeMask: Bool = false
    /// Hard ceiling on the scroll's height (e.g. the app-sheet window cap). When
    /// content exceeds it the scroll engages; otherwise the scroll hugs content.
    var maxHeight: CGFloat? = nil
    var indicatorTopPadding: CGFloat = 10
    var indicatorBottomPadding: CGFloat = 10
    /// When true, the scroll hugs its content's WIDTH too (the content sets its own
    /// fixed width). A scroll view is otherwise horizontally greedy and would fill
    /// the available width. Off for content that fills a width envelope (the caller
    /// constrains width from outside instead).
    var hugsWidth: Bool = false
    /// Animates the scroll's own resize when its content grows/shrinks. Without
    /// this the exact-height frame SNAPS unless the triggering state change
    /// happened to be inside `withAnimation` — the size lands via a preference →
    /// state set, which is outside the trigger's transaction. The first
    /// measurement is never animated (the initial fill→hug must be instant).
    var resizeAnimation: Animation? = nil
    @ViewBuilder let content: () -> Content

    @State private var contentSize: CGSize = .zero

    public init(
        showFadeMask: Bool = false,
        maxHeight: CGFloat? = nil,
        indicatorTopPadding: CGFloat = 10,
        indicatorBottomPadding: CGFloat = 10,
        hugsWidth: Bool = false,
        resizeAnimation: Animation? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showFadeMask = showFadeMask
        self.maxHeight = maxHeight
        self.indicatorTopPadding = indicatorTopPadding
        self.indicatorBottomPadding = indicatorBottomPadding
        self.hugsWidth = hugsWidth
        self.resizeAnimation = resizeAnimation
        self.content = content
    }

    /// The EXACT height to render at: the content's natural height, clamped to
    /// `maxHeight`. nil before the first measurement (lets the scroll fill so the
    /// content can lay out and report its size). Using an exact height — not
    /// `maxHeight:` — is deliberate: a finite `.frame(maxHeight:)` expands to fill
    /// when its parent proposes more (the app-sheet ZStack proposes the full
    /// window), which is exactly the dead-space bug. An exact height can't.
    private var resolvedHeight: CGFloat? {
        guard contentSize.height > 0 else { return nil }
        if let maxHeight { return min(contentSize.height, maxHeight) }
        return contentSize.height
    }

    private var resolvedWidth: CGFloat? {
        guard hugsWidth, contentSize.width > 0 else { return nil }
        return contentSize.width
    }

    public var body: some View {
        ScrollViewWithThinIndicator(
            showFadeMask: showFadeMask,
            indicatorTopPadding: indicatorTopPadding,
            indicatorBottomPadding: indicatorBottomPadding
        ) {
            content()
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: AutoHeightContentSizeKey.self, value: geometry.size)
                    }
                }
        }
        .frame(width: resolvedWidth, height: resolvedHeight)
        .onPreferenceChange(AutoHeightContentSizeKey.self) { newSize in
            if let resizeAnimation, contentSize != .zero {
                withAnimation(resizeAnimation) { contentSize = newSize }
            } else {
                contentSize = newSize
            }
        }
    }
}


// MARK: - Previews

#Preview("Thin Scroll Indicator") {
    ScrollViewWithThinIndicator {
        VStack(spacing: 8) {
            ForEach(0..<50) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
    }
    .frame(width: 300, height: 400)
}

#Preview("Short Content - No Indicator") {
    ScrollViewWithThinIndicator {
        VStack(spacing: 8) {
            ForEach(0..<3) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
    }
    .frame(width: 300, height: 400)
}

#Preview("With Fade Mask") {
    ScrollViewWithThinIndicator(showFadeMask: true) {
        VStack(spacing: 8) {
            ForEach(0..<50) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding()
    }
    .frame(width: 300, height: 400)
}
