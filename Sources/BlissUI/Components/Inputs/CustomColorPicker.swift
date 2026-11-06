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
        guard let srgb = color.usingColorSpace(.sRGB) else { return .white.opacity(0.9) }
        let luminance = 0.2126 * srgb.redComponent + 0.7152 * srgb.greenComponent + 0.0722 * srgb.blueComponent
        return luminance > 0.6 ? .black.opacity(0.7) : .white.opacity(0.9)
    }
}

/// The picker's swatch: a small tile with a hairline.
struct ColorPickerSwatch: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
            .fill(color)
            .frame(width: 44, height: 24)
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            }
    }
}

/// A color swatch button that opens a popover with HSL sliders and an Apply button.
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
    var onColorApplied: () -> Void = {}

    @State private var showingPopover = false
    @State private var tempRed: Double = 0
    @State private var tempGreen: Double = 0
    @State private var tempBlue: Double = 0
    /// The default's components the popover opened on, when it did — Apply with
    /// them untouched keeps following the default instead of pinning today's
    /// color (a theme's accent differs per scheme; the system's can change).
    @State private var openedOnDefault: [Double]?

    public init(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        isUsingDefault: Binding<Bool>? = nil,
        defaultOption: ColorPickerDefault = .systemAccent,
        onColorApplied: @escaping () -> Void = {}
    ) {
        self._red = red
        self._green = green
        self._blue = blue
        self.isUsingDefault = isUsingDefault
        self.defaultOption = defaultOption
        self.onColorApplied = onColorApplied
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
            ColorPickerSwatch(color: displayColor)
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall))
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
    var onApply: () -> Void
    var onUseDefault: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // HSL state derived from RGB.
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var lightness: Double = 0

    public init(
        red: Binding<Double>,
        green: Binding<Double>,
        blue: Binding<Double>,
        defaultOption: ColorPickerDefault? = nil,
        onApply: @escaping () -> Void,
        onUseDefault: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._red = red
        self._green = green
        self._blue = blue
        self.defaultOption = defaultOption
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
                    .frame(height: 50)
                    .overlay {
                        RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }

                Text(hexValue)
                    .font(Typography.codeTiny)
                    .foregroundStyle(.tertiary)
            }

            // HSL Sliders.
            VStack(spacing: Spacing.sm) {
                HueSliderRow(hue: $hue, onChanged: updateRGBFromHSL)
                SaturationSliderRow(saturation: $saturation, hue: hue, onChanged: updateRGBFromHSL)
                LightnessSliderRow(lightness: $lightness, hue: hue, saturation: saturation, onChanged: updateRGBFromHSL)
            }

            // Preset colors, led by the default (system or theme accent) when there is one.
            HStack(spacing: Spacing.xs) {
                if let defaultOption {
                    // Clicking the default applies it immediately.
                    Button {
                        onUseDefault()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(nsColor: defaultOption.color))
                                .frame(width: 22, height: 22)

                            Image(systemName: defaultOption.symbol)
                                .font(Typography.labelXTinyBold)
                                .foregroundStyle(defaultOption.glyphColor)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        }
                    }
                    .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
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
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
                    .accessibilityLabel(Text(verbatim: preset.name))
                }
            }

            Divider()

            // Action buttons.
            HStack(spacing: Spacing.sm) {
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
        .frame(width: 240)
        .onAppear {
            updateHSLFromRGB()
        }
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

// MARK: - Hue Slider Row

private struct HueSliderRow: View {
    @Binding var hue: Double
    var onChanged: () -> Void

    // Rainbow gradient for hue.
    private var hueGradient: LinearGradient {
        let colors = stride(from: 0.0, through: 1.0, by: 0.1).map { h in
            Color(hue: h, saturation: 1, brightness: 1)
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("H")
                .font(Typography.codeSmallMedium)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(hueGradient)
                        .frame(height: 6)

                    Circle()
                        .fill(Color(hue: hue, saturation: 1, brightness: 1))
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .offset(x: hue * (geometry.size.width - 14))
                }
                .frame(height: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newHue = min(max(value.location.x / geometry.size.width, 0), 1)
                            hue = newHue
                            onChanged()
                        }
                )
            }
            .frame(height: 14)

            Text("\(Int(hue * 360))°")
                .font(Typography.codeSmall)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Saturation Slider Row

private struct SaturationSliderRow: View {
    @Binding var saturation: Double
    var hue: Double
    var onChanged: () -> Void

    private var saturationGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0, brightness: 0.8),
                Color(hue: hue, saturation: 1, brightness: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("S")
                .font(Typography.codeSmallMedium)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(saturationGradient)
                        .frame(height: 6)

                    Circle()
                        .fill(Color(hue: hue, saturation: saturation, brightness: 1))
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .offset(x: saturation * (geometry.size.width - 14))
                }
                .frame(height: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newSat = min(max(value.location.x / geometry.size.width, 0), 1)
                            saturation = newSat
                            onChanged()
                        }
                )
            }
            .frame(height: 14)

            Text(saturation, format: .percent.precision(.fractionLength(0)).rounded(rule: .towardZero))
                .font(Typography.codeSmall)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Lightness Slider Row

private struct LightnessSliderRow: View {
    @Binding var lightness: Double
    var hue: Double
    var saturation: Double
    var onChanged: () -> Void

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

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("L")
                .font(Typography.codeSmallMedium)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(lightnessGradient)
                        .frame(height: 6)

                    Circle()
                        .fill(Color(red: lightness, green: lightness, blue: lightness))
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .strokeBorder(lightness > 0.5 ? Color.black.opacity(0.3) : .white, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .offset(x: lightness * (geometry.size.width - 14))
                }
                .frame(height: 14)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newLight = min(max(value.location.x / geometry.size.width, 0), 1)
                            lightness = newLight
                            onChanged()
                        }
                )
            }
            .frame(height: 14)

            Text(lightness, format: .percent.precision(.fractionLength(0)).rounded(rule: .towardZero))
                .font(Typography.codeSmall)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Previews

private struct ColorPickerPreview: View {
    @State private var red = 0.36
    @State private var green = 0.42
    @State private var blue = 0.95
    @State private var usesDefault = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            ColorPickerButton(red: $red, green: $green, blue: $blue, isUsingDefault: $usesDefault)
            ColorPickerPopover(red: $red, green: $green, blue: $blue, defaultOption: .systemAccent, onApply: {}, onUseDefault: {}, onCancel: {})
        }
        .padding(Spacing.lg)
    }
}

#Preview("Color picker", traits: .fixedLayout(width: 380, height: 360)) {
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
