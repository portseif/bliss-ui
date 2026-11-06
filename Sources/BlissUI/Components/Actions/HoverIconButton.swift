//
//  HoverIconButton.swift
//  BlissUI
//
//  Small icon button for inline row actions (copy, reveal, edit…). Shows a
//  faint, small-radius background on hover so the hit target reads as a button
//  without adding permanent chrome. Glyph size is configurable (default 12px).
//

import SwiftUI

public struct HoverIconButton: View {
    let systemImage: String
    /// Glyph point size. The hover chip and hit area pad around it.
    var size: CGFloat = 12
    /// Per-side padding around the glyph for the hit area + hover chip. Kept
    /// small so the button fits within a normal text line and doesn't grow its
    /// row (glyph + 2×padding ≈ a body line height).
    var chipPadding: CGFloat = 3
    /// Optional foreground override (e.g. a green checkmark confirmation).
    var tint: Color? = nil
    /// Optional hover tooltip text.
    var help: String? = nil
    let action: () -> Void

    public init(
        systemImage: String,
        size: CGFloat = 12,
        chipPadding: CGFloat = 3,
        tint: Color? = nil,
        help: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.size = size
        self.chipPadding = chipPadding
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
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(tint ?? Color.secondary)
                .frame(width: size + chipPadding * 2, height: size + chipPadding * 2)
                .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous))
        }
        .buttonStyle(InlineIconButtonStyle())

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

#Preview(traits: .fixedLayout(width: 200, height: 80)) {
    HStack(spacing: Spacing.xxs) {
        HoverIconButton(systemImage: "eye", help: "Show") {}
        HoverIconButton(systemImage: "doc.on.doc", help: "Copy") {}
        HoverIconButton(systemImage: "checkmark", tint: Success.success500, help: "Copied") {}
        HoverIconButton(systemImage: "pencil", help: "Edit") {}
    }
    .padding(Spacing.xl)
    .background(Color.windowBackground)
}
