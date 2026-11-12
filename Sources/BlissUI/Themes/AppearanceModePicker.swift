//
//  AppearanceModePicker.swift
//  BlissUI
//
//  Light / Dark / System as three small window previews, like macOS's own
//  Appearance setting: System is split, light on the left and dark on the
//  right. The previews draw with the active theme's palettes, so each shows
//  what that mode will look like.
//

import SwiftUI

/// Picks the color scheme from three window previews.
///
/// ```swift
/// @AppStorage(BlissAppearance.Keys.colorScheme) private var scheme = ColorSchemeOption.system.rawValue
///
/// SettingsRow("Mode") {
///     AppearanceModePicker(selection: Binding(
///         get: { ColorSchemeOption(rawValue: scheme) ?? .system },
///         set: { scheme = $0.rawValue }
///     ))
/// }
/// ```
public struct AppearanceModePicker: View {
    @Binding private var selection: ColorSchemeOption

    /// - Parameter selection: The chosen scheme.
    public init(selection: Binding<ColorSchemeOption>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(ColorSchemeOption.allCases) { option in
                AppearanceModeThumbnail(option: option, isSelected: selection == option) {
                    withAnimation(Animations.selection) { selection = option }
                }
            }
        }
    }
}

/// One mode's preview: a ring in the accent when it's the one in use.
private struct AppearanceModeThumbnail: View {
    let option: ColorSchemeOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    static let size = CGSize(width: 84, height: 56)
    private static let cornerRadius: CGFloat = Sizing.radiusMedium

    var body: some View {
        Button(action: onSelect) {
            preview
                .frame(width: Self.size.width, height: Self.size.height)
                // Hovered, the preview blurs behind its name.
                .blur(radius: isHovering ? 2.5 : 0)
                .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
                .overlay {
                    if isHovering { nameLabel }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                }
                // The selection ring sits just outside the preview, with a gap.
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius + 3, style: .continuous)
                        .strokeBorder(ringColor, lineWidth: 2)
                }
                .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius + 3, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Self.cornerRadius + 3))
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: isHovering)
        .accessibilityLabel(Text(verbatim: option.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The mode's name in a tooltip-style pill, centered on the preview.
    private var nameLabel: some View {
        Text(verbatim: option.title)
            .font(Typography.captionSmall)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .fill(labelSurface)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 0.5)
            }
            .transition(.opacity)
            .accessibilityHidden(true)
    }

    /// A tooltip's surface: the theme's raised one, else the vibrant material.
    private var labelSurface: AnyShapeStyle {
        if let palette = ThemeColors.activePalette { return AnyShapeStyle(palette.elevatedBackground.color) }
        return AnyShapeStyle(.thinMaterial)
    }

    private var ringColor: Color {
        if isSelected { return Color.accent }
        return isHovering ? Color.menuBorder : Color.clear
    }

    @ViewBuilder
    private var preview: some View {
        switch option {
        case .light:
            WindowMiniature(colors: .forScheme(.light))
        case .dark:
            WindowMiniature(colors: .forScheme(.dark))
        case .system:
            ZStack {
                WindowMiniature(colors: .forScheme(.light))
                WindowMiniature(colors: .forScheme(.dark))
                    .mask(HStack(spacing: 0) {
                        Color.clear
                        Color.black
                    })
            }
        }
    }
}

/// The colors a miniature window draws with for one scheme: the active
/// theme's palette for it, or the built-in surfaces under System.
private struct MiniatureColors {
    let shell: Color
    let content: Color
    let line: Color
    let accent: Color

    static func forScheme(_ scheme: ColorScheme) -> MiniatureColors {
        let isDark = scheme == .dark
        let line = isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)
        if let palette = ThemeColors.palette(for: scheme) {
            let accent = ThemeAccentOverrides.color(for: BlissTheme.active(for: scheme)) ?? palette.accent
            let themedLine = palette.foreground.map { $0.color.opacity(isDark ? 0.3 : 0.22) } ?? line
            return MiniatureColors(shell: palette.windowBackground.color, content: palette.contentBackground.color, line: themedLine, accent: accent.color)
        }
        return MiniatureColors(
            shell: isDark ? Color.appShellDark : Color.appShellLight,
            content: isDark ? Color(red: 0.12, green: 0.12, blue: 0.13) : .white,
            line: line,
            accent: Color.accent
        )
    }
}

/// A tiny window: a sidebar strip, a content pane with a few lines of text
/// (one in the accent), and a composer bar with an accent dot.
private struct WindowMiniature: View {
    let colors: MiniatureColors

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Circle().fill(colors.line).frame(width: 5, height: 5)
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(colors.line).frame(width: size.width * 0.14, height: 2)
                    }
                }
                .padding(5)
                .frame(width: size.width * 0.26, height: size.height, alignment: .topLeading)
                .background(colors.shell)

                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(colors.accent).frame(width: size.width * 0.32, height: 2.5)
                    Capsule().fill(colors.line).frame(width: size.width * 0.5, height: 2)
                    Capsule().fill(colors.line).frame(width: size.width * 0.4, height: 2)
                    Capsule().fill(colors.accent.opacity(0.8)).frame(width: size.width * 0.24, height: 2)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer(minLength: 0)
                        Circle().fill(colors.accent).frame(width: 4, height: 4)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 8)
                    .background(Capsule().strokeBorder(colors.line, lineWidth: 1))
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(colors.content)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview(traits: .fixedLayout(width: 380, height: 120)) {
    @Previewable @State var scheme = ColorSchemeOption.system
    AppearanceModePicker(selection: $scheme)
        .padding()
}
