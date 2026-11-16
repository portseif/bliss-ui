//
//  HoverIconButton.swift
//  BlissUI
//
//  The inline icon button: a glyph in a small chip that shows the shared hover
//  fill under the pointer and the one focus ring from the keyboard, with no
//  permanent chrome. Every small icon action in a row or a field (copy,
//  reveal, clear, dismiss, collapse) is one of these, so they all hover and
//  press the same way.
//

import SwiftUI

/// The glyph and chip sizes of a `HoverIconButton`.
public enum HoverIconButtonSize: Hashable, Sendable {
    /// A 12pt glyph in an 18pt chip: inside a field or a caption row.
    case small
    /// A 14pt glyph in a 20pt chip: a banner's dismiss, a card's action.
    case regular

    var glyphFont: Font {
        switch self {
        case .small: Typography.caption
        case .regular: Typography.labelLarge
        }
    }

    var chip: CGFloat {
        switch self {
        case .small: Sizing.inlineIconButton
        case .regular: Sizing.iconMedium
        }
    }
}

public struct HoverIconButton: View {
    let systemImage: String
    private let glyphFont: Font
    private let chip: CGFloat
    /// Keeps the chip filled, for a toggle that's on (pinned, starred).
    var isActive: Bool = false
    /// Optional foreground override (e.g. a green checkmark confirmation).
    var tint: Color? = nil
    /// Optional hover tooltip text.
    var help: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - systemImage: The glyph.
    ///   - size: The glyph and chip size.
    ///   - isActive: Keeps the chip filled, for a toggle that's on.
    ///   - tint: A foreground in place of `.secondary`.
    ///   - help: The tooltip, which is also the accessibility label.
    public init(
        systemImage: String,
        size: HoverIconButtonSize = .small,
        isActive: Bool = false,
        tint: Color? = nil,
        help: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.glyphFont = size.glyphFont
        self.chip = size.chip
        self.isActive = isActive
        self.tint = tint
        self.help = help
        self.action = action
    }

    /// A glyph at any point size, padded by `chipPadding` on each side — for
    /// a chip that must match a neighbour's geometry. Prefer `size:`.
    public init(
        systemImage: String,
        size: CGFloat,
        chipPadding: CGFloat = Spacing.insetSpacing,
        tint: Color? = nil,
        help: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.glyphFont = FontResolver.font(.ui, size: size, weight: .regular)
        self.chip = size + chipPadding * 2
        self.tint = tint
        self.help = help
        self.action = action
    }

    public var body: some View {
        let button = Button(action: action) {
            Image(systemName: systemImage)
                // A glyph swap animates when its state change does (a
                // show / hide toggle draws its slash this way).
                .contentTransition(.symbolEffect(.replace))
                .font(glyphFont)
                .foregroundStyle(tint ?? (isActive ? Color.primary : Color.secondary))
                .frame(width: chip, height: chip)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                            .fill(RowTint.selected(colorScheme))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous))
        }
        .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))

        if let help {
            // Match the tight padding of toolbar icon tooltips.
            button.tooltip(configuration: .iconHint, position: .above) {
                Text(help).font(Typography.labelSmall)
            }
            .accessibilityLabel(Text(help))
        } else {
            button
        }
    }
}

#Preview(traits: .fixedLayout(width: 240, height: 80)) {
    HStack(spacing: Spacing.xxs) {
        HoverIconButton(systemImage: "eye", help: "Show") {}
        HoverIconButton(systemImage: "doc.on.doc", help: "Copy") {}
        HoverIconButton(systemImage: "checkmark", tint: Success.success500, help: "Copied") {}
        HoverIconButton(systemImage: "pin", isActive: true, help: "Pinned") {}
        HoverIconButton(systemImage: "pencil", size: .regular, help: "Edit") {}
    }
    .padding(Spacing.xl)
    .background(Color.windowBackground)
}
