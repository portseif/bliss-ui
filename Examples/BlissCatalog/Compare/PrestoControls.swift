//
//  PrestoControls.swift
//  BlissCatalog
//
//  Copies of Presto's controls, for the "Presto vs Bliss" page only. Each one
//  keeps Presto's sizes, corners, spacing and motion, and takes its colors from
//  BlissUI's tokens, so the comparison shows the controls' shape and feel
//  rather than the two apps' palettes. Presto's Geist type is not bundled
//  here; the same sizes are set in the system font, at BlissUI's regular
//  weight.
//
//  The bare numbers are Presto's metrics, kept on purpose so the comparison is
//  faithful. Whichever control wins moves into the library on its tokens.
//

import BlissUI
import SwiftUI

// MARK: - Look

/// Presto's color roles, mapped onto BlissUI's surface and status tokens.
enum PrestoLook {
    /// The dialog card.
    static var panel: Color { Color.windowBackground }
    /// Menus, toasts and other raised surfaces.
    static var raised: Color { Color.controlBackground }
    /// The well a field sits in.
    static var canvas: Color { Color.restingFill }
    static var line: Color { Color.menuBorder }
    static var ink: Color { Color.primary }
    static var muted: Color { Color.secondary }
    static var faint: Color { Color.primary.opacity(0.45) }
    static var accent: Color { Color.accent }
    static var accentInk: Color { AccentHue.contrastForeground }
    static var accentSoft: Color { Color.accent.opacity(0.12) }
    static var danger: Color { Danger.danger500 }
    /// The deep danger tone a solid fill with white text uses.
    static var dangerFill: Color { Danger.tint }
    static var success: Color { Success.success500 }

    /// Presto's ease-out for anything that opens or moves.
    static let easeOutStrong = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// Regular, as every BlissUI text token is: Presto's semibold buttons and
    /// titles and medium menu and key labels are drawn at BlissUI's weight.
    static func ui(_ size: CGFloat) -> Font {
        .system(size: size)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

/// Shrinks a little while pressed, as every Presto button does.
struct PrestoPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .pointerStyle(.link)
    }
}

// MARK: - Buttons

/// Presto's 32 pt dialog buttons: an accent fill for the step to take, a red
/// fill for one that deletes, an outline for the rest.
struct PrestoButtonStyle: ButtonStyle {
    enum Kind {
        case secondary, prominent, destructive
    }

    var kind = Kind.secondary
    var height: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        PrestoButtonLabel(configuration: configuration, kind: kind, height: height)
            .pointerStyle(.link)
    }
}

private struct PrestoButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let kind: PrestoButtonStyle.Kind
    let height: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        configuration.label
            .font(PrestoLook.ui(12))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background {
                switch kind {
                case .prominent:
                    shape.fill(PrestoLook.accent.opacity(isHovered && isEnabled ? 0.92 : 1))
                case .destructive:
                    shape.fill(PrestoLook.dangerFill.opacity(isHovered && isEnabled ? 0.92 : 1))
                case .secondary:
                    shape.fill(isHovered && isEnabled ? RowTint.hover(scheme) : .clear)
                    shape.strokeBorder(PrestoLook.line)
                }
            }
            .contentShape(.rect)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        switch kind {
        case .prominent: PrestoLook.accentInk
        case .destructive: .white
        case .secondary: PrestoLook.ink
        }
    }
}

/// The X in a dialog's corner, which Escape presses too.
struct PrestoCloseButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHovered ? PrestoLook.ink : PrestoLook.muted)
                .frame(width: 32, height: 32)
                .background(isHovered ? RowTint.hover(scheme) : .clear, in: .rect(cornerRadius: 8))
                .contentShape(.rect)
        }
        .buttonStyle(PrestoPressableStyle())
        .keyboardShortcut(.cancelAction)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text("Close"))
        // Tucked into the corner, out past the card's 20 pt padding, without
        // moving the title beside it.
        .offset(x: 8, y: -8)
    }
}

// MARK: - Dialogs

/// A bold heading over a line of explanation, at the top of a dialog.
struct PrestoSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(PrestoLook.ui(16))
                .foregroundStyle(PrestoLook.ink)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: detail)
                .font(PrestoLook.ui(12))
                .foregroundStyle(PrestoLook.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The dialog card's chrome: the panel, a 16 pt corner, a hairline and a deep
/// shadow.
struct PrestoDialogCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(PrestoLook.panel, in: .rect(cornerRadius: 16))
            .clipShape(.rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(PrestoLook.line) }
            .shadow(color: .black.opacity(0.5), radius: 32, y: 24)
    }
}

/// What a confirmation asks: a question, what happens, and the step's name.
struct PrestoConfirmation: Equatable {
    var title: String
    var detail: String
    var note: String?
    var confirmTitle: String
    var isDestructive = true
    /// The toast, with Undo, once it's confirmed.
    var doneMessage: String
}

/// A confirmation laid out as Presto's Delete dialog: the question and its
/// detail beside the X, an optional note, and Cancel beside the step.
struct PrestoConfirmDialog: View {
    let confirmation: PrestoConfirmation
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                PrestoSectionHeader(title: confirmation.title, detail: confirmation.detail)
                Spacer(minLength: 12)
                PrestoCloseButton(action: onClose)
            }
            if let note = confirmation.note {
                Text(verbatim: note)
                    .font(PrestoLook.ui(12))
                    .foregroundStyle(PrestoLook.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onClose)
                    .buttonStyle(PrestoButtonStyle())
                Button(confirmation.confirmTitle, action: onConfirm)
                    .buttonStyle(PrestoButtonStyle(kind: confirmation.isDestructive ? .destructive : .prominent))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
    }
}

// MARK: - Toasts

/// One Presto toast: the message, with Undo, or a red mark for a problem.
struct PrestoToast: Identifiable, Equatable {
    var id = UUID()
    var message: String
    var isProblem = false
    var canUndo = false
}

/// Presto's toast card: a 20 pt-cornered capsule with the message, and Undo or
/// a close X. Stacked, it takes the stack's one width, and a card tucked behind
/// the front one hides its words.
struct PrestoToastView: View {
    let toast: PrestoToast
    var uniformWidth: CGFloat?
    var isTucked = false
    let onUndo: () -> Void
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var isUndoHovered = false

    var body: some View {
        sized
            .frame(minHeight: 40)
            .background(PrestoLook.raised.opacity(0.97), in: .rect(cornerRadius: 20, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PrestoLook.line) }
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }

    @ViewBuilder
    private var sized: some View {
        if let uniformWidth {
            row.frame(width: uniformWidth, alignment: .leading)
        } else {
            row.frame(maxWidth: 520).fixedSize()
        }
    }

    private var row: some View {
        HStack(spacing: 10) {
            if toast.isProblem {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(PrestoLook.danger)
                    .accessibilityHidden(true)
            }
            Text(verbatim: toast.message)
                .font(PrestoLook.ui(12.5))
                .foregroundStyle(PrestoLook.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: uniformWidth == nil ? nil : .infinity, alignment: .leading)
            if toast.canUndo {
                Button(action: onUndo) {
                    Text("Undo")
                        .font(PrestoLook.ui(12))
                        .foregroundStyle(isUndoHovered ? PrestoLook.ink : PrestoLook.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(RowTint.selected(scheme), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(PrestoPressableStyle())
                .onHover { isUndoHovered = $0 }
            } else {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PrestoLook.faint)
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(PrestoPressableStyle())
                .accessibilityLabel(Text("Close"))
            }
        }
        .padding(.leading, toast.isProblem ? 12 : 16)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .opacity(isTucked ? 0 : 1)
    }
}

/// Presto's toasts with BlissUI's toast behavior, copied from `ToastService`
/// (whose stack and pause are internal to the library): newest on top of a
/// stack of at most five, a toast with an id that's up updates in place, and
/// plain toasts leave after `ToastService.defaultAutoDismissDelay` while a
/// problem stays until it's closed. The pointer over the stack holds the
/// timers.
@Observable
final class PrestoToasts {
    static let shared = PrestoToasts()

    /// Newest first: index 0 is the front card.
    private(set) var toasts: [PrestoToast] = []
    @ObservationIgnored private var autoDismissTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var isPaused = false
    @ObservationIgnored private var expiredWhilePaused: Set<UUID> = []

    private static let maxToasts = ToastService.maxToasts

    func show(_ toast: PrestoToast) {
        if let index = toasts.firstIndex(where: { $0.id == toast.id }) {
            toasts[index] = toast
        } else {
            toasts.insert(toast, at: 0)
            while toasts.count > Self.maxToasts, let oldest = toasts.last {
                dismiss(id: oldest.id)
            }
        }
        autoDismissTasks.removeValue(forKey: toast.id)?.cancel()
        expiredWhilePaused.remove(toast.id)
        guard !toast.isProblem else { return }
        let id = toast.id
        autoDismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ToastService.defaultAutoDismissDelay))
            guard !Task.isCancelled, let self else { return }
            if self.isPaused {
                self.expiredWhilePaused.insert(id)
            } else {
                self.dismiss(id: id)
            }
        }
    }

    func dismiss(id: UUID) {
        autoDismissTasks.removeValue(forKey: id)?.cancel()
        expiredWhilePaused.remove(id)
        toasts.removeAll { $0.id == id }
        if toasts.isEmpty {
            isPaused = false
            expiredWhilePaused.removeAll()
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        guard !paused else { return }
        for id in expiredWhilePaused { dismiss(id: id) }
    }
}

/// BlissUI's toast stack, with Presto's cards: the newest in front, up to two
/// more peeking out above it, each a little smaller. Hovering fans them out
/// into a list, newest at the bottom and every card one width, and holds their
/// timers until the pointer leaves.
struct PrestoToastStack: View {
    let center: PrestoToasts

    @State private var isHovering = false
    @State private var heights: [UUID: CGFloat] = [:]
    @State private var collapseTask: Task<Void, Never>?

    /// BlissUI's `ToastMetrics`, which the library keeps internal.
    private enum StackMetrics {
        static let visibleBehind = 2
        static let peek: CGFloat = 10
        static let scaleStep: CGFloat = 0.05
        static let entryScale: CGFloat = 0.95
        static let hoverGrace: Duration = .milliseconds(220)
        static let listGap: CGFloat = Spacing.sm
        /// Presto's one-line toast.
        static let pillHeight: CGFloat = 40
    }

    var body: some View {
        let toasts = center.toasts
        let isStacked = toasts.count > 1
        let isListed = isStacked && isHovering

        ZStack(alignment: .bottom) {
            ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
                card(toast, at: index, in: toasts, isListed: isListed)
            }
        }
        .frame(height: height(of: toasts, isListed: isListed), alignment: .bottom)
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        .onDisappear {
            collapseTask?.cancel()
            isHovering = false
            center.setPaused(false)
        }
        .animation(Animations.toast, value: toasts.map(\.id))
        .animation(Animations.toast, value: isListed)
    }

    private func card(_ toast: PrestoToast, at index: Int, in toasts: [PrestoToast], isListed: Bool) -> some View {
        let isStacked = toasts.count > 1
        let removal: AnyTransition = .opacity.combined(with: .scale(scale: StackMetrics.entryScale))
        let insertion: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
        return PrestoToastView(
            toast: toast,
            uniformWidth: isStacked ? Sizing.toastWidth : nil,
            isTucked: isStacked && !isListed && index > 0,
            onUndo: { center.dismiss(id: toast.id) },
            onClose: { center.dismiss(id: toast.id) }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            heights[toast.id] = height
        }
        .scaleEffect(scale(of: index, isListed: isListed), anchor: .top)
        .offset(y: offset(of: index, in: toasts, isListed: isListed))
        .opacity(isListed || index <= StackMetrics.visibleBehind ? 1 : 0)
        .zIndex(Double(toasts.count - index))
        .allowsHitTesting(isListed || index == 0)
        .transition(.motion(.asymmetric(insertion: insertion, removal: removal)))
    }

    /// A card behind the front one is a step smaller per place, from its top so
    /// the edge that peeks out stays put.
    private func scale(of index: Int, isListed: Bool) -> CGFloat {
        guard !isListed, index > 0 else { return 1 }
        return 1 - StackMetrics.scaleStep * CGFloat(min(index, StackMetrics.visibleBehind))
    }

    private func height(for toast: PrestoToast) -> CGFloat {
        heights[toast.id] ?? StackMetrics.pillHeight
    }

    private func offset(of index: Int, in toasts: [PrestoToast], isListed: Bool) -> CGFloat {
        guard index > 0, let front = toasts.first else { return 0 }
        if isListed {
            let below = toasts[..<index].reduce(0) { $0 + height(for: $1) }
            return -(below + StackMetrics.listGap * CGFloat(index))
        }
        let depth = CGFloat(min(index, StackMetrics.visibleBehind))
        return height(for: toasts[index]) - height(for: front) - StackMetrics.peek * depth
    }

    private func height(of toasts: [PrestoToast], isListed: Bool) -> CGFloat {
        guard let front = toasts.first else { return 0 }
        if isListed {
            return toasts.reduce(0) { $0 + height(for: $1) } + StackMetrics.listGap * CGFloat(toasts.count - 1)
        }
        return height(for: front) + StackMetrics.peek * CGFloat(min(toasts.count - 1, StackMetrics.visibleBehind))
    }

    private func hoverChanged(_ hovering: Bool) {
        collapseTask?.cancel()
        if hovering {
            isHovering = true
            center.setPaused(true)
        } else {
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: StackMetrics.hoverGrace)
                guard !Task.isCancelled else { return }
                isHovering = false
                center.setPaused(false)
            }
        }
    }
}

// MARK: - Presenting

/// The Presto confirmation the comparison page has open, drawn by
/// `PrestoOverlayHost` at the window's root, as Presto draws its own.
@Observable
final class PrestoOverlays {
    static let shared = PrestoOverlays()

    var confirmation: PrestoConfirmation?
}

/// Presto's dialog over a scrim, and its toast stack where BlissUI's rests:
/// centered, `Spacing.xl` above the window's bottom edge.
struct PrestoOverlayHost: View {
    @State private var overlays = PrestoOverlays.shared
    @State private var toasts = PrestoToasts.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let confirmation = overlays.confirmation {
                Color.black.opacity(scheme == .dark ? 0.6 : 0.25)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture { overlays.confirmation = nil }
                    .transition(.opacity)
                    .accessibilityHidden(true)
                PrestoDialogCard {
                    PrestoConfirmDialog(
                        confirmation: confirmation,
                        onConfirm: {
                            overlays.confirmation = nil
                            toasts.show(PrestoToast(message: confirmation.doneMessage, canUndo: true))
                        },
                        onClose: { overlays.confirmation = nil }
                    )
                }
                .padding(16)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                .accessibilityAddTraits(.isModal)
            }
        }
        // The whole window, so the toasts rest at its bottom edge as BlissUI's do.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(PrestoLook.animation(PrestoLook.easeOutStrong, reduceMotion: reduceMotion), value: overlays.confirmation)
        .overlay(alignment: .bottom) {
            if !toasts.toasts.isEmpty {
                PrestoToastStack(center: toasts)
                    .padding(.bottom, Spacing.xl)
                    .transition(.opacity)
            }
        }
        .animation(Animations.toast, value: toasts.toasts.isEmpty)
    }
}

// MARK: - Menus

/// The button that opens a Presto menu: a raised fill, a wash on hover, and a
/// step up while pressed or open.
struct PrestoMenuTriggerStyle: ButtonStyle {
    let isOpen: Bool

    func makeBody(configuration: Configuration) -> some View {
        PrestoMenuTriggerLabel(configuration: configuration, isOpen: isOpen)
            .pointerStyle(.link)
    }
}

private struct PrestoMenuTriggerLabel: View {
    let configuration: ButtonStyleConfiguration
    let isOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    private var isHighlighted: Bool { configuration.isPressed || isOpen }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .font(PrestoLook.ui(12))
            .foregroundStyle(isHighlighted || isHovering ? PrestoLook.ink : PrestoLook.muted)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(PrestoLook.raised, in: shape)
            .overlay { shape.fill(PrestoLook.ink.opacity(isHighlighted ? 0.08 : isHovering ? 0.04 : 0)) }
            .overlay { shape.strokeBorder(PrestoLook.line) }
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A row in a Presto menu: icon, title, an optional detail and shortcut, and
/// a check when picked. One highlight follows the pointer and the arrow keys
/// alike: hovering a row makes it the menu's focused row.
struct PrestoMenuRow: View {
    let title: String
    var detail: String?
    var systemImage: String?
    var isSelected = false
    var isDestructive = false
    var isCallToAction = false
    var shortcut: String?
    let index: Int
    @Binding var focusedIndex: Int?
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var tint: Color? {
        if isDestructive { return PrestoLook.danger }
        return isCallToAction ? PrestoLook.accent : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: isCallToAction ? .semibold : .regular))
                        .foregroundStyle(tint ?? PrestoLook.muted)
                        .frame(width: 16)
                }
                Text(verbatim: title)
                    .font(PrestoLook.ui(13))
                    .foregroundStyle(tint ?? PrestoLook.ink)
                if let detail {
                    Text(verbatim: detail)
                        .font(PrestoLook.ui(12))
                        .foregroundStyle(PrestoLook.faint)
                }
                Spacer(minLength: 16)
                if let shortcut {
                    PrestoShortcutKey(shortcut)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PrestoLook.muted)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minWidth: 200, alignment: .leading)
            .background(focusedIndex == index ? highlight : .clear, in: .rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovering in
            if isHovering { focusedIndex = index }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The highlighted row's fill: BlissUI's red wash on a row that deletes, the
    /// accent's soft fill on one that starts something new, else a faint wash.
    private var highlight: Color {
        if isDestructive { return StatusWash.fill(Danger.danger500, scheme) }
        return isCallToAction ? PrestoLook.accentSoft : PrestoLook.ink.opacity(0.07)
    }
}

/// A small label over a group of rows: capitals with wide spacing.
struct PrestoMenuSectionHeader: View {
    let title: String
    /// 13 lines it up with the titles of loose rows; 3 with the edge of a
    /// section's inset panel, a little in for the type's side bearing.
    var leadingInset: CGFloat = 13

    var body: some View {
        Text(verbatim: title)
            .font(PrestoLook.ui(9))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(PrestoLook.faint)
            .padding(.leading, leadingInset)
            .padding(.vertical, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A group in a Presto menu: a heading over its rows, which sit together in an
/// inset panel a step darker than the menu's surface.
struct PrestoMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var scheme

    /// Presto's sections sit on its panel color, about a quarter darker than the
    /// menu in dark mode and just off it in light, so it's a black wash over
    /// whatever the menu is drawn on.
    private var groupFill: Color {
        Color.black.opacity(scheme == .dark ? 0.25 : 0.025)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            PrestoMenuSectionHeader(title: title, leadingInset: 3)
            VStack(alignment: .leading, spacing: 1) {
                content()
            }
            .padding(3)
            .background(groupFill, in: shape)
            .overlay { shape.strokeBorder(PrestoLook.line) }
        }
    }
}

struct PrestoMenuDivider: View {
    var body: some View {
        PrestoLook.line
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
    }
}

// MARK: - Inputs

/// Presto's segmented control: one pill slides between the options on a
/// filled track. Compact is the inspector's 28 pt track in the field color.
struct PrestoSegmentedPills<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var isCompact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    var body: some View {
        let track = RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                PrestoSegment(
                    title: title(option),
                    isCompact: isCompact,
                    isSelected: option == selection,
                    namespace: namespace
                ) {
                    withAnimation(PrestoLook.animation(PrestoLook.easeOutStrong, reduceMotion: reduceMotion)) { selection = option }
                }
            }
        }
        .padding(isCompact ? 2 : 3)
        .frame(height: isCompact ? 28 : 32)
        .background(isCompact ? PrestoLook.canvas : PrestoLook.ink.opacity(0.06), in: track)
        .overlay {
            if isCompact { track.strokeBorder(PrestoLook.line) }
        }
        .clipShape(track)
    }
}

private struct PrestoSegment: View {
    let title: String
    let isCompact: Bool
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isCompact ? 5 : 6, style: .continuous)
        Button(action: action) {
            Text(verbatim: title)
                .font(isCompact ? PrestoLook.ui(11.5) : PrestoLook.ui(12))
                .foregroundStyle(isSelected || (isCompact && isHovering) ? PrestoLook.ink : isCompact ? PrestoLook.faint : PrestoLook.muted)
                .lineLimit(1)
                .padding(.horizontal, isCompact ? 4 : 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        shape
                            .fill(isCompact ? RowTint.selected(scheme) : PrestoLook.ink.opacity(0.1))
                            .shadow(color: .black.opacity(isCompact ? 0 : 0.3), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "selectedSegment", in: namespace)
                    } else if isHovering {
                        shape.fill(PrestoLook.ink.opacity(0.04))
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
    }
}

/// Presto's switch: a 26 × 16 track with the label beside it, dimmed while off.
struct PrestoSwitch: View {
    let label: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Capsule()
                    .fill(isOn ? PrestoLook.accent : RowTint.selected(scheme))
                    .frame(width: 26, height: 16)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(isOn ? PrestoLook.accentInk : PrestoLook.faint)
                            .frame(width: 12, height: 12)
                            .padding(2)
                    }
                    .animation(PrestoLook.animation(PrestoLook.easeOutStrong, reduceMotion: reduceMotion), value: isOn)
                Text(verbatim: label)
                    .font(PrestoLook.ui(11.5))
                    .foregroundStyle(isOn ? PrestoLook.ink : PrestoLook.faint)
            }
            .frame(height: 28)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityAddTraits(.isToggle)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityLabel(Text(verbatim: label))
    }
}

/// Presto's search field: bare until hovered or focused, then a filled box,
/// with the shortcut that focuses it while empty and a clear button once typed in.
struct PrestoSearchField: View {
    @Binding var text: String
    let prompt: String
    var shortcut: String?
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(PrestoLook.faint)
            TextField(prompt, text: $text, prompt: Text(verbatim: prompt).foregroundStyle(PrestoLook.faint))
                .textFieldStyle(.plain)
                .font(PrestoLook.ui(13))
                .foregroundStyle(PrestoLook.ink)
                .focused($isFocused)
                .onExitCommand {
                    text = ""
                    isFocused = false
                }
            if text.isEmpty {
                if let shortcut { PrestoShortcutKey(shortcut) }
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(PrestoLook.faint)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isFocused || isHovered ? PrestoLook.canvas : .clear, in: shape)
        .overlay { shape.strokeBorder(isFocused ? PrestoLook.line : .clear) }
        .onHover { isHovered = $0 }
    }
}

extension View {
    /// Presto's text field look: a well with a hairline, in the accent while
    /// focused and red while what's in it can't be used. 32 pt tall.
    func prestoFieldChrome(isFocused: Bool = false, isInvalid: Bool = false) -> some View {
        padding(.horizontal, 10)
            .frame(minHeight: 32, alignment: .leading)
            .background(PrestoLook.canvas, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isInvalid ? PrestoLook.danger : isFocused ? PrestoLook.accent.opacity(0.6) : PrestoLook.line)
            }
    }
}

// MARK: - Display

/// A small key cap for a shortcut, translucent so it reads on any surface.
struct PrestoShortcutKey: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Text(verbatim: keys)
            .font(PrestoLook.mono(10.5))
            .foregroundStyle(PrestoLook.muted)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(minWidth: 22, minHeight: 18)
            .background(PrestoLook.ink.opacity(0.06), in: shape)
            .overlay { shape.strokeBorder(PrestoLook.ink.opacity(0.12)) }
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// Presto's spinner: a fading arc that turns by the clock, in the color of the
/// text around it.
struct PrestoSpinner: View {
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2

    var body: some View {
        TimelineView(.animation) { timeline in
            let turn = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.8) / 0.8
            Rectangle()
                .fill(.foreground)
                .mask {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(colors: [.black.opacity(0), .black], center: .center, startAngle: .degrees(0), endAngle: .degrees(252)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .padding(lineWidth / 2)
                }
                .rotationEffect(.degrees(turn * 360))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A dot that breathes while something is under way.
struct PrestoPulseDot: View {
    let color: Color
    var isPulsing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !isPulsing || reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
            let opacity = isPulsing && !reduceMotion ? 0.35 + 0.65 * (0.5 + 0.5 * cos(phase * 2 * .pi)) : 1
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(opacity)
        }
        .accessibilityHidden(true)
    }
}

/// A colored dot and a word for where something stands.
struct PrestoStatusTag: View {
    let label: String
    let color: Color
    var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            PrestoPulseDot(color: color, isPulsing: isPulsing)
            Text(verbatim: label)
        }
        .font(PrestoLook.ui(11))
        .foregroundStyle(PrestoLook.muted)
    }
}

/// A small mono tag on a soft wash of its color.
struct PrestoTagPill: View {
    let text: String
    var tint: Color = PrestoLook.accent

    var body: some View {
        Text(verbatim: text)
            .font(PrestoLook.mono(10.5))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 4))
            .fixedSize()
    }
}

/// Text that opens a page: a faint underline that turns solid on hover.
struct PrestoInlineLink: View {
    let title: String
    let url: URL
    @State private var isHovered = false

    var body: some View {
        Link(destination: url) {
            Text(verbatim: title)
                .underline(color: isHovered ? PrestoLook.ink : PrestoLook.ink.opacity(0.3))
                .foregroundStyle(PrestoLook.ink)
        }
        .buttonStyle(.plain)
        .font(PrestoLook.ui(12))
        .pointerStyle(.link)
        .onHover { isHovered = $0 }
    }
}

/// A value to paste elsewhere, in mono and selectable, with a copy button that
/// turns into a check.
struct PrestoCopyableValue: View {
    let value: String
    @State private var didCopy = false
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(verbatim: value)
                .font(PrestoLook.mono(11.5))
                .foregroundStyle(PrestoLook.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    didCopy = false
                }
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(didCopy ? PrestoLook.success : isHovered ? PrestoLook.ink : PrestoLook.faint)
                    .frame(width: 16, height: 16)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .onHover { isHovered = $0 }
            .accessibilityLabel(Text("Copy"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PrestoLook.canvas, in: .rect(cornerRadius: 6))
        .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(PrestoLook.line) }
    }
}

/// What went wrong, as a red line of text rather than a card.
struct PrestoProblemText: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(PrestoLook.ui(12))
            .foregroundStyle(PrestoLook.danger)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// What went wrong, as a card: the red mark beside the problem and what to do
/// about it, on BlissUI's red wash with its outline, at Presto's sizes.
struct PrestoProblemBanner: View {
    let title: String
    var message: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(PrestoLook.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // Semibold, as BlissUI's banner title is.
                Text(verbatim: title)
                    .font(PrestoLook.ui(12.5))
                    .fontWeight(.semibold)
                    .foregroundStyle(PrestoLook.ink)
                if let message {
                    Text(verbatim: message)
                        .font(PrestoLook.ui(12))
                        .foregroundStyle(PrestoLook.muted)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(StatusWash.fill(Danger.danger500, scheme), in: shape)
        .overlay { shape.strokeBorder(StatusWash.border(Danger.danger500, scheme)) }
    }
}

/// A spinner beside text, for a step waiting on someone else.
struct PrestoWaitingLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            PrestoSpinner(size: 14, lineWidth: 1.5)
            Text(verbatim: text)
                .font(PrestoLook.ui(12))
        }
        .foregroundStyle(PrestoLook.muted)
    }
}
