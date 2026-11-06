//
//  FiltersPage.swift
//  BlissCatalog
//
//  The "Filters" page: the Linear-style filter bar over a table it filters,
//  Filter / Display menus built from the menu rows, and a type-to-filter menu.
//

import BlissUI
import SwiftUI

struct FiltersPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            DemoBlock(title: "Filter bar") {
                FilterBarDemo()
            }
            DemoBlock(title: "Filter and Display menus") {
                FacetMenusDemo()
            }
            DemoBlock(title: "Type-to-filter menu") {
                AssigneeMenuDemo()
            }
        }
    }
}

// MARK: - Sample data

/// A task in the demos. Values are the option ids the filter fields use.
private struct FilterDemoTask: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let priority: String
    let labels: [String]
    var assignee: String

    /// Static, so the rows keep their IDs across renders.
    static let samples = [
        FilterDemoTask(title: "Polish the onboarding card", status: "progress", priority: "high", labels: ["design"], assignee: "Ada"),
        FilterDemoTask(title: "Fix the sheet focus trap", status: "todo", priority: "urgent", labels: ["bug"], assignee: "Grace"),
        FilterDemoTask(title: "Write the theming guide", status: "backlog", priority: "low", labels: ["docs"], assignee: "Alan"),
        FilterDemoTask(title: "Ship the Low Glare theme", status: "done", priority: "medium", labels: ["design", "feature"], assignee: "Katherine"),
        FilterDemoTask(title: "Tooltip flickers on scroll", status: "todo", priority: "high", labels: ["bug"], assignee: "Ada"),
        FilterDemoTask(title: "Onboarding copy pass", status: "backlog", priority: "medium", labels: ["docs", "design"], assignee: "Grace"),
    ]

    /// This task's values for a filter field id.
    func values(for fieldID: String) -> [String] {
        switch fieldID {
        case "status": [status]
        case "priority": [priority]
        case "label": labels
        case "title": [title]
        default: []
        }
    }
}

/// The fields the demos filter on. A computed list, not a `static let`: the
/// status colors follow the theme, so they're read on every render.
@MainActor
private enum FilterDemoFields {
    static var status: FilterField {
        FilterField(id: "status", title: "Status", icon: "circle.dashed", kind: .options([
            FilterOption(id: "backlog", title: "Backlog", color: Grey.grey400),
            FilterOption(id: "todo", title: "Todo", color: Info.info500),
            FilterOption(id: "progress", title: "In Progress", color: Warning.warning500),
            FilterOption(id: "done", title: "Done", color: Success.success500),
        ]))
    }

    static var priority: FilterField {
        FilterField(id: "priority", title: "Priority", icon: "flag", kind: .options([
            FilterOption(id: "urgent", title: "Urgent", icon: "exclamationmark.circle.fill", color: Danger.danger500),
            FilterOption(id: "high", title: "High", icon: "arrow.up"),
            FilterOption(id: "medium", title: "Medium", icon: "equal"),
            FilterOption(id: "low", title: "Low", icon: "arrow.down"),
        ]))
    }

    static var label: FilterField {
        FilterField(id: "label", title: "Label", icon: "tag", kind: .options([
            FilterOption(id: "design", title: "Design", icon: "paintpalette"),
            FilterOption(id: "bug", title: "Bug", icon: "ladybug"),
            FilterOption(id: "docs", title: "Docs", icon: "doc.text"),
            FilterOption(id: "feature", title: "Feature", icon: "sparkles"),
        ]))
    }

    static var title: FilterField {
        FilterField(id: "title", title: "Title", icon: "textformat", kind: .text(placeholder: "Type to match titles"))
    }

    static var all: [FilterField] { [status, priority, label, title] }
}

// MARK: - Filter bar

private struct FilterBarDemo: View {
    @State private var conditions = [
        FilterCondition(fieldID: "status", operator: .is, values: ["todo", "progress"]),
    ]
    @State private var matchMode: FilterMatchMode = .all

    private var tasks: [FilterDemoTask] { FilterDemoTask.samples }

    private var matchingTasks: [FilterDemoTask] {
        tasks.filter { task in
            conditions.matches(matchMode) { field -> [String] in task.values(for: field) }
        }
    }

    var body: some View {
        let fields = FilterDemoFields.all
        let matching = matchingTasks
        VStack(alignment: .leading, spacing: Spacing.md) {
            FilterBar(conditions: $conditions, fields: fields)
            HStack(spacing: Spacing.sm) {
                // The all / any choice only matters with two or more chips.
                if conditions.count > 1 {
                    Text("Match")
                    SegmentedPills(
                        options: FilterMatchMode.allCases,
                        selection: $matchMode,
                        style: .compact,
                        title: { $0 == .all ? "all" : "any" }
                    )
                    .fixedSize()
                    Text("of the conditions")
                }
                Spacer()
                Text("\(matching.count) of \(tasks.count) tasks match")
                    .monospacedDigit()
            }
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
            BlissTable(
                matching,
                columns: [
                    BlissTableColumn("Task", sortedBy: \FilterDemoTask.title),
                    BlissTableColumn("Status", width: .fixed(110)),
                    BlissTableColumn("Priority", width: .fixed(90)),
                    BlissTableColumn("Labels", width: .fixed(140)),
                ],
                contentInset: 0
            ) { task in
                Text(verbatim: task.title)
                    .font(Typography.bodySmall)
                    .lineLimit(1)
                optionLabel(fields[0], value: task.status)
                optionLabel(fields[1], value: task.priority)
                Text(verbatim: task.labels.map(fields[2].title(forValue:)).joined(separator: ", "))
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .animation(Animations.selection, value: matching.map(\.id))
        }
    }

    private func optionLabel(_ field: FilterField, value: String) -> some View {
        let option = field.options.first { $0.id == value }
        return HStack(spacing: Spacing.xs) {
            if let option {
                IconGlyph(name: option.icon ?? IconItem.statusDotName, color: option.color ?? .secondary, size: Sizing.iconTiny)
            }
            Text(verbatim: field.title(forValue: value))
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Filter + Display menus

/// One checkbox in the facet menu, in the order its arrow keys step through.
private struct FilterFacet: Hashable {
    let fieldID: String
    let option: FilterOption
}

private enum DemoSort: String, CaseIterable {
    case title = "Title"
    case priority = "Priority"
}

private struct FacetMenusDemo: View {
    @State private var selectedFacets: Set<FilterFacet> = []
    @State private var facetFocusedIndex: Int?
    @State private var showingFacets = false

    @State private var sort: DemoSort = .title
    @State private var showsLabels = true
    @State private var displayFocusedIndex: Int?
    @State private var showingDisplay = false

    private var tasks: [FilterDemoTask] { FilterDemoTask.samples }

    private var facets: [FilterFacet] {
        [FilterDemoFields.status, FilterDemoFields.priority].flatMap { field in
            field.options.map { FilterFacet(fieldID: field.id, option: $0) }
        }
    }

    /// The facets as conditions: OR within a field, AND across fields.
    private var conditions: [FilterCondition] {
        Dictionary(grouping: selectedFacets, by: \.fieldID).map { fieldID, picked in
            FilterCondition(fieldID: fieldID, operator: .is, values: picked.map(\.option.id))
        }
    }

    private var visibleTasks: [FilterDemoTask] {
        let conditions = self.conditions
        let matching = tasks.filter { task in
            conditions.matches { field -> [String] in task.values(for: field) }
        }
        switch sort {
        case .title: return matching.sorted { $0.title < $1.title }
        case .priority:
            let order = FilterDemoFields.priority.options.map(\.id)
            return matching.sorted { (order.firstIndex(of: $0.priority) ?? 0) < (order.firstIndex(of: $1.priority) ?? 0) }
        }
    }

    var body: some View {
        let facets = self.facets
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                FilterMenuButton(count: selectedFacets.count) {
                    showingFacets.toggle()
                }
                // ↑ ↓ move through the checkboxes; Return or Space toggles one and
                // the menu stays open for the next; Esc closes it.
                .floatingMenu(
                    isPresented: $showingFacets,
                    itemCount: facets.count,
                    focusedIndex: $facetFocusedIndex,
                    xPosition: .leading,
                    yPosition: .below,
                    onActivate: { index in
                        if facets.indices.contains(index) { selectedFacets.formSymmetricDifference([facets[index]]) }
                        return .keepOpen
                    }
                ) {
                    FacetMenuContent(
                        facets: facets,
                        counts: facetCounts(facets),
                        selected: $selectedFacets,
                        focusedIndex: $facetFocusedIndex
                    )
                }
                Spacer()
                FilterMenuButton("Display", systemImage: "slider.horizontal.3") {
                    showingDisplay.toggle()
                }
                .floatingMenu(
                    isPresented: $showingDisplay,
                    itemCount: DisplayMenuContent.optionCount,
                    focusedIndex: $displayFocusedIndex,
                    xPosition: .trailing,
                    yPosition: .below,
                    onActivate: { index in
                        DisplayMenuContent.apply(index, sort: $sort, showsLabels: $showsLabels)
                        return .keepOpen
                    }
                ) {
                    DisplayMenuContent(sort: $sort, showsLabels: $showsLabels, focusedIndex: $displayFocusedIndex)
                }
            }
            DividedForEach(visibleTasks) { task in
                HStack(spacing: Spacing.sm) {
                    Text(verbatim: task.title)
                        .font(Typography.bodySmall)
                    Spacer()
                    if showsLabels {
                        ForEach(task.labels, id: \.self) { label in
                            Badge(.verbatim(FilterDemoFields.label.title(forValue: label))).badgeSize(.small)
                        }
                    }
                    Text(verbatim: FilterDemoFields.priority.title(forValue: task.priority))
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .padding(.vertical, Spacing.listRowPadding)
            } separator: {
                Divider()
            }
        }
    }

    private func facetCounts(_ facets: [FilterFacet]) -> [FilterFacet: Int] {
        Dictionary(uniqueKeysWithValues: facets.map { facet in
            (facet, tasks.filter { $0.values(for: facet.fieldID).contains(facet.option.id) }.count)
        })
    }
}

/// The Filter menu: a checkbox per status and priority, with live counts.
/// A `View` with `@Binding`s — the menu snapshots its content at open.
private struct FacetMenuContent: View {
    let facets: [FilterFacet]
    let counts: [FilterFacet: Int]
    @Binding var selected: Set<FilterFacet>
    @Binding var focusedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Filter").font(Typography.labelMedium)
                Spacer()
                Button("Clear all") { selected.removeAll() }
                    .buttonStyle(FocusablePlainButtonStyle())
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xxs)

            ForEach(Array(facets.enumerated()), id: \.element) { index, facet in
                if index == 0 || facets[index - 1].fieldID != facet.fieldID {
                    FilterMenuSectionHeader(facet.fieldID == "status" ? "Status" : "Priority")
                }
                FilterCheckRow(
                    .verbatim(facet.option.title),
                    count: counts[facet],
                    isOn: selected.contains(facet),
                    isFocused: focusedIndex == index
                ) {
                    selected.formSymmetricDifference([facet])
                }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 220)
    }
}

/// The Display menu: sort radios, then a column toggle.
private struct DisplayMenuContent: View {
    @Binding var sort: DemoSort
    @Binding var showsLabels: Bool
    @Binding var focusedIndex: Int?

    /// Every choice in list order — what the menu's arrow keys step through.
    static var optionCount: Int { DemoSort.allCases.count + 1 }

    static func apply(_ index: Int, sort: Binding<DemoSort>, showsLabels: Binding<Bool>) {
        if DemoSort.allCases.indices.contains(index) {
            sort.wrappedValue = DemoSort.allCases[index]
        } else if index == DemoSort.allCases.count {
            showsLabels.wrappedValue.toggle()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            FilterMenuSectionHeader("Sort by")
            ForEach(Array(DemoSort.allCases.enumerated()), id: \.element) { index, option in
                DisplayRadioRow(LocalizedStringKey(option.rawValue), isOn: sort == option, isFocused: focusedIndex == index) {
                    sort = option
                }
            }
            FilterMenuSectionHeader("Columns")
            FilterCheckRow("Labels", isOn: showsLabels, isFocused: focusedIndex == DemoSort.allCases.count) {
                showsLabels.toggle()
            }
        }
        .padding(Spacing.menuPadding)
        .frame(width: 200)
    }
}

// MARK: - Type-to-filter menu

private struct AssigneeMenuDemo: View {
    private static let people = ["Ada Lovelace", "Alan Turing", "Grace Hopper", "Katherine Johnson", "Margaret Hamilton"]

    @State private var assignee = "Grace Hopper"
    @State private var showingMenu = false
    @State private var focusedIndex: Int?
    @State private var query = ""

    static func visiblePeople(_ query: String) -> [String] {
        guard !query.isEmpty else { return people }
        return people.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                showingMenu.toggle()
            } label: {
                Label(assignee, systemImage: "person.crop.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
            // Typing narrows the list (the panel can't host a text field, so the
            // header echoes the query); ↑ ↓ and Return pick.
            .floatingMenu(
                isPresented: $showingMenu,
                itemCount: Self.visiblePeople(query).count,
                focusedIndex: $focusedIndex,
                xPosition: .leading,
                yPosition: .below,
                onSelect: { index in
                    let visible = Self.visiblePeople(query)
                    if visible.indices.contains(index) { assignee = visible[index] }
                },
                onTypeahead: { typed in
                    query = typed
                    focusedIndex = Self.visiblePeople(typed).isEmpty ? nil : 0
                }
            ) {
                AssigneeMenuContent(
                    assignee: $assignee,
                    query: $query,
                    focusedIndex: $focusedIndex,
                    onPick: { person in
                        assignee = person
                        showingMenu = false
                    }
                )
            }
            .onChange(of: showingMenu) { _, isOpen in
                if !isOpen { query = "" }
            }
            Text("Open the menu and start typing a name.")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AssigneeMenuContent: View {
    @Binding var assignee: String
    @Binding var query: String
    @Binding var focusedIndex: Int?
    let onPick: (String) -> Void

    var body: some View {
        let visible = AssigneeMenuDemo.visiblePeople(query)
        VStack(alignment: .leading, spacing: 1) {
            FilterMenuSearchHeader(query: query, placeholder: "Assign to…", showsNoMatches: visible.isEmpty)
            ForEach(Array(visible.enumerated()), id: \.element) { index, person in
                FilterMenuRow(.verbatim(person), isFocused: focusedIndex == index, isSelected: person == assignee) {
                    onPick(person)
                } leading: {
                    Image(systemName: "checkmark")
                        .font(Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .opacity(person == assignee ? 1 : 0)
                }
                .onHover { hovering in
                    if hovering { focusedIndex = index }
                }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: 220, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
}
