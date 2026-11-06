//
//  ToastModifiers.swift
//  BlissUI
//
//  `.globalToast()` (the window-level stack fed by `ToastService`), the
//  binding-driven `.toast(_:)` for a single local toast, and `.toastsRestAbove()`.
//

import SwiftUI

// MARK: - View Modifier for easier usage

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    var autoDismissDelay: TimeInterval = 3.0

    func body(content: Content) -> some View {
        content
            .overlay {
                if let toastData = toast {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()

                            // onDismiss gives the pill its ✕: an error or warning
                            // never auto-dismisses, so without it a sheet's
                            // failure toast could only go when the sheet did.
                            ToastNotification(
                                toast: toastData,
                                onDismiss: { toast = nil },
                                onCancel: { toast = nil }
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, Spacing.xl)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .ignoresSafeArea()
                    .transition(.motion(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 10)),
                        removal: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: -10))
                    )))
                    .onAppear {
                        // Auto-dismiss success/info toasts after delay
                        if toastData.style == .success || toastData.style == .info {
                            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                                if toast?.id == toastData.id {
                                    toast = nil
                                }
                            }
                        }
                    }
                    .onChange(of: toastData.style) { _, newStyle in
                        // Auto-dismiss when transitioning to success
                        if newStyle == .success {
                            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                                if toast?.id == toastData.id {
                                    toast = nil
                                }
                            }
                        }
                    }
                }
            }
            .animation(Animations.toast, value: toast?.id)
            .animation(Animations.toast, value: toast?.style)
    }
}

extension View {
    /// Shows one toast at the bottom of this view while `toast` is non-nil — for a
    /// sheet or pane with its own feedback. Success and info toasts clear the
    /// binding after `autoDismissDelay`; the pill's × clears it any time.
    public func toast(_ toast: Binding<ToastData?>, autoDismissDelay: TimeInterval = 3.0) -> some View {
        modifier(ToastModifier(toast: toast, autoDismissDelay: autoDismissDelay))
    }

    /// Apply global toast notifications from ToastService.
    /// Use this at the root view level (e.g., ContentView) to show toasts centered
    /// at the bottom of the window.
    public func globalToast() -> some View {
        modifier(GlobalToastModifier())
    }
}

// MARK: - Global Toast Modifier

/// Modifier that observes ToastService and displays its stack at the window level.
struct GlobalToastModifier: ViewModifier {
    @ObservedObject private var toastService = ToastService.shared

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ToastObstructionKey.self) { obstructions in
                if !toastService.toasts.isEmpty {
                    GeometryReader { geometry in
                        let stackBottomPadding = bottomPadding(clearing: obstructions, in: geometry)
                        VStack {
                            Spacer()

                            ToastStack(toastService: toastService)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.bottom, stackBottomPadding)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        // A bar sliding in under a toast that's already up moves it.
                        .animation(Animations.toast, value: stackBottomPadding)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .animation(Animations.toast, value: toastService.toasts.isEmpty)
    }

    /// The stack's distance from the bottom edge: its usual gap, or enough to
    /// clear a floating bar that sits where the toasts rest. A bar further up
    /// (one riding above a docked bottom panel) isn't in the way and is ignored.
    private func bottomPadding(clearing obstructions: [Anchor<CGRect>], in geometry: GeometryProxy) -> CGFloat {
        let restingTop = geometry.size.height - Self.restingGap - ToastStack.collapsedReach
        let clearances = obstructions
            .map { geometry[$0] }
            .filter { $0.maxY > restingTop }
            .map { geometry.size.height - $0.minY + Spacing.sm }
        return max(Self.restingGap, clearances.max() ?? 0)
    }

    private static let restingGap: CGFloat = Spacing.xl
}

// MARK: - Toast obstructions

/// Bottom-anchored floating bars the toasts must not land on. Each reports its
/// bounds and the stack rests just above whichever sits in its spot.
struct ToastObstructionKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Marks a floating bar pinned to the bottom of the window (e.g. a table's
    /// bulk-action bar) so toasts rest above it instead of on top of it.
    public func toastsRestAbove() -> some View {
        anchorPreference(key: ToastObstructionKey.self, value: .bounds) { [$0] }
    }
}

// MARK: - Toast stack

/// The toasts as a deck of cards: the newest in front, up to two more peeking
/// out above it, each a little smaller. Hovering fans them out into a
/// vertical list — newest at the bottom, every card the same width — and
/// holds their auto-dismiss timers until the pointer leaves.
private struct ToastStack: View {
    @ObservedObject var toastService: ToastService

    @State private var isHovering = false
    @State private var heights: [UUID: CGFloat] = [:]
    @State private var collapseTask: Task<Void, Never>?

    /// Every card's width while there's more than one.
    private static let cardWidth: CGFloat = 440
    /// How much of each card behind shows above the one in front of it.
    private static let peek: CGFloat = 10
    /// Cards shown behind the front one in the collapsed deck.
    private static let visibleBehind = 2
    /// A one-line pill's height, used until a card has been measured.
    private static let pillHeight: CGFloat = 44
    /// How far up a full collapsed deck of one-line pills reaches from its bottom edge.
    static let collapsedReach: CGFloat = pillHeight + peek * CGFloat(visibleBehind)
    /// How much smaller each card behind gets.
    private static let scaleStep: CGFloat = 0.05
    /// Space between cards once they're listed.
    private static let listGap: CGFloat = Spacing.sm

    var body: some View {
        let toasts = toastService.toasts
        let isStacked = toasts.count > 1
        let isListed = isStacked && isHovering

        ZStack(alignment: .bottom) {
            ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
                ToastNotification(
                    toast: toast,
                    onDismiss: { toastService.dismiss(id: toast.id) },
                    onCancel: toastService.isCancellable(toast.id) ? { toastService.cancel(toast.id) } : nil,
                    uniformWidth: isStacked ? Self.cardWidth : nil,
                    isTucked: isStacked && !isListed && index > 0
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    heights[toast.id] = height
                }
                // Scaled from the top so the edge that peeks out stays put.
                .scaleEffect(isListed || index == 0 ? 1 : 1 - Self.scaleStep * CGFloat(min(index, Self.visibleBehind)), anchor: .top)
                .offset(y: offset(of: index, in: toasts, isListed: isListed))
                .opacity(isListed || index <= Self.visibleBehind ? 1 : 0)
                .zIndex(Double(toasts.count - index))
                .allowsHitTesting(isListed || index == 0)
                .transition(.motion(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                )))
            }
        }
        // Laid out at the deck's (or the list's) full height, so the hover region
        // covers every card and the gaps between them — moving from one card to
        // the next never collapses the list.
        .frame(height: height(of: toasts, isListed: isListed), alignment: .bottom)
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        // Removed while hovered (its last toast closed): no hover exit follows.
        .onDisappear {
            collapseTask?.cancel()
            isHovering = false
            toastService.setPaused(false)
        }
        .animation(Animations.toast, value: toasts.map(\.id))
        .animation(Animations.toast, value: isListed)
    }

    private func height(for toast: ToastData) -> CGFloat {
        heights[toast.id] ?? Self.pillHeight
    }

    /// Vertical offset of a card from the stack's bottom edge (negative is up).
    private func offset(of index: Int, in toasts: [ToastData], isListed: Bool) -> CGFloat {
        guard index > 0, let front = toasts.first else { return 0 }
        if isListed {
            let below = toasts[..<index].reduce(0) { $0 + height(for: $1) }
            return -(below + Self.listGap * CGFloat(index))
        }
        // Collapsed: the card's TOP sits a peek above the card in front, whatever
        // either card's height (the front one may be an opened error card).
        let depth = CGFloat(min(index, Self.visibleBehind))
        return height(for: toasts[index]) - height(for: front) - Self.peek * depth
    }

    private func height(of toasts: [ToastData], isListed: Bool) -> CGFloat {
        guard let front = toasts.first else { return 0 }
        if isListed {
            return toasts.reduce(0) { $0 + height(for: $1) } + Self.listGap * CGFloat(toasts.count - 1)
        }
        return height(for: front) + Self.peek * CGFloat(min(toasts.count - 1, Self.visibleBehind))
    }

    private func hoverChanged(_ hovering: Bool) {
        collapseTask?.cancel()
        if hovering {
            isHovering = true
            toastService.setPaused(true)
        } else {
            // A short grace so brushing past the edge doesn't snap the list shut.
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                isHovering = false
                toastService.setPaused(false)
            }
        }
    }
}

#Preview("Toast Container") {
    struct PreviewWrapper: View {
        @State private var toast: ToastData? = .success(
            title: "Success",
            message: "Operation completed"
        )

        var body: some View {
            VStack {
                Text("Main Content")
                Button("Show Toast") {
                    toast = .success(title: "Success", message: "Changes saved")
                }
            }
            .frame(width: 500, height: 400)
            .background(Color.windowBackground)
            .toast($toast)
        }
    }

    return PreviewWrapper()
}
