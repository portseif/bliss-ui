//
//  IconPicker.swift
//  BlissUI
//
//  Reusable icon picker with SF Symbols and bundled asset icons organized by category.
//  BlissUI ships SF Symbol categories (`IconCategory.defaults`); pass your own
//  categories to add the app's asset icons (`icon-` names, loaded from the app's
//  asset catalog).
//

import SwiftUI

// MARK: - Icon Category

/// A titled group of icons in the picker, with a badge glyph for its header.
public nonisolated struct IconCategory: Identifiable, Sendable {
    public let id: String
    public let title: String
    /// The SF Symbol on the category's header badge.
    public let icon: String
    public let icons: [IconItem]

    /// `id` defaults to the title; pass one when titles can repeat.
    public init(id: String? = nil, title: String, icon: String, icons: [IconItem]) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
        self.icons = icons
    }

    public static let general = IconCategory(
        id: "general",
        title: String(localized: "General"),
        icon: "square.grid.2x2",
        icons: [
            .sfSymbol("folder"), .sfSymbol("folder.badge.gear"),
            .sfSymbol("globe"), .sfSymbol("globe.americas"),
            .sfSymbol("server.rack"), .sfSymbol("cloud"),
            .sfSymbol("bolt.fill"), .sfSymbol("star"),
            .sfSymbol("heart"), .sfSymbol("bookmark"),
            .sfSymbol("tag"), .sfSymbol("flag"),
            .sfSymbol("cube"), .sfSymbol("cube.box"),
            .sfSymbol("shippingbox"), .sfSymbol("archivebox"),
            .sfSymbol("tray.full"), .sfSymbol("briefcase"),
            .sfSymbol("building.2"), .sfSymbol("house"),
            .sfSymbol("cart"), .sfSymbol("creditcard"),
            .sfSymbol("chart.bar"), .sfSymbol("chart.line.uptrend.xyaxis"),
            .sfSymbol("person.2"), .sfSymbol("person.crop.circle"),
            .sfSymbol("lock"), .sfSymbol("key"),
            .sfSymbol("shield"), .sfSymbol("shield.checkered"),
            .sfSymbol("bell"), .sfSymbol("envelope"),
            .sfSymbol("camera"), .sfSymbol("photo"),
            .sfSymbol("paintbrush"), .sfSymbol("paintpalette"),
            .sfSymbol("wand.and.stars"), .sfSymbol("sparkles"),
            .sfSymbol("leaf"), .sfSymbol("flame"),
            .sfSymbol("drop"), .sfSymbol("sun.max"),
            .sfSymbol("moon"), .sfSymbol("gamecontroller"),
            .sfSymbol("headphones"), .sfSymbol("music.note"),
            .sfSymbol("mic"), .sfSymbol("video"),
        ]
    )

    public static let tools = IconCategory(
        id: "tools",
        title: String(localized: "Tools"),
        icon: "wrench.and.screwdriver",
        icons: [
            .sfSymbol("wrench"), .sfSymbol("hammer"),
            .sfSymbol("gearshape"), .sfSymbol("gearshape.2"),
            .sfSymbol("slider.horizontal.3"), .sfSymbol("tuningfork"),
            .sfSymbol("gauge.with.needle"), .sfSymbol("speedometer"),
            .sfSymbol("antenna.radiowaves.left.and.right"),
            .sfSymbol("network"), .sfSymbol("wifi"),
            .sfSymbol("cpu"), .sfSymbol("memorychip"),
            .sfSymbol("externaldrive"), .sfSymbol("internaldrive"),
            .sfSymbol("puzzlepiece.extension"), .sfSymbol("lifepreserver"),
        ]
    )

    /// The categories BlissUI ships, in picker order.
    public static let defaults: [IconCategory] = [.general, .tools]
}

// MARK: - Icon Item

/// One pickable icon: an SF Symbol, or an asset from the app's catalog.
public nonisolated struct IconItem: Identifiable, Equatable, Sendable {
    public let name: String
    public let isAsset: Bool

    public var id: String { name }

    /// The reserved icon name for the 6×6 status dot — the simplest mark, and a
    /// good default for a new item. Rendered as a colored dot rather than a glyph.
    public static let statusDotName = "status-dot"

    public var isStatusDot: Bool { name == Self.statusDotName }

    /// Display name for search (strips "icon-" prefix from assets)
    var searchableName: String {
        if isStatusDot { return "dot default" }
        if isAsset {
            return name.replacingOccurrences(of: "icon-", with: "").replacingOccurrences(of: "-", with: " ")
        }
        return name.replacingOccurrences(of: ".", with: " ")
    }

    public static func sfSymbol(_ name: String) -> IconItem {
        IconItem(name: name, isAsset: false)
    }

    /// An asset from the app's main-bundle catalog. Name it with the `icon-`
    /// prefix so `IconGlyph` renders the stored name as an asset too.
    public static func asset(_ name: String) -> IconItem {
        IconItem(name: name, isAsset: true)
    }

    public static let statusDot = IconItem(name: statusDotName, isAsset: false)
}

// MARK: - Icon Glyph (shared renderer)

/// Renders a stored icon name — the 6×6 status dot, a bundled asset (`icon-*`), or an
/// SF Symbol — tinted by `color`. Use it wherever a picked mark is shown (a sidebar
/// row, a sheet preview, a table chip) so every surface draws it the same way.
/// Convention: `IconItem.statusDotName` → dot, `icon-` prefix → asset, else SF Symbol.
public struct IconGlyph: View {
    let name: String
    var color: Color = .secondary
    var size: CGFloat = 16

    public init(name: String, color: Color = .secondary, size: CGFloat = 16) {
        self.name = name
        self.color = color
        self.size = size
    }

    public var body: some View {
        if name == IconItem.statusDotName {
            Circle()
                .fill(color)
                .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
        } else if name.hasPrefix("icon-") {
            Image(name)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(color)
        } else {
            Image(systemName: name)
                .font(.system(size: size))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Compact Icon Picker Button

/// A small swatch-style button that shows the currently selected icon in its color and
/// opens the icon picker in a popover. The popover carries the shared `ColorPickerButton`
/// at the top (so icon + color are chosen in one place), then the `GroupIconPicker` (with
/// the status-dot default). Sits as a leading accessory next to a name field — e.g. in
/// a "new item" sheet. Bind `red`/`green`/`blue` (0...1) for the mark's color.
public struct IconPickerButton: View {
    @Binding var selectedIcon: String
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    /// Off for a mark without a color of its own (e.g. a tool's logo): no Color
    /// row, no status dot, and the glyph drawn in the secondary tone.
    var showsColor = true
    /// The icon sets offered in the popover.
    var categories: [IconCategory] = IconCategory.defaults

    @State private var showingPicker = false
    @Environment(\.colorScheme) private var colorScheme

    private var color: Color { showsColor ? Color(red: red, green: green, blue: blue) : .secondary }

    /// An icon alone, without a color.
    public init(selectedIcon: Binding<String>, categories: [IconCategory] = IconCategory.defaults) {
        self.init(selectedIcon: selectedIcon, red: .constant(0), green: .constant(0), blue: .constant(0), showsColor: false, categories: categories)
    }

    public init(
        selectedIcon: Binding<String>,
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        showsColor: Bool = true,
        categories: [IconCategory] = IconCategory.defaults
    ) {
        self._selectedIcon = selectedIcon
        self._red = red
        self._green = green
        self._blue = blue
        self.showsColor = showsColor
        self.categories = categories
    }

    public var body: some View {
        Button {
            showingPicker = true
        } label: {
            IconGlyph(name: selectedIcon, color: color, size: 15)
                .frame(width: 30, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                }
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall))
        .accessibilityLabel(Text("Choose icon"))
        .popover(isPresented: $showingPicker) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if showsColor {
                    HStack(spacing: Spacing.sm) {
                        Text("Color")
                            .font(Typography.labelMedium)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: Spacing.sm)
                        ColorPickerButton(red: $red, green: $green, blue: $blue)
                    }
                }
                GroupIconPicker(selectedIcon: $selectedIcon, includeStatusDot: showsColor, categories: categories)
            }
            .frame(width: 380)
            .padding(Spacing.md)
        }
    }
}

// MARK: - Icon Picker

/// A searchable grid of icons by category. Binds the picked icon's name, which
/// `IconGlyph` renders.
public struct GroupIconPicker: View {
    @Binding var selectedIcon: String
    /// Show a leading "Default" option — a 6×6 status dot — as the simplest mark.
    /// Opt-in (off by default), for marks that carry a color of their own.
    var includeStatusDot: Bool = false
    /// The icon sets to offer, in order.
    var categories: [IconCategory] = IconCategory.defaults
    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme

    public init(
        selectedIcon: Binding<String>,
        includeStatusDot: Bool = false,
        categories: [IconCategory] = IconCategory.defaults
    ) {
        self._selectedIcon = selectedIcon
        self.includeStatusDot = includeStatusDot
        self.categories = categories
    }

    /// Whether the status-dot default should show for the current search.
    private var showsStatusDot: Bool {
        guard includeStatusDot else { return false }
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return query.isEmpty || "dot default".contains(query)
    }

    private var filteredCategories: [(IconCategory, [IconItem])] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)

        return categories.compactMap { category in
            let filteredIcons: [IconItem]
            if query.isEmpty {
                filteredIcons = category.icons
            } else {
                filteredIcons = category.icons.filter { iconItem in
                    iconItem.searchableName.localizedCaseInsensitiveContains(query) ||
                    category.title.localizedCaseInsensitiveContains(query)
                }
            }

            if filteredIcons.isEmpty { return nil }
            return (category, filteredIcons)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Search
            TextField("Search icons...", text: $searchText)
                .textFieldStyle(.largePadded)

            // Icon grid by category — fixed-height scroll so the picker hugs its
            // content (a host popover sizes to it instead of leaving dead space).
            ScrollViewWithThinIndicator(showFadeMask: true) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if showsStatusDot {
                        defaultSection
                    }
                    if filteredCategories.isEmpty && !showsStatusDot {
                        emptySearchState
                    } else {
                        ForEach(filteredCategories, id: \.0.id) { category, icons in
                            categorySection(category: category, icons: icons)
                        }
                    }
                }
                .padding(.bottom, Spacing.md)
            }
            .frame(height: 240)
        }
    }

    // MARK: - Default (status dot) Section

    private var defaultSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs + 1) {
                Image(systemName: "circle.fill")
                    .font(Typography.captionTiny)
                Text("Default")
                    .font(Typography.labelTiny)
            }
            .foregroundStyle(colorScheme == .dark ? Grey.grey400 : Grey.grey500)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs - 1)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 36), spacing: Spacing.xs)], spacing: Spacing.xs) {
                IconPickerCell(
                    iconItem: .statusDot,
                    isSelected: selectedIcon == IconItem.statusDotName
                ) {
                    withAnimation(Animations.selection) {
                        selectedIcon = IconItem.statusDotName
                    }
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(category: IconCategory, icons: [IconItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Category badge header
            HStack(spacing: Spacing.xs + 1) {
                Image(systemName: category.icon)
                    .font(Typography.captionTiny)

                Text(category.title)
                    .font(Typography.labelTiny)
            }
            .foregroundStyle(colorScheme == .dark ? Grey.grey400 : Grey.grey500)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs - 1)
            .background(
                Capsule()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )

            // Icon grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 36), spacing: Spacing.xs)], spacing: Spacing.xs) {
                ForEach(icons) { iconItem in
                    IconPickerCell(
                        iconItem: iconItem,
                        isSelected: selectedIcon == iconItem.name
                    ) {
                        withAnimation(Animations.selection) {
                            selectedIcon = iconItem.name
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptySearchState: some View {
        EmptyState(icon: "magnifyingglass", title: "No icons found", subtitle: "Try another name.")
            .contained()
    }
}

// MARK: - Icon Picker Cell

private struct IconPickerCell: View {
    let iconItem: IconItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        if isSelected {
            return Color.accent.opacity(0.15)
        }
        if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
        return colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)
    }

    private var iconColor: Color {
        if isSelected {
            return Color.accent
        }
        return colorScheme == .dark ? Grey.grey300 : Grey.grey600
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accent.opacity(0.6)
        }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            Group {
                if iconItem.isStatusDot {
                    Circle()
                        .fill(iconColor)
                        .frame(width: Sizing.statusCircle, height: Sizing.statusCircle)
                } else if iconItem.isAsset {
                    Image(iconItem.name)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: iconItem.name)
                        .font(Typography.bodyMedium)
                }
            }
            .foregroundStyle(iconColor)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium))
        .onHover { hovering in
            isHovering = hovering
        }
        .tooltip(configuration: .iconHint, position: .above) {
            Text(iconItem.searchableName.capitalized).font(Typography.labelSmall)
        }
        .accessibilityLabel(Text(verbatim: iconItem.searchableName.capitalized))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

private struct GroupIconPickerPreview: View {
    @State private var selectedIcon = "folder"

    var body: some View {
        GroupIconPicker(selectedIcon: $selectedIcon)
            .frame(width: 400, height: 500)
            .padding()
            .background(Color.windowBackground)
    }
}

#Preview("Icon Picker") {
    GroupIconPickerPreview()
}

private struct IconPickerButtonPreview: View {
    @State private var icon = IconItem.statusDotName
    @State private var red = 0.2
    @State private var green = 0.78
    @State private var blue = 0.35
    var body: some View {
        HStack(spacing: Spacing.sm) {
            IconPickerButton(selectedIcon: $icon, red: $red, green: $green, blue: $blue)
            Text("Selected: \(icon)")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.windowBackground)
    }
}

#Preview("Icon Picker Button (dot default)", traits: .fixedLayout(width: 320, height: 90)) {
    IconPickerButtonPreview()
}
