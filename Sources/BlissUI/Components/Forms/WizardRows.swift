//
//  WizardRows.swift
//  BlissUI
//
//  The rows a multi-step flow is built from: `WizardRadioRow`, one choice in a
//  list (an icon, a title and a line of detail, with a radio mark), and
//  `WizardStepRow`, one step of a run or a wizard's rail — waiting, current,
//  running with the spinner, done, or failed.
//

import SwiftUI

// MARK: - Metrics

enum WizardRowMetrics {
    /// The radio row's icon slot.
    static let iconSlot: CGFloat = Sizing.controlDefault
    /// The radio row's insets, and the compact row's vertical one.
    static let verticalInset: CGFloat = Spacing.md
    static let compactVerticalInset: CGFloat = Spacing.sm
    static let horizontalInset: CGFloat = Spacing.sm
    /// The step row's status mark, and the compact one.
    static let markSize: CGFloat = Sizing.iconMedium
    static let compactMarkSize: CGFloat = Sizing.iconDefault
    /// The pending ring's weight: a quiet outline, not a hairline.
    static let pendingRingOpacity: Double = 0.3
    static let spinnerLineWidth: CGFloat = 2
}

// MARK: - Wizard Radio Row

/// One choice in a radio list: an icon, a title and a line of detail, with a
/// radio mark on the trailing edge. The picked row takes the selected wash and
/// an accent edge, like an `OptionCard`; hover is the subtler step below it.
/// A Tab stop with the shared ring; Space or Return picks it.
public struct WizardRadioRow<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let icon: String?
    private let badge: Badge?
    private let isSelected: Bool
    private let showsBorder: Bool
    private let compact: Bool
    private let action: () -> Void
    private let trailing: () -> Trailing

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private let cornerRadius = OptionCardMetrics.cornerRadius

    /// - Parameters:
    ///   - title: The choice. Looked up in your app's strings.
    ///   - detail: A line on what it means, under the title.
    ///   - icon: An SF Symbol, accent-colored while the row is picked.
    ///   - badge: A badge beside the title ("Recommended").
    ///   - isSelected: Whether the row is picked.
    ///   - showsBorder: A hairline at rest, so a wizard mixing rows and cards
    ///     reads as one set.
    ///   - compact: A tighter row.
    ///   - action: Runs on a click, Space or Return — pick this row.
    ///   - trailing: Before the radio mark — a price, a count.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        icon: String? = nil,
        badge: Badge? = nil,
        isSelected: Bool,
        showsBorder: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.badge = badge
        self.isSelected = isSelected
        self.showsBorder = showsBorder
        self.compact = compact
        self.action = action
        self.trailing = trailing
    }

    private var fill: Color {
        if isSelected { return RowTint.selected(colorScheme) }
        return isHovering && isEnabled ? RowTint.hover(colorScheme) : .clear
    }

    private var border: Color {
        if isSelected { return Color.accent }
        return showsBorder ? Color.menuBorder : .clear
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(isSelected ? Color.accent : Color.secondary)
                        .frame(width: WizardRowMetrics.iconSlot, height: WizardRowMetrics.iconSlot)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(title)
                            .font(Typography.labelMedium)
                            .foregroundStyle(.primary)
                        if let badge {
                            badge.badgeSize(.small)
                        }
                    }
                    if let detail, !compact {
                        Text(detail)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Spacing.sm)

                trailing()

                RadioGlyph(isOn: isSelected, size: Sizing.iconSmall)
            }
            .padding(.vertical, compact ? WizardRowMetrics.compactVerticalInset : WizardRowMetrics.verticalInset)
            .padding(.horizontal, WizardRowMetrics.horizontalInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // The picked row keeps the stronger persistent fill; hover is
                // the subtler step below it — a hovered neighbor must never
                // out-rank the current choice.
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: cornerRadius))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in withAnimation(Animations.hover) { isHovering = hovering } }
        .animation(Animations.selection, value: isSelected)
    }
}

extension WizardRadioRow where Trailing == EmptyView {
    /// - Parameters:
    ///   - title: The choice. Looked up in your app's strings.
    ///   - detail: A line on what it means, under the title.
    ///   - icon: An SF Symbol, accent-colored while the row is picked.
    ///   - badge: A badge beside the title ("Recommended").
    ///   - isSelected: Whether the row is picked.
    ///   - showsBorder: A hairline at rest.
    ///   - compact: A tighter row.
    ///   - action: Runs on a click, Space or Return — pick this row.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        icon: String? = nil,
        badge: Badge? = nil,
        isSelected: Bool,
        showsBorder: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(title, detail: detail, icon: icon, badge: badge, isSelected: isSelected, showsBorder: showsBorder, compact: compact, action: action) { EmptyView() }
    }

    /// The same row with `subtitle:` for its detail line — prefer `detail:`,
    /// the name every other row uses.
    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.init(title, detail: subtitle, icon: icon, isSelected: isSelected, action: action)
    }
}

// MARK: - Wizard Step Row

/// Where a step stands.
public nonisolated enum WizardStepState: Hashable, Sendable {
    /// Not reached yet.
    case pending
    /// The step you're on, waiting on you (a wizard's rail).
    case current
    /// Working on it now.
    case running
    /// Finished.
    case done
    /// Stopped with an error.
    case failed
}

/// One step of a run or a wizard: a status mark, the step's title and an
/// optional line under it. The mark is a numbered (or plain) ring while
/// pending — accent for the current step — the spinner (or a progress ring)
/// while running, an accent disc with a check once done, and a filled danger
/// disc with a cross on failure. A failed step's detail is set in the danger
/// mark, for the reason.
public struct WizardStepRow<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let number: Int?
    private let state: WizardStepState
    private let progress: Double?
    private let compact: Bool
    private let trailing: () -> Trailing

    private var markSize: CGFloat { compact ? WizardRowMetrics.compactMarkSize : WizardRowMetrics.markSize }

    /// - Parameters:
    ///   - title: The step. Looked up in your app's strings.
    ///   - detail: A line under it — what it did, or why it failed.
    ///   - number: Shown in the ring while the step hasn't finished; nil for a plain ring.
    ///   - state: Where the step stands.
    ///   - progress: 0…1 while `.running`: a determinate ring in the spinner's
    ///     place (an install, a download).
    ///   - compact: A smaller mark and no detail line, for a toast or a sheet footer.
    ///   - trailing: After the text — a duration ("4.2 s"), a Retry button.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        number: Int? = nil,
        state: WizardStepState,
        progress: Double? = nil,
        compact: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.number = number
        self.state = state
        self.progress = progress
        self.compact = compact
        self.trailing = trailing
    }

    public var body: some View {
        // Baseline-aligned, like a Label, so the mark stays with the title when
        // a detail line hangs below it.
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            mark
                .frame(width: markSize, height: markSize)
                .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(state == .pending ? Color.textSecondary : Color.textPrimary)
                if let detail, !compact {
                    Text(detail)
                        .font(Typography.captionSmall)
                        .foregroundStyle(state == .failed ? AnyShapeStyle(Danger.danger500) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .animation(Animations.selection, value: state)
        .accessibilityElement(children: .combine)
        .accessibilityValue(stateDescription)
    }

    // MARK: Mark

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .pending, .current:
            Circle()
                .strokeBorder(state == .current ? Color.accent : Color.secondary.opacity(WizardRowMetrics.pendingRingOpacity), lineWidth: 1)
                .overlay {
                    if let number {
                        Text(verbatim: "\(number)")
                            .font(compact ? Typography.labelXTiny : Typography.labelSmall)
                            .foregroundStyle(state == .current ? Color.accent : Color.secondary)
                    }
                }
        case .running:
            if let progress {
                ProgressRing(value: progress, size: markSize, lineWidth: WizardRowMetrics.spinnerLineWidth)
            } else {
                ThinkingSpinner(size: markSize - Spacing.hairline, lineWidth: WizardRowMetrics.spinnerLineWidth, color: Color.accent)
            }
        case .done:
            Circle()
                .fill(Color.accent)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(compact ? Typography.labelXTinyBold : Typography.labelXSmallBold)
                        .foregroundStyle(AccentHue.contrastForeground)
                }
        case .failed:
            // White on the danger TINT: the lifted dark-mode mark is too light
            // to carry white.
            Circle()
                .fill(Danger.tint)
                .overlay {
                    Image(systemName: "xmark")
                        .font(compact ? Typography.labelXTinyBold : Typography.labelXSmallBold)
                        .foregroundStyle(.white)
                }
        }
    }

    private var stateDescription: Text {
        switch state {
        case .pending: Text("Not started", bundle: .module)
        case .current: Text("Current step", bundle: .module)
        case .running: Text("In progress", bundle: .module)
        case .done: Text("Done", bundle: .module)
        case .failed: Text("Failed", bundle: .module)
        }
    }
}

extension WizardStepRow where Trailing == EmptyView {
    /// - Parameters:
    ///   - title: The step. Looked up in your app's strings.
    ///   - detail: A line under it — what it did, or why it failed.
    ///   - number: Shown in the ring while the step hasn't finished; nil for a plain ring.
    ///   - state: Where the step stands.
    ///   - progress: 0…1 while `.running`: a determinate ring in the spinner's place.
    ///   - compact: A smaller mark and no detail line.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        number: Int? = nil,
        state: WizardStepState,
        progress: Double? = nil,
        compact: Bool = false
    ) {
        self.init(title, detail: detail, number: number, state: state, progress: progress, compact: compact) { EmptyView() }
    }
}

// MARK: - Previews

#Preview("Radio rows", traits: .fixedLayout(width: 420, height: 260)) {
    @Previewable @State var source = 0
    VStack(spacing: Spacing.xxs) {
        WizardRadioRow("From a template", detail: "Start from a ready-made layout", icon: "square.stack.3d.up", badge: Badge("Recommended").badgeStyle(.success), isSelected: source == 0) { source = 0 }
        WizardRadioRow("Import a file", detail: "Bring in an existing document", icon: "arrow.down.doc", isSelected: source == 1) { source = 1 }
        WizardRadioRow("Blank", icon: "doc", isSelected: source == 2, compact: true) { source = 2 } trailing: {
            Text(verbatim: "Free").font(Typography.captionSmall).foregroundStyle(.secondary)
        }
    }
    .padding(Spacing.lg)
}

#Preview("Step rows", traits: .fixedLayout(width: 420, height: 280)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        WizardStepRow("Download files", detail: "128 files · 4.2 MB", number: 1, state: .done) {
            Text(verbatim: "4.2 s").font(Typography.captionSmall).foregroundStyle(.secondary)
        }
        WizardStepRow("Check signatures", number: 2, state: .running, progress: 0.6)
        WizardStepRow("Install", detail: "The disk is full.", number: 3, state: .failed) {
            Button("Retry") {}.buttonStyle(GhostButtonStyle(compact: true))
        }
        WizardStepRow("Choose a location", number: 4, state: .current)
        WizardStepRow("Finish", number: 5, state: .pending, compact: true)
    }
    .padding(Spacing.lg)
}
