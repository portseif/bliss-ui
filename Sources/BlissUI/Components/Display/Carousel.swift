//
//  Carousel.swift
//  BlissUI
//
//  Pages side by side, one in view: an onboarding tour, a gallery, a run of
//  feature cards. A paging scroll view does the swiping and the snap; arrows
//  over the edges show on hover, page dots sit under it, and the keyboard
//  pages from either. Autoplay is opt-in and stays out of the way: it pauses
//  under the pointer or keyboard focus, and never runs with Reduce Motion.
//

import SwiftUI

// MARK: - Carousel

/// Pages side by side, one in view, with arrows, page dots and keyboard paging.
///
/// ```swift
/// Carousel(features, selection: $featureID, autoplayInterval: 6) { feature in
///     FeatureCard(feature)
/// }
/// ```
///
/// Trackpad swipes page (`.scrollTargetBehavior(.paging)`), the arrows show
/// while the pointer is over the carousel, and with the carousel focused ←/→
/// page and Home/End jump. The dots are a `PageControl`.
public struct Carousel<Data: RandomAccessCollection, ID: Hashable, Page: View>: View where Data.Element: Identifiable, ID == Data.Element.ID {
    private let data: Data
    private let selection: Binding<ID>?
    private let showsArrows: Bool
    private let showsPageControl: Bool
    private let autoplayInterval: TimeInterval?
    private let cornerRadius: CGFloat
    private let loops: Bool
    private let pageSpacing: CGFloat
    private let page: (Data.Element) -> Page

    /// The page in view when the caller keeps no selection of their own.
    @State private var internalSelection: ID?
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    /// - Parameters:
    ///   - data: The pages, in order.
    ///   - selection: The id of the page in view; nil keeps it inside.
    ///   - showsArrows: Previous and next buttons over the edges while hovered.
    ///   - showsPageControl: The dots under the pages.
    ///   - autoplayInterval: Seconds between automatic pages (wrapping to the
    ///     first); nil for none. Paused under the pointer or keyboard focus,
    ///     and off under Reduce Motion.
    ///   - cornerRadius: The pages' clip; 0 for a full-bleed hero.
    ///   - loops: The arrows and keys wrap at the ends instead of disabling.
    ///   - pageSpacing: A gap between pages.
    ///   - page: One page's content; it fills the carousel's width.
    public init(
        _ data: Data,
        selection: Binding<ID>? = nil,
        showsArrows: Bool = true,
        showsPageControl: Bool = true,
        autoplayInterval: TimeInterval? = nil,
        cornerRadius: CGFloat = Sizing.radiusLarge,
        loops: Bool = false,
        pageSpacing: CGFloat = 0,
        @ViewBuilder page: @escaping (Data.Element) -> Page
    ) {
        self.data = data
        self.selection = selection
        self.showsArrows = showsArrows
        self.showsPageControl = showsPageControl
        self.autoplayInterval = autoplayInterval
        self.cornerRadius = cornerRadius
        self.loops = loops
        self.pageSpacing = pageSpacing
        self.page = page
    }

    // MARK: Position

    private var ids: [ID] { data.map(\.id) }

    private var currentID: ID? {
        selection?.wrappedValue ?? internalSelection ?? ids.first
    }

    private var currentIndex: Int {
        guard let currentID, let index = ids.firstIndex(of: currentID) else { return 0 }
        return index
    }

    /// What the scroll view reads and writes: the caller's selection, or the
    /// internal one. A swipe that settles on a page lands here too.
    private var position: Binding<ID?> {
        Binding(
            get: { currentID },
            set: { newValue in
                guard let newValue else { return }
                if let selection {
                    selection.wrappedValue = newValue
                } else {
                    internalSelection = newValue
                }
            }
        )
    }

    private var isPaused: Bool {
        isHovering || isFocused || prefersReducedMotion
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            pages
                .overlay { if showsArrows { arrows } }
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .focusRing(isFocused: isFocused, cornerRadius: cornerRadius)
                .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
                    move(press.key)
                    return .handled
                }
                .onHover { isHovering = $0 }
                .animation(Animations.hover, value: isHovering)
                .accessibilityElement(children: .contain)

            if showsPageControl && ids.count > 1 {
                PageControl(count: ids.count, current: Binding(get: { currentIndex }, set: { go(to: $0) }))
            }
        }
        .task(id: AutoplayKey(interval: autoplayInterval, isPaused: isPaused)) {
            await autoplay()
        }
    }

    private var pages: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: pageSpacing) {
                ForEach(data) { element in
                    page(element)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
            // Under "Show scroll bars: Always" the legacy scroller ignores
            // `.scrollIndicators(.hidden)` and draws over the page.
            .background(NativeScrollerSuppressor())
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: position)
        .scrollIndicators(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Previous and next over the page edges: visible under the pointer, and
    /// disabled while hidden so Tab never lands on them unseen.
    private var arrows: some View {
        HStack {
            arrow(systemImage: "chevron.left", label: Text("Previous page", bundle: .module), isEnabled: loops || currentIndex > 0) {
                go(to: currentIndex - 1)
            }
            Spacer(minLength: 0)
            arrow(systemImage: "chevron.right", label: Text("Next page", bundle: .module), isEnabled: loops || currentIndex < ids.count - 1) {
                go(to: currentIndex + 1)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .opacity(isHovering ? 1 : 0)
        .disabled(!isHovering)
        .allowsHitTesting(isHovering)
    }

    private func arrow(systemImage: String, label: Text, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(ToolbarIconButtonStyle())
        // A surface under the glyph, so it reads over whatever the page shows.
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(Color.controlBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                }
        }
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    // MARK: Paging

    private func move(_ key: KeyEquivalent) {
        switch key {
        case .leftArrow: go(to: currentIndex - 1)
        case .rightArrow: go(to: currentIndex + 1)
        case .home: go(to: 0)
        default: go(to: ids.count - 1)
        }
    }

    private func go(to index: Int) {
        // Looping wraps either end; otherwise a step past the ends is ignored.
        let index = loops && !ids.isEmpty ? (index + ids.count) % ids.count : index
        guard ids.indices.contains(index), index != currentIndex else { return }
        let target = ids[index]
        if prefersReducedMotion {
            position.wrappedValue = target
        } else {
            withAnimation(Animations.pane) { position.wrappedValue = target }
        }
    }

    /// Advances every `autoplayInterval` seconds, wrapping to the first page.
    /// The task restarts when the pause state changes and ends on disappear.
    private func autoplay() async {
        guard let autoplayInterval, !isPaused, ids.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(autoplayInterval))
            guard !Task.isCancelled else { return }
            go(to: (currentIndex + 1) % ids.count)
        }
    }
}

/// Restarts the autoplay task when the interval or the pause state changes.
private struct AutoplayKey: Hashable {
    let interval: TimeInterval?
    let isPaused: Bool
}

// MARK: - Page Control

/// A row of dots, one per page, the current one in the accent. One Tab stop:
/// ←/→ move, Home/End jump, and a click on a dot goes there. VoiceOver gets an
/// adjustable element ("Page 2 of 5").
public struct PageControl: View {
    private let count: Int
    @Binding private var current: Int

    @FocusState private var isFocused: Bool

    /// How faint an inactive dot is.
    private static let inactiveOpacity: Double = 0.2

    /// - Parameters:
    ///   - count: How many pages there are.
    ///   - current: The page in view, zero-based.
    public init(count: Int, current: Binding<Int>) {
        self.count = max(count, 0)
        self._current = current
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.accent : Color.primary.opacity(Self.inactiveOpacity))
                    .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                    // A hit target bigger than the dot.
                    .contentShape(Circle().inset(by: -Spacing.xxs))
                    .onTapGesture { set(index) }
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .contentShape(Capsule())
        .animation(Animations.selection, value: current)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .focusRingCapsule(isFocused: isFocused)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .home, .end], phases: [.down, .repeat]) { press in
            switch press.key {
            case .leftArrow: set(current - 1)
            case .rightArrow: set(current + 1)
            case .home: set(0)
            default: set(count - 1)
            }
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(current + 1) of \(count)", bundle: .module))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(current + 1)
            case .decrement: set(current - 1)
            @unknown default: break
            }
        }
    }

    private func set(_ index: Int) {
        guard index >= 0, index < count, index != current else { return }
        current = index
    }
}

// MARK: - Preview

private struct CarouselPreviewPage: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let systemImage: String
    let wash: Color
}

#Preview("Carousel", traits: .fixedLayout(width: 520, height: 320)) {
    @Previewable @State var pageID = 1
    let pages = [
        CarouselPreviewPage(id: 1, title: "Welcome", detail: "A tour of what's new in this release.", systemImage: "sparkles", wash: StatusWash.fill(Success.success500, .light)),
        CarouselPreviewPage(id: 2, title: "Sync", detail: "Your projects follow you to every Mac.", systemImage: "arrow.triangle.2.circlepath", wash: StatusWash.fill(Info.info500, .light)),
        CarouselPreviewPage(id: 3, title: "Shortcuts", detail: "Hold ⌘ to see every row's key.", systemImage: "command", wash: StatusWash.fill(Warning.warning500, .light)),
        CarouselPreviewPage(id: 4, title: "Themes", detail: "Four built in, and room for your own.", systemImage: "paintpalette", wash: StatusWash.fill(Danger.danger500, .light)),
    ]
    Carousel(pages, selection: $pageID) { page in
        VStack(spacing: Spacing.sm) {
            Image(systemName: page.systemImage)
                .font(Typography.displaySmall)
                .foregroundStyle(.secondary)
            Text(verbatim: page.title)
                .font(Typography.headingMedium)
            Text(verbatim: page.detail)
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(page.wash)
    }
    .frame(height: 240)
    .padding(Spacing.xl)
}
