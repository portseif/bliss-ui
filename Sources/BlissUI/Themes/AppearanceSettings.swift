//
//  AppearanceSettings.swift
//  BlissUI
//
//  A drop-in Appearance pane: Light / Dark / System, the accent color, and a
//  grid of theme cards (every built-in plus anything you registered). It reads
//  and writes the same `BlissAppearance` keys `.blissTheme()` watches, so a
//  change re-themes the app at once.
//

import SwiftUI

/// The Appearance settings pane. Drop it into a Settings scene or a sheet.
public struct AppearanceSettings: View {
    @AppStorage(BlissAppearance.Keys.colorScheme) private var colorScheme = ColorSchemeOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.accentColorOverride) private var accentColorOverride = AccentColorOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.customAccentColorRed) private var customRed: Double = BlissAppearance.defaultCustomAccent.red
    @AppStorage(BlissAppearance.Keys.customAccentColorGreen) private var customGreen: Double = BlissAppearance.defaultCustomAccent.green
    @AppStorage(BlissAppearance.Keys.customAccentColorBlue) private var customBlue: Double = BlissAppearance.defaultCustomAccent.blue
    @AppStorage(BlissAppearance.Keys.theme) private var themeID = BlissTheme.system.id
    /// The accents picked per theme — observed so a pick re-renders the row.
    @AppStorage(BlissAppearance.Keys.themeAccentOverrides) private var themeAccentOverrides = ""

    public init() {}

    private var activeTheme: BlissTheme { BlissThemeRegistry.theme(withID: themeID) ?? .system }

    /// The theme's own accent for the scheme in use — the picker's default.
    private var themeDefaultAccent: ThemeRGB? {
        activeTheme.palette(for: ThemeColors.resolvedScheme)?.accent
    }

    /// The accent picked for the active theme, if any.
    private var pickedThemeAccent: ThemeRGB? {
        _ = themeAccentOverrides
        return ThemeAccentOverrides.color(for: activeTheme)
    }

    public var body: some View {
        SettingsForm {
            RoundedSection(divided: true) {
                FloatingMenuPicker(
                    String(localized: "Color scheme"),
                    selection: colorSchemeTitle,
                    options: ColorSchemeOption.allCases,
                    optionTitle: { $0.title },
                    optionIcon: { $0.icon }
                )

                HStack {
                    Text("Accent color")
                    Spacer()
                    accentPicker
                }
            } header: {
                HStack(spacing: Spacing.xs) {
                    Text("Appearance")
                    InfoButton(text: "Choose light or dark and the accent color. System follows your macOS settings.")
                }
            }

            RoundedSection {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)],
                    spacing: Spacing.sm
                ) {
                    ForEach(BlissTheme.all) { theme in
                        ThemeCard(theme: theme, isSelected: themeID == theme.id) {
                            withAnimation(Animations.selection) { themeID = theme.id }
                        }
                    }
                }
            } header: {
                HStack(spacing: Spacing.xs) {
                    Text("Theme")
                    InfoButton(text: "Themes recolor the window, panes, accent and — where the theme defines them — the success, warning, error and info colors. Each follows your light or dark choice. High Contrast holds every status color to 7:1; Color Blind Safe stays distinct with red-green and blue-yellow color blindness; Low Glare is dim and warm for light sensitivity.")
                }
            }
        }
    }

    // MARK: - Pickers

    private var colorSchemeTitle: Binding<String> {
        Binding(
            get: { ColorSchemeOption(rawValue: colorScheme)?.title ?? colorScheme },
            set: { title in
                if let option = ColorSchemeOption.allCases.first(where: { $0.title == title }) {
                    colorScheme = option.rawValue
                }
            }
        )
    }

    @ViewBuilder
    private var accentPicker: some View {
        if let themeDefaultAccent {
            // A theme's accent is its default; a pick is kept for that theme.
            ColorPickerButton(
                red: themeAccentComponent(\.red) { ThemeRGB(red: $1, green: $0.green, blue: $0.blue) },
                green: themeAccentComponent(\.green) { ThemeRGB(red: $0.red, green: $1, blue: $0.blue) },
                blue: themeAccentComponent(\.blue) { ThemeRGB(red: $0.red, green: $0.green, blue: $1) },
                isUsingDefault: usesThemeAccent,
                defaultOption: .themeAccent(themeDefaultAccent.nsColor)
            )
        } else {
            ColorPickerButton(
                red: $customRed,
                green: $customGreen,
                blue: $customBlue,
                isUsingDefault: usesSystemAccent
            )
        }
    }

    /// One component of the theme accent the picker edits; a write stores a
    /// pick for this theme.
    private func themeAccentComponent(
        _ component: KeyPath<ThemeRGB, Double>,
        replacing: @escaping (ThemeRGB, Double) -> ThemeRGB
    ) -> Binding<Double> {
        Binding(
            get: { (pickedThemeAccent ?? themeDefaultAccent ?? BlissAppearance.defaultCustomAccent)[keyPath: component] },
            set: { value in
                let base = pickedThemeAccent ?? themeDefaultAccent ?? BlissAppearance.defaultCustomAccent
                ThemeAccentOverrides.set(replacing(base, value), for: activeTheme)
            }
        )
    }

    /// True while the theme's own accent is in use; choosing the default swatch clears the pick.
    private var usesThemeAccent: Binding<Bool> {
        Binding(
            get: { pickedThemeAccent == nil },
            set: { usesDefault in
                if usesDefault { ThemeAccentOverrides.set(nil, for: activeTheme) }
            }
        )
    }

    private var usesSystemAccent: Binding<Bool> {
        Binding(
            get: { accentColorOverride == AccentColorOption.system.rawValue },
            set: { usesSystem in
                accentColorOverride = usesSystem ? AccentColorOption.system.rawValue : AccentColorOption.custom.rawValue
            }
        )
    }
}

// MARK: - Theme Card

/// A selectable theme swatch: a four-band color preview with the theme's name
/// below, a ring when selected, and a subtle hover fill.
public struct ThemeCard: View {
    private let theme: BlissTheme
    private let isSelected: Bool
    private let onSelect: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    public init(theme: BlissTheme, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.theme = theme
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    private var cornerRadius: CGFloat { Sizing.radiusMedium }

    public var body: some View {
        VStack(spacing: 6) {
            swatch
            Text(LocalizedStringKey(theme.name))
                .font(Typography.labelSmall)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .rowTapAction(isSelected: isSelected, focusCornerRadius: cornerRadius, focusBleed: 0, perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        .animation(Animations.selection, value: isSelected)
    }

    private var backgroundFill: Color {
        if isSelected { return RowTint.selected(colorScheme) }
        return isHovering ? RowTint.hover(colorScheme) : Color.clear
    }

    private var swatch: some View {
        HStack(spacing: 0) {
            ForEach(Array(theme.swatchColors.enumerated()), id: \.offset) { _, color in
                Rectangle().fill(color)
            }
        }
        .frame(height: 38)
        .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

// MARK: - Previews

#Preview("Appearance Settings") {
    AppearanceSettings()
        .frame(width: 450, height: 420)
}

#Preview("Theme Cards", traits: .fixedLayout(width: 440, height: 120)) {
    HStack(spacing: Spacing.sm) {
        ForEach(BlissTheme.builtIn) { theme in
            ThemeCard(theme: theme, isSelected: theme == .system, onSelect: {})
        }
    }
    .padding()
}
