//
//  SlideoutPanel.swift
//  BlissUI
//
//  A panel that slides in over a view's trailing (or leading) edge — a
//  notifications feed, an inspector, recent activity — with a header (title,
//  actions, ✕) over its scrolling content and an optional pinned footer. Esc
//  or a click outside closes it.
//
//  The panel is always mounted and slid off-screen when closed, so opening and
//  closing is a real slide (an animated `offset` + fade) rather than a pop — an
//  `if` with a `.transition` popped. It enters on `Animations.pane` and leaves
//  faster on `Animations.exit`; under Reduce Motion it only fades.
//

import SwiftUI

extension View {
    /// Slides a panel in over this view's `edge` while `isPresented` is true.
    ///
    /// ```swift
    /// PageContent()
    ///     .slideoutPanel(isPresented: $showsNotifications, title: "Notifications") {
    ///         NotificationRows()
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: Whether the panel is in. Esc, the ✕ and a click outside
    ///     set it to false.
    ///   - title: The header, looked up in your app's strings like `Text("…")`.
    ///   - subtitle: A secondary line under the title ("3 unread").
    ///   - edge: The side it slides in from.
    ///   - width: The panel's width.
    ///   - insetsContent: The content's `Spacing.cardPadding` inset; off lets
    ///     `DividedForEach` rows and their hover fills run to the panel's edges.
    ///   - dimsBackground: A scrim over the page while the panel is in, for
    ///     one the user must close before continuing.
    ///   - content: The panel's rows; they scroll under the header.
    public func slideoutPanel<PanelContent: View>(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        edge: HorizontalEdge = .trailing,
        width: CGFloat = Sizing.slideoutPanelWidth,
        insetsContent: Bool = true,
        dimsBackground: Bool = false,
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View {
        slideoutPanel(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            edge: edge,
            width: width,
            insetsContent: insetsContent,
            dimsBackground: dimsBackground,
            content: content,
            actions: { EmptyView() },
            footer: { EmptyView() }
        )
    }

    /// Slides a panel in over this view's `edge`, with `actions` ("Mark all
    /// read") in its header beside the ✕.
    ///
    /// - Parameters:
    ///   - isPresented: Whether the panel is in.
    ///   - title: The header, looked up in your app's strings like `Text("…")`.
    ///   - subtitle: A secondary line under the title.
    ///   - edge: The side it slides in from.
    ///   - width: The panel's width.
    ///   - insetsContent: The content's inset; off for edge-to-edge rows.
    ///   - dimsBackground: A scrim over the page while the panel is in.
    ///   - content: The panel's rows; they scroll under the header.
    ///   - actions: Header controls, before the ✕.
    public func slideoutPanel<PanelContent: View, Actions: View>(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        edge: HorizontalEdge = .trailing,
        width: CGFloat = Sizing.slideoutPanelWidth,
        insetsContent: Bool = true,
        dimsBackground: Bool = false,
        @ViewBuilder content: @escaping () -> PanelContent,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        slideoutPanel(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            edge: edge,
            width: width,
            insetsContent: insetsContent,
            dimsBackground: dimsBackground,
            content: content,
            actions: actions,
            footer: { EmptyView() }
        )
    }

    /// Slides a panel in over this view's `edge`, with header `actions` and a
    /// `footer` pinned under the scrolling content ("Clear all").
    ///
    /// - Parameters:
    ///   - isPresented: Whether the panel is in.
    ///   - title: The header, looked up in your app's strings like `Text("…")`.
    ///   - subtitle: A secondary line under the title.
    ///   - edge: The side it slides in from.
    ///   - width: The panel's width.
    ///   - insetsContent: The content's inset; off for edge-to-edge rows.
    ///   - dimsBackground: A scrim over the page while the panel is in.
    ///   - content: The panel's rows; they scroll under the header.
    ///   - actions: Header controls, before the ✕.
    ///   - footer: A bar pinned under the content, over a hairline.
    public func slideoutPanel<PanelContent: View, Actions: View, Footer: View>(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        edge: HorizontalEdge = .trailing,
        width: CGFloat = Sizing.slideoutPanelWidth,
        insetsContent: Bool = true,
        dimsBackground: Bool = false,
        @ViewBuilder content: @escaping () -> PanelContent,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        modifier(SlideoutPanelModifier(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            edge: edge,
            width: width,
            insetsContent: insetsContent,
            dimsBackground: dimsBackground,
            panelContent: content,
            actions: actions,
            footer: footer
        ))
    }
}

/// The slide-out panel's own numbers.
private enum SlideoutPanelMetrics {
    /// The gap between the panel and the host's edges, so it reads as a card
    /// floating over the page.
    static var inset: CGFloat { Spacing.xxs }
    /// The click-catcher behind an undimmed panel: all but invisible, so a
    /// click outside still lands on it.
    static let clickCatcherOpacity: CGFloat = 0.001
}

private struct SlideoutPanelModifier<PanelContent: View, Actions: View, Footer: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let edge: HorizontalEdge
    let width: CGFloat
    let insetsContent: Bool
    let dimsBackground: Bool
    let panelContent: () -> PanelContent
    let actions: () -> Actions
    let footer: () -> Footer

    /// How far it sits off its edge while closed: its width, its inset, and room
    /// for its shadow.
    private var hiddenOffset: CGFloat {
        let distance = width + SlideoutPanelMetrics.inset + Spacing.xl
        return edge == .trailing ? distance : -distance
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: edge == .trailing ? .trailing : .leading) {
                    // Catches a click outside the panel, which closes it — a
                    // scrim when the panel is modal. Kept conditional since a
                    // Color's opacity transition is reliable.
                    if isPresented {
                        Color.black.opacity(dimsBackground ? Scrim.opacity : SlideoutPanelMetrics.clickCatcherOpacity)
                            .contentShape(Rectangle())
                            .onTapGesture { isPresented = false }
                            .transition(.opacity)
                    }

                    SlideoutPanelCard(
                        title: title,
                        subtitle: subtitle,
                        insetsContent: insetsContent,
                        onClose: { isPresented = false },
                        content: panelContent,
                        actions: actions,
                        footer: footer
                    )
                    .frame(width: width)
                    .padding(SlideoutPanelMetrics.inset)
                    // Scoped to the panel: the page's own changes in the same
                    // transaction keep their timing. Leaves faster than it arrives,
                    // like the menus.
                    .animation(isPresented ? Animations.pane : Animations.exit) { panel in
                        panel
                            .offset(x: isPresented || prefersReducedMotion ? 0 : hiddenOffset)
                            .opacity(isPresented ? 1 : 0)
                    }
                    .allowsHitTesting(isPresented)
                    // Closed, it stays mounted off-screen: keep its buttons out of
                    // the Tab loop and VoiceOver, and its Esc from firing.
                    .disabled(!isPresented)
                    .accessibilityHidden(!isPresented)
                }
                // The panel slides from outside the host; it never draws past it
                // (over a neighboring pane) on the way.
                .clipped()
            }
    }
}

/// The panel itself: header (title, actions, ✕), a hairline, the content
/// scrolling under it and an optional pinned footer, on the control surface
/// with the floating-panel chrome.
private struct SlideoutPanelCard<PanelContent: View, Actions: View, Footer: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let insetsContent: Bool
    let onClose: () -> Void
    let content: () -> PanelContent
    let actions: () -> Actions
    let footer: () -> Footer

    private var cornerRadius: CGFloat { Sizing.radiusLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollViewWithThinIndicator(showFadeMask: true) {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(insetsContent ? Spacing.cardPadding : 0)
            }
            if Footer.self != EmptyView.self {
                Divider()
                HStack(spacing: Spacing.sm) {
                    footer()
                }
                .padding(.horizontal, Spacing.cardPadding)
                .padding(.vertical, Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque: the page must not read through it as it slides over.
        .background(Color.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .elevation(.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(Typography.headingSmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.sm)
            actions()
            // Esc closes it, like a sheet or a menu. Only while it's open: closed,
            // the panel is disabled, and so is the shortcut.
            SheetCloseButton(action: onClose)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.leading, Spacing.cardPadding)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 640, height: 420)) {
    @Previewable @State var isPresented = true
    VStack(alignment: .leading, spacing: Spacing.md) {
        Text(verbatim: "Page content")
            .font(Typography.headingMedium)
        Button("Toggle panel") { isPresented.toggle() }
            .buttonStyle(SecondaryButtonStyle(compact: true))
    }
    .padding(Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.contentAreaBackground)
    .slideoutPanel(isPresented: $isPresented, title: "Notifications", subtitle: "3 unread") {
        DividedForEach(["Build finished", "Backup completed", "Invite accepted"], id: \.self) { item in
            HStack {
                Text(verbatim: item).font(Typography.bodySmall)
                Spacer()
                TimeAgoLabel(date: Date().addingTimeInterval(-3_600)).foregroundStyle(.secondary)
            }
            .rowHover()
        }
    } actions: {
        Button("Mark all read") {}
            .buttonStyle(GhostButtonStyle(compact: true, hugsLabel: true))
    } footer: {
        Spacer()
        Button("Clear all") {}
            .buttonStyle(SecondaryButtonStyle(compact: true))
    }
}
