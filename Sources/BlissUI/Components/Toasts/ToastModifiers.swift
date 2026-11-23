//
//  ToastModifiers.swift
//  BlissUI
//
//  `.globalToast()` (the window-level stack fed by `ToastService`), the
//  binding-driven `.toast(_:)` for a single local toast, and `.toastsRestAbove()`.
//

import SwiftUI

/// Where the toast stack rests.
public nonisolated enum ToastPosition: Sendable {
    /// Centered over the content pane's bottom edge.
    case bottomCenter
    /// In the bottom trailing corner, Xcode-style.
    case bottomTrailing

    var alignment: Alignment {
        switch self {
        case .bottomCenter: return .bottom
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

// MARK: - View Modifier for easier usage

struct ToastModifier: ViewModifier {
    @Binding var toast: ToastData?
    var autoDismissDelay: TimeInterval = ToastService.defaultAutoDismissDelay

    @State private var dismissTask: Task<Void, Never>?
    @State private var isHovering = false
    /// The timer ran out under the pointer: dismiss once it leaves.
    @State private var expiredWhileHovering = false

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
                            .padding(.bottom, ToastMetrics.restingGap)
                            // Reading the toast holds its timer, as the global stack does.
                            .onHover(perform: hoverChanged)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .ignoresSafeArea()
                    .transition(.motion(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: ToastMetrics.entryScale)).combined(with: .offset(y: ToastMetrics.entryOffset)),
                        removal: .opacity.combined(with: .scale(scale: ToastMetrics.entryScale)).combined(with: .offset(y: -ToastMetrics.entryOffset))
                    )))
                    .onAppear { scheduleDismiss(of: toastData) }
                    // Auto-dismiss when a running toast turns into a result.
                    .onChange(of: toastData.style) { _, _ in scheduleDismiss(of: toastData) }
                    .onDisappear {
                        dismissTask?.cancel()
                        isHovering = false
                        expiredWhileHovering = false
                    }
                }
            }
            .animation(Animations.toast, value: toast?.id)
            .animation(Animations.toast, value: toast?.style)
    }

    /// Success and info toasts leave after the delay — unless the pointer is
    /// on them, in which case they wait for it to leave.
    private func scheduleDismiss(of toastData: ToastData) {
        dismissTask?.cancel()
        expiredWhileHovering = false
        guard toastData.style == .success || toastData.style == .info else { return }
        let id = toastData.id
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoDismissDelay))
            guard !Task.isCancelled, toast?.id == id else { return }
            if isHovering {
                expiredWhileHovering = true
            } else {
                toast = nil
            }
        }
    }

    private func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        if !hovering, expiredWhileHovering {
            expiredWhileHovering = false
            toast = nil
        }
    }
}

extension View {
    /// Shows one toast at the bottom of this view while `toast` is non-nil — for a
    /// sheet or pane with its own feedback. Success and info toasts clear the
    /// binding after `autoDismissDelay` (held while the pointer is on them);
    /// the pill's × clears it any time.
    public func toast(_ toast: Binding<ToastData?>, autoDismissDelay: TimeInterval = ToastService.defaultAutoDismissDelay) -> some View {
        modifier(ToastModifier(toast: toast, autoDismissDelay: autoDismissDelay))
    }

    /// Apply global toast notifications from ToastService.
    /// Use this at the root view level (e.g., ContentView) to show toasts at the
    /// bottom of the window — centered, or in the trailing corner.
    public func globalToast(position: ToastPosition = .bottomCenter) -> some View {
        modifier(GlobalToastModifier(position: position))
    }
}

// MARK: - Metrics

/// The toast cards' geometry, shared by the pill, the stack and the modifiers.
enum ToastMetrics {
    /// A one-line pill: the 20pt status disc plus `verticalPadding` each side.
    static let pillHeight: CGFloat = Sizing.iconMedium + verticalPadding * 2
    /// Above and below the pill's content.
    static let verticalPadding: CGFloat = 10
    /// Above and below a status pill's words, which `pillHeight` then centers.
    static let statusVerticalPadding: CGFloat = Spacing.xs
    /// The sides of a plain action's capsule (Undo).
    static let actionPillPaddingH: CGFloat = Spacing.sm + Spacing.hairline
    /// After the pill's last control (the ✕ carries its own chip padding).
    static let trailingPadding: CGFloat = Spacing.sm + Spacing.hairline
    /// The collapsed pill's corner, finite so it can morph into the card's.
    static let collapsedCornerRadius: CGFloat = pillHeight / 2
    /// The stack's distance from the bottom edge.
    static let restingGap: CGFloat = Spacing.xl
    /// The determinate ring on an in-progress pill, and its stroke.
    static let ringSize: CGFloat = Sizing.inlineIconButton
    static let ringLineWidth: CGFloat = 2.5
    /// The spinner on a detail row.
    static let rowSpinnerSize: CGFloat = Sizing.controlTiny
    static let rowSpinnerLineWidth: CGFloat = 1.5
    /// How tall the expanded card's scrolling regions get before they scroll.
    static let detailItemsScrollHeight: CGFloat = 220
    static let messageScrollHeight: CGFloat = 170
    static let failuresScrollHeight: CGFloat = 200
    /// How long "Copied" shows before the copy button resets.
    static let copiedResetDelay: Duration = .seconds(2)
    /// How much of each card behind shows above the one in front of it.
    static let peek: CGFloat = 10
    /// How much smaller each card behind gets.
    static let scaleStep: CGFloat = 0.05
    /// A short grace after the pointer leaves the stack, so brushing past the
    /// edge doesn't snap the list shut.
    static let hoverGrace: Duration = .milliseconds(220)
    /// A toast's entry: it rises and grows from just under its resting spot.
    static let entryScale: CGFloat = 0.95
    static let entryOffset: CGFloat = 10
}

// MARK: - Global Toast Modifier

/// Modifier that observes ToastService and displays its stack at the window level.
struct GlobalToastModifier: ViewModifier {
    let position: ToastPosition
    private let toastService = ToastService.shared

    init(position: ToastPosition = .bottomCenter) {
        self.position = position
    }

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ToastObstructionKey.self) { obstructions in
                if !toastService.toasts.isEmpty {
                    GeometryReader { geometry in
                        let stackBottomPadding = bottomPadding(clearing: obstructions, in: geometry)
                        VStack {
                            Spacer()

                            ToastStack(toastService: toastService, position: position)
                                .frame(maxWidth: .infinity, alignment: position.alignment)
                                .padding(.bottom, stackBottomPadding)
                                .padding(.trailing, position == .bottomTrailing ? ToastMetrics.restingGap : 0)
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
        let restingTop = geometry.size.height - ToastMetrics.restingGap - ToastStack.collapsedReach
        let clearances = obstructions
            .map { geometry[$0] }
            .filter { $0.maxY > restingTop }
            .map { geometry.size.height - $0.minY + Spacing.sm }
        return max(ToastMetrics.restingGap, clearances.max() ?? 0)
    }
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
    let toastService: ToastService
    let position: ToastPosition

    @State private var isHovering = false
    @State private var heights: [UUID: CGFloat] = [:]
    @State private var collapseTask: Task<Void, Never>?

    /// Cards shown behind the front one in the collapsed deck.
    private static let visibleBehind = 2
    /// How far up a full collapsed deck of one-line pills reaches from its bottom edge.
    static let collapsedReach: CGFloat = ToastMetrics.pillHeight + ToastMetrics.peek * CGFloat(visibleBehind)
    /// Space between cards once they're listed.
    private static let listGap: CGFloat = Spacing.sm

    var body: some View {
        let toasts = toastService.toasts
        let isStacked = toasts.count > 1
        let isListed = isStacked && isHovering

        ZStack(alignment: position.alignment) {
            ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
                ToastNotification(
                    toast: toast,
                    onDismiss: { toastService.dismiss(id: toast.id) },
                    onCancel: toastService.isCancellable(toast.id) ? { toastService.cancel(toast.id) } : nil,
                    uniformWidth: isStacked ? Sizing.toastWidth : nil,
                    isTucked: isStacked && !isListed && index > 0
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    heights[toast.id] = height
                }
                // Scaled from the top so the edge that peeks out stays put.
                .scaleEffect(isListed || index == 0 ? 1 : 1 - ToastMetrics.scaleStep * CGFloat(min(index, Self.visibleBehind)), anchor: .top)
                .offset(y: offset(of: index, in: toasts, isListed: isListed))
                .opacity(isListed || index <= Self.visibleBehind ? 1 : 0)
                .zIndex(Double(toasts.count - index))
                .allowsHitTesting(isListed || index == 0)
                .transition(.motion(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: ToastMetrics.entryScale))
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
        heights[toast.id] ?? ToastMetrics.pillHeight
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
        return height(for: toasts[index]) - height(for: front) - ToastMetrics.peek * depth
    }

    private func height(of toasts: [ToastData], isListed: Bool) -> CGFloat {
        guard let front = toasts.first else { return 0 }
        if isListed {
            return toasts.reduce(0) { $0 + height(for: $1) } + Self.listGap * CGFloat(toasts.count - 1)
        }
        return height(for: front) + ToastMetrics.peek * CGFloat(min(toasts.count - 1, Self.visibleBehind))
    }

    private func hoverChanged(_ hovering: Bool) {
        collapseTask?.cancel()
        if hovering {
            isHovering = true
            toastService.setPaused(true)
        } else {
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: ToastMetrics.hoverGrace)
                guard !Task.isCancelled else { return }
                isHovering = false
                toastService.setPaused(false)
            }
        }
    }
}

#Preview("Toast Container", traits: .fixedLayout(width: 500, height: 400)) {
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
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.windowBackground)
            .toast($toast)
        }
    }

    return PreviewWrapper()
}
