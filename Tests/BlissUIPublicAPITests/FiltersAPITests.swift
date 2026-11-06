import Foundation
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the filter bar, its model and
/// matching helpers, the Filter / Display menu rows and the trigger button,
/// built the way an app would build them.
@MainActor
@Suite struct FiltersAPITests {
    private struct Ticket {
        let title: String
        let status: String
        let labels: [String]

        func value(for fieldID: String) -> String {
            fieldID == "status" ? status : title
        }
    }

    /// The model is plain data an app can build and evaluate off the main actor.
    nonisolated private static func makeOffMainActorModel() -> ([FilterField], [FilterCondition]) {
        let fields = [
            FilterField(id: "status", title: "Status", icon: "circle.dashed", kind: .options([
                FilterOption(id: "open", title: "Open", color: .blue),
                FilterOption(title: "Closed", icon: "checkmark.circle"),
                FilterOption(id: "draft", title: "Draft", icon: IconItem.statusDotName, color: .gray),
            ])),
            FilterField(id: "title", title: "Title", kind: .text(placeholder: "Type a title")),
            FilterField(id: "notes", title: "Notes", kind: .text()),
        ]
        let conditions = [
            FilterCondition(field: fields[0], values: ["open"]),
            FilterCondition(fieldID: "title", operator: .contains, values: ["ship"]),
        ]
        return (fields, conditions)
    }

    @Test func modelBuildsOffTheMainActor() {
        let (fields, conditions) = Self.makeOffMainActorModel()
        #expect(fields[0].options.count == 3)
        #expect(fields[0].options[1].id == "Closed")
        #expect(fields[0].operators == [.is, .isNot])
        #expect(fields[1].isText && fields[1].defaultOperator == .contains)
        #expect(fields[0].title(forValue: "open") == "Open")
        #expect(fields[0].title(forValue: "gone") == "gone")
        #expect(conditions[0].operator == .is)
        #expect(conditions[0].fieldID == "status")
        #expect(fields[0].kind != fields[1].kind)
    }

    @Test func conditionsMatchRows() {
        let (_, conditions) = Self.makeOffMainActorModel()
        let tasks = [
            Ticket(title: "Ship it", status: "open", labels: ["bug"]),
            Ticket(title: "Ship docs", status: "closed", labels: []),
            Ticket(title: "Plan", status: "open", labels: ["design", "bug"]),
        ]

        let all = tasks.filter { task in conditions.matches { field in task.value(for: field) } }
        #expect(all.map(\.title) == ["Ship it"])

        let any = tasks.filter { task in conditions.matches(.any) { field in task.value(for: field) } }
        #expect(any.count == 3)

        let labelled = FilterCondition(fieldID: "labels", operator: .isNot, values: ["bug"])
        let withoutBugs = tasks.filter { labelled.matches(values: $0.labels) }
        #expect(withoutBugs.map(\.title) == ["Ship docs"])
        #expect([labelled].matches(values: { _ in ["design"] }))
        #expect([FilterCondition]().matches { _ in "" })
        #expect(FilterCondition(fieldID: "title", operator: .notContains, values: ["plan"]).matches("Ship it"))
    }

    @Test func conditionsAreCodable() throws {
        let condition = FilterCondition(fieldID: "status", operator: .isNot, values: ["open", "draft"])
        let data = try JSONEncoder().encode([condition])
        let decoded = try JSONDecoder().decode([FilterCondition].self, from: data)
        #expect(decoded == [condition])
        let modes = try JSONDecoder().decode([FilterMatchMode].self, from: JSONEncoder().encode(FilterMatchMode.allCases))
        #expect(modes == [.all, .any])
    }

    @Test func operatorsHaveTitles() {
        #expect(FilterOperator.allCases.count == 4)
        for comparison in FilterOperator.allCases {
            #expect(!comparison.title.isEmpty)
            #expect(comparison.id == comparison.rawValue)
        }
        #expect(FilterOperator.is.title(valueCount: 1) == FilterOperator.is.title)
        #expect(FilterOperator.is.title(valueCount: 2) != FilterOperator.is.title)
        #expect(FilterOperator.contains.title(valueCount: 3) == FilterOperator.contains.title)
    }

    @Test func filterBarIsReachable() {
        let (fields, conditions) = Self.makeOffMainActorModel()
        _ = FilterBar(conditions: .constant(conditions), fields: fields)
        _ = FilterBar(
            conditions: .constant([]),
            fields: fields,
            opensFieldMenuOnAppear: true,
            onMenusClosed: {}
        )
    }

    @Test func menuRowsAreReachable() {
        _ = FilterMenuSectionHeader("Status")
        _ = FilterCheckRow("Open", count: 3, isOn: true) {}
        _ = FilterCheckRow(.verbatim("Labels"), isOn: false, isFocused: true) {}
        _ = DisplayRadioRow("Name", isOn: true) {}
        _ = DisplayRadioRow("Last updated", isOn: false, isFocused: true) {}
        _ = FilterMenuRow("Status", isFocused: false) {}
        _ = FilterMenuRow(.verbatim("Open"), isFocused: true, isSelected: true) {} leading: {
            CheckboxGlyph(isOn: true)
        }
        _ = FilterMenuSearchHeader(query: "", placeholder: "Filter…")
        _ = FilterMenuSearchHeader(query: "op", placeholder: .verbatim("Status"), showsNoMatches: true)
    }

    @Test func menuButtonIsReachable() {
        _ = FilterMenuButton {}
        _ = FilterMenuButton(isActive: true, count: 2) {}
        _ = FilterMenuButton("Display", systemImage: "slider.horizontal.3") {}
        _ = FilterMenuButton("Display", systemImage: "slider.horizontal.3", isActive: true, count: 0) {}
            .floatingMenu(isPresented: .constant(false), itemCount: 2, focusedIndex: .constant(nil), onActivate: { _ in .keepOpen }) {
                DisplayRadioRow("Name", isOn: true) {}
            }
    }
}
