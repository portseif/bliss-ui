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
