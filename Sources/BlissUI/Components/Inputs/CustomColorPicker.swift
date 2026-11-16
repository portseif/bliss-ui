//
//  CustomColorPicker.swift
//  BlissUI
//
//  The app's custom color selector: a swatch button that opens a popover with
//  HSL sliders, a live hex readout, and preset swatches. Used instead of the
//  native `ColorPicker` (which breaks with `@AppStorage` on re-render).
//
//  Generalized from the Appearance accent picker so any surface can reuse it.
//  The "use the default" swatch is optional — pass an `isUsingDefault` binding
//  and a `ColorPickerDefault` (the system accent, or a color theme's own accent)
//  to get it, or omit it for a plain custom color (e.g. a saved filter's color).
//
//  As an accent picker it binds straight to `BlissAppearance`: the components to
//  `@AppStorage(BlissAppearance.Keys.customAccentColorRed)` (and green / blue),
//  `isUsingDefault` to "accent option is System", and the default to
//  `ColorPickerDefault.accent(of: BlissAppearance.theme)`.
//
//  The HSL rows are `BlissSlider`s over a gradient rail, so they're Tab stops
//  with the shared ring and the arrow keys, like every slider.
//

import SwiftUI

// MARK: - Custom Color Picker Button

/// The color a picker falls back to, offered as the first preset swatch: the
/// macOS accent, or a color theme's own accent.
public struct ColorPickerDefault {
    public let color: NSColor
    /// The glyph drawn on the swatch.
    public let symbol: String
    /// The swatch's tooltip and VoiceOver label.
    public let label: LocalizedStringKey

    public init(color: NSColor, symbol: String, label: LocalizedStringKey) {
        self.color = color
        self.symbol = symbol
        self.label = label
    }

    public static let systemAccent = ColorPickerDefault(color: .controlAccentColor, symbol: "gearshape.fill", label: .verbatim(String(localized: "Use system accent color", bundle: .module)))

    public static func themeAccent(_ color: NSColor) -> ColorPickerDefault {
        ColorPickerDefault(color: color, symbol: "paintpalette.fill", label: .verbatim(String(localized: "Use the theme's accent color", bundle: .module)))
    }

    /// The default for a theme's accent picker: the macOS accent under
    /// `.system` (or a theme with no palette for `scheme`), else the theme's own
    /// accent for `scheme` — not the user's pick, which is what the picker edits.
    public static func accent(
        of theme: BlissTheme,
        in scheme: ColorScheme = ThemeColors.resolvedScheme
    ) -> ColorPickerDefault {
        guard let palette = theme.palette(for: scheme) else { return .systemAccent }
        return .themeAccent(palette.accent.nsColor)
    }

    /// Dark glyph on a light swatch, white on anything else.
    var glyphColor: Color {
        guard let srgb = color.usingColorSpace(.sRGB) else { return .white.opacity(ColorPickerMetrics.glyphOpacity) }
        let luminance = 0.2126 * srgb.redComponent + 0.7152 * srgb.greenComponent + 0.0722 * srgb.blueComponent
        return luminance > ColorPickerMetrics.lightSwatchLuminance ? .black.opacity(ColorPickerMetrics.darkGlyphOpacity) : .white.opacity(ColorPickerMetrics.glyphOpacity)
    }
}

/// The picker's swatch: a small tile with a hairline, the height of a field
/// (or of a small control when compact).
struct ColorPickerSwatch: View {
    let color: Color
    var compact = false

    var body: some View {
        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
            .fill(color)
            .frame(width: ColorPickerMetrics.swatchWidth, height: compact ? Sizing.controlSmall : Sizing.controlDefault)
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
    }
}

/// How a `ColorPickerButton` shows its color.
public nonisolated enum ColorPickerButtonLabel: Sendable {
    /// A small swatch.
    case swatch
    /// A capsule with a round swatch and the color's hex value ("#CC7D5E").
    case hexChip
}

/// A color swatch button that opens a popover with HSL sliders and an Apply button.
///
/// Bind `red`/`green`/`blue` (0...1). Pass `isUsingDefault` only where a default
/// applies (`defaultOption`: the system accent unless given another); omit it for
/// a plain custom color.
public struct ColorPickerButton: View {
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    /// When non-nil, the picker offers the default as its first preset and shows
    /// it in the swatch while it's in use. Nil = a plain custom color.
    var isUsingDefault: Binding<Bool>? = nil
    var defaultOption: ColorPickerDefault = .systemAccent
    var label: ColorPickerButtonLabel = .swatch
    /// The dense `Sizing.controlSmall` height for a toolbar; the default is a
    /// field's `Sizing.controlDefault`.
    var compact = false
    var onColorApplied: () -> Void = {}

    @State private var showingPopover = false
    @State private var tempRed: Double = 0
    @State private var tempGreen: Double = 0
    @State private var tempBlue: Double = 0
    /// The default's components the popover opened on, when it did — Apply with
    /// them untouched keeps following the default instead of pinning today's
    /// color (a theme's accent differs per scheme; the system's can change).
    @State private var openedOnDefault: [Double]?

    /// - Parameters:
    ///   - red: The color's red component (0...1); likewise `green` and `blue`.
    ///   - isUsingDefault: Whether the default is in use; nil for a plain color.
    ///   - defaultOption: The default offered as the first preset.
    ///   - label: A swatch, or a capsule with the hex value.
    ///   - compact: The dense `Sizing.controlSmall` height for a toolbar.
    ///   - onColorApplied: Called after Apply or the default swatch.
    public init(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        isUsingDefault: Binding<Bool>? = nil,
        defaultOption: ColorPickerDefault = .systemAccent,
        label: ColorPickerButtonLabel = .swatch,
        compact: Bool = false,
        onColorApplied: @escaping () -> Void = {}
    ) {
        self._red = red
        self._green = green
        self._blue = blue
        self.isUsingDefault = isUsingDefault
        self.defaultOption = defaultOption
        self.label = label
        self.compact = compact
        self.onColorApplied = onColorApplied
    }

    /// The shown color's components (the default's while it's in use).
    private var displayComponents: (red: Double, green: Double, blue: Double) {
        if usingDefault, let srgb = defaultOption.color.usingColorSpace(.sRGB) {
            return (Double(srgb.redComponent), Double(srgb.greenComponent), Double(srgb.blueComponent))
        }
        return (red, green, blue)
    }

    private var displayHex: String {
        let (r, g, b) = displayComponents
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    private var usingDefault: Bool { isUsingDefault?.wrappedValue ?? false }

    /// The color to display in the swatch (the default, or the custom pick).
    private var displayColor: Color {
        if usingDefault {
            return Color(nsColor: defaultOption.color)
        }
        return Color(red: red, green: green, blue: blue)
    }

    public var body: some View {
        Button {
            // Copy current values to temp (the default's, while it's in use).
            if usingDefault {
                if let srgb = defaultOption.color.usingColorSpace(.sRGB) {
                    tempRed = Double(srgb.redComponent)
                    tempGreen = Double(srgb.greenComponent)
                    tempBlue = Double(srgb.blueComponent)
                }
                openedOnDefault = [tempRed, tempGreen, tempBlue]
            } else {
                tempRed = red
                tempGreen = green
                tempBlue = blue
                openedOnDefault = nil
            }
            showingPopover = true
        } label: {
            switch label {
            case .swatch:
                ColorPickerSwatch(color: displayColor, compact: compact)
            case .hexChip:
                ColorHexChip(color: displayColor, hex: displayHex, compact: compact)
            }
        }
        // The hover wash and press every clickable card shares.
        .buttonStyle(SelectableCardButtonStyle(cornerRadius: label == .hexChip ? Sizing.radiusFull : Sizing.radiusSmall))
        .accessibilityLabel(Text("Choose color", bundle: .module))
        .popover(isPresented: $showingPopover) {
            ColorPickerPopover(
                red: $tempRed,
                green: $tempGreen,
                blue: $tempBlue,
                defaultOption: isUsingDefault == nil ? nil : defaultOption,
                onApply: {
                    if openedOnDefault == [tempRed, tempGreen, tempBlue] {
                        showingPopover = false
                        return
                    }
                    red = tempRed
                    green = tempGreen
                    blue = tempBlue
                    isUsingDefault?.wrappedValue = false
                    onColorApplied()
                    showingPopover = false
                },
                onUseDefault: {
                    isUsingDefault?.wrappedValue = true
                    onColorApplied()
                    showingPopover = false
                },
                onCancel: {
                    showingPopover = false
                }
            )
        }
    }
}

/// A capsule with a round swatch and the hex value, for `ColorPickerButton(label: .hexChip)`.
private struct ColorHexChip: View {
    let color: Color
    let hex: String
    var compact = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: Sizing.iconSmall, height: Sizing.iconSmall)
                .overlay { Circle().strokeBorder(Color.menuBorder, lineWidth: 1) }
            Text(verbatim: hex)
                .font((compact ? Typography.labelSmall : Typography.labelMedium).monospacedDigit())
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.md)
        .frame(minHeight: compact ? Sizing.controlSmall : Sizing.controlDefault)
        .background(Capsule().fill(Color.restingFill))
        .overlay(Capsule().strokeBorder(Color.menuBorder, lineWidth: 1))
        .contentShape(Capsule())
    }
}

// MARK: - Color Picker Popover Content

/// The picker's popover body — preview + hex readout, HSL sliders, presets, and
/// Cancel / Apply — for hosting in your own popover or panel. It edits the bound
/// components live; the callbacks decide what Apply / Cancel / the default mean.
public struct ColorPickerPopover: View {
    @Binding var red: Double
    @Binding var green: Double
    @Binding var blue: Double
    /// The "use the default" swatch leading the presets (accent pickers only).
    var defaultOption: ColorPickerDefault? = nil
    /// The preset swatches (and the default) under the sliders; off for a
    /// plain custom color picker.
    var showsPresets = true
    var onApply: () -> Void
    var onUseDefault: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // HSL state derived from RGB.
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var lightness: Double = 0

    /// - Parameters:
    ///   - red: The color's red component (0...1); likewise `green` and `blue`.
    ///   - defaultOption: The "use the default" swatch leading the presets.
    ///   - showsPresets: The preset swatches under the sliders.
    ///   - onApply: Apply was pressed.
    ///   - onUseDefault: The default swatch was picked.
    ///   - onCancel: Cancel was pressed.
    public init(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        defaultOption: ColorPickerDefault? = nil,
        showsPresets: Bool = true,
        onApply: @escaping () -> Void,
        onUseDefault: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._red = red
        self._green = green
        self._blue = blue
        self.defaultOption = defaultOption
        self.showsPresets = showsPresets
        self.onApply = onApply
        self.onUseDefault = onUseDefault
        self.onCancel = onCancel
    }

    private var previewColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    private var hexValue: String {
        // Rounded like `ThemeRGB.hexString`, so the readout matches what Apply stores.
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Color preview with hex.
            VStack(spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(previewColor)
                    .frame(height: ColorPickerMetrics.previewHeight)
                    .overlay {
                        RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                            .strokeBorder(Color.menuBorder, lineWidth: 1)
                    }

                Text(hexValue)
                    .font(Typography.codeTiny)
                    .foregroundStyle(.tertiary)
            }

            // HSL sliders: each slides over its own ramp, with the thumb in the
            // color it points at.
            VStack(spacing: Spacing.sm) {
                sliderRow(
                    letter: "H",
                    title: .verbatim(String(localized: "Hue", bundle: .module)),
                    value: hueBinding,
                    thumb: Color(hue: hue, saturation: 1, brightness: 1),
                    gradient: hueGradient
                ) { Text(verbatim: "\(Int($0 * 360))°") }
                sliderRow(
                    letter: "S",
                    title: .verbatim(String(localized: "Saturation", bundle: .module)),
                    value: saturationBinding,
                    thumb: Color(hue: hue, saturation: saturation, brightness: 1),
                    gradient: saturationGradient
                ) { Text($0, format: .percent.precision(.fractionLength(0)).rounded(rule: .towardZero)) }
                sliderRow(
                    letter: "L",
                    title: .verbatim(String(localized: "Lightness", bundle: .module)),
                    value: lightnessBinding,
                    thumb: Color(red: lightness, green: lightness, blue: lightness),
                    gradient: lightnessGradient
                ) { Text($0, format: .percent.precision(.fractionLength(0)).rounded(rule: .towardZero)) }
            }

            if showsPresets {
                presets
            }

            Divider()

            // Cancel directly left of the action, as in every footer.
            HStack(spacing: Spacing.sm) {
                Spacer(minLength: 0)
                Button(String(localized: "Cancel", bundle: .module)) {
                    onCancel()
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "Apply", bundle: .module)) {
                    onApply()
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.md)
        .frame(width: ColorPickerMetrics.popoverWidth)
        .onAppear {
            updateHSLFromRGB()
        }
    }

    // MARK: - Pieces

    /// A letter, the slider over its ramp, and the readout.
    private func sliderRow(
        letter: String,
        title: LocalizedStringKey,
        value: Binding<Double>,
        thumb: Color,
        gradient: LinearGradient,
        readout: @escaping (Double) -> Text
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(verbatim: letter)
                .font(Typography.labelSmall)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.iconDefault)
                .accessibilityHidden(true)

            BlissSlider(title, value: value, color: thumb, trackGradient: gradient, valueLabel: readout)
        }
    }

    /// Preset colors, led by the default (system or theme accent) when there is one.
    private var presets: some View {
        HStack(spacing: Spacing.xs) {
            if let defaultOption {
                // Clicking the default applies it immediately.
                Button {
                    onUseDefault()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(nsColor: defaultOption.color))
                            .frame(width: ColorPickerMetrics.presetSize, height: ColorPickerMetrics.presetSize)

                        Image(systemName: defaultOption.symbol)
                            .font(Typography.labelXTinyBold)
                            .foregroundStyle(defaultOption.glyphColor)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(Color.menuBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusFull))
                .tooltip(configuration: .iconHint, position: .above) {
                    Text(defaultOption.label).font(Typography.labelSmall)
                }
                .accessibilityLabel(Text(defaultOption.label))
            }

            ForEach(presetColors, id: \.self) { preset in
                Button {
                    red = preset.red
                    green = preset.green
                    blue = preset.blue
                    updateHSLFromRGB()
                } label: {
                    Circle()
                        .fill(Color(red: preset.red, green: preset.green, blue: preset.blue))
                        .frame(width: ColorPickerMetrics.presetSize, height: ColorPickerMetrics.presetSize)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.menuBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusFull))
                .accessibilityLabel(Text(verbatim: preset.name))
            }
        }
    }

    // MARK: - Ramps

    /// The sliders write the HSL component and push it into RGB at once, the
    /// way a drag did; a preset writes RGB and pulls HSL back.
    private var hueBinding: Binding<Double> {
        Binding(get: { hue }, set: { hue = $0; updateRGBFromHSL() })
    }

    private var saturationBinding: Binding<Double> {
        Binding(get: { saturation }, set: { saturation = $0; updateRGBFromHSL() })
    }

    private var lightnessBinding: Binding<Double> {
        Binding(get: { lightness }, set: { lightness = $0; updateRGBFromHSL() })
    }

    /// The rainbow.
    private var hueGradient: LinearGradient {
        let colors = stride(from: 0.0, through: 1.0, by: 0.1).map { h in
            Color(hue: h, saturation: 1, brightness: 1)
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var saturationGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0, brightness: ColorPickerMetrics.desaturatedBrightness),
                Color(hue: hue, saturation: 1, brightness: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var lightnessGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                Color(hue: hue, saturation: saturation, brightness: 1),
                Color.white
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Color Conversion

    private func updateHSLFromRGB() {
        let (h, s, l) = rgbToHSL(r: red, g: green, b: blue)
        hue = h
        saturation = s
        lightness = l
    }

    private func updateRGBFromHSL() {
        let (r, g, b) = hslToRGB(h: hue, s: saturation, l: lightness)
        red = r
        green = g
        blue = b
    }

    private func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2

        if maxC == minC {
            return (0, 0, l)
        }

        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)

        var h: Double = 0
        if maxC == r {
            h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h = h / 6
        if h < 0 { h += 1 }

        return (h, s, l)
    }

    private func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        if s == 0 {
            return (l, l, l)
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }

        let r = hueToRGB(p, q, h + 1/3)
        let g = hueToRGB(p, q, h)
        let b = hueToRGB(p, q, h - 1/3)

        return (r, g, b)
    }

    private var presetColors: [PresetColor] {
        [
            PresetColor(name: String(localized: "Purple", bundle: .module), red: 0.35, green: 0.34, blue: 0.84),
            PresetColor(name: String(localized: "Pink", bundle: .module), red: 0.92, green: 0.26, blue: 0.42),
            PresetColor(name: String(localized: "Orange", bundle: .module), red: 1.0, green: 0.58, blue: 0.0),
            PresetColor(name: String(localized: "Green", bundle: .module), red: 0.2, green: 0.78, blue: 0.35),
            PresetColor(name: String(localized: "Teal", bundle: .module), red: 0.0, green: 0.75, blue: 0.75),
            PresetColor(name: String(localized: "White", bundle: .module), red: 1.0, green: 1.0, blue: 1.0),
            PresetColor(name: String(localized: "Black", bundle: .module), red: 0.15, green: 0.15, blue: 0.15),
        ]
    }
}

struct PresetColor: Hashable {
    /// What VoiceOver reads for the swatch.
    let name: String
    let red: Double
    let green: Double
    let blue: Double
}

// MARK: - Metrics

private enum ColorPickerMetrics {
    /// The swatch tile's width; its height is the control's.
    static let swatchWidth: CGFloat = 44
    /// The popover's width: the sliders need room for a ramp and a readout.
    static let popoverWidth: CGFloat = 240
    /// The color preview block above the hex readout.
    static let previewHeight: CGFloat = 50
    /// A preset circle: the default plus seven presets fit the popover.
    static let presetSize: CGFloat = Sizing.iconMedium
    /// The saturation ramp's grey end: a touch under white so it reads as a ramp.
    static let desaturatedBrightness: Double = 0.8
    /// Above this luminance a default swatch gets the dark glyph.
    static let lightSwatchLuminance: Double = 0.6
    static let glyphOpacity: Double = 0.9
    static let darkGlyphOpacity: Double = 0.7
}

// MARK: - Previews

private struct ColorPickerPreview: View {
    @State private var red = 0.36
    @State private var green = 0.42
    @State private var blue = 0.95
    @State private var usesDefault = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ColorPickerButton(red: $red, green: $green, blue: $blue, isUsingDefault: $usesDefault)
                ColorPickerButton(red: $red, green: $green, blue: $blue, label: .hexChip)
                ColorPickerButton(red: $red, green: $green, blue: $blue, compact: true)
            }
            ColorPickerPopover(red: $red, green: $green, blue: $blue, defaultOption: .systemAccent, onApply: {}, onUseDefault: {}, onCancel: {})
        }
        .padding(Spacing.lg)
    }
}

#Preview("Color picker", traits: .fixedLayout(width: 420, height: 360)) {
    ColorPickerPreview()
}

#Preview("Theme accent default", traits: .fixedLayout(width: 280, height: 360)) {
    @Previewable @State var red = 0.74
    @Previewable @State var green = 0.58
    @Previewable @State var blue = 0.98
    ColorPickerPopover(
        red: $red, green: $green, blue: $blue,
        defaultOption: .accent(of: .lowGlare),
        onApply: {}, onUseDefault: {}, onCancel: {}
    )
    .padding(Spacing.lg)
}
