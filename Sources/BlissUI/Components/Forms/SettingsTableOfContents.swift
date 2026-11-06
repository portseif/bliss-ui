//
//  SettingsTableOfContents.swift
//  BlissUI
//
//  Settings as one long scrolling form with a table of contents beside it:
//  the rail lists the sections, marks the one in view (scroll-spy), and jumps
//  to a section when you pick it. `SettingsScrollView` wires the rail, the form
//  and the spy together; `SettingsTableOfContents` is the rail on its own for a
//  layout that tracks the section itself.
//

import AppKit
import SwiftUI

// MARK: - Item

/// One section in a settings table of contents.
public struct SettingsTableOfContentsItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: LocalizedStringKey
    /// A section with nothing to show (no search matches) dims and can't be picked.
    public var isEnabled: Bool

    /// - Parameters:
    ///   - id: The section's ID — the one its content passes to `.settingsSection(_:)`.
    ///   - title: The rail's label. Looked up in your app's strings.
    ///   - isEnabled: Dims the row and makes it unpickable when false.
    public init(_ id: ID, title: LocalizedStringKey, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
    }
}

// MARK: - Rail

/// A minimal table of contents: a plain text list, one row per section. The
/// active row (the section in view) gets a small accent dot and primary text;
/// the rest are dimmed and brighten on hover. Each row is a Tab stop; picking
/// one calls `onSelect`.
public struct SettingsTableOfContents<ID: Hashable>: View {
    private let items: [SettingsTableOfContentsItem<ID>]
    private let activeID: ID?
    private let onSelect: (ID) -> Void

    /// - Parameters:
    ///   - items: The sections, in form order.
    ///   - activeID: The section in view, marked in the rail.
    ///   - onSelect: A row was picked: scroll the form to that section.
    public init(
        _ items: [SettingsTableOfContentsItem<ID>],
        activeID: ID?,
        onSelect: @escaping (ID) -> Void
    ) {
        self.items = items
        self.activeID = activeID
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(items) { item in
                SettingsTableOfContentsRow(
                    title: item.title,
                    isActive: item.id == activeID,
                    isEnabled: item.isEnabled,
                    action: { onSelect(item.id) }
                )
            }
        }
    }
}

/// One rail row — text only, no fill. A fixed-width leading slot holds the
/// active dot so the text never shifts as it appears.
private struct SettingsTableOfContentsRow: View {
    let title: LocalizedStringKey
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var titleColor: Color {
        if isActive { return .primary }
        return isHovering ? .secondary : Color.secondary.opacity(0.7)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(isActive ? Color.accent : .clear)
                    .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                Text(title)
                    .font(Typography.bodySmall)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 3))
        .opacity(isEnabled ? 1 : 0.3)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        .animation(Animations.selection, value: isActive)
    }
}

// MARK: - Section marker

extension View {
    /// Marks a section of a `SettingsScrollView`'s form: the rail's jump
    /// scrolls to it, and the scroll-spy watches where it sits.
    public func settingsSection<ID: Hashable>(_ id: ID) -> some View {
        self
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SettingsSectionFramesKey.self,
                        value: [AnyHashable(id): geometry.frame(in: .named(SettingsScrollSpy.coordinateSpace))]
                    )
                }
            }
    }
}

/// Live frames of the marked sections, in the form's viewport coordinates —
/// feeds the scroll-spy (`minY` for the section at the top, the last one's
/// `maxY` for the bottom of the scroll) and the jump (how far to scroll).
struct SettingsSectionFramesKey: PreferenceKey {
    static let defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Scroll-spy

/// Which section is "in view": the one at the top of the form. The pure part
/// of the spy, kept apart from the view so it can be tested.
enum SettingsScrollSpy {
    static let coordinateSpace = "blissSettingsScrollView"
    /// How far below the form's top a jump puts a section: past the 24pt edge
    /// fade of `ScrollViewWithThinIndicator`, so the heading isn't dimmed.
    static let jumpMargin: CGFloat = Spacing.xl

    /// A section counts as at the top once its heading is above this line in
    /// the viewport (rather than exactly at 0, which only a jump lands on).
    static let foldLine: CGFloat = 120
    /// The form counts as scrolled once something sits this far above the top.
    static let scrolledThreshold: CGFloat = 8
    /// The bottom latch turns on once the last section's bottom is this far
    /// inside the viewport…
    static let latchOnInset: CGFloat = 8
    /// …and off only once it's this far below the viewport again.
    static let latchOffOverflow: CGFloat = 48

    /// The section at the top: the last one whose top is above the fold line,
    /// else the closest one below it.
    static func topmostSection(in frames: [AnyHashable: CGRect]) -> AnyHashable? {
        frames.filter { $0.value.minY <= foldLine }.max { $0.value.minY < $1.value.minY }?.key
            ?? frames.min { $0.value.minY < $1.value.minY }?.key
    }

    /// The bottom latch. The last section can't scroll to the top, so with the
    /// form scrolled to the bottom it's the one to mark — otherwise the one
    /// before it would stay marked. A hysteresis band (on once its bottom is
    /// well inside the viewport, off only well after it leaves) stops the mark
    /// flickering between the last two as momentum settles. Only when the form
    /// actually overflows (something has scrolled above the top): a short,
    /// fully visible form would otherwise latch the last section.
    static func isAtBottom(
        wasAtBottom: Bool,
        frames: [AnyHashable: CGRect],
        lastSection: AnyHashable?,
        viewportHeight: CGFloat
    ) -> Bool {
        let hasScrolled = frames.values.contains { $0.minY < -scrolledThreshold }
        guard viewportHeight > 0, hasScrolled, let lastSection, let lastFrame = frames[lastSection] else { return false }
        if lastFrame.maxY <= viewportHeight - latchOnInset { return true }
        if lastFrame.maxY > viewportHeight + latchOffOverflow { return false }
        return wasAtBottom
    }
}

// MARK: - Settings Scroll View

/// Settings as one long form with a table of contents on its leading edge.
/// The rail marks the section in view as you scroll and jumps to a section
/// when you pick it; scrolling over the rail scrolls the form. Mark each
/// section in `content` with `.settingsSection(id)`, using the IDs in
/// `sections`:
///
/// ```swift
/// SettingsScrollView(sections: [
///     SettingsTableOfContentsItem(Pane.general, title: "General"),
///     SettingsTableOfContentsItem(Pane.appearance, title: "Appearance"),
/// ]) {
///     VStack(alignment: .leading, spacing: Spacing.xl) {
///         generalSection.settingsSection(Pane.general)
///         appearanceSection.settingsSection(Pane.appearance)
///     }
///     .padding(Spacing.xl)
/// }
/// ```
///
/// The theme picker re-IDs the window's tree, which recreates this view at its
/// top; to keep the place, remember `activeSection` and hand it back through
/// `scrollTarget` in `.onAppear` — the jump waits for that section's layout.
public struct SettingsScrollView<ID: Hashable, Header: View, Content: View>: View {
    private let sections: [SettingsTableOfContentsItem<ID>]
    private let externalActiveSection: Binding<ID?>?
    private let externalScrollTarget: Binding<ID?>?
    private let railWidth: CGFloat
    private let header: Header
    private let content: Content

    @State private var internalActiveSection: ID?
    @State private var internalScrollTarget: ID?
    /// A jump asked for before its section was laid out (a restore on appear);
    /// it fires once the section reports a frame.
    @State private var pendingTarget: ID?
    @State private var viewportHeight: CGFloat = 0
    /// The bottom latch (see `SettingsScrollSpy.isAtBottom`).
    @State private var isAtBottom = false
    /// The form's `NSScrollView` and its sections' last frames: the rail —
    /// short, rarely overflowing — forwards its scroll-wheel events into it,
    /// and a jump scrolls it.
    @State private var formScrollTarget = FormScrollTarget()

    /// - Parameters:
    ///   - sections: The sections, in form order; their IDs match the
    ///     `.settingsSection(_:)` marks in `content`.
    ///   - activeSection: The section in view, written as the form scrolls.
    ///   - scrollTarget: Set a section to jump to it; it's cleared once the
    ///     jump lands.
    ///   - railWidth: The table of contents' width.
    ///   - header: Pinned above the form, beside the rail (a title, a search field).
    ///   - content: The form.
    public init(
        sections: [SettingsTableOfContentsItem<ID>],
        activeSection: Binding<ID?>? = nil,
        scrollTarget: Binding<ID?>? = nil,
        railWidth: CGFloat = 176,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.sections = sections
        self.externalActiveSection = activeSection
        self.externalScrollTarget = scrollTarget
        self.railWidth = railWidth
        self.header = header()
        self.content = content()
    }

    private var activeSection: Binding<ID?> { externalActiveSection ?? $internalActiveSection }
    private var scrollTarget: Binding<ID?> { externalScrollTarget ?? $internalScrollTarget }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
            VStack(alignment: .leading, spacing: 0) {
                header
                form
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let target = scrollTarget.wrappedValue { jump(to: target) }
        }
        .onChange(of: scrollTarget.wrappedValue) { _, target in
            if let target { jump(to: target) }
        }
    }

    private var rail: some View {
        ScrollViewWithThinIndicator {
            SettingsTableOfContents(sections, activeID: activeSection.wrappedValue) { id in
                scrollTarget.wrappedValue = id
            }
            .padding(.vertical, Spacing.lg)
            .padding(.horizontal, Spacing.md)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        // Scrolling anywhere in Settings scrolls the form (the rail itself
        // rarely overflows).
        .background(ScrollWheelForwarder(target: formScrollTarget))
    }

    private var form: some View {
        // The overlay-scroller scroll view, not a raw ScrollView: that reserves a
        // gutter under "Show scroll bars: Always", which shifts a centered form
        // off the header above it.
        ScrollViewWithThinIndicator(showFadeMask: true, fillsViewport: true) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(EnclosingScrollViewBinder(target: formScrollTarget))
        }
        .coordinateSpace(name: SettingsScrollSpy.coordinateSpace)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        .onPreferenceChange(SettingsSectionFramesKey.self) { frames in
            updateActiveSection(frames: frames)
        }
    }

    private func updateActiveSection(frames: [AnyHashable: CGRect]) {
        guard !frames.isEmpty else { return }
        // Kept on the reference, not in state: frames change on every scroll
        // step, and only the active section should re-render the view.
        formScrollTarget.sectionFrames = frames
        let lastSection = sections.last { frames[AnyHashable($0.id)] != nil }.map { AnyHashable($0.id) }
        isAtBottom = SettingsScrollSpy.isAtBottom(
            wasAtBottom: isAtBottom,
            frames: frames,
            lastSection: lastSection,
            viewportHeight: viewportHeight
        )
        let active = isAtBottom ? lastSection : SettingsScrollSpy.topmostSection(in: frames)
        if let active = active?.base as? ID, active != activeSection.wrappedValue {
            activeSection.wrappedValue = active
        }
        // A restore in flight: jump the moment the target is actually laid out
        // (a fixed delay raced heavy sections and could no-op).
        if let pendingTarget, canLand(on: pendingTarget) {
            land(on: pendingTarget)
        }
    }

    private func jump(to target: ID) {
        scrollTarget.wrappedValue = nil
        pendingTarget = target
        Task { @MainActor in
            // A turn of the main loop later at the earliest, once the form's
            // scroll view is in the window and has laid out.
            if canLand(on: target) {
                land(on: target)
                return
            }
            // If the frames don't publish again after this (their first report
            // can come before `onAppear`), jump anyway.
            try? await Task.sleep(for: .milliseconds(250))
            guard pendingTarget == target else { return }
            land(on: target)
        }
    }

    private func canLand(on target: ID) -> Bool {
        viewportHeight > 0
            && formScrollTarget.scrollView != nil
            && formScrollTarget.sectionFrames[AnyHashable(target)] != nil
    }

    /// Scrolls the form's own `NSScrollView` by the section's distance from
    /// the jump margin. `ScrollViewReader` can't take the margin, and it lands
    /// on whichever view carries the ID first — a `ForEach` row of the same ID.
    private func land(on target: ID) {
        pendingTarget = nil
        guard let frame = formScrollTarget.sectionFrames[AnyHashable(target)] else { return }
        formScrollTarget.scroll(by: frame.minY - SettingsScrollSpy.jumpMargin)
    }
}

extension SettingsScrollView where Header == EmptyView {
    /// A settings form with a table of contents and no pinned header.
    public init(
        sections: [SettingsTableOfContentsItem<ID>],
        activeSection: Binding<ID?>? = nil,
        scrollTarget: Binding<ID?>? = nil,
        railWidth: CGFloat = 176,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            sections: sections,
            activeSection: activeSection,
            scrollTarget: scrollTarget,
            railWidth: railWidth,
            header: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Scroll forwarding (rail → form)

/// Holds a weak reference to the form's `NSScrollView` so the rail can forward
/// scroll-wheel events into it. The rail's own scroll view never overflows, so
/// scrolling over it did nothing until this redirect. Also keeps the sections'
/// last frames for a jump.
final class FormScrollTarget {
    weak var scrollView: NSScrollView?
    var sectionFrames: [AnyHashable: CGRect] = [:]

    /// Scrolls the form down by `distance` points (up when negative), clamped
    /// to its content.
    func scroll(by distance: CGFloat) {
        guard let scrollView, let documentView = scrollView.documentView else { return }
        let clipView = scrollView.contentView
        let maximumOffset = max(0, documentView.frame.height - clipView.bounds.height)
        let currentOffset = clipView.bounds.origin.y
        // A flipped document grows downward; a plain one grows upward.
        let proposedOffset = documentView.isFlipped ? currentOffset + distance : currentOffset - distance
        let offset = min(max(proposedOffset, 0), maximumOffset)
        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: offset))
        scrollView.reflectScrolledClipView(clipView)
    }
}

/// Walks up from its backing view to the enclosing `NSScrollView` and records
/// it in the shared target. Placed inside the form's scroll content.
private struct EnclosingScrollViewBinder: NSViewRepresentable {
    let target: FormScrollTarget

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            var current = view?.superview
            while let candidate = current {
                if let scrollView = candidate as? NSScrollView {
                    target.scrollView = scrollView
                    return
                }
                current = candidate.superview
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A transparent backing view that takes scroll-wheel events landing over its
/// frame and forwards them to the form's scroll view. A local event monitor, so
/// the forward happens before the rail's own scroll view sees the event.
private struct ScrollWheelForwarder: NSViewRepresentable {
    let target: FormScrollTarget

    func makeNSView(context: Context) -> ForwarderView { ForwarderView(target: target) }

    func updateNSView(_ nsView: ForwarderView, context: Context) { nsView.target = target }

    final class ForwarderView: NSView {
        var target: FormScrollTarget
        private var monitor: Any?

        init(target: FormScrollTarget) {
            self.target = target
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { removeMonitor() } else { installMonitor() }
        }

        private func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let window = self.window,
                      event.window == window,
                      let scrollView = self.target.scrollView
                else { return event }
                let frameInWindow = self.convert(self.bounds, to: nil)
                guard frameInWindow.contains(event.locationInWindow) else { return event }
                scrollView.scrollWheel(with: event)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { removeMonitor() }
    }
}

// MARK: - Previews

private enum PreviewPane: String, CaseIterable {
    case general = "General", appearance = "Appearance", privacy = "Privacy", advanced = "Advanced"
}

#Preview("Settings scroll view", traits: .fixedLayout(width: 640, height: 360)) {
    SettingsScrollView(sections: PreviewPane.allCases.map {
        SettingsTableOfContentsItem($0, title: LocalizedStringKey($0.rawValue))
    }) {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ForEach(PreviewPane.allCases, id: \.self) { pane in
                RoundedSection(LocalizedStringKey(pane.rawValue), divided: true) {
                    SettingsToggleRow("Show in menu bar", isOn: .constant(true))
                    SettingsToggleRow("Play sounds", detail: "When a task finishes.", isOn: .constant(false))
                    SettingsRow("Version") { Text(verbatim: "1.0").foregroundStyle(.secondary) }
                }
                .settingsSection(pane)
            }
        }
        .padding(Spacing.lg)
    }
}

#Preview("Table of contents", traits: .fixedLayout(width: 200, height: 180)) {
    SettingsTableOfContents(
        PreviewPane.allCases.map { SettingsTableOfContentsItem($0, title: LocalizedStringKey($0.rawValue), isEnabled: $0 != .advanced) },
        activeID: PreviewPane.appearance,
        onSelect: { _ in }
    )
    .padding(Spacing.lg)
}
