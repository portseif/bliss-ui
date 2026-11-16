//
//  FieldsGallery.swift
//  BlissCatalog
//
//  The "Number & Text Fields" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let fields: [GalleryEntry] = [
        GalleryEntry("number-field", width: 420, height: 116) {
            VStack(spacing: Spacing.md) {
                GalleryFieldRow("Keep backups for") {
                    NumberField("Days to keep", value: .constant(30), in: 1...365, unit: "days")
                }
                GalleryFieldRow("Line height") {
                    NumberField("Line height", value: .constant(1.5), in: 1...3, step: 0.1)
                }
            }
        },
        GalleryEntry("message-composer", width: 480, height: 190) {
            MessageComposer(
                "Message",
                text: .constant("Here are the mockups from this morning."),
                prompt: Text("Message the team…"),
                attachments: .constant([
                    ComposerAttachment(name: "Onboarding.png", systemImage: "photo"),
                    ComposerAttachment(name: "Notes.md"),
                ]),
                onSend: {},
                onAttach: {}
            ) {
                Button {} label: { Image(systemName: "face.smiling") }
                    .buttonStyle(ToolbarIconButtonStyle(compact: true))
                    .accessibilityLabel(Text("Emoji"))
            }
        },
        GalleryEntry("rich-text-editor", width: 560, height: 300) {
            RichTextEditor("Release notes", text: .constant(CatalogRichText.article))
        },
        GalleryEntry("bliss-slider", width: 420, height: 134) {
            VStack(spacing: Spacing.lg) {
                GalleryFieldRow("Volume") {
                    BlissSlider("Volume", value: .constant(0.6), valueLabel: { Text($0, format: .percent.precision(.fractionLength(0))) })
                        .frame(width: 220)
                }
                GalleryFieldRow("Columns") {
                    BlissSlider("Columns", value: .constant(3), in: 1...6, showsTicks: true, valueLabel: { Text($0, format: .number) })
                        .frame(width: 220)
                }
                GalleryFieldRow("Opacity") {
                    BlissSlider("Opacity", value: .constant(0.8), step: 0.1)
                        .frame(width: 220)
                }
            }
        },
        GalleryEntry("input-field", width: 420, height: 120) {
            VStack(spacing: Spacing.md) {
                InputField("Search", text: .constant("focus ring"), systemImage: "magnifyingglass", isClearable: true, keyboardHint: "⌘K")
                InputField("Domain", text: .constant("bliss"), isLoading: true) {
                    Text(verbatim: ".dev")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        },
        GalleryEntry("one-time-code", width: 360, height: 90) {
            OneTimeCodeField(code: .constant("4271"))
        },
        GalleryEntry("text-area", width: 460, height: 168) {
            VStack(spacing: Spacing.md) {
                TextArea("Notes", text: .constant(""), prompt: Text("Add a note…"), lineLimit: 2...4)
                TextArea(
                    "Bio",
                    text: .constant("Designer and tinkerer. Builds small tools for people who make things."),
                    lineLimit: 2...5,
                    characterLimit: 160
                )
            }
        },
    ]
}

/// A label and its control on one line, as in a settings form.
private struct GalleryFieldRow<Control: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let control: () -> Control

    init(_ title: LocalizedStringKey, @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.control = control
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(title)
                .font(Typography.bodySmall)
            Spacer(minLength: Spacing.md)
            control()
        }
    }
}
