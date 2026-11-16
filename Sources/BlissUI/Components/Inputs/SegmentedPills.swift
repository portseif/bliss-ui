//
//  SegmentedPills.swift
//  BlissUI
//
//  The shared segmented control: a selection pill that slides between options,
//  each option a Tab stop (Space picks it) with the shared hover fill.
//  `.regular` fills its width on a filled track (sheets, a wizard step's
//  picker) at the regular control height; `.compact` hugs its labels inside a
//  hairline at the compact one (inline toolbars, like a List | Compare view
//  switch). A switcher that carries more than a choice is better as its own
//  view.
//

import SwiftUI

/// `.regular` fills its width on a filled track; `.compact` hugs its labels in
/// a hairline.
public nonisolated enum SegmentedPillsStyle: Sendable {
    case regular
    case compact
}

/// What a segment shows: its title with an optional icon, or the icon alone
/// (the title still labels it for VoiceOver and shows as its tooltip).
public nonisolated enum SegmentedPillsLabelStyle: Sendable {
    case titleAndIcon
    case iconOnly
}

/// The control's measures: the track is pinned to a control height and the
/// segments fill it, so the pills sit level with the buttons beside them.
enum SegmentedPillsMetrics {
    static func trackHeight(_ style: SegmentedPillsStyle) -> CGFloat {
        style == .regular ? Sizing.controlMedium : Sizing.controlDefault
    }

    static func trackInset(_ style: SegmentedPillsStyle) -> CGFloat {
        style == .regular ? Spacing.insetSpacing : Spacing.hairline
    }

    static func trackRadius(_ style: SegmentedPillsStyle) -> CGFloat {
        style == .regular ? Sizing.radiusMedium : Sizing.radiusDefault
    }

    /// Concentric with the track: its radius less the inset.
    static func segmentRadius(_ style: SegmentedPillsStyle) -> CGFloat {
        style == .regular ? Sizing.radiusDefault : Sizing.radiusSmall
    }

    static let segmentSpacing: CGFloat = Spacing.hairline
}

/// A segmented control over `options`. `title` (and optionally `icon`, an SF
/// Symbol) labels each option; `isOptionEnabled` dims one and skips it.
public struct SegmentedPills<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var style: SegmentedPillsStyle = .regular
    var labelStyle: SegmentedPillsLabelStyle = .titleAndIcon
    var fillsWidth: Bool?
    var isEnabled: Bool = true
    var animation: Animation = Animations.selection
    let title: (Option) -> String
    var icon: (Option) -> String? = { _ in nil }
    /// An option that can't be picked is drawn dimmed and skipped by the keyboard.
    var isOptionEnabled: (Option) -> Bool = { _ in true }

    @Namespace private var namespace

    /// - Parameters:
    ///   - labelStyle: `.iconOnly` draws each segment's icon alone (a view
    ///     switcher); the title stays its accessibility label and tooltip.
    ///   - fillsWidth: Whether the segments stretch across the width they're
    ///     given. nil follows the style: `.regular` fills, `.compact` hugs.
    public init(
        options: [Option],
        selection: Binding<Option>,
        style: SegmentedPillsStyle = .regular,
        labelStyle: SegmentedPillsLabelStyle = .titleAndIcon,
        fillsWidth: Bool? = nil,
        isEnabled: Bool = true,
        animation: Animation = Animations.selection,
        title: @escaping (Option) -> String,
        icon: @escaping (Option) -> String? = { _ in nil },
        isOptionEnabled: @escaping (Option) -> Bool = { _ in true }
    ) {
        self.options = options
        self._selection = selection
        self.style = style
        self.labelStyle = labelStyle
        self.fillsWidth = fillsWidth
        self.isEnabled = isEnabled
        self.animation = animation
        self.title = title
        self.icon = icon
        self.isOptionEnabled = isOptionEnabled
    }

    private var stretches: Bool { fillsWidth ?? (style == .regular) }

    public var body: some View {
        HStack(spacing: SegmentedPillsMetrics.segmentSpacing) {
            ForEach(options, id: \.self) { option in
                SegmentedPillsSegment(
                    title: title(option),
                    icon: icon(option),
                    isSelected: option == selection,
                    isEnabled: isOptionEnabled(option),
                    style: style,
                    labelStyle: labelStyle,
                    stretches: stretches,
                    namespace: namespace
                ) {
                    withAnimation(animation) { selection = option }
                }
            }
        }
        .padding(SegmentedPillsMetrics.trackInset(style))
        .frame(height: SegmentedPillsMetrics.trackHeight(style))
        .background {
            switch style {
            case .regular:
                RoundedRectangle(cornerRadius: SegmentedPillsMetrics.trackRadius(style), style: .continuous)
                    .fill(Color.restingFill)
            case .compact:
                RoundedRectangle(cornerRadius: SegmentedPillsMetrics.trackRadius(style), style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SegmentedPillsMetrics.trackRadius(style), style: .continuous))
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .disabled(!isEnabled)
    }
}

private struct SegmentedPillsSegment: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let isEnabled: Bool
    let style: SegmentedPillsStyle
    let labelStyle: SegmentedPillsLabelStyle
    let stretches: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isRegular: Bool { style == .regular }

    private var cornerRadius: CGFloat { SegmentedPillsMetrics.segmentRadius(style) }

    /// The label at the control's size: the button label for the regular
    /// control, a step down for the compact one.
    private var font: Font {
        isRegular ? Typography.labelMedium : Typography.labelSmall
    }

    private var foreground: Color {
        if isSelected { return .primary }
        return isEnabled ? .secondary : Color.textTertiary
    }

    private var showsTitle: Bool { labelStyle == .titleAndIcon || icon == nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(font)
                }
                if showsTitle {
                    Text(verbatim: title)
                        .font(font)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isRegular ? Spacing.md : Spacing.sm)
            .frame(maxWidth: stretches ? .infinity : nil, maxHeight: .infinity)
            .background { background }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: cornerRadius))
        .disabled(!isEnabled)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .modifier(SegmentTooltip(title: title, isOn: !showsTitle))
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            // One pill that slides between the options (only the selected one
            // draws it): the control surface on a hairline for the regular
            // track, the selection fill inside the compact hairline.
            if isRegular {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.controlBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.menuBorder, lineWidth: 1)
                    }
                    .matchedGeometryEffect(id: "selectedSegment", in: namespace)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RowTint.selected(colorScheme))
                    .matchedGeometryEffect(id: "selectedSegment", in: namespace)
            }
        } else if isHovering && isEnabled {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(RowTint.hover(colorScheme))
        }
    }
}

/// An icon-only segment names itself on hover; a titled one doesn't need to.
private struct SegmentTooltip: ViewModifier {
    let title: String
    let isOn: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isOn {
            content.tooltip(position: .below) { Text(verbatim: title) }
        } else {
            content
        }
    }
}

#Preview("Segmented pills", traits: .fixedLayout(width: 420, height: 200)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        SegmentedPills(
            options: ["Hourly", "Daily", "Weekly"],
            selection: .constant("Daily"),
            title: { $0 }
        )
        SegmentedPills(
            options: ["List", "Compare"],
            selection: .constant("List"),
            style: .compact,
            title: { $0 },
            icon: { $0 == "List" ? "list.bullet" : "rectangle.split.2x1" }
        )
        SegmentedPills(
            options: ["List", "Grid"],
            selection: .constant("Grid"),
            style: .compact,
            labelStyle: .iconOnly,
            title: { $0 },
            icon: { $0 == "List" ? "list.bullet" : "square.grid.2x2" }
        )
    }
    .padding(Spacing.lg)
}
