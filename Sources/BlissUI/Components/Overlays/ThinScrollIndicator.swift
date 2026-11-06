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
                    if scrollView.scrollerStyle != .overlay {
                        scrollView.scrollerStyle = .overlay
                    }
                    scrollView.hasVerticalScroller = false
                    scrollView.hasHorizontalScroller = false
                    scrollView.verticalScroller?.isHidden = true
                    scrollView.horizontalScroller?.isHidden = true
                    return
                }
                current = candidate.superview
            }
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

    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isScrolling = false
    @State private var isHovering = false
    @State private var scrollEndTask: Task<Void, Never>?

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

    private var needsIndicator: Bool {
        contentHeight > viewportHeight + 1
    }

    private var isIndicatorVisible: Bool {
        needsIndicator && (isHovering || isScrolling)
    }

    /// Opacity for top fade mask - fades in as user scrolls down
    private var topFadeOpacity: Double {
        guard showFadeMask, needsIndicator else { return 0 }
        // Fade in over first 20 pixels of scroll
        let fadeDistance: CGFloat = 20
        return min(max(scrollOffset / fadeDistance, 0), 1)
    }

    /// Opacity for bottom fade mask - fades out as user approaches bottom
    private var bottomFadeOpacity: Double {
        guard showFadeMask, needsIndicator else { return 0 }
        let maxScroll = contentHeight - viewportHeight
        guard maxScroll > 0 else { return 0 }
        // Fade out over last 20 pixels of scroll
        let fadeDistance: CGFloat = 20
        let distanceFromBottom = maxScroll - scrollOffset
        return min(max(distanceFromBottom / fadeDistance, 0), 1)
    }

    private var indicatorHeight: CGFloat {
        guard contentHeight > 0, viewportHeight > 0 else { return indicatorMinHeight }
        let ratio = viewportHeight / contentHeight
        let calculatedHeight = viewportHeight * ratio - (indicatorTopPadding + indicatorBottomPadding)
        return max(indicatorMinHeight, min(calculatedHeight, viewportHeight - (indicatorTopPadding + indicatorBottomPadding)))
    }

    private var indicatorOffset: CGFloat {
        guard contentHeight > viewportHeight, viewportHeight > 0 else { return indicatorTopPadding }
        let scrollableHeight = contentHeight - viewportHeight
        let trackHeight = viewportHeight - indicatorHeight - (indicatorTopPadding + indicatorBottomPadding)
        guard scrollableHeight > 0, trackHeight > 0 else { return indicatorTopPadding }
        let progress = min(max(scrollOffset / scrollableHeight, 0), 1)
        return indicatorTopPadding + (progress * trackHeight)
    }

    public var body: some View {
        GeometryReader { outerGeometry in
            ScrollView(axes, showsIndicators: false) {
                content()
                    // Inflate to viewport when `fillsViewport` is on so a
                    // short content view fills the visible scroll area.
                    // `outerGeometry.size.height` is the live viewport size
                    // from the surrounding `GeometryReader`.
                    .frame(
                        minHeight: fillsViewport && axes.contains(.vertical) ? outerGeometry.size.height : nil,
                        alignment: .top
                    )
                    .background(NativeScrollerSuppressor())
                    .background(
                        GeometryReader { innerGeometry in
                            Color.clear
                                .onAppear {
                                    contentHeight = innerGeometry.size.height
                                }
                                .onChange(of: innerGeometry.size.height) { _, newHeight in
                                    contentHeight = newHeight
                                }
                                .onChange(of: innerGeometry.frame(in: .named(scrollCoordinateSpace)).minY) { _, newY in
                                    let newOffset = -newY
                                    let previousOffset = scrollOffset

                                    if abs(newOffset - previousOffset) > 0.5 {
                                        scrollOffset = newOffset
                                        isScrolling = true
                                        scrollEndTask?.cancel()
                                        scrollEndTask = Task {
                                            try? await Task.sleep(for: .milliseconds(800))
                                            guard !Task.isCancelled else { return }
                                            await MainActor.run {
                                                withAnimation(Animations.scrollIndicator) {
                                                    isScrolling = false
                                                }
                                            }
                                        }
                                    }
                                }
                        }
                    )
            }
            .scrollIndicators(.hidden)
            // No rubber-band when the content already fits. SwiftUI's default
            // (.automatic) bounces macOS scroll views even at exact fit, so an
            // auto-heighted sheet card (AutoHeightScroll hugs content exactly)
            // let the WHOLE modal bounce on scroll — reading as "the modal is
            // scrollable". Overflowing content still scrolls + bounces.
            .scrollBounceBehavior(.basedOnSize)
            .coordinateSpace(name: scrollCoordinateSpace)
            .onChange(of: outerGeometry.size.height) { _, newHeight in
                viewportHeight = newHeight
            }
            .onAppear {
                viewportHeight = outerGeometry.size.height
            }
            // Edge fades — an alpha MASK on the content, not a colored overlay, so
            // rows dissolve into whatever sits behind the scroll view. A colored
            // overlay needs an opaque color matching that surface, and none exists
            // for the macOS 26 dark content pane (a 25% black wash) or a themed one.
            // The thumb overlay below sits outside the mask, so it never fades.
            .modifier(ScrollEdgeFade(
                isEnabled: showFadeMask,
                topOpacity: topFadeOpacity,
                bottomOpacity: bottomFadeOpacity,
                height: fadeMaskHeight
            ))
            .overlay(alignment: .trailing) {
                // Thin scroll indicator — outside the fade mask so it never dims
                RoundedRectangle(cornerRadius: indicatorWidth / 2)
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: indicatorWidth, height: indicatorHeight)
                    .padding(.top, indicatorOffset)
                    .padding(.trailing, indicatorPadding)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .opacity(isIndicatorVisible ? 1 : 0)
                    .animation(Animations.scrollIndicator, value: isIndicatorVisible)
                    .allowsHitTesting(false)
                    .zIndex(1)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Edge fade

/// Fades a scroll view's top and bottom edges by masking the content's alpha.
/// `topOpacity` / `bottomOpacity` (0…1) are how strong each fade is right now —
/// the top one grows as you scroll away from the top, the bottom one shrinks as
/// you reach the end — so an edge with nothing hidden past it stays crisp. The
/// mask is only applied when enabled, so a scroll without fades pays no
/// offscreen-compositing cost.
private struct ScrollEdgeFade: ViewModifier {
    let isEnabled: Bool
    let topOpacity: Double
    let bottomOpacity: Double
    let height: CGFloat

    func body(content: Content) -> some View {
        if isEnabled {
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
                    .cornerRadius(8)
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
                    .cornerRadius(8)
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
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .frame(width: 300, height: 400)
}
