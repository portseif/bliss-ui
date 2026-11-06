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

// MARK: - Wizard Radio Row

/// One choice in a radio list: an icon, a title and a line of detail, with a
/// radio mark on the trailing edge. The picked row keeps the stronger
/// `RowTint` fill; hover is the subtler step below it. A Tab stop with the
/// shared ring; Space or Return picks it.
public struct WizardRadioRow: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let icon: String?
    private let isSelected: Bool
    private let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - title: The choice. Looked up in your app's strings.
    ///   - subtitle: A line on what it means, under the title.
    ///   - icon: An SF Symbol, accent-colored while the row is picked.
    ///   - isSelected: Whether the row is picked.
    ///   - action: Runs on a click, Space or Return — pick this row.
    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(isSelected ? Color.accent : Color.secondary)
                        .frame(width: Sizing.controlDefault, height: Sizing.controlDefault)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.labelLarge)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Spacing.sm)

                RadioGlyph(isOn: isSelected, size: Sizing.iconDefault)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // The picked row keeps the stronger persistent fill; hover is
                // the subtler step below it — a hovered neighbor must never
                // out-rank the current choice.
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(
                        isSelected
                            ? RowTint.selected(colorScheme)
                            : (isHovering ? RowTint.hover(colorScheme) : Color.clear)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { hovering in withAnimation(Animations.hover) { isHovering = hovering } }
        .animation(Animations.selection, value: isSelected)
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
/// pending — accent for the current step — the spinner while running, an
/// accent disc with a check once done, and a filled danger disc with a cross
/// on failure. A failed step's detail is set in the danger mark, for the reason.
public struct WizardStepRow: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let number: Int?
    private let state: WizardStepState

    private let markSize: CGFloat = 20

    /// - Parameters:
    ///   - title: The step. Looked up in your app's strings.
    ///   - detail: A line under it — what it did, or why it failed.
    ///   - number: Shown in the ring while the step hasn't finished; nil for a plain ring.
    ///   - state: Where the step stands.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        number: Int? = nil,
        state: WizardStepState
    ) {
        self.title = title
        self.detail = detail
        self.number = number
        self.state = state
    }

    public var body: some View {
        // Baseline-aligned, like a Label, so the mark stays with the title when
        // a detail line hangs below it.
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm + 2) {
            mark
                .frame(width: markSize, height: markSize)
                .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(state == .pending ? Color.secondary : Color.primary)
                if let detail {
                    Text(detail)
                        .font(Typography.captionSmall)
                        .foregroundStyle(state == .failed ? AnyShapeStyle(Danger.danger500) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
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
                .strokeBorder(state == .current ? Color.accent : Color.secondary.opacity(0.3), lineWidth: 1.5)
                .overlay {
                    if let number {
                        Text(verbatim: "\(number)")
                            .font(Typography.labelSmall)
                            .foregroundStyle(state == .current ? Color.accent : Color.secondary)
                    }
                }
        case .running:
            ThinkingSpinner(size: markSize - 2, lineWidth: 2, color: Color.accent)
        case .done:
            Circle()
                .fill(Color.accent)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(Typography.labelXSmallBold)
                        .foregroundStyle(AccentHue.contrastForeground)
                }
        case .failed:
            // White on the danger TINT: the lifted dark-mode mark is too light
            // to carry white.
            Circle()
                .fill(Danger.tint)
                .overlay {
                    Image(systemName: "xmark")
                        .font(Typography.labelXSmallBold)
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

// MARK: - Previews

#Preview("Radio rows", traits: .fixedLayout(width: 420, height: 230)) {
    @Previewable @State var source = 0
    VStack(spacing: Spacing.xxs) {
        WizardRadioRow("From a template", subtitle: "Start from a ready-made layout", icon: "square.stack.3d.up", isSelected: source == 0) { source = 0 }
        WizardRadioRow("Import a file", subtitle: "Bring in an existing document", icon: "arrow.down.doc", isSelected: source == 1) { source = 1 }
        WizardRadioRow("Blank", icon: "doc", isSelected: source == 2) { source = 2 }
    }
    .padding(Spacing.lg)
}

#Preview("Step rows", traits: .fixedLayout(width: 420, height: 260)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        WizardStepRow("Download files", detail: "128 files · 4.2 MB", number: 1, state: .done)
        WizardStepRow("Check signatures", number: 2, state: .running)
        WizardStepRow("Install", detail: "The disk is full.", number: 3, state: .failed)
        WizardStepRow("Choose a location", number: 4, state: .current)
        WizardStepRow("Finish", number: 5, state: .pending)
    }
    .padding(Spacing.lg)
}
