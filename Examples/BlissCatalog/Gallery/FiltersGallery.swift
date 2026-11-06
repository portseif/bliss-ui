//
//  FiltersGallery.swift
//  BlissCatalog
//
//  The "Filters" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let filters: [GalleryEntry] = [
        GalleryEntry("filter-bar", width: 600, height: 102) {
            FilterBar(
                conditions: .constant([
                    FilterCondition(fieldID: "status", operator: .is, values: ["todo", "progress"]),
                    FilterCondition(fieldID: "priority", operator: .is, values: ["urgent"]),
                    FilterCondition(fieldID: "title", operator: .contains, values: ["onboarding"]),
                ]),
                fields: FiltersGallerySamples.fields
            )
        },
        GalleryEntry("filter-menu-button", width: 380, height: 76) {
            HStack(spacing: Spacing.sm) {
                FilterMenuButton {}
                FilterMenuButton(count: 3) {}
                FilterMenuButton("Display", systemImage: "slider.horizontal.3") {}
            }
        },
        GalleryEntry("filter-check-rows", width: 280, height: 256) {
            FiltersGalleryMenuCard {
                FilterMenuSectionHeader("Status")
                FilterCheckRow("Todo", count: 8, isOn: true) {}
                FilterCheckRow("In Progress", count: 3, isOn: true, isFocused: true) {}
                FilterCheckRow("Done", count: 21, isOn: false) {}
                FilterMenuSectionHeader("Priority")
                FilterCheckRow("Urgent", count: 2, isOn: false) {}
                FilterCheckRow("High", count: 5, isOn: false) {}
            }
        },
        GalleryEntry("display-radio-rows", width: 260, height: 258) {
            FiltersGalleryMenuCard {
                FilterMenuSectionHeader("Sort by")
                DisplayRadioRow("Title", isOn: false) {}
                DisplayRadioRow("Last updated", isOn: true) {}
                DisplayRadioRow("Priority", isOn: false) {}
                FilterMenuSectionHeader("Columns")
                FilterCheckRow("Labels", isOn: true) {}
                FilterCheckRow("Assignee", isOn: false) {}
            }
        },
        GalleryEntry("filter-menu-rows", width: 280, height: 148) {
            FiltersGalleryMenuCard {
                FilterMenuSearchHeader(query: "do", placeholder: "Status")
                FiltersGalleryValueRow(title: "Todo", color: Info.info500, isOn: true, isFocused: true)
                FiltersGalleryValueRow(title: "Done", color: Success.success500, isOn: false, isFocused: false)
            }
        },
    ]
}

// MARK: - Samples

@MainActor
private enum FiltersGallerySamples {
    static var fields: [FilterField] {
        [
            FilterField(id: "status", title: "Status", icon: "circle.dashed", kind: .options([
                FilterOption(id: "todo", title: "Todo", color: Info.info500),
                FilterOption(id: "progress", title: "In Progress", color: Warning.warning500),
                FilterOption(id: "done", title: "Done", color: Success.success500),
            ])),
            FilterField(id: "priority", title: "Priority", icon: "flag", kind: .options([
                FilterOption(id: "urgent", title: "Urgent", icon: "exclamationmark.circle.fill", color: Danger.danger500),
                FilterOption(id: "high", title: "High", icon: "arrow.up"),
            ])),
            FilterField(id: "title", title: "Title", icon: "textformat", kind: .text()),
        ]
    }
}

/// A value-menu row as the filter bar draws it: checkbox, color dot, title.
private struct FiltersGalleryValueRow: View {
    let title: String
    let color: Color
    let isOn: Bool
    let isFocused: Bool

    var body: some View {
        FilterMenuRow(.verbatim(title), isFocused: isFocused, isSelected: isOn) {} leading: {
            HStack(spacing: Spacing.sm) {
                CheckboxGlyph(isOn: isOn)
                IconGlyph(name: IconItem.statusDotName, color: color)
                    .frame(width: Sizing.iconSmall)
            }
        }
    }
}

/// The floating menu's surface, drawn in place so the rows can be captured.
private struct FiltersGalleryMenuCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
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
