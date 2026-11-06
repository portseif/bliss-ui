//
//  ToastNotification.swift
//  BlissUI
//
//  Global toast notification component for showing transient feedback messages.
//  Supports success, error, in-progress, and progress states with animations.
//

import SwiftUI

// MARK: - Circular Progress Indicator

/// A circular progress ring. Shows the numeric percentage in the center when
/// `showsValue` is true; pass `false` for a compact ring whose percentage is
/// rendered inline elsewhere (the progress pill).
private struct CircularProgressIndicator: View {
    let progress: Double
    var color: Color = Primary.primary500
    var size: CGFloat = 40
    var lineWidth: CGFloat = 3
    var showsValue: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    private var trackColor: Color {
        colorScheme == .dark ? Grey.grey700 : Grey.grey200
    }

    var body: some View {
        ZStack {
            // Track circle
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Animations.disclosure, value: progress)

            // Percentage text
            if showsValue {
                SlidingNumber(
                    value: Int(progress * 100),
                    font: .system(size: 14, weight: .regular, design: .default),
                    color: color,
                    tracking: -0.5
                )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status Icon

/// Filled status circle with a white glyph (the leading badge on success/error/info pills).
private struct ToastStatusIcon: View {
    let glyph: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            // The deep tone: a white glyph on a status color's lifted dark mark
            // (light mint, amber, cyan) wouldn't read.
            Circle().fill(color.statusTint)
            Image(systemName: glyph)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Dismiss Button

/// The toast pill's × (dismiss / cancel). A bare glyph at rest — matching the mockups —
/// with the circular chip fading in only on hover.
private struct ToastDismissButton: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                    .opacity(isHovering ? 1 : 0)
                Image(systemName: "xmark")
                    .font(Typography.labelXTinySemibold)
                    .foregroundStyle(isHovering ? Color.primary : Color.secondary)
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
        .accessibilityLabel(Text("Dismiss"))
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
    }
}

/// Animated toast notification view. `.globalToast()` and `.toast(_:)` place
/// these for you; build one directly only to show a toast somewhere of your own.
public struct ToastNotification: View {
    let toast: ToastData
    var onDismiss: (() -> Void)?
    /// When set, an in-progress/progress toast shows an × that runs this after a
    /// confirmation. Wired from `ToastService.registerCancel`; nil elsewhere (no × shown).
    var onCancel: (() -> Void)?
    /// In a stack every card takes this width, so the deck and the hovered list
    /// line up; a lone toast (nil) hugs its content.
    var uniformWidth: CGFloat?
    /// A card tucked behind the front one in the collapsed deck: it folds back to
    /// its one-line pill so only its top edge peeks out.
    var isTucked: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var expanded = false
    @State private var copied = false
    @State private var showingCancelConfirm = false

    /// - Parameters:
    ///   - onDismiss: Gives the pill its ×; nil shows none.
    ///   - onCancel: Gives an in-progress toast an × that runs this after a
    ///     confirmation; nil shows none.
    public init(toast: ToastData, onDismiss: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.init(toast: toast, onDismiss: onDismiss, onCancel: onCancel, uniformWidth: nil, isTucked: false)
    }

    /// A card in the stack (`ToastStack`).
    init(toast: ToastData, onDismiss: (() -> Void)?, onCancel: (() -> Void)?, uniformWidth: CGFloat?, isTucked: Bool) {
        self.toast = toast
        self.onDismiss = onDismiss
        self.onCancel = onCancel
        self.uniformWidth = uniformWidth
        self.isTucked = isTucked
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : .white
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12)
    }

    private var shadowRadius: CGFloat {
        colorScheme == .dark ? 16 : 12
    }

    /// Primary label for the in-progress pill: the live phase message with its trailing
    /// ellipsis trimmed (the spinner/ring already signals "ongoing").
    private var inlineLabel: String {
        var text = (toast.message.components(separatedBy: "\n").first ?? toast.message)
            .trimmingCharacters(in: .whitespaces)
        if text.hasSuffix("...") {
            text = String(text.dropLast(3))
        } else if text.hasSuffix("…") {
            text = String(text.dropLast())
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    public var body: some View {
        Group {
            if toast.style.isInProgress {
                progressBody
            } else {
                statusPillBody
            }
        }
        .onChange(of: isTucked) { _, tucked in
            if tucked, expanded {
                withAnimation(Animations.accordion) { expanded = false }
            }
        }
    }

    // MARK: - In-progress / progress pill

    /// Single-line capsule: `[ring|spinner] Label · 41% · 0:14 [×]`. The × only shows when
    /// the running operation registered a cancel handler (`registerCancel`); tapping it asks
    /// for confirmation before cancelling. Clicking anywhere else on the pill expands it
    /// into a detail card (full phase text, linear progress bar, elapsed) — the same
    /// accordion morph as the error pill, toggled rather than one-way.
    private var progressBody: some View {
        // Finite collapsed radius (≈ half the pill height) so the corner radius can
        // interpolate during the morph — `.infinity` would jump.
        let cornerRadius: CGFloat = expanded ? Sizing.radiusLarge : 22
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                // Leading indicator: determinate ring (percentage shown inline, not centered)
                // when we have a value, otherwise the indeterminate spinner.
                if let progress = toast.style.progressValue {
                    CircularProgressIndicator(
                        progress: progress,
                        color: toast.style.iconColor,
                        size: 18,
                        lineWidth: 2.5,
                        showsValue: false
                    )
                } else {
                    ThinkingSpinner(size: 16, lineWidth: 2, color: toast.style.iconColor)
                }

                // Label · percent · elapsed, on one line. Expanded, the title takes
                // over the line (the live phase + numbers move into the card body).
                HStack(spacing: Spacing.xs) {
                    // Sweep a shimmer across the live status text to signal active
                    // work (the % + spinner already convey progress). A bright band
                    // (.primary) sweeps the dimmed (.secondary) text — the classic
                    // loading shimmer; the reverse reads as almost nothing.
                    // ShimmerTextOverlay is used over `.shimmer()` because the latter's
                    // overlay blend is a no-op on near-white text.
                    ShimmerTextOverlay(
                        text: expanded ? toast.title : inlineLabel,
                        font: Typography.labelMedium,
                        baseColor: .secondary,
                        shimmerColor: .primary,
                        duration: 2.2,
                        shimmerWidth: 0.4
                    )
                    .lineLimit(1)

                    if !expanded {
                        // Live elapsed timer. `Text(timerInterval:)` ticks itself every second, so a
                        // slow step (e.g. a long export) still reads as "working", not frozen.
                        if let startedAt = toast.startedAt {
                            pillSeparator
                            Text(timerInterval: startedAt...Date.distantFuture, countsDown: false, showsHours: false)
                                .font(Typography.labelMedium)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                if expanded || uniformWidth != nil { Spacer(minLength: Spacing.sm) }

                // Cancel — only when the operation registered a cancel handler.
                if onCancel != nil {
                    ToastDismissButton(action: { showingCancelConfirm = true })
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let primaryAction = toast.primaryAction {
                    primaryAction()
                } else {
                    withAnimation(Animations.accordion) { expanded.toggle() }
                }
            }

            if expanded {
                progressDetail
                    // Blur + fade reveal, matching the error card's fold-out.
                    .transition(.blurReplace)
            }
        }
        // Tucked behind the front card, only the card's edge should show.
        .opacity(isTucked ? 0 : 1)
        .disabled(isTucked)   // hidden buttons stay out of the Tab loop
        .padding(.leading, Spacing.md)
        .padding(.trailing, (onCancel != nil ? Spacing.sm : Spacing.md) + Spacing.hairline)
        .padding(.vertical, Spacing.sm + 2)
        .cardWidth(uniformWidth)
        .background {
            shape
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: shadowRadius, y: 4)
        }
        .overlay {
            shape
                .strokeBorder(pillBorderColor, lineWidth: 1)
        }
        // Background/overlay hug the content; the cap only kicks in for very long
        // text. Centered (no leading alignment) so the pill sits horizontally
        // centered over the content pane.
        .frame(maxWidth: uniformWidth ?? (expanded ? 420 : 380))
        // Clear any stale confirm state each time the pill (re)enters the tree, so a dialog
        // left open when a prior operation ended can't auto-present on the next one.
        .onAppear { showingCancelConfirm = false }
        // A NEW operation (different toast id) shouldn't inherit the old card state.
        .onChange(of: toast.id) { _, _ in expanded = false }
        .confirmationDialog(
            "Stop this task?",
            isPresented: $showingCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) { onCancel?() }
            Button("Keep Running", role: .cancel) {}
        } message: {
            Text("It stops at the next safe step. Anything already done stays in place.")
        }
    }

    /// The expanded progress card body: the full live phase text, a linear
    /// progress bar with the percent, and the elapsed timer + Stop in a footer.
    /// Everything stays live — the toast updates in place (same id) as the
    /// operation reports progress, and this card re-renders with it.
    private var progressDetail: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Divider().padding(.top, Spacing.sm)

            // Full current-phase message — untruncated, wraps naturally.
            Text(toast.message.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(Typography.codeSmall)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Optional per-item detail (e.g. a batch job's per-item status + each
            // item's result). Structured rows when provided (shimmering
            // current item, result cards); else the plain fullMessage text.
            if !toast.detailItems.isEmpty {
                // The house thin scroll, hugging short content: a raw ScrollView
                // showed the wide legacy scroller under "Show scroll bars: Always".
                AutoHeightScroll(showFadeMask: true, maxHeight: 220) {
                    VStack(alignment: .leading, spacing: Spacing.xs + 2) {
                        ForEach(toast.detailItems) { item in
                            detailItemRow(item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
            } else if let detail = toast.fullMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
               !detail.isEmpty {
                AutoHeightScroll(showFadeMask: true, maxHeight: 170) {
                    Text(detail)
                        .font(Typography.codeSmall)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 170)
            }

            if let progress = toast.style.progressValue {
                HStack(spacing: Spacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(colorScheme == .dark ? Grey.grey700 : Grey.grey200)
                            Capsule()
                                .fill(toast.style.iconColor)
                                .frame(width: max(4, geo.size.width * progress))
                                .animation(Animations.toast, value: progress)
                        }
                    }
                    .frame(height: 4)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(Typography.labelSmall)
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            HStack(spacing: Spacing.sm) {
                if let startedAt = toast.startedAt {
                    HStack(spacing: 4) {
                        Text("Elapsed")
                        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false, showsHours: false)
                            .monospacedDigit()
                    }
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if onCancel != nil {
                    Button {
                        showingCancelConfirm = true
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        }
    }

    /// One structured detail row: a pending dot, the shimmering current item, a
    /// done row with its result text in a mono message card, or a failed row.
    @ViewBuilder
    private func detailItemRow(_ item: ToastDetailItem) -> some View {
        switch item.state {
        case .pending:
            HStack(spacing: Spacing.xs + 2) {
                Circle()
                    .fill(Grey.grey400.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text(item.name)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        case .working:
            HStack(spacing: Spacing.xs + 2) {
                ThinkingSpinner(size: 10, lineWidth: 1.5, color: Color.accent)
                ShimmerTextOverlay(
                    text: item.text.map { "\(item.name) — \($0)…" } ?? "\(item.name)…",
                    font: Typography.captionSmall,
                    baseColor: .secondary,
                    shimmerColor: .primary,
                    duration: 2.2
                )
            }
        case .done:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs + 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Typography.captionSmall)
                        .foregroundStyle(Success.success500)
                    Text(item.name)
                        .font(Typography.captionSemibold)
                        .foregroundStyle(.primary)
                }
                if let text = item.text, !text.isEmpty {
                    Text(text)
                        .font(Typography.codeSmall)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.sm)
                        .background {
                            RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
                        }
                }
            }
        case .failed:
            HStack(spacing: Spacing.xs + 2) {
                Image(systemName: "xmark.circle.fill")
                    .font(Typography.captionSmall)
                    .foregroundStyle(Danger.danger500)
                Text(item.text.map { "\(item.name) — \($0)" } ?? item.name)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Status pill (success / error / info)

    @ViewBuilder
    private var statusPillBody: some View {
        if toast.style == .error || toast.style == .warning {
            errorBody
        } else {
            standardPill
        }
    }

    /// Single-line success / info pill.
    private var standardPill: some View {
        HStack(spacing: Spacing.sm) {
            ToastStatusIcon(glyph: toast.customIcon ?? toast.style.glyph, color: toast.style.iconColor)

            // Title · detail segments, on one line.
            HStack(spacing: Spacing.xs) {
                Text(toast.title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                ForEach(displaySegments) { segment in
                    pillSeparator
                    Text(segment.text)
                        .font(Typography.labelMedium)
                        .foregroundStyle(segment.isProminent ? Color.primary : Color.secondary)
                        .lineLimit(1)
                }
            }

            if uniformWidth != nil { Spacer(minLength: Spacing.sm) }

            if !toast.actions.isEmpty {
                inlineActions
            }

            if let onDismiss = onDismiss {
                ToastDismissButton(action: onDismiss)
            }
        }
        .opacity(isTucked ? 0 : 1)
        .disabled(isTucked)   // hidden buttons stay out of the Tab loop
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm + Spacing.hairline)
        .padding(.vertical, Spacing.sm + 2)
        .cardWidth(uniformWidth)
        .background {
            Capsule(style: .continuous)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: shadowRadius, y: 4)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(pillBorderColor, lineWidth: 1)
        }
        // Background/overlay hug the content; the cap only kicks in for very long text.
        .frame(maxWidth: uniformWidth ?? 520)
    }

    /// Error pill — click anywhere on it to expand the full error inline (selectable),
    /// with a Copy error button. Primary actions stay accessible while collapsed.
    private var errorBody: some View {
        // Finite collapsed radius (≈ the pill's half-height, so it still reads as a
        // capsule) — `.infinity` can't be interpolated, so the corner radius would
        // jump instead of morph. Finite lets it animate cleanly into the card.
        let cornerRadius: CGFloat = expanded ? Sizing.radiusLarge : 22
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                ToastStatusIcon(glyph: toast.customIcon ?? toast.style.glyph, color: toast.style.iconColor)

                HStack(spacing: Spacing.xs) {
                    Text(toast.title)
                        .font(Typography.labelMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !expanded {
                        ForEach(displaySegments) { segment in
                            pillSeparator
                            Text(segment.text)
                                .font(Typography.labelMedium)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: Spacing.sm)

                if !expanded, !toast.actions.isEmpty {
                    inlineActions
                }
                if let onDismiss = onDismiss {
                    ToastDismissButton(action: onDismiss)
                }
            }
            .contentShape(Rectangle())
            // Accordion-style expand/collapse: morph the pill into a card. Size +
            // corner radius animate together under one spring; the revealed content
            // blur-fades in (see `.transition` below) so it never pops from nothing.
            .onTapGesture { withAnimation(Animations.accordion) { expanded.toggle(); copied = false } }
            // The tap-to-expand is a gesture; give VoiceOver the same press.
            .accessibilityAction(named: expanded ? Text("Hide Details") : Text("Show Details")) {
                withAnimation(Animations.accordion) { expanded.toggle(); copied = false }
            }

            if expanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Divider().padding(.top, Spacing.sm)

                    if toast.failures.isEmpty {
                        // Auto-height: wrap to the toast width + take the text's natural
                        // height so the card fits the message instead of a fixed box.
                        Text(errorText)
                            .font(Typography.codeSmall)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // Structured per-item failures (e.g. skipped rows), capped so a
                        // large burst scrolls inside the card instead of ballooning it.
                        if let summary = failureSummary {
                            Text(summary)
                                .font(Typography.codeSmall)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        AutoHeightScroll(showFadeMask: true, maxHeight: 200) {
                            VStack(spacing: 0) {
                                DividedForEach(toast.failures) { failure in
                                    ToastFailureRow(failure: failure)
                                } separator: {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }

                    HStack(spacing: Spacing.md) {
                        Button { copyError() } label: {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(Typography.labelTiny)
                                Text(copied ? "Copied" : (toast.failures.isEmpty ? "Copy error" : "Copy log"))
                                    .font(Typography.labelMedium)
                            }
                            .foregroundStyle(copied ? Success.success500 : Color.accent)
                        }
                        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 3))

                        if !toast.actions.isEmpty {
                            inlineActions
                        }
                        Spacer(minLength: 0)
                    }
                }
                // Blur + fade reveal (masks the swap and reads as emerging from the
                // fold) rather than a hard pop — Emil's blur-to-mask principle.
                .transition(.blurReplace)
            }
        }
        .opacity(isTucked ? 0 : 1)
        .disabled(isTucked)   // hidden buttons stay out of the Tab loop
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm + Spacing.hairline)
        .padding(.vertical, Spacing.sm + 2)
        .cardWidth(uniformWidth)
        .background {
            shape.fill(backgroundColor).shadow(color: shadowColor, radius: shadowRadius, y: 4)
        }
        .overlay {
            shape.strokeBorder(pillBorderColor, lineWidth: 1)
        }
        .frame(maxWidth: uniformWidth ?? (expanded ? 460 : 520))
    }

    private var errorText: String {
        (toast.fullMessage ?? toast.message).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Summary line above the structured failure rows: "N / M OK" when the total is
    /// known, else a plain skipped count. Nil when there are no structured failures.
    private var failureSummary: String? {
        guard !toast.failures.isEmpty else { return nil }
        if let total = toast.totalItems {
            return String(localized: "\(max(0, total - toast.failures.count)) / \(total) OK")
        }
        let n = toast.failures.count
        return n == 1 ? String(localized: "1 item skipped") : String(localized: "\(n) items skipped")
    }

    private func copyError() {
        let payload = "\(toast.title)\n\n\(errorText)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    /// Segments shown after the title. Explicit `segments` win; otherwise derive a
    /// "N of M items" segment for structured failures, else fall back to `message`.
    private var displaySegments: [ToastSegment] {
        if !toast.segments.isEmpty { return toast.segments }
        if !toast.failures.isEmpty, let total = toast.totalItems {
            return [ToastSegment(String(localized: "\(toast.failures.count) of \(total) items"))]
        }
        let trimmed = toast.message.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? [] : [ToastSegment(trimmed)]
    }

    private var inlineActions: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(toast.actions) { action in
                Button {
                    action.action()
                    // Acting on a toast settles it — otherwise a Retry or an
                    // Open in Finder would leave it sitting in the stack.
                    onDismiss?()
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        if let icon = action.icon {
                            Image(systemName: icon)
                                .font(Typography.labelTiny)
                        }
                        Text(action.label)
                            .font(Typography.labelMedium)
                    }
                    .foregroundStyle(Color.accent)
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 3))
            }
        }
    }

    // MARK: - Shared bits

    /// Middot separator between the pill's label / percent / time segments.
    private var pillSeparator: some View {
        Text("·")
            .font(Typography.labelMedium)
            .foregroundStyle(.secondary)
    }

    /// Subtle neutral hairline around the progress pill (matches the screenshot — not the
    /// accent-tinted border the standard card uses).
    private var pillBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
}

private extension View {
    /// In a stack every card takes the same width; a lone toast hugs its content.
    @ViewBuilder
    func cardWidth(_ width: CGFloat?) -> some View {
        if let width {
            frame(width: width, alignment: .leading)
        } else {
            self
        }
    }
}

// MARK: - Shared failure row

/// One failed-item row: path/identifier on top, `code · message` beneath in danger red.
/// Shared by the expandable warning/error toast body and the details popover.
struct ToastFailureRow: View {
    let failure: ToastFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "doc")
                    .font(Typography.labelSmall)
                    .foregroundStyle(.secondary)
                Text(failure.path)
                    .font(Typography.codeSmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text("\(failure.code) · \(failure.message)")
                .font(Typography.codeSmall)
                .foregroundStyle(Danger.danger500)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        // The row pads its own sides, so the fill is the row itself.
        .rowHover(horizontalBleed: 0)
    }
}

// MARK: - Previews

#Preview("Toast - Success", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .success(
                title: "Photos exported",
                message: "",
                segments: [ToastSegment("100 items", isProminent: true), ToastSegment("0:24 total")]
            ),
            onDismiss: {}
        )
    }
}

#Preview("Toast - Error", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .error(
                title: "Upload failed",
                message: "Network timeout",
                actions: [ToastAction(label: "Retry") {}]
            ),
            onDismiss: {}
        )
    }
}

#Preview("Toast - Error with Details", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .error(
                title: "Upload failed",
                message: "",
                failures: [
                    ToastFailure(path: "storage/uploads/2024/q4-report-final.pdf", code: "EACCES", message: "Permission denied at destination"),
                    ToastFailure(path: "storage/media/launch-video-2025.mp4", code: "ETIMEDOUT", message: "Connection closed after 30s (212 MB)"),
                    ToastFailure(path: "backups/archive-2025-05-29.zip", code: "ECONNRESET", message: "Peer reset connection mid-stream")
                ],
                totalItems: 100,
                failedAt: Date(timeIntervalSinceNow: -18),
                actions: [ToastAction(label: "Retry") {}]
            ),
            onDismiss: {}
        )
    }
}

#Preview("Toast - Warning (partial import)", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .warning(
                title: "Import finished",
                message: "Imported contacts.csv",
                segments: [ToastSegment("contacts", isProminent: true), ToastSegment("3 rows skipped")],
                failures: [
                    ToastFailure(path: "Line 8421", code: "E_TOO_LONG", message: "Value too long for column 'notes'"),
                    ToastFailure(path: "Line 9102", code: "E_ENCODING", message: "Invalid UTF-8 sequence in column 'name'"),
                    ToastFailure(path: "Line 10233", code: "E_DUPLICATE", message: "Duplicate entry '42' for key 'id'")
                ],
                actions: [ToastAction(label: "Retry", icon: "arrow.clockwise") {}]
            ),
            onDismiss: {}
        )
    }
}

#Preview("Toast - Progress Pill", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        // Matches the target design: ring · label · percent · elapsed · cancel.
        ToastNotification(
            toast: ToastData(
                title: "Uploading...",
                message: "Uploading photos...",
                style: .progress(0.41),
                startedAt: Date(timeIntervalSinceNow: -14)
            ),
            onDismiss: {},
            onCancel: {}
        )
    }
}

#Preview("Toast - In Progress", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: ToastData(
                title: "Preparing...",
                message: "Indexing files...",
                style: .inProgress,
                startedAt: Date(timeIntervalSinceNow: -3)
            ),
            onDismiss: {},
            onCancel: {}
        )
    }
}

#Preview("Toast - Progress (no cancel)", traits: .fixedLayout(width: 400, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .progress(title: "Exporting", message: "Writing archive...", progress: 0.67)
        )
    }
}

#Preview("Toast - Info", traits: .fixedLayout(width: 460, height: 150)) {
    ZStack {
        Color.windowBackground.ignoresSafeArea()

        ToastNotification(
            toast: .info(
                title: "Update available",
                message: "Version 2.4.0",
                actions: [ToastAction(label: "Install") {}]
            ),
            onDismiss: {}
        )
    }
}
