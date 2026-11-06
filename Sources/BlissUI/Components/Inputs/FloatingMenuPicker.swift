//
//  FloatingMenuPicker.swift
//  BlissUI
//
//  iOS-inspired picker component:
//  - Opacity-based backgrounds for light/dark modes
//  - Hover eases, a press scales to 0.97, the open state follows the menu's timing
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

    @State private var showingMenu = false
    @State private var focusedIndex: Int? = nil
    /// Live type-to-filter query while the menu is open (fed by the floating
    /// menu's keyboard monitor; reset whenever the menu closes).
    @State private var typedQuery = ""

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
        showsTitle: Bool = true
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
    }

    public init(
        _ title: String,
        selection: Binding<String>,
        options: [T],
        optionTitle: @escaping (T) -> String,
        optionIconView: @escaping (T, CGFloat) -> IconContent,
        compactLabel: String? = nil,
        horizontalPadding: CGFloat = Spacing.buttonPaddingH,
        showsTitle: Bool = true
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
        HStack {
            if showsTitle && !title.isEmpty {
                Text(title)
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
                                    .font(Typography.labelMedium)
                            }
                        }
                    }
                    Text(selection)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Typography.bodySmallSemibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(FloatingMenuPickerButtonStyle(isActive: showingMenu, horizontalPadding: horizontalPadding))
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
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        FloatingMenuPickerButton(
            configuration: configuration,
            isActive: isActive,
            horizontalPadding: horizontalPadding,
            colorScheme: colorScheme
        )
    }
}

/// Internal view for floating menu picker button with focus tracking
private struct FloatingMenuPickerButton: View {
    let configuration: ButtonStyleConfiguration
    let isActive: Bool
    let horizontalPadding: CGFloat
    let colorScheme: ColorScheme

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    private var isHighlighted: Bool { configuration.isPressed || isActive }

    /// A faint hairline, fainter while disabled.
    private var borderColor: Color {
        Color.primary.opacity(isEnabled ? 0.1 : 0.06)
    }

    /// iOS-style text color. Disabled keeps the value readable, a step dimmer.
    private var textColor: Color {
        if !isEnabled {
            return colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.35)
        }
        if isHighlighted || isHovering {
            return colorScheme == .dark ? .white : .primary
        }
        return colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5)
    }

    /// The neutral row wash: hover, then a step up while pressed or open.
    private var backgroundColor: Color {
        if isHighlighted { return RowTint.selected(colorScheme) }
        if isHovering { return RowTint.hover(colorScheme) }
        return Color.clear
    }

    var body: some View {
        configuration.label
            .font(Typography.bodySmall)
            .foregroundStyle(textColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, Spacing.buttonPaddingV)
            .frame(maxHeight: Sizing.controlDefault + 2)
            .background(
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusMedium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous))
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

    /// iOS-style text color
    private func textColor(isSelected: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? .white : .primary
        }
        return colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }

    /// iOS-style checkmark
    private var checkmarkColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45)
    }

    /// Icon color
    private var iconColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.35)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if !filterQuery.isEmpty {
                filterHeader
            }
            optionRows
        }
        .padding(Spacing.menuPadding)
        // Fit-content by default. Pickers WITH a hover stat flyout keep the
        // fixed floor — the flyout's xOffset (206) assumes this panel width.
        .frame(minWidth: optionDetail != nil ? 180 : nil)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// The active typeahead query (typing is otherwise invisible), plus a
    /// "No matches" row when the filter empties the list.
    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(filterQuery)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)

            if visibleOptions.isEmpty {
                Text("No matches", bundle: .module)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.xs - 1)
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
        VStack(alignment: .leading, spacing: 1) {
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
                                .opacity(0.7)
                        } else if let iconProvider = optionIcon {
                            if let colorProvider = optionColor, let color = colorProvider(option) {
                                Circle()
                                    .fill(color)
                                    .frame(width: Sizing.controlTiny, height: Sizing.controlTiny)
                            } else {
                                Image(systemName: iconProvider(option))
                                    .font(Typography.caption)
                                    .frame(width: Sizing.iconDefault)
                                    .foregroundStyle(iconColor)
                            }
                        }

                        Text(title)
                            .font(Typography.bodySmall)
                            .foregroundStyle(textColor(isSelected: isSelected))

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(Typography.labelSmall)
                                .foregroundStyle(checkmarkColor)
                        }
                    }
                    // Tighter than the button padding tokens — menu rows read better
                    // compact (≈ standard macOS menu row height).
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.xs - 1)
                    .background(
                        RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                            .fill(isFocused ? RowTint.hover(colorScheme) : Color.clear)
                    )
                    .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
                }
                .buttonStyle(.plain)
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
                    xOffset: 206,
                    yOffset: 30
                ) {
                    if let optionDetail {
                        StatGraphFlyout(detail: optionDetail(option))
                    }
                }
            }
        }
    }
}

// MARK: - Stat Graph Flyout

/// The hover popup beside a picker row: a heading plus labeled bars that grow
/// in when the first popup appears.
private struct StatGraphFlyout: View {
    let detail: PickerOptionDetail
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bar.label)
                            .font(Typography.labelTiny)
                            .foregroundStyle(.secondary)
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(bar.color)
                                    .frame(width: max(4, geometry.size.width * (revealed ? bar.value : 0)))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(width: 200)
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

#Preview {
    VStack(spacing: 20) {
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
    }
    .padding()
    .frame(width: 400)
}
