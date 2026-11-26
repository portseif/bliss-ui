//
//  AppearanceSettings.swift
//  BlissUI
//
//  A drop-in Appearance page: the mode as three window previews, a card with
//  the theme, accent, background, foreground and font, and an Advanced
//  disclosure (font sizes, motion, separate modes, content and code fonts)
//  with Reset to default beside it. It reads and writes the same `BlissAppearance`
//  keys `.blissTheme()` watches, so a change re-themes the app at once.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Which rows an `AppearanceSettings` page offers. Mode, theme and accent are
/// always there; the rest are opt-outs for an app that doesn't want them.
public struct AppearanceSettingsOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Import, duplicate and delete beside the theme picker.
    public static let themeFiles = AppearanceSettingsOptions(rawValue: 1 << 0)
    /// The font rows: family and face, sizes, content and code fonts.
    public static let fonts = AppearanceSettingsOptions(rawValue: 1 << 1)
    /// The contrast slider.
    public static let contrast = AppearanceSettingsOptions(rawValue: 1 << 2)
    /// The pointer cursor toggle.
    public static let pointerCursors = AppearanceSettingsOptions(rawValue: 1 << 3)
    /// The translucent sidebar toggle.
    public static let translucentSidebar = AppearanceSettingsOptions(rawValue: 1 << 4)
    /// Separate light and dark modes, and the mode switch above the theme card.
    public static let separateModes = AppearanceSettingsOptions(rawValue: 1 << 5)

    public static let all: AppearanceSettingsOptions = [.themeFiles, .fonts, .contrast, .pointerCursors, .translucentSidebar, .separateModes]
}

/// The page's fixed widths and the selection ring its tiles share.
enum AppearanceSettingsMetrics {
    /// The contrast slider.
    static let sliderWidth: CGFloat = 220
    /// A font size field.
    static let fontSizeFieldWidth: CGFloat = 120
    /// The accent ring around a picked tile (theme card, mode preview, Dock icon).
    static let selectionRingWidth: CGFloat = 2
    /// A theme name that doesn't fit shrinks this far before it truncates.
    static let nameMinimumScale: CGFloat = 0.8
}

/// The Appearance settings page. Drop it into a settings view, a Settings
/// scene or a sheet.
public struct AppearanceSettings: View {
    @AppStorage(BlissAppearance.Keys.colorScheme) private var colorScheme = ColorSchemeOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.accentColorOverride) private var accentColorOverride = AccentColorOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.customAccentColorRed) private var customRed: Double = BlissAppearance.defaultCustomAccent.red
    @AppStorage(BlissAppearance.Keys.customAccentColorGreen) private var customGreen: Double = BlissAppearance.defaultCustomAccent.green
    @AppStorage(BlissAppearance.Keys.customAccentColorBlue) private var customBlue: Double = BlissAppearance.defaultCustomAccent.blue
    @AppStorage(BlissAppearance.Keys.theme) private var themeID = BlissTheme.system.id
    /// The accents picked per theme — observed so a pick re-renders the row.
    @AppStorage(BlissAppearance.Keys.themeAccentOverrides) private var themeAccentOverrides = ""
    @AppStorage(BlissAppearance.Keys.reduceMotion) private var reduceMotion = ReduceMotionOption.system.rawValue
    @AppStorage(BlissAppearance.Keys.surfaceOverrides) private var surfaceOverrides = ""
    @AppStorage(BlissAppearance.Keys.separateModes) private var separateModes = false
    @AppStorage(BlissAppearance.Keys.themeLight) private var lightThemeID = ""
    @AppStorage(BlissAppearance.Keys.themeDark) private var darkThemeID = ""
    @AppStorage(BlissAppearance.Keys.typography) private var typography = ""
    @AppStorage(BlissAppearance.Keys.pointerCursors) private var usesPointerCursors = false
    @AppStorage(BlissAppearance.Keys.translucentSidebar) private var translucentSidebar = false
    @AppStorage(BlissAppearance.Keys.contrast) private var contrast = BlissAppearance.defaultContrast
    /// The contrast while the slider is dragged; it's stored on release, since
    /// each stored value re-renders the whole window.
    @State private var draggedContrast: Int?
    @State private var isConfirmingThemeDeletion = false
    // Kept in defaults, not view state: a theme change rebuilds the page.
    @AppStorage("bliss.settings.showsAdvanced") private var showsAdvanced = false
    /// Which mode's theme and colors the card edits while modes are separate.
    @AppStorage("bliss.settings.editingScheme") private var editingSchemeName = ""

    private let dockIcons: [DockIconOption]
    private let options: AppearanceSettingsOptions
    private let themes: [BlissTheme]?
    private let footer: AnyView?
    @AppStorage(BlissAppearance.Keys.dockIcon) private var dockIconID = ""

    /// - Parameters:
    ///   - dockIcons: Dock icons to offer (`DockIconOption.appIcon()`
    ///     first); the row shows when there are two or more. Call
    ///     `BlissAppearance.applyDockIcon(from:)` with the same list at launch.
    ///   - options: Which optional rows to show; most apps want mode, theme
    ///     and accent and not the font or contrast rows.
    ///   - themes: The themes the picker offers; nil offers every registered one.
    public init(dockIcons: [DockIconOption] = [], options: AppearanceSettingsOptions = .all, themes: [BlissTheme]? = nil) {
        self.dockIcons = dockIcons
        self.options = options
        self.themes = themes
        self.footer = nil
    }

    /// The same page with the app's own rows after the library's, in the
    /// same form spacing (a `RoundedSection` of them, usually).
    public init<Footer: View>(
        dockIcons: [DockIconOption] = [],
        options: AppearanceSettingsOptions = .all,
        themes: [BlissTheme]? = nil,
        @ViewBuilder footer: () -> Footer
    ) {
        self.dockIcons = dockIcons
        self.options = options
        self.themes = themes
        self.footer = AnyView(footer())
    }

    /// The themes the picker shows.
    private var availableThemes: [BlissTheme] {
        themes ?? BlissTheme.all
    }

    /// The mode the theme card edits: the one picked while light and dark are
    /// separate, else the one on screen.
    private var editingScheme: ColorScheme {
        guard separateModes else { return ThemeColors.resolvedScheme }
        switch editingSchemeName {
        case "light": return .light
        case "dark": return .dark
        default: return ThemeColors.resolvedScheme
        }
    }

    private var activeTheme: BlissTheme {
        _ = (themeID, lightThemeID, darkThemeID, separateModes)
        return BlissTheme.active(for: editingScheme)
    }

    /// The theme's own accent for the mode being edited — the picker's default.
    private var themeDefaultAccent: ThemeRGB? {
        activeTheme.palette(for: editingScheme)?.accent
    }

    /// The accent picked for the active theme, if any.
    private var pickedThemeAccent: ThemeRGB? {
        _ = themeAccentOverrides
        return ThemeAccentOverrides.color(for: activeTheme)
    }

    public var body: some View {
        SettingsForm {
            RoundedSection {
                SettingsRow(.verbatim(String(localized: "Mode", bundle: .module))) {
                    AppearanceModePicker(selection: colorSchemeOption)
                }
            }

            RoundedSection(divided: true) {
                if separateModes && options.contains(.separateModes) {
                    SettingsRow(.verbatim(String(localized: "Colors for", bundle: .module))) {
                        SegmentedPills(
                            options: [ColorSchemeOption.light, .dark],
                            selection: editingSchemeOption,
                            title: { $0.title },
                            icon: { $0.icon }
                        )
                        .fixedSize()
                    }
                }
                SettingsRow(.verbatim(String(localized: "Theme", bundle: .module))) {
                    HStack(spacing: Spacing.xs) {
                        if options.contains(.themeFiles) {
                            themeFileButtons
                        }
                        themePicker
                    }
                }
                SettingsRow(.verbatim(String(localized: "Accent", bundle: .module))) {
                    HStack(spacing: Spacing.sm) {
                        accentSourcePicker
                        accentPicker
                    }
                }
                SettingsRow(.verbatim(String(localized: "Background", bundle: .module)), detail: .verbatim(modeCaption)) {
                    surfacePicker(.background)
                }
                SettingsRow(.verbatim(String(localized: "Foreground", bundle: .module)), detail: .verbatim(modeCaption)) {
                    surfacePicker(.foreground)
                }
                // One UI font for both modes unless they're separate.
                if options.contains(.fonts) {
                    SettingsRow(.verbatim(String(localized: "Font", bundle: .module)), detail: separateModes ? .verbatim(modeCaption) : nil) {
                        fontFamilyPicker(.ui)
                    }
                }
            }

            HStack {
                Button {
                    withAnimation(Animations.disclosure) { showsAdvanced.toggle() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text("Advanced", bundle: .module)
                        BlissSymbol("chevron.right")
                            .font(Typography.labelTinySemibold)
                            .rotationEffect(.degrees(showsAdvanced ? 90 : 0))
                    }
                    .foregroundStyle(Color.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: Spacing.ringOutset))
                .accessibilityValue(showsAdvanced ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))

                Spacer()

                Button {
                    withAnimation(Animations.selection) { BlissAppearance.resetToDefaults() }
                    BlissAppearance.applyDockIcon(from: dockIcons)
                } label: {
                    Text("Reset to default", bundle: .module)
                        .foregroundStyle(Color.textSecondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: Spacing.ringOutset))
            }
            .font(Typography.bodySmall)

            if showsAdvanced {
                if options.contains(.fonts) {
                    RoundedSection(divided: true) {
                        SettingsRow(
                            .verbatim(String(localized: "UI font size", bundle: .module)),
                            detail: .verbatim(String(localized: "Adjust the base size used across the app", bundle: .module))
                        ) {
                            fontSizeField(String(localized: "UI font size", bundle: .module), value: uiFontSize, in: BlissAppearance.uiFontSizeRange)
                        }
                        SettingsRow(
                            .verbatim(String(localized: "Code font size", bundle: .module)),
                            detail: .verbatim(String(localized: "Adjust the base size used for code", bundle: .module))
                        ) {
                            fontSizeField(String(localized: "Code font size", bundle: .module), value: codeFontSize, in: BlissAppearance.codeFontSizeRange)
                        }
                    }
                    .transition(.motion(.opacity.combined(with: .move(edge: .top))))
                }

                RoundedSection(divided: true) {
                    SettingsRow(
                        .verbatim(String(localized: "Reduce motion", bundle: .module)),
                        detail: .verbatim(String(localized: "Reduce animations, or match your Mac", bundle: .module))
                    ) {
                        SegmentedPills(
                            options: ReduceMotionOption.allCases,
                            selection: reduceMotionOption,
                            title: { $0.title }
                        )
                        .fixedSize()
                    }
                    if options.contains(.separateModes) {
                        SettingsToggleRow(
                            .verbatim(String(localized: "Separate light and dark modes", bundle: .module)),
                            detail: .verbatim(String(localized: "Choose a theme, colors and font for each", bundle: .module)),
                            isOn: separateModesBinding
                        )
                    }
                }
                .transition(.motion(.opacity.combined(with: .move(edge: .top))))

                if options.contains(.fonts) || options.contains(.translucentSidebar) || options.contains(.contrast) {
                    RoundedSection(divided: true) {
                        if options.contains(.fonts) {
                            SettingsRow(.verbatim(String(localized: "UI font style", bundle: .module)), detail: separateModes ? .verbatim(modeCaption) : nil) {
                                fontFacePicker(.ui)
                            }
                            SettingsRow(.verbatim(String(localized: "Content font", bundle: .module))) {
                                HStack(spacing: Spacing.sm) {
                                    fontFamilyPicker(.content)
                                    fontFacePicker(.content)
                                }
                            }
                            SettingsRow(.verbatim(String(localized: "Code font", bundle: .module))) {
                                HStack(spacing: Spacing.sm) {
                                    fontFamilyPicker(.code)
                                    fontFacePicker(.code)
                                }
                            }
                        }
                        if options.contains(.translucentSidebar) {
                            SettingsToggleRow(.verbatim(String(localized: "Translucent sidebar", bundle: .module)), isOn: $translucentSidebar)
                        }
                        if options.contains(.contrast) {
                            SettingsRow(.verbatim(String(localized: "Contrast", bundle: .module))) {
                                contrastSlider
                            }
                        }
                    }
                    .transition(.motion(.opacity.combined(with: .move(edge: .top))))
                }

                if options.contains(.pointerCursors) || dockIcons.count > 1 {
                    RoundedSection(divided: true) {
                        if options.contains(.pointerCursors) {
                            SettingsToggleRow(
                                .verbatim(String(localized: "Use pointer cursors", bundle: .module)),
                                detail: .verbatim(String(localized: "Change the cursor to a pointer when hovering over interactive elements", bundle: .module)),
                                isOn: $usesPointerCursors
                            )
                        }
                        if dockIcons.count > 1 {
                            SettingsRow(
                                .verbatim(String(localized: "Dock icon", bundle: .module)),
                                detail: .verbatim(String(localized: "Choose the icon the app uses in the Dock", bundle: .module))
                            ) {
                                DockIconPicker(options: dockIcons, selection: dockIconSelection)
                            }
                        }
                    }
                    .transition(.motion(.opacity.combined(with: .move(edge: .top))))
                }
            }

            if let footer {
                footer
            }
        }
    }

    // MARK: - Pickers

    private var colorSchemeOption: Binding<ColorSchemeOption> {
        Binding(
            get: { ColorSchemeOption(rawValue: colorScheme) ?? .system },
            set: { colorScheme = $0.rawValue }
        )
    }

    private var reduceMotionOption: Binding<ReduceMotionOption> {
        Binding(
            get: { ReduceMotionOption(rawValue: reduceMotion) ?? .system },
            set: { reduceMotion = $0.rawValue }
        )
    }

    /// Every theme, each with its swatch.
    private var themePicker: some View {
        FloatingMenuPicker(
            String(localized: "Theme", bundle: .module),
            selection: Binding(
                get: { activeTheme.name },
                set: { name in
                    if let theme = availableThemes.first(where: { $0.name == name }) {
                        BlissAppearance.setTheme(theme, for: editingScheme)
                    }
                }
            ),
            options: availableThemes,
            optionTitle: { $0.name },
            optionIconView: { theme, size in ThemeSwatchIcon(theme: theme, size: size) },
            showsTitle: false
        )
    }

    // MARK: - Theme files

    /// Import a theme file, duplicate the theme as it looks now, and (for the
    /// user's own themes) delete it.
    @ViewBuilder
    private var themeFileButtons: some View {
        themeFileButton(String(localized: "Import theme", bundle: .module), systemImage: "square.and.arrow.down", action: importTheme)
        themeFileButton(String(localized: "Duplicate theme", bundle: .module), systemImage: "plus.square.on.square") {
            BlissAppearance.setTheme(BlissTheme.duplicate(activeTheme), for: editingScheme)
        }
        if activeTheme.isCustom {
            themeFileButton(String(localized: "Delete theme", bundle: .module), systemImage: "trash") {
                isConfirmingThemeDeletion = true
            }
            .confirmationDialog(
                Text("Delete this theme?", bundle: .module),
                isPresented: $isConfirmingThemeDeletion
            ) {
                Button(role: .destructive) {
                    BlissTheme.deleteCustom(activeTheme)
                } label: {
                    Text("Delete", bundle: .module)
                }
            } message: {
                Text("Its colors can't be restored. Modes that use it go back to the default theme.", bundle: .module)
            }
        }
    }

    private func themeFileButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BlissSymbol(systemImage)
        }
        .buttonStyle(ToolbarIconButtonStyle())
        .tooltip(.verbatim(title), position: .below)
        .accessibilityLabel(Text(verbatim: title))
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a theme file", bundle: .module)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            BlissAppearance.setTheme(try BlissTheme.importTheme(from: url), for: editingScheme)
        } catch {
            ToastService.shared.showError(
                title: String(localized: "Couldn't import the theme", bundle: .module),
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Dock icon

    private var dockIconSelection: Binding<String> {
        Binding(
            get: { dockIcons.contains { $0.id == dockIconID } ? dockIconID : (dockIcons.first?.id ?? "") },
            set: { id in
                dockIconID = id
                BlissAppearance.applyDockIcon(from: dockIcons)
            }
        )
    }

    // MARK: - Contrast

    private var contrastSlider: some View {
        BlissSlider(
            .verbatim(String(localized: "Contrast", bundle: .module)),
            value: Binding(
                get: { draggedContrast ?? contrast },
                set: { value in
                    if draggedContrast != nil { draggedContrast = value } else { contrast = value }
                }
            ),
            in: 0...100,
            valueLabel: { Text($0, format: .number) },
            onEditingChanged: { isDragging in
                if isDragging {
                    draggedContrast = contrast
                } else if let draggedContrast {
                    self.draggedContrast = nil
                    contrast = draggedContrast
                }
            }
        )
        .frame(width: AppearanceSettingsMetrics.sliderWidth)
    }

    // MARK: - Fonts

    /// The stored font for `role`, for the mode being edited.
    private func fontChoice(_ role: FontRole) -> FontChoice {
        _ = (typography, separateModes)
        return BlissAppearance.font(role, for: editingScheme)
    }

    private var uiFontSize: Binding<Int> {
        Binding(get: { _ = typography; return BlissAppearance.uiFontSize }, set: { BlissAppearance.uiFontSize = $0 })
    }

    private var codeFontSize: Binding<Int> {
        Binding(get: { _ = typography; return BlissAppearance.codeFontSize }, set: { BlissAppearance.codeFontSize = $0 })
    }

    private func fontSizeField(_ title: String, value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        NumberField(.verbatim(title), value: value, in: range, unit: .verbatim("px"))
            .frame(width: AppearanceSettingsMetrics.fontSizeFieldWidth)
    }

    /// System or an installed family (a monospaced one, for code). A new
    /// family starts on its regular face.
    private func fontFamilyPicker(_ role: FontRole) -> some View {
        let systemTitle = String(localized: "System", bundle: .module)
        let title: String = switch role {
        case .ui: String(localized: "Font", bundle: .module)
        case .content: String(localized: "Content font", bundle: .module)
        case .code: String(localized: "Code font", bundle: .module)
        }
        return FloatingMenuPicker(
            title,
            selection: Binding(
                get: { fontChoice(role).family ?? systemTitle },
                set: { name in
                    let family = name == systemTitle ? nil : name
                    guard family != fontChoice(role).family else { return }
                    BlissAppearance.setFont(FontChoice(family: family), role, for: editingScheme)
                }
            ),
            options: [systemTitle] + (role == .code ? FontResolver.monospacedFamilies : FontResolver.allFamilies),
            optionTitle: { $0 },
            showsTitle: false
        )
        .fixedSize()
    }

    /// The family's upright faces; off for System, which picks its own.
    private func fontFacePicker(_ role: FontRole) -> some View {
        let choice = fontChoice(role)
        let faces = choice.family.map(FontResolver.faces(of:)) ?? []
        let regularTitle = String(localized: "Regular", bundle: .module)
        let selectedFace = faces.min { abs($0.weight - choice.weight) < abs($1.weight - choice.weight) }
        let title: String = switch role {
        case .ui: String(localized: "UI font style", bundle: .module)
        case .content: String(localized: "Content font", bundle: .module)
        case .code: String(localized: "Code font", bundle: .module)
        }
        return FloatingMenuPicker(
            title,
            selection: Binding(
                get: { selectedFace?.name ?? regularTitle },
                set: { name in
                    guard let face = faces.first(where: { $0.name == name }) else { return }
                    BlissAppearance.setFont(FontChoice(family: choice.family, weight: face.weight), role, for: editingScheme)
                }
            ),
            options: faces.isEmpty ? [regularTitle] : faces.map(\.name),
            optionTitle: { $0 },
            showsTitle: false
        )
        .fixedSize()
        .disabled(choice.family == nil)
    }

    /// Which mode's colors the rows below apply to.
    private var modeCaption: String {
        editingScheme == .dark
            ? String(localized: "In dark mode", bundle: .module)
            : String(localized: "In light mode", bundle: .module)
    }

    private var editingSchemeOption: Binding<ColorSchemeOption> {
        Binding(
            get: { editingScheme == .dark ? .dark : .light },
            set: { editingSchemeName = $0 == .dark ? "dark" : "light" }
        )
    }

    /// Turning separate modes on starts both modes on today's theme, so
    /// nothing changes until one is picked.
    private var separateModesBinding: Binding<Bool> {
        Binding(
            get: { separateModes },
            set: { isOn in
                if isOn {
                    let current = BlissTheme.active(for: ThemeColors.resolvedScheme).id
                    if lightThemeID.isEmpty { lightThemeID = current }
                    if darkThemeID.isEmpty { darkThemeID = current }
                    editingSchemeName = ThemeColors.resolvedScheme == .dark ? "dark" : "light"
                }
                separateModes = isOn
            }
        )
    }

    /// The theme's own background or text color for the mode being edited,
    /// before any of the user's picks.
    private func themeSurface(_ role: ThemeSurfaceRole) -> ThemeRGB {
        var base = activeTheme.palette(for: editingScheme) ?? ThemePalette.systemBase(for: editingScheme)
        // Text the theme would pick for the background in use, which may have
        // flipped from light to dark with it.
        if role == .foreground, let background = pickedSurface(.background) {
            base = base.withBackground(background)
        }
        switch role {
        case .background:
            return base.windowBackground
        case .foreground:
            return base.foreground ?? (editingScheme == .dark ? ThemeRGB(0xF2F2F2) : ThemeRGB(0x1C1C1E))
        }
    }

    private func pickedSurface(_ role: ThemeSurfaceRole) -> ThemeRGB? {
        _ = surfaceOverrides
        return BlissAppearance.surfaceColor(role, for: activeTheme, in: editingScheme)
    }

    /// A hex chip for the background or text color: the theme's own until one
    /// is picked, kept for this theme and mode.
    private func surfacePicker(_ role: ThemeSurfaceRole) -> some View {
        let defaultColor = themeSurface(role)
        func component(_ keyPath: KeyPath<ThemeRGB, Double>, _ replacing: @escaping (ThemeRGB, Double) -> ThemeRGB) -> Binding<Double> {
            Binding(
                get: { (pickedSurface(role) ?? defaultColor)[keyPath: keyPath] },
                set: { value in
                    let base = pickedSurface(role) ?? defaultColor
                    BlissAppearance.setSurfaceColor(replacing(base, value), role, for: activeTheme, in: editingScheme)
                }
            )
        }
        return ColorPickerButton(
            red: component(\.red) { ThemeRGB(red: $1, green: $0.green, blue: $0.blue) },
            green: component(\.green) { ThemeRGB(red: $0.red, green: $1, blue: $0.blue) },
            blue: component(\.blue) { ThemeRGB(red: $0.red, green: $0.green, blue: $1) },
            isUsingDefault: Binding(
                get: { pickedSurface(role) == nil },
                set: { usesDefault in
                    if usesDefault { BlissAppearance.setSurfaceColor(nil, role, for: activeTheme, in: editingScheme) }
                }
            ),
            defaultOption: ColorPickerDefault(
                color: defaultColor.nsColor,
                symbol: "paintpalette.fill",
                label: .verbatim(role == .background
                    ? String(localized: "Use the theme's background", bundle: .module)
                    : String(localized: "Use the theme's text color", bundle: .module))
            ),
            label: .hexChip
        )
    }

    /// The theme's own accent (the system's, under System) or a custom one.
    private var accentSourcePicker: some View {
        let defaultTitle = themeDefaultAccent == nil
            ? String(localized: "System", bundle: .module)
            : String(localized: "Theme", bundle: .module)
        let customTitle = String(localized: "Custom", bundle: .module)
        return FloatingMenuPicker(
            String(localized: "Accent", bundle: .module),
            selection: Binding(
                get: { isUsingDefaultAccent ? defaultTitle : customTitle },
                set: { title in
                    if title == defaultTitle {
                        useDefaultAccent()
                    } else if isUsingDefaultAccent {
                        // Custom starts from the color in use, so nothing jumps.
                        pinCurrentAccent()
                    }
                }
            ),
            options: [defaultTitle, customTitle],
            optionTitle: { $0 },
            showsTitle: false
        )
    }

    private var isUsingDefaultAccent: Bool {
        themeDefaultAccent == nil ? accentColorOverride == AccentColorOption.system.rawValue : pickedThemeAccent == nil
    }

    private func useDefaultAccent() {
        if themeDefaultAccent == nil {
            accentColorOverride = AccentColorOption.system.rawValue
        } else {
            ThemeAccentOverrides.set(nil, for: activeTheme)
        }
    }

    private func pinCurrentAccent() {
        if let themeDefaultAccent {
            ThemeAccentOverrides.set(themeDefaultAccent, for: activeTheme)
        } else if let system = AccentHue.effectiveAccentNSColor.usingColorSpace(.sRGB) {
            customRed = Double(system.redComponent)
            customGreen = Double(system.greenComponent)
            customBlue = Double(system.blueComponent)
            accentColorOverride = AccentColorOption.custom.rawValue
        }
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
                defaultOption: .themeAccent(themeDefaultAccent.nsColor),
                label: .hexChip
            )
        } else {
            ColorPickerButton(
                red: $customRed,
                green: $customGreen,
                blue: $customBlue,
                isUsingDefault: usesSystemAccent,
                label: .hexChip
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

/// A theme's four swatch colors in a small rounded square, for the theme menu.
private struct ThemeSwatchIcon: View {
    let theme: BlissTheme
    let size: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(theme.swatchColors.enumerated()), id: \.offset) { _, color in
                Rectangle().fill(color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

// MARK: - Theme Card

/// A selectable theme swatch: a four-band color preview with the theme's name
/// below, the accent ring the page's other tiles show when selected, and the
/// row hover wash.
public struct ThemeCard: View {
    private let theme: BlissTheme
    private let isSelected: Bool
    private let showsName: Bool
    private let onSelect: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlShape) private var controlShape

    /// - Parameter showsName: The theme's name under the swatch; off for a
    ///   compact grid of swatches with tooltips of their own.
    public init(theme: BlissTheme, isSelected: Bool, showsName: Bool = true, onSelect: @escaping () -> Void) {
        self.theme = theme
        self.isSelected = isSelected
        self.showsName = showsName
        self.onSelect = onSelect
    }

    /// The tile holds a swatch and a name, so a round control shape gives it
    /// a box's corners rather than a capsule.
    private var cornerRadius: CGFloat { controlShape.boxRadius(rounded: Sizing.radiusMedium) }
    /// The ring sits a gap outside the tile, like the mode previews'; square
    /// tiles get a square ring.
    private var ringRadius: CGFloat { cornerRadius == 0 ? 0 : cornerRadius + Spacing.insetSpacing }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            swatch
            if showsName {
                Text(LocalizedStringKey(theme.name))
                    .font(Typography.labelMedium)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(AppearanceSettingsMetrics.nameMinimumScale)
            }
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .padding(Spacing.insetSpacing)
        .overlay {
            RoundedRectangle(cornerRadius: ringRadius, style: .continuous)
                .strokeBorder(isSelected ? Color.accent : Color.clear, lineWidth: AppearanceSettingsMetrics.selectionRingWidth)
        }
        .contentShape(RoundedRectangle(cornerRadius: ringRadius, style: .continuous))
        .rowTapAction(isSelected: isSelected, focusCornerRadius: ringRadius, focusBleed: 0, perform: onSelect)
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
        .frame(height: Sizing.controlLarge)
        .clipShape(RoundedRectangle(cornerRadius: controlShape.swatchRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: controlShape.swatchRadius, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

// MARK: - Previews

#Preview("Appearance Settings", traits: .fixedLayout(width: 640, height: 520)) {
    AppearanceSettings()
        .padding()
}

#Preview("Theme Cards", traits: .fixedLayout(width: 440, height: 200)) {
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.sm) {
            ForEach(BlissTheme.builtIn) { theme in
                ThemeCard(theme: theme, isSelected: theme == .system, onSelect: {})
            }
        }
        HStack(spacing: Spacing.sm) {
            ForEach(BlissTheme.builtIn) { theme in
                ThemeCard(theme: theme, isSelected: theme == .lowGlare, showsName: false, onSelect: {})
            }
        }
    }
    .padding()
}
