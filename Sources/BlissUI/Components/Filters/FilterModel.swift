//
//  FilterModel.swift
//  BlissUI
//
//  The data behind a `FilterBar`: the fields an app can filter on (each a
//  multi-select of options, or free text), and the field / operator / values
//  conditions the bar edits. Conditions are plain `Codable` values, so an app
//  can save a filter and evaluate it against its own rows with `matches`.
//

import SwiftUI

// MARK: - Match mode

/// How a set of conditions combines: every one must pass, or any one.
public nonisolated enum FilterMatchMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case any

    public var id: String { rawValue }
}

// MARK: - Operator

/// How a condition compares a row's value with the condition's values.
public nonisolated enum FilterOperator: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    /// The row's value is one of the values (no values = no constraint).
    case `is`
    /// The row's value is none of the values.
    case isNot
    /// The row's text contains the typed text, ignoring case.
    case contains
    /// The row's text doesn't contain the typed text.
    case notContains

    public var id: String { rawValue }

    /// "is", "is not", "contains", "does not contain".
    public var title: String {
        switch self {
        case .is: String(localized: "is", bundle: .module)
        case .isNot: String(localized: "is not", bundle: .module)
        case .contains: String(localized: "contains", bundle: .module)
        case .notContains: String(localized: "does not contain", bundle: .module)
        }
    }

    /// With several values selected, is / is not read as "is any of" / "is none of".
    public func title(valueCount: Int) -> String {
        guard valueCount > 1 else { return title }
        switch self {
        case .is: return String(localized: "is any of", bundle: .module)
        case .isNot: return String(localized: "is none of", bundle: .module)
        case .contains, .notContains: return title
        }
    }
}

// MARK: - Option

/// One choice of a multi-select field. `id` is what a condition stores and
/// what `matches` compares against your row's value, so keep it stable (never
/// display text); `title` is what the menus show and filter on as you type.
public nonisolated struct FilterOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// The option's mark, drawn by `IconGlyph`: an SF Symbol, an `icon-` asset
    /// from your app's catalog, or `IconItem.statusDotName` for a dot.
    public var icon: String?
    /// Tints the mark. A color with no icon draws a status dot.
    public var color: Color?

    /// - Parameters:
    ///   - id: The stored value. Defaults to `title`.
    ///   - title: Shown as-is — pass translated text (`String(localized:)`).
    ///   - icon: An SF Symbol, an `icon-` asset, or `IconItem.statusDotName`.
    ///   - color: The mark's tint; alone, a colored dot.
    public init(id: String? = nil, title: String, icon: String? = nil, color: Color? = nil) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
        self.color = color
    }

    /// The name `IconGlyph` draws, or nil for an option with no mark.
    var markName: String? {
        icon ?? (color == nil ? nil : IconItem.statusDotName)
    }
}

// MARK: - Field

/// A row attribute the bar can filter on: what a chip's first segment shows,
/// and what its value menu offers.
public nonisolated struct FilterField: Identifiable, Hashable, Sendable {
    public nonisolated enum Kind: Hashable, Sendable {
        /// Pick one or more options. Operators: is (any of) / is not (none of).
        case options([FilterOption])
        /// Match typed text. Operators: contains / does not contain.
        /// `placeholder` prompts in the value menu before anything is typed.
        case text(placeholder: String? = nil)
    }

    public let id: String
    public let title: String
    /// Shown before the title in chips and the field menu: an SF Symbol, an
    /// `icon-` asset or `IconItem.statusDotName` (drawn by `IconGlyph`).
    public var icon: String?
    public var kind: Kind

    /// - Parameters:
    ///   - id: What a condition stores as its `fieldID` — your key for the attribute.
    ///   - title: Shown as-is — pass translated text (`String(localized:)`).
    ///   - icon: An SF Symbol, an `icon-` asset, or `IconItem.statusDotName`.
    ///   - kind: Multi-select options, or free text.
    public init(id: String, title: String, icon: String? = nil, kind: Kind) {
        self.id = id
        self.title = title
        self.icon = icon
        self.kind = kind
    }

    /// The options a picker field offers (empty for a text field).
    public var options: [FilterOption] {
        if case .options(let options) = kind { return options }
        return []
    }

    public var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    /// Operators valid for this field. Text uses contains; options use is / is not.
    public var operators: [FilterOperator] {
        isText ? [.contains, .notContains] : [.is, .isNot]
    }

    /// The operator a new condition on this field starts with.
    public var defaultOperator: FilterOperator { operators[0] }

    /// What a stored value shows as: its option's title, else the value itself.
    public func title(forValue value: String) -> String {
        options.first { $0.id == value }?.title ?? value
    }

    /// The option a stored value names, if the field still offers it.
    func option(forValue value: String) -> FilterOption? {
        options.first { $0.id == value }
    }

    /// Stands in for a condition whose field the app no longer describes (a
    /// saved filter outliving a field), so its chip still shows and can be
    /// removed or edited: titled by the raw id, offering the stored values.
    static func placeholder(for condition: FilterCondition) -> FilterField {
        let kind: Kind = switch condition.operator {
        case .contains, .notContains: .text()
        case .is, .isNot: .options(condition.values.map { FilterOption(title: $0) })
        }
        return FilterField(id: condition.fieldID, title: condition.fieldID, kind: kind)
    }
}

// MARK: - Condition

/// One chip of a `FilterBar`: a field, an operator and the values it tests.
public nonisolated struct FilterCondition: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// The `FilterField.id` this condition tests.
    public var fieldID: String
    public var `operator`: FilterOperator
    /// Option ids a row's value is matched against (`is` = is any of, `isNot` =
    /// is none of), or — for a text field — the search text in the first
    /// element. Empty = no constraint.
    public var values: [String]

    public init(id: UUID = UUID(), fieldID: String, operator: FilterOperator, values: [String] = []) {
        self.id = id
        self.fieldID = fieldID
        self.operator = `operator`
        self.values = values
    }

    /// A condition on `field`, starting from the field's default operator.
    public init(field: FilterField, operator: FilterOperator? = nil, values: [String] = []) {
        self.init(fieldID: field.id, operator: `operator` ?? field.defaultOperator, values: values)
    }

    /// Whether a row whose value for this condition's field is `value` passes.
    public func matches(_ value: String) -> Bool {
        matches(values: CollectionOfOne(value))
    }

    /// Whether a row with several values for this field (tags, assignees)
    /// passes: is any of = shares one of them, is none of = shares none,
    /// contains = one of them contains the text.
    public func matches<RowValues: Sequence<String>>(values rowValues: RowValues) -> Bool {
        switch self.operator {
        case .is:
            return values.isEmpty || rowValues.contains { values.contains($0) }
        case .isNot:
            return !rowValues.contains { values.contains($0) }
        case .contains, .notContains:
            // `localizedCaseInsensitiveContains("")` is false, so empty text must
            // short-circuit to "no constraint" rather than "matches nothing".
            guard let text = values.first, !text.isEmpty else { return true }
            let found = rowValues.contains { $0.localizedCaseInsensitiveContains(text) }
            return self.operator == .contains ? found : !found
        }
    }

    /// Adds `value` if it isn't selected, removes it if it is.
    mutating func toggleValue(_ value: String) {
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
        }
    }
}

// MARK: - Matching rows

extension Sequence where Element == FilterCondition {
    /// Whether a row passes these conditions under `mode`. `value` returns the
    /// row's value for a field id — the same strings as your options' ids.
    ///
    /// ```swift
    /// let visible = tasks.filter { task in
    ///     conditions.matches { field in task.value(for: field) }
    /// }
    /// ```
    /// No conditions match every row.
    public func matches(_ mode: FilterMatchMode = .all, value: (_ fieldID: String) -> String) -> Bool {
        matches(mode) { condition in condition.matches(value(condition.fieldID)) }
    }

    /// Like `matches(_:value:)`, for rows with several values per field.
    public func matches(_ mode: FilterMatchMode = .all, values: (_ fieldID: String) -> [String]) -> Bool {
        matches(mode) { condition in condition.matches(values: values(condition.fieldID)) }
    }

    private func matches(_ mode: FilterMatchMode, by test: (FilterCondition) -> Bool) -> Bool {
        switch mode {
        case .all: return allSatisfy(test)
        case .any:
            // `contains(where:)` is false for an empty filter; no conditions
            // means no constraint in either mode.
            var isEmpty = true
            for condition in self {
                isEmpty = false
                if test(condition) { return true }
            }
            return isEmpty
        }
    }
}
