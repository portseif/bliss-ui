//
//  SegmentedPills.swift
//  BlissUI
//
//  The shared segmented control: a selection pill that slides between options,
//  each option a Tab stop (Space picks it) with the shared hover fill.
//  `.regular` fills its width on a filled track (sheets, a wizard step's
//  picker); `.compact` hugs its labels inside a hairline (inline toolbars, like
//  a List | Compare view switch). A switcher that carries more than a choice
//  is better as its own view.
//

import SwiftUI

/// `.regular` fills its width on a filled track; `.compact` hugs its labels in
/// a hairline.
public nonisolated enum SegmentedPillsStyle: Sendable {
    case regular
    case compact
}

/// A segmented control over `options`. `title` (and optionally `icon`, an SF
/// Symbol) labels each option; `isOptionEnabled` dims one and skips it.
public struct SegmentedPills<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    var style: SegmentedPillsStyle = .regular
    var isEnabled: Bool = true
    var animation: Animation = Animations.selection
    let title: (Option) -> String
    var icon: (Option) -> String? = { _ in nil }
    /// An option that can't be picked is drawn dimmed and skipped by the keyboard.
    var isOptionEnabled: (Option) -> Bool = { _ in true }

    @Namespace private var namespace

    public init(
        options: [Option],
        selection: Binding<Option>,
        style: SegmentedPillsStyle = .regular,
        isEnabled: Bool = true,
        animation: Animation = Animations.selection,
        title: @escaping (Option) -> String,
        icon: @escaping (Option) -> String? = { _ in nil },
        isOptionEnabled: @escaping (Option) -> Bool = { _ in true }
    ) {
        self.options = options
        self._selection = selection
        self.style = style
        self.isEnabled = isEnabled
        self.animation = animation
        self.title = title
        self.icon = icon
        self.isOptionEnabled = isOptionEnabled
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                SegmentedPillsSegment(
                    title: title(option),
                    icon: icon(option),
                    isSelected: option == selection,
                    isEnabled: isOptionEnabled(option),
                    style: style,
                    namespace: namespace
                ) {
                    withAnimation(animation) { selection = option }
                }
            }
        }
        .padding(style == .regular ? 3 : 2)
        .background {
            switch style {
            case .regular:
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            case .compact:
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: style == .regular ? Sizing.radiusMedium : Sizing.radiusDefault, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .disabled(!isEnabled)
    }
}

private struct SegmentedPillsSegment: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let isEnabled: Bool
    let style: SegmentedPillsStyle
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var isRegular: Bool { style == .regular }

    private var cornerRadius: CGFloat {
        isRegular ? Sizing.radiusDefault : Sizing.radiusSmall + 1
    }

    private var foreground: Color {
        if isSelected { return .primary }
        return isEnabled ? .secondary : Color.secondary.opacity(0.35)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(isRegular ? Typography.labelSmall : Typography.captionTiny)
                }
                Text(title)
                    .font(Typography.labelSmall)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isRegular ? Spacing.md : Spacing.sm)
            .padding(.vertical, isRegular ? Spacing.sm : Spacing.xs)
            .frame(maxWidth: isRegular ? .infinity : nil)
            .background { background }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: cornerRadius))
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            // One pill that slides between the options (only the selected one
            // draws it).
            if isRegular {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 3, y: 1)
                    .matchedGeometryEffect(id: "selectedSegment", in: namespace)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .matchedGeometryEffect(id: "selectedSegment", in: namespace)
            }
        } else if isHovering && isEnabled {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(RowTint.hover(colorScheme))
        }
    }
}

#Preview("Segmented pills", traits: .fixedLayout(width: 420, height: 160)) {
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
    }
    .padding(Spacing.lg)
}
