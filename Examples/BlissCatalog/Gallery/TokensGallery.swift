//
//  TokensGallery.swift
//  BlissCatalog
//
//  The "Tokens & Autocomplete" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let tokens: [GalleryEntry] = [
        GalleryEntry("token-field", height: 116) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TokenField("Add a label", tokens: .constant(["Design", "Engineering", "Research", "Docs"]))
                TokenField(
                    "Invite by email",
                    tokens: .constant(["ada@example.com", "grace@", "alan@example.com"]),
                    isValid: { $0.contains("@") && $0.contains(".") }
                )
            }
        },
        GalleryEntry("combo-box", width: 400, height: 168) {
            GalleryComboBoxCard()
        },
        GalleryEntry("shortcut-recorder", width: 400, height: 148) {
            VStack(spacing: Spacing.sm) {
                GalleryRecorderRow(title: "Quick search", shortcut: KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift]))
                GalleryRecorderRow(title: "Toggle sidebar", shortcut: KeyboardShortcutValue(.character("s"), modifiers: [.control, .command]))
                GalleryRecorderRow(title: "New note", shortcut: nil)
            }
        },
    ]
}

private struct GalleryRecorderRow: View {
    let title: LocalizedStringKey
    let shortcut: KeyboardShortcutValue?

    var body: some View {
        HStack {
            Text(title)
                .font(Typography.bodySmall)
            Spacer()
            ShortcutRecorder(shortcut: .constant(shortcut))
        }
    }
}

/// The combo box with its suggestion list open. The list is a floating panel
/// (a separate window a capture can't see), so the index draws it inline on
/// the menu surface, the way `GalleryMenuCard` draws menu rows: "lo" typed,
/// the keys on the second match.
private struct GalleryComboBoxCard: View {
    @Environment(\.colorScheme) private var colorScheme

    private let matches = ["London", "Los Angeles", "São Paulo"]
    private let query = "lo"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ComboBox("City", text: .constant(query), suggestions: matches)
                .focusRing(isFocused: true, cornerRadius: isTahoeOrLater ? Sizing.radiusFull : Sizing.radiusDefault, showsOnPointerFocus: true)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(matches.enumerated()), id: \.offset) { index, match in
                    row(match, isHighlighted: index == 1)
                }
            }
            .padding(Spacing.menuPadding)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .fill(Color.controlBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
        }
    }

    private func row(_ title: String, isHighlighted: Bool) -> some View {
        Text(emphasized(title))
            .font(Typography.bodySmall)
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
            .padding(.horizontal, Spacing.sm + 2)
            .padding(.vertical, Spacing.xs - 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Sizing.radiusDefault, style: .continuous)
                    .fill(isHighlighted ? RowTint.hover(colorScheme) : Color.clear)
            )
            .focusRing(isFocused: isHighlighted, cornerRadius: Sizing.radiusDefault, showsOnPointerFocus: true)
    }

    /// The typed text in the semibold face, as the real rows show it.
    private func emphasized(_ title: String) -> AttributedString {
        var attributed = AttributedString(title)
        if let range = attributed.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].font = Typography.labelMediumBold
        }
        return attributed
    }
}
