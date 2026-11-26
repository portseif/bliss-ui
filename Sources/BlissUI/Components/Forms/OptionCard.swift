//
//  OptionCard.swift
//  BlissUI
//
//  A card picked by clicking it — a plan, a kind of task, a destination — and
//  the grid that lays a set of them out and keeps the selection. One choice
//  (a radio mark) or several (a checkbox mark).
//

import SwiftUI

// MARK: - Metrics

/// The card's geometry, shared with `WizardRadioRow` so a wizard that mixes
/// cards and rows reads as one set.
enum OptionCardMetrics {
    static let cornerRadius: CGFloat = Sizing.radiusLarge
    /// A card laid out in a row: the content's inset.
    static let horizontalInset: CGFloat = Spacing.md
    static let verticalInset: CGFloat = Spacing.md
    /// A card stacked vertically (a row of plans): the card's inset.
    static let stackedInset: CGFloat = Spacing.cardPadding
    /// A compact card's vertical inset.
    static let compactVerticalInset: CGFloat = Spacing.sm
    /// The icon's slot in the row layout and in the stacked layout.
    static let rowIconSlot: CGFloat = Sizing.iconMedium
    static let stackedIconSlot: CGFloat = Sizing.iconLarge
}

// MARK: - Selection mode

/// Whether a set of option cards picks one or several.
public nonisolated enum OptionCardSelection: Sendable, Hashable {
    /// Radio: picking a card unpicks the others.
    case single
    /// Checkbox: each card turns on and off by itself.
    case multiple
}

// MARK: - Option Card

/// A pickable card: an icon (or your own artwork), a title, a line of detail,
/// an optional value ("$9 / mo") and an optional `Badge`, with a radio
/// (`.single`) or checkbox (`.multiple`) mark showing whether it's picked. A
/// picked card takes the selected wash and an accent edge. It's a Tab stop
/// with the shared ring; Space or Return picks it. `axis: .vertical` stacks
/// the content centered, for a row of plans.
///
/// Usually built by `OptionCardGrid`, which keeps the selection; use it alone
/// for a layout of your own.
public struct OptionCard<Artwork: View>: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let value: LocalizedStringKey?
    private let icon: String?
    private let badge: Badge?
    private let isSelected: Bool
    private let selection: OptionCardSelection
    private let axis: Axis
    private let compact: Bool
    private let showsMark: Bool
    private let action: () -> Void
    private let artwork: (() -> Artwork)?
    /// Set by `OptionCardGrid`: stretch to the tallest card in the row, so a
    /// row of cards with different amounts of text lines up.
    var fillsHeight = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius = OptionCardMetrics.cornerRadius

    /// A card with your own artwork in the icon's place — a template's
    /// thumbnail, a theme swatch.
    /// - Parameters:
    ///   - title: The option's name. Looked up in your app's strings.
    ///   - detail: A line on what it means, under the title.
    ///   - value: A price or a figure, trailing in a row card, under the title
    ///     in a stacked one.
    ///   - badge: A badge beside the title ("Save 20%", "Soon"), styled as you like.
    ///   - isSelected: Whether the card is picked.
    ///   - selection: The mark: a radio for `.single`, a checkbox for `.multiple`.
    ///   - axis: `.horizontal` lays the content out in a row; `.vertical`
    ///     stacks it centered.
    ///   - compact: A tighter card with no detail line, for a dense sheet.
    ///   - showsMark: Off, the card's state is its edge and wash alone (a swatch picker).
    ///   - action: Runs on a click, Space or Return — pick or toggle the option.
    ///   - artwork: Drawn in the icon's slot.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        value: LocalizedStringKey? = nil,
        badge: Badge? = nil,
        isSelected: Bool,
        selection: OptionCardSelection = .single,
        axis: Axis = .horizontal,
        compact: Bool = false,
        showsMark: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder artwork: @escaping () -> Artwork
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.icon = nil
        self.badge = badge
        self.isSelected = isSelected
        self.selection = selection
        self.axis = axis
        self.compact = compact
        self.showsMark = showsMark
        self.action = action
        self.artwork = artwork
    }

    fileprivate init(
        title: LocalizedStringKey,
        detail: LocalizedStringKey?,
        value: LocalizedStringKey?,
        icon: String?,
        badge: Badge?,
        isSelected: Bool,
        selection: OptionCardSelection,
        axis: Axis,
        compact: Bool,
        showsMark: Bool,
        action: @escaping () -> Void,
        artwork: (() -> Artwork)?
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.icon = icon
        self.badge = badge
        self.isSelected = isSelected
        self.selection = selection
        self.axis = axis
        self.compact = compact
        self.showsMark = showsMark
        self.action = action
        self.artwork = artwork
    }

    public var body: some View {
        Button(action: action) {
            Group {
                switch axis {
                case .horizontal: horizontalContent
                case .vertical: verticalContent
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: fillsHeight ? .infinity : nil,
                alignment: axis == .horizontal ? .topLeading : .top
            )
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? RowTint.selected(colorScheme) : Color.restingFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accent : Color.menuBorder, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
            .animation(Animations.selection, value: isSelected)
        }
        .buttonStyle(SelectableCardButtonStyle(cornerRadius: cornerRadius))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Layouts

    private var horizontalContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            leadingMark(font: Typography.bodyMedium, slot: OptionCardMetrics.rowIconSlot)
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                HStack(spacing: Spacing.xs) {
                    titleText
                    if let badge {
                        badge.badgeSize(.small)
                    }
                }
                if let detail, !compact {
                    detailText(detail)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: Spacing.xs)
            if let value {
                valueText(value)
            }
            if showsMark {
                mark
                    .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
            }
        }
        .padding(.horizontal, OptionCardMetrics.horizontalInset)
        .padding(.vertical, compact ? OptionCardMetrics.compactVerticalInset : OptionCardMetrics.verticalInset)
    }

    private var verticalContent: some View {
        VStack(spacing: Spacing.xs) {
            leadingMark(font: Typography.headingMedium, slot: OptionCardMetrics.stackedIconSlot)
            titleText
            if let value {
                valueText(value)
            }
            if let detail, !compact {
                detailText(detail)
                    .multilineTextAlignment(.center)
            }
            if let badge {
                badge.badgeSize(.small)
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(.horizontal, OptionCardMetrics.stackedInset)
        .padding(.vertical, compact ? OptionCardMetrics.compactVerticalInset : OptionCardMetrics.stackedInset)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            if showsMark {
                mark.padding(Spacing.sm)
            }
        }
    }

    // MARK: Pieces

    /// The artwork, or the icon in its slot.
    @ViewBuilder
    private func leadingMark(font: Font, slot: CGFloat) -> some View {
        if let artwork {
            artwork()
                .accessibilityHidden(true)
        } else if let icon {
            BlissSymbol(icon)
                .font(font)
                .foregroundStyle(isSelected ? Color.accent : Color.secondary)
                .frame(width: axis == .horizontal ? slot : nil, height: axis == .vertical ? slot : nil)
                .accessibilityHidden(true)
        }
    }

    private var titleText: some View {
        Text(title)
            .font(Typography.labelMedium)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }

    private func detailText(_ detail: LocalizedStringKey) -> some View {
        Text(detail)
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func valueText(_ value: LocalizedStringKey) -> some View {
        Text(value)
            .font(Typography.labelMedium.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var mark: some View {
        switch selection {
        case .single: RadioGlyph(isOn: isSelected, size: Sizing.iconSmall)
        case .multiple: CheckboxGlyph(isOn: isSelected, size: Sizing.iconSmall)
        }
    }
}

extension OptionCard where Artwork == EmptyView {
    /// - Parameters:
    ///   - title: The option's name. Looked up in your app's strings.
    ///   - detail: A line on what it means, under the title.
    ///   - value: A price or a figure, trailing in a row card, under the title
    ///     in a stacked one.
    ///   - icon: An SF Symbol, accent-colored while the card is picked.
    ///   - badge: A badge beside the title ("Save 20%", "Soon"), styled as you like.
    ///   - isSelected: Whether the card is picked.
    ///   - selection: The mark: a radio for `.single`, a checkbox for `.multiple`.
    ///   - axis: `.horizontal` lays the content out in a row; `.vertical`
    ///     stacks it centered.
    ///   - compact: A tighter card with no detail line, for a dense sheet.
    ///   - showsMark: Off, the card's state is its edge and wash alone.
    ///   - action: Runs on a click, Space or Return — pick or toggle the option.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        value: LocalizedStringKey? = nil,
        icon: String? = nil,
        badge: Badge? = nil,
        isSelected: Bool,
        selection: OptionCardSelection = .single,
        axis: Axis = .horizontal,
        compact: Bool = false,
        showsMark: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            detail: detail,
            value: value,
            icon: icon,
            badge: badge,
            isSelected: isSelected,
            selection: selection,
            axis: axis,
            compact: compact,
            showsMark: showsMark,
            action: action,
            artwork: nil
        )
    }
}

// MARK: - Option Card Grid

/// A set of `OptionCard`s in rows of `columns`, keeping the selection: bind a
/// single value for one choice (radio marks) or a set for several (checkbox
/// marks). Cards in a row share the tallest one's height. With
/// `minimumCardWidth` the columns follow the width instead (a resizable
/// window), and rows no longer equalize.
///
/// ```swift
/// OptionCardGrid(Plan.allCases, selection: $plan, columns: 3, axis: .vertical,
///                title: { $0.title }, detail: { $0.price },
///                badge: { $0 == .yearly ? Badge("Save 20%").badgeStyle(.success) : nil })
/// ```
public struct OptionCardGrid<Option: Hashable>: View {
    private let options: [Option]
    /// The single choice (`.constant(nil)` in multiple mode).
    @Binding private var singleSelection: Option?
    /// The picked set (`.constant([])` in single mode).
    @Binding private var multipleSelection: Set<Option>
    private let mode: OptionCardSelection
    private let columns: Int
    private let minimumCardWidth: CGFloat?
    private let axis: Axis
    private let title: (Option) -> LocalizedStringKey
    private let detail: (Option) -> LocalizedStringKey?
    private let icon: (Option) -> String?
    private let badge: (Option) -> Badge?
    private let isOptionEnabled: (Option) -> Bool

    /// One choice: picking a card unpicks the others.
    /// - Parameters:
    ///   - options: The options, in reading order.
    ///   - selection: The picked option.
    ///   - columns: Cards per row (1 for a list of wide cards).
    ///   - minimumCardWidth: Adaptive columns: as many cards per row as fit at
    ///     this width, instead of `columns`.
    ///   - axis: The cards' layout (see `OptionCard`).
    ///   - title: Each option's name. Looked up in your app's strings.
    ///   - detail: A line under the name.
    ///   - icon: An SF Symbol for the option.
    ///   - badge: A badge beside the name.
    ///   - isOptionEnabled: A disabled option dims and can't be picked.
    public init(
        _ options: [Option],
        selection: Binding<Option>,
        columns: Int = 2,
        minimumCardWidth: CGFloat? = nil,
        axis: Axis = .horizontal,
        title: @escaping (Option) -> LocalizedStringKey,
        detail: @escaping (Option) -> LocalizedStringKey? = { _ in nil },
        icon: @escaping (Option) -> String? = { _ in nil },
        badge: @escaping (Option) -> Badge? = { _ in nil },
        isOptionEnabled: @escaping (Option) -> Bool = { _ in true }
    ) {
        self.options = options
        self._singleSelection = Binding(selection)
        self._multipleSelection = .constant([])
        self.mode = .single
        self.columns = max(1, columns)
        self.minimumCardWidth = minimumCardWidth
        self.axis = axis
        self.title = title
        self.detail = detail
        self.icon = icon
        self.badge = badge
        self.isOptionEnabled = isOptionEnabled
    }

    /// Several choices: each card turns on and off by itself.
    /// - Parameters: As for one choice, with `selection` the set of picked options.
    public init(
        _ options: [Option],
        selection: Binding<Set<Option>>,
        columns: Int = 2,
        minimumCardWidth: CGFloat? = nil,
        axis: Axis = .horizontal,
        title: @escaping (Option) -> LocalizedStringKey,
        detail: @escaping (Option) -> LocalizedStringKey? = { _ in nil },
        icon: @escaping (Option) -> String? = { _ in nil },
        badge: @escaping (Option) -> Badge? = { _ in nil },
        isOptionEnabled: @escaping (Option) -> Bool = { _ in true }
    ) {
        self.options = options
        self._singleSelection = .constant(nil)
        self._multipleSelection = selection
        self.mode = .multiple
        self.columns = max(1, columns)
        self.minimumCardWidth = minimumCardWidth
        self.axis = axis
        self.title = title
        self.detail = detail
        self.icon = icon
        self.badge = badge
        self.isOptionEnabled = isOptionEnabled
    }

    public var body: some View {
        if let minimumCardWidth {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCardWidth), spacing: Spacing.sm)], alignment: .leading, spacing: Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    card(for: option)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(OptionCardGridLayout.rows(count: options.count, columns: columns), id: \.self) { row in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        ForEach(options[row], id: \.self) { option in
                            card(for: option)
                        }
                        // Keep the last row's cards the same width as the rest.
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity).frame(height: 0)
                        }
                    }
                    // Each card fills the row's height, so the row takes the
                    // tallest card's ideal height and the others stretch to it.
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func isSelected(_ option: Option) -> Bool {
        switch mode {
        case .single: singleSelection == option
        case .multiple: multipleSelection.contains(option)
        }
    }

    private func pick(_ option: Option) {
        withAnimation(Animations.selection) {
            switch mode {
            case .single:
                singleSelection = option
            case .multiple:
                if multipleSelection.contains(option) {
                    multipleSelection.remove(option)
                } else {
                    multipleSelection.insert(option)
                }
            }
        }
    }

    private func card(for option: Option) -> some View {
        var card = OptionCard(
            title(option),
            detail: detail(option),
            icon: icon(option),
            badge: badge(option),
            isSelected: isSelected(option),
            selection: mode,
            axis: axis,
            action: { pick(option) }
        )
        card.fillsHeight = minimumCardWidth == nil
        return card.disabled(!isOptionEnabled(option))
    }
}

/// The grid's row ranges, kept apart from the view so it can be tested.
enum OptionCardGridLayout {
    /// `count` items in rows of `columns`: the index range of each row.
    static func rows(count: Int, columns: Int) -> [Range<Int>] {
        let columns = max(1, columns)
        return stride(from: 0, to: count, by: columns).map { start in
            start..<min(start + columns, count)
        }
    }
}

// MARK: - Previews

private enum PreviewPlan: String, CaseIterable {
    case monthly = "Monthly", yearly = "Yearly", lifetime = "Lifetime"
}

#Preview("Option cards", traits: .fixedLayout(width: 520, height: 300)) {
    @Previewable @State var kind = "Review"
    @Previewable @State var plan = PreviewPlan.yearly
    VStack(spacing: Spacing.lg) {
        OptionCardGrid(
            ["Review", "Refactor", "Write tests", "Explain"],
            selection: $kind,
            title: { LocalizedStringKey($0) },
            detail: { _ in "Reads the code and reports back." },
            icon: { _ in "doc.text.magnifyingglass" },
            isOptionEnabled: { $0 != "Explain" }
        )
        OptionCardGrid(
            PreviewPlan.allCases,
            selection: $plan,
            columns: 3,
            axis: .vertical,
            title: { LocalizedStringKey($0.rawValue) },
            detail: { $0 == .lifetime ? "Pay once" : "Billed \($0.rawValue.lowercased())" },
            badge: { $0 == .yearly ? Badge("Save 20%").badgeStyle(.success) : nil }
        )
    }
    .padding(Spacing.lg)
}

#Preview("Multiple choice", traits: .fixedLayout(width: 520, height: 140)) {
    @Previewable @State var contents: Set<String> = ["Database"]
    OptionCardGrid(
        ["Database", "Files", "Settings"],
        selection: $contents,
        columns: 3,
        title: { LocalizedStringKey($0) },
        icon: { $0 == "Database" ? "cylinder" : ($0 == "Files" ? "folder" : "gearshape") }
    )
    .padding(Spacing.lg)
}

#Preview("Artwork and values", traits: .fixedLayout(width: 520, height: 120)) {
    HStack(spacing: Spacing.sm) {
        OptionCard("Pro", detail: "Billed yearly", value: "$80 / yr", isSelected: true, action: {}) {
            RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                .fill(Color.accent)
                .frame(width: OptionCardMetrics.rowIconSlot, height: OptionCardMetrics.rowIconSlot)
        }
        OptionCard("Team", value: "$240 / yr", icon: "person.3", isSelected: false, compact: true, action: {})
    }
    .padding(Spacing.lg)
}
