//
//  SlideoutPanel.swift
//  BlissUI
//
//  A panel that slides in over a view's trailing (or leading) edge — a
//  notifications feed, an inspector, recent activity — with a header (title,
//  actions, ✕) over its scrolling content. Esc or a click outside closes it.
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
    ///   - edge: The side it slides in from.
    ///   - width: The panel's width.
    ///   - content: The panel's rows; they scroll under the header.
    public func slideoutPanel<PanelContent: View>(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        edge: HorizontalEdge = .trailing,
        width: CGFloat = 340,
        @ViewBuilder content: @escaping () -> PanelContent
    ) -> some View {
        slideoutPanel(isPresented: isPresented, title: title, edge: edge, width: width, content: content) {
            EmptyView()
        }
    }

    /// Slides a panel in over this view's `edge`, with `actions` ("Mark all
    /// read") in its header beside the ✕.
    ///
    /// - Parameters:
    ///   - isPresented: Whether the panel is in.
    ///   - title: The header, looked up in your app's strings like `Text("…")`.
    ///   - edge: The side it slides in from.
    ///   - width: The panel's width.
    ///   - content: The panel's rows; they scroll under the header.
    ///   - actions: Header controls, before the ✕.
    public func slideoutPanel<PanelContent: View, Actions: View>(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        edge: HorizontalEdge = .trailing,
        width: CGFloat = 340,
        @ViewBuilder content: @escaping () -> PanelContent,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        modifier(SlideoutPanelModifier(
            isPresented: isPresented,
            title: title,
            edge: edge,
            width: width,
            panelContent: content,
            actions: actions
        ))
    }
}

private struct SlideoutPanelModifier<PanelContent: View, Actions: View>: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let edge: HorizontalEdge
    let width: CGFloat
    let panelContent: () -> PanelContent
    let actions: () -> Actions

    /// The gap between the panel and the host's edges, so it reads as a card
    /// floating over the page.
    private static var inset: CGFloat { Spacing.xxs }

    /// How far it sits off its edge while closed: its width, its inset, and room
    /// for its shadow.
    private var hiddenOffset: CGFloat {
        let distance = width + Self.inset + Spacing.xl
        return edge == .trailing ? distance : -distance
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: edge == .trailing ? .trailing : .leading) {
                    // Catches a click outside the panel, which closes it. Kept
                    // conditional since a Color's opacity transition is reliable.
                    if isPresented {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { isPresented = false }
                            .transition(.opacity)
                    }

                    SlideoutPanelCard(
                        title: title,
                        onClose: { isPresented = false },
                        content: panelContent,
                        actions: actions
                    )
                    .frame(width: width)
                    .padding(Self.inset)
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

/// The panel itself: header (title, actions, ✕), a hairline, and the content
/// scrolling under it, on the content surface with a hairline border.
private struct SlideoutPanelCard<PanelContent: View, Actions: View>: View {
    let title: LocalizedStringKey
    let onClose: () -> Void
    let content: () -> PanelContent
    let actions: () -> Actions

    @Environment(\.colorScheme) private var colorScheme

    private var cornerRadius: CGFloat { Sizing.radiusLarge + 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollViewWithThinIndicator(showFadeMask: true) {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque: the page must not read through it as it slides over.
        .background(Color.contentAreaBackground)
        .background(Color.appShell)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 16, x: 0, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(Typography.headingSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.sm)
            actions()
            // Esc closes it, like a sheet or a menu. Only while it's open: closed,
            // the panel is disabled, and so is the shortcut.
            SheetCloseButton(action: onClose, verticalOffset: 0)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.leading, Spacing.md)
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
    .slideoutPanel(isPresented: $isPresented, title: "Notifications") {
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
            .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 3))
            .font(Typography.labelSmall)
            .foregroundStyle(Color.accent)
    }
}
