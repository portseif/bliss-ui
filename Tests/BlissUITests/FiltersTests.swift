import Foundation
import SwiftUI
import Testing
@testable import BlissUI

/// The filter model's matching rules, and the ordering the filter bar's menus
/// use while they're open.
@MainActor
@Suite struct FiltersTests {
    private let status = FilterField(id: "status", title: "Status", kind: .options([
        FilterOption(id: "running", title: "Running", color: .green),
        FilterOption(id: "stopped", title: "Stopped"),
        FilterOption(id: "paused", title: "Paused", icon: "pause"),
    ]))
    private let name = FilterField(id: "name", title: "Name", kind: .text())

    // MARK: Matching

    @Test func isMatchesAnyOfItsValues() {
        let condition = FilterCondition(fieldID: "status", operator: .is, values: ["running", "paused"])
        #expect(condition.matches("running"))
        #expect(condition.matches("paused"))
        #expect(!condition.matches("stopped"))
        #expect(condition.matches(values: ["stopped", "paused"]))
        #expect(!condition.matches(values: []))
    }

    @Test func isNotMatchesNoneOfItsValues() {
        let condition = FilterCondition(fieldID: "status", operator: .isNot, values: ["running", "paused"])
        #expect(condition.matches("stopped"))
        #expect(!condition.matches("running"))
        #expect(!condition.matches(values: ["stopped", "paused"]))
        #expect(condition.matches(values: []))
    }

    /// An empty chip is no constraint, whatever its operator.
    @Test(arguments: FilterOperator.allCases)
    func emptyValuesMatchEverything(comparison: FilterOperator) {
        let condition = FilterCondition(fieldID: "status", operator: comparison, values: [])
        #expect(condition.matches("anything"))
        #expect(condition.matches(""))
        let emptyText = FilterCondition(fieldID: "name", operator: comparison, values: [""])
        if comparison == .contains || comparison == .notContains {
            #expect(emptyText.matches("anything"))
        }
    }

    @Test func containsIgnoresCase() {
        let contains = FilterCondition(fieldID: "name", operator: .contains, values: ["SHOP"])
        #expect(contains.matches("my-shop-site"))
        #expect(!contains.matches("blog"))
        let notContains = FilterCondition(fieldID: "name", operator: .notContains, values: ["shop"])
        #expect(!notContains.matches("Shopfront"))
        #expect(notContains.matches("blog"))
        #expect(contains.matches(values: ["blog", "shop"]))
        #expect(!notContains.matches(values: ["blog", "shop"]))
    }

    @Test func matchModesCombineConditions() {
        let conditions = [
            FilterCondition(fieldID: "status", operator: .is, values: ["running"]),
            FilterCondition(fieldID: "name", operator: .contains, values: ["shop"]),
        ]
        let row = ["status": "stopped", "name": "shop"]
        #expect(!conditions.matches(.all) { row[$0] ?? "" })
        #expect(conditions.matches(.any) { row[$0] ?? "" })
        let neither = ["status": "stopped", "name": "blog"]
        #expect(!conditions.matches(.any) { neither[$0] ?? "" })
        // No conditions: no constraint in either mode.
        #expect([FilterCondition]().matches(.all) { _ in "" })
        #expect([FilterCondition]().matches(.any) { _ in "" })
    }

    // MARK: Fields

    @Test func fieldsDeriveOperatorsFromTheirKind() {
        #expect(status.operators == [.is, .isNot])
        #expect(name.operators == [.contains, .notContains])
        #expect(FilterCondition(field: status).operator == .is)
        #expect(FilterCondition(field: name).operator == .contains)
        #expect(FilterCondition(field: status, operator: .isNot).operator == .isNot)
    }

    @Test func optionsWithoutAnIconDrawADotOnlyWhenColored() {
        #expect(status.options[0].markName == IconItem.statusDotName)
        #expect(status.options[1].markName == nil)
        #expect(status.options[2].markName == "pause")
    }

    @Test func unknownFieldsGetAPlaceholderChip() {
        let options = FilterField.placeholder(for: FilterCondition(fieldID: "gone", operator: .isNot, values: ["a", "b"]))
        #expect(options.title == "gone")
        #expect(options.options.map(\.id) == ["a", "b"])
        let text = FilterField.placeholder(for: FilterCondition(fieldID: "gone", operator: .contains, values: ["x"]))
        #expect(text.isText)
    }

    @Test func toggleValueAddsThenRemoves() {
        var condition = FilterCondition(field: status)
        condition.toggleValue("running")
        condition.toggleValue("paused")
        #expect(condition.values == ["running", "paused"])
        condition.toggleValue("running")
        #expect(condition.values == ["paused"])
    }

    @Test func operatorTitlesReadAnyOfWithSeveralValues() {
        #expect(FilterOperator.is.title(valueCount: 0) == FilterOperator.is.title)
        #expect(FilterOperator.is.title(valueCount: 2) == String(localized: "is any of", bundle: .module))
        #expect(FilterOperator.isNot.title(valueCount: 2) == String(localized: "is none of", bundle: .module))
        #expect(FilterOperator.notContains.title(valueCount: 2) == FilterOperator.notContains.title)
    }

    // MARK: Menus

    @Test func pinnedValuesLeadTheValueMenu() {
        let visible = FilterValueOrder.visible(status.options, pinned: ["paused", "running"], query: "")
        #expect(visible.map(\.id) == ["paused", "running", "stopped"])
        // A pinned value the field no longer offers is skipped.
        let stale = FilterValueOrder.visible(status.options, pinned: ["gone"], query: "")
        #expect(stale.map(\.id) == ["running", "stopped", "paused"])
    }

    @Test func typingNarrowsTheMenusByTitle() {
        let visible = FilterValueOrder.visible(status.options, pinned: ["paused"], query: "P")
        #expect(visible.map(\.id) == ["paused", "stopped"])
        #expect(FilterValueOrder.visible(status.options, pinned: [], query: "zzz").isEmpty)
        #expect(FilterBar.visibleFields([status, name], query: "").count == 2)
        #expect(FilterBar.visibleFields([status, name], query: "na").map(\.id) == ["name"])
    }
}
