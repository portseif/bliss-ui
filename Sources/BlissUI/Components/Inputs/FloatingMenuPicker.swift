//
//  FloatingMenuPicker.swift
//  BlissUI
//
//  iOS-inspired picker component:
//  - The trigger is a compact button: the control height, the neutral row
//    wash on hover, a step up while open
//  - Hover eases, a press scales like every button, the open state follows
//    the menu's timing
//  - Keyboard focus and navigation never animate
//

import SwiftUI

// MARK: - Option Detail

/// A labeled bar (value 0...1) shown in an option's hover detail.
public nonisolated struct PickerStatBar: Identifiable, Sendable {
    public let label: String
    public let value: Double
    public let color: Color
    public var id: String { label }

    public init(label: String, value: Double, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }
}

/// Hover-detail data for a picker option: a heading plus labeled bars, rendered
/// in the picker's side pane. The bars grow in when the first detail opens.
public nonisolated struct PickerOptionDetail: Sendable {
    public let title: String
    public var subtitle: String? = nil
    public let bars: [PickerStatBar]

    public init(title: String, subtitle: String? = nil, bars: [PickerStatBar]) {
        self.title = title
        self.subtitle = subtitle
        self.bars = bars
    }
}

// MARK: - Floating Menu Picker

/// A modern picker that uses a floating menu instead of the system picker.
/// `selection` holds the chosen option's `optionTitle`; typing while the menu is
/// open filters the options.
public struct FloatingMenuPicker<T: Hashable, IconContent: View>: View {
    let title: String
    let compactLabel: String?
    @Binding var selection: String
    let options: [T]
    let optionTitle: (T) -> String
    let optionIcon: ((T) -> String)?
    let optionColor: ((T) -> Color?)?
    let optionIconView: ((T, CGFloat) -> IconContent)?
    /// Optional per-option detail shown in a side pane for the focused (hovered)
    /// option — e.g. a stat graph. `nil` keeps the plain list.
    let optionDetail: ((T) -> PickerOptionDetail)?
    /// The trigger's side padding. Pass a tighter value where the picker sits
    /// inline, e.g. in a title-bar breadcrumb.
    let horizontalPadding: CGFloat
    /// Draws the title beside the trigger. Pass false where a row already shows
    /// it (a `SettingsRow`); the title still labels the trigger for VoiceOver.
    let showsTitle: Bool
    /// The dense trigger (`Sizing.controlSmall`, the small label) for a toolbar.
    let compact: Bool
    /// The trigger's hairline; off for a borderless trigger in a title bar or
    /// a table header.
    let showsBorder: Bool
    /// Shown in the secondary tone while `selection` matches no option.
    let placeholder: String?
    /// The selected option's icon and the chevron, no text — a toolbar sort or
    /// view picker. The title still labels the trigger for VoiceOver.
    let iconOnly: Bool

    @State private var showingMenu = false
    @State private var focusedIndex: Int? = nil
    /// Live type-to-filter query while the menu is open (fed by the floating
    /// menu's keyboard monitor; reset whenever the menu closes).
    @State private var typedQuery = ""

    /// - Parameters:
    ///   - title: The row's title, and the trigger's accessibility label.
    ///   - selection: The chosen option's `optionTitle`.
    ///   - options: What the menu lists.
    ///   - optionTitle: How an option reads.
    ///   - optionIcon: An SF Symbol before each option, and on the trigger.
    ///   - optionColor: A color dot instead of the icon, when it returns one.
    ///   - optionDetail: A hover pane beside the focused row.
    ///   - compactLabel: Secondary text before the trigger.
    ///   - horizontalPadding: The trigger's side inset.
    ///   - showsTitle: Draws the title beside the trigger.
    ///   - compact: The dense `Sizing.controlSmall` trigger for a toolbar.
    ///   - showsBorder: The trigger's hairline.
    ///   - placeholder: Shown while `selection` matches no option ("Choose…").
    ///   - iconOnly: The selected icon and the chevron only.
    public init(
        _ title: String,
        selection: Binding<String>,
        options: [T],
        optionTitle: @escaping (T) -> String,
        optionIcon: ((T) -> String)? = nil,
        optionColor: ((T) -> Color?)? = nil,
        optionDetail: ((T) -> PickerOptionDetail)? = nil,
        compactLabel: String? = nil,
        horizontalPadding: CGFloat = Spacing.buttonPaddingH,
        showsTitle: Bool = true,
        compact: Bool = false,
        showsBorder: Bool = true,
        placeholder: String? = nil,
        iconOnly: Bool = false
    ) where IconContent == EmptyView {
        self.title = title
        self.showsTitle = showsTitle
        self.compactLabel = compactLabel
        self._selection = selection
        self.options = options
        self.optionTitle = optionTitle
        self.optionIcon = optionIcon
        self.optionColor = optionColor
        self.optionIconView = nil
        self.optionDetail = optionDetail
        self.horizontalPadding = horizontalPadding
        self.compact = compact
        self.showsBorder = showsBorder
        self.placeholder = placeholder
        self.iconOnly = iconOnly
    }

    /// A picker whose options draw their own icon view.
    public init(
        _ title: String,
        selection: Binding<String>,
        options: [T],
        optionTitle: @escaping (T) -> String,
        optionIconView: @escaping (T, CGFloat) -> IconContent,
        compactLabel: String? = nil,
        horizontalPadding: CGFloat = Spacing.buttonPaddingH,
        showsTitle: Bool = true,
        compact: Bool = false,
        showsBorder: Bool = true,
        placeholder: String? = nil,
        iconOnly: Bool = false
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self.compactLabel = compactLabel
        self._selection = selection
        self.options = options
        self.optionTitle = optionTitle
        self.optionIcon = nil
        self.optionColor = nil
        self.optionIconView = optionIconView
        self.optionDetail = nil
        self.horizontalPadding = horizontalPadding
        self.compact = compact
        self.showsBorder = showsBorder
        self.placeholder = placeholder
        self.iconOnly = iconOnly
    }

    private var selectedOption: T? {
        options.first { optionTitle($0) == selection }
    }

    /// Options narrowed by the typeahead query. The `isEmpty` guard is
    /// load-bearing — `localizedCaseInsensitiveContains("")` returns false.
    private func filteredOptions(for query: String) -> [T] {
        guard !query.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(query) }
    }

    private var visibleOptions: [T] { filteredOptions(for: typedQuery) }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            if showsTitle && !title.isEmpty {
                Text(title)
                    .font(Typography.bodySmall)
                Spacer()
            }
            if let label = compactLabel {
                Text(label)
                    .font(Typography.labelMedium)
                    .foregroundStyle(.secondary)
            }
            Button {
                showingMenu.toggle()
            } label: {
                HStack(spacing: Spacing.inlineSpacing) {
                    if let option = selectedOption {
                        if let iconViewProvider = optionIconView {
                            iconViewProvider(option, Sizing.iconDefault)
                        } else if let iconProvider = optionIcon {
                            if let colorProvider = optionColor, let color = colorProvider(option) {
                                Circle()
                                    .fill(color)
                                    .frame(width: Sizing.iconTiny, height: Sizing.iconTiny)
                            } else {
                                Image(systemName: iconProvider(option))
                                    .font(compact ? Typography.labelSmall : Typography.labelMedium)
                            }
                        }
                    }
                    if !iconOnly {
                        if selectedOption == nil, let placeholder {
                            Text(placeholder)
                                .foregroundStyle(Color.textTertiary)
                        } else {
                            Text(selection)
                        }
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Typography.labelXSmall)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(FloatingMenuPickerButtonStyle(isActive: showingMenu, horizontalPadding: horizontalPadding, compact: compact, showsBorder: showsBorder))
            .accessibilityLabel(Text(verbatim: title.isEmpty ? selection : title))
            .accessibilityValue(Text(verbatim: title.isEmpty ? "" : selection))
            .floatingMenu(
                isPresented: $showingMenu,
                itemCount: visibleOptions.count,
                focusedIndex: $focusedIndex,
                // Menus open aligned to the trigger's LEADING edge — a fit-content
                // panel wider than a small trigger grows rightward, never juts
                // left of it.
                xPosition: .leading,
                yPosition: .below,
                onSelect: { index in
                    let visible = visibleOptions
                    guard visible.indices.contains(index) else { return }
                    selection = optionTitle(visible[index])
                    showingMenu = false
                },
                onTypeahead: { query in
                    typedQuery = query
                    // Land focus on the first match so ↵ selects it directly.
                    focusedIndex = filteredOptions(for: query).isEmpty ? nil : 0
                }
            ) {
                FloatingMenuPickerContent(
                    options: options,
                    selectedValue: selection,
                    focusedIndex: $focusedIndex,
                    optionTitle: optionTitle,
                    optionIcon: optionIcon,
                    optionColor: optionColor,
                    optionIconView: optionIconView,
                    optionDetail: optionDetail,
                    filterQuery: $typedQuery,
                    onSelect: { value in
                        selection = value
                        showingMenu = false
                    }
                )
            }
            .onChange(of: showingMenu) { _, isOpen in
                if !isOpen { typedQuery = "" }
            }
        }
    }
}

// MARK: - Floating Menu Picker Button Style

struct FloatingMenuPickerButtonStyle: ButtonStyle {
    let isActive: Bool
    var horizontalPadding: CGFloat = Spacing.buttonPaddingH
    var compact: Bool = false
    var showsBorder: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        Group {
            FloatingMenuPickerButton(
                configuration: configuration,
                isActive: isActive,
                horizontalPadding: horizontalPadding,
                compact: compact,
                showsBorder: showsBorder,
                colorScheme: colorScheme
            )
        }
        .interactiveCursor()
    }
}

/// Internal view for floating menu picker button with focus tracking
private struct FloatingMenuPickerButton: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let horizontalPadding: CGFloat
    let compact: Bool
    let showsBorder: Bool
    let colorScheme: ColorScheme

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlShape) private var controlShape
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isHighlighted: Bool { configuration.isPressed || isActive }

    private var cornerRadius: CGFloat { controlShape.radius(rounded: Sizing.radiusMedium) }

    /// The one neutral hairline, when the trigger shows one.
    private var borderColor: Color {
        showsBorder ? Color.menuBorder : .clear
    }

    /// The secondary tone at rest, full strength under the pointer or while
    /// open — the secondary button's text.
    private var textColor: Color {
        isHighlighted || isHovering ? Color.primary : Color.secondary
    }

    /// The neutral row wash: hover, then a step up while pressed or open.
    private var backgroundColor: Color {
        if isHighlighted { return RowTint.selected(colorScheme) }
        if isHovering { return RowTint.hover(colorScheme) }
        return Color.clear
    }

    var body: some View {
        configuration.label
            .font(compact ? Typography.labelSmall : Typography.labelMedium)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? min(horizontalPadding, Spacing.sm) : horizontalPadding)
            .padding(.vertical, compact ? Spacing.xxs : Spacing.buttonPaddingV)
            .frame(minHeight: compact ? Sizing.controlSmall : Sizing.controlDefault)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius))
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .focusRing(isFocused: isFocused, cornerRadius: cornerRadius)
            .scaleEffect(configuration.isPressed ? Animations.pressScale : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .matching(cornerRadius)))
            .opacity(isEnabled ? 1 : Animations.disabledOpacity)
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled ? $0 : false }
            // Hover eases, a press answers at once, and the open highlight
            // follows the menu: in on its ease-out, out faster. Focus comes from
            // the keyboard, so its ring isn't animated.
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
            .animation(isActive ? Animations.menuOpen : Animations.menuClose, value: isActive)
    }
}

// MARK: - Floating Menu Picker Content

struct FloatingMenuPickerContent<T, IconContent: View>: View {
    let options: [T]
    let selectedValue: String
    @Binding var focusedIndex: Int?
    let optionTitle: (T) -> String
    let optionIcon: ((T) -> String)?
    let optionColor: ((T) -> Color?)?
    let optionIconView: ((T, CGFloat) -> IconContent)?
    var optionDetail: ((T) -> PickerOptionDetail)? = nil
    /// Type-to-filter query. MUST be a binding — the menu panel snapshots its
    /// content at open time, so only binding reads stay live while it's open.
    @Binding var filterQuery: String
    let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    /// The row the pointer last focused. Focus that moves anywhere else came from
    /// the arrow keys, which is the only time a long, scrolling menu should
    /// follow it — scrolling on hover would slide rows out from under the cursor.
    @State private var hoveredIndex: Int?

    /// Options narrowed by the typeahead query, filtered HERE (off the live
    /// binding) so the open panel re-renders as the user types. The `isEmpty`
    /// guard is load-bearing — `localizedCaseInsensitiveContains("")` is false.
    private var visibleOptions: [T] {
        guard !filterQuery.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(filterQuery) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            if !filterQuery.isEmpty {
                filterHeader
            }
            optionRows
        }
        .padding(Spacing.menuPadding)
        // Fit-content by default. Pickers WITH a hover stat flyout keep the
        // fixed floor — the flyout's offset assumes this panel width.
        .frame(minWidth: optionDetail != nil ? Sizing.menuMinWidth : nil)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The active typeahead query (typing is otherwise invisible), plus a
    /// "No matches" row when the filter empties the list.
    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(filterQuery)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.menuRowPaddingH)
            .padding(.vertical, Spacing.menuRowPaddingV)

            if visibleOptions.isEmpty {
                Text("No matches", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.menuRowPaddingH)
                    .padding(.vertical, Spacing.menuRowPaddingV)
            }
        }
    }

    /// Presentation for an option's hover flyout: open while that row is focused.
    private func flyoutBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { optionDetail != nil && focusedIndex == index },
            set: { newValue in if !newValue, focusedIndex == index { focusedIndex = nil } }
        )
    }

    private var optionRows: some View {
        // The floating menu wraps a list taller than its room in a ScrollView;
        // the reader keeps the keyboard-focused row inside it. Outside a scroll
        // (a short menu) scrollTo does nothing.
        ScrollViewReader { proxy in
            optionRowStack
                .onChange(of: focusedIndex) { _, index in
                    guard let index else { return }
                    // A hover moved it: don't slide rows from under the pointer.
                    // Consumed, so the keys landing on that row later still scroll.
                    if index == hoveredIndex {
                        hoveredIndex = nil
                        return
                    }
                    proxy.scrollTo(index)
                }
        }
    }

    private var optionRowStack: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            ForEach(Array(visibleOptions.enumerated()), id: \.offset) { index, option in
                let title = optionTitle(option)
                let isSelected = title == selectedValue
                let isFocused = focusedIndex == index

                Button {
                    onSelect(title)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if let iconViewProvider = optionIconView {
                            iconViewProvider(option, Sizing.iconTiny)
                                .frame(width: Sizing.iconDefault)
                        } else if let iconProvider = optionIcon {
                            if let colorProvider = optionColor, let color = colorProvider(option) {
                                Circle()
                                    .fill(color)
                                    .frame(width: Sizing.controlTiny, height: Sizing.controlTiny)
                            } else {
                                Image(systemName: iconProvider(option))
                                    .font(Typography.caption)
                                    .frame(width: Sizing.iconDefault)
                                    .foregroundStyle(MenuRowTone.icon)
                            }
                        }

                        Text(title)
                            .font(Typography.bodySmall)
                            .foregroundStyle(MenuRowTone.title)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(Typography.labelSmall)
                                .foregroundStyle(MenuRowTone.checkmark)
                        }
                    }
                    // The menu rows' inset: a step tighter than a list row.
                    .padding(.horizontal, Spacing.menuRowPaddingH)
                    .padding(.vertical, Spacing.menuRowPaddingV)
                    .background(
                        RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .matching(Sizing.radiusDefault))
                            .fill(isFocused ? RowTint.hover(colorScheme) : Color.clear)
                    )
                    .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
                }
                .buttonStyle(.plain)
                .interactiveCursor()
                .id(index)
                .onHover { hovering in
                    if hovering {
                        // Marks only a move it makes (the onChange consumes it).
                        if focusedIndex != index { hoveredIndex = index }
                        focusedIndex = index
                        // The highlight follows the pointer here, so the ring
                        // waits for the next key press.
                        FocusVisibilityService.shared.notePointerInput()
                    }
                }
                // Hover flyout: a separate popup beside this row showing its
                // detail. No chevron — it just appears while the row is focused.
                .floatingMenu(
                    isPresented: flyoutBinding(index),
                    xPosition: .trailing,
                    yPosition: .below,
                    menuGap: 0,
                    xOffset: FloatingMenuPickerMetrics.flyoutXOffset,
                    yOffset: FloatingMenuPickerMetrics.flyoutYOffset
                ) {
                    if let optionDetail {
                        StatGraphFlyout(detail: optionDetail(option))
                    }
                }
            }
        }
    }
}

// MARK: - Metrics

private enum FloatingMenuPickerMetrics {
    /// Where the flyout lands: past the panel's `Sizing.menuMinWidth` floor
    /// plus its padding, so it sits beside the row rather than over it.
    static let flyoutXOffset: CGFloat = Sizing.menuMinWidth + Spacing.xl + Spacing.hairline
    /// One menu row down, so the flyout's top lines up with the row's.
    static let flyoutYOffset: CGFloat = Sizing.controlDefault + Spacing.hairline
    /// The flyout's width.
    static let flyoutWidth: CGFloat = 200
}

// MARK: - Stat Graph Flyout

/// The hover popup beside a picker row: a heading plus labeled bars that grow
/// in when the first popup appears.
private struct StatGraphFlyout: View {
    let detail: PickerOptionDetail
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(detail.title)
                    .font(Typography.labelMedium)
                if let subtitle = detail.subtitle {
                    Text(subtitle)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(detail.bars) { bar in
                    VStack(alignment: .leading, spacing: Spacing.hairline) {
                        Text(bar.label)
                            .font(Typography.labelTiny)
                            .foregroundStyle(.secondary)
                        ProgressBar(value: revealed ? bar.value : 0, tint: bar.color)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(width: FloatingMenuPickerMetrics.flyoutWidth)
        .onAppear {
            // Each row has its own popup, so sweeping down the list opens a new
            // one per row. Those open straight after the last one closed and
            // show their bars at once (regrowing on every hover reads as lag),
            // as does Reduced Motion. Only the first one grows them in.
            guard !MenuMotion.opensInstantly, !prefersReducedMotion else {
                revealed = true
                return
            }
            withAnimation(Animations.menuOpen.delay(0.03)) { revealed = true }
        }
    }
}

// MARK: - Preview

#Preview("Floating menu picker", traits: .fixedLayout(width: 400, height: 200)) {
    VStack(spacing: Spacing.lg) {
        FloatingMenuPicker(
            "Color Scheme",
            selection: .constant("System"),
            options: ["System", "Light", "Dark"],
            optionTitle: { $0 },
            optionIcon: { option in
                switch option {
                case "System": return "circle.lefthalf.filled"
                case "Light": return "sun.max"
                case "Dark": return "moon"
                default: return "circle"
                }
            }
        )
        FloatingMenuPicker("Sort", selection: .constant(""), options: ["Name", "Date"], optionTitle: { $0 }, showsTitle: false, compact: true, placeholder: "Sort by…")
        FloatingMenuPicker("View", selection: .constant("Grid"), options: ["List", "Grid"], optionTitle: { $0 }, optionIcon: { $0 == "List" ? "list.bullet" : "square.grid.2x2" }, showsTitle: false, showsBorder: false, iconOnly: true)
    }
    .padding(Spacing.lg)
}
