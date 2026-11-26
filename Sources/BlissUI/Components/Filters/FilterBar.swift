//
//  FilterBar.swift
//  BlissUI
//
//  Linear-style condition editor. Each condition is a chip — field │ operator ▾ │
//  values ▾ │ × — and a Filter button adds one: pick a field, and that chip's
//  value menu opens on it. Option fields multi-select (the operator then reads
//  "is any of" / "is none of"); text fields match typed text. Every menu
//  filters as you type (the floating menu's typeahead — a detached panel can't
//  host a focused text field).
//

import SwiftUI

// MARK: - Metrics

/// The bar's chip geometry: the chips, the add button and Clear share one
/// height, a step under the compact control's.
enum FilterBarMetrics {
    static let chipHeight: CGFloat = Sizing.controlSmall
    static let cornerRadius: CGFloat = Sizing.radiusDefault
    /// A typed text value is cut here so a chip never swallows the bar.
    static let maximumTextValueWidth: CGFloat = 160
    /// How many option marks a multi-value chip shows before the count.
    static let maximumMarks = 3
    /// The marks sit nearly flush, like a stack of dots.
    static let markSpacing: CGFloat = 1
    /// The field menu anchors to the Filter button, which needs a laid-out
    /// frame first; a value menu waits for the field menu to close and the
    /// new chip to lay out.
    static let fieldMenuOpenDelay: Duration = .milliseconds(120)
    static let valueMenuOpenDelay: Duration = .milliseconds(150)
}

/// Edits a list of filter conditions as chips, over the fields you describe.
///
/// ```swift
/// @State private var conditions: [FilterCondition] = []
///
/// FilterBar(conditions: $conditions, fields: [
///     FilterField(id: "status", title: "Status", icon: "circle.dashed", kind: .options([
///         FilterOption(id: "open", title: "Open", color: Info.info500),
///         FilterOption(id: "done", title: "Done", color: Success.success500),
///     ])),
///     FilterField(id: "title", title: "Title", icon: "textformat", kind: .text()),
/// ])
///
/// let visible = tasks.filter { task in
///     conditions.matches { field in task.value(for: field) }
/// }
/// ```
///
/// Picking a field adds an empty chip and opens its value menu; closing that
/// menu with nothing picked drops the chip again. An option field that already
/// has an "is" chip reopens it instead of adding a second. Values ticked when
/// a value menu opens lead its list until it closes, so rows don't jump under
/// the pointer while you tick. A locked condition (`FilterCondition.isLocked`)
/// keeps its field and operator and survives Clear.
public struct FilterBar: View {
    @Binding private var conditions: [FilterCondition]
    private let fields: [FilterField]
    private let matchMode: Binding<FilterMatchMode>?
    private let showsClearButton: Bool
    private let alwaysShowsAddTitle: Bool
    private let opensFieldMenuOnAppear: Bool
    private let onMenusClosed: (() -> Void)?

    @State private var showingFieldMenu = false
    @State private var fieldFocusedIndex: Int?
    @State private var fieldQuery = ""
    /// The chip whose value menu is open. One at a time, so opening a new chip's
    /// menu closes the previous one.
    @State private var openValueMenuID: UUID?
    /// A value menu that's been scheduled but hasn't opened yet — the gap between
    /// the two would otherwise read as "no menus open".
    @State private var pendingValueMenuID: UUID?

    /// - Parameters:
    ///   - conditions: The chips, in order. The bar adds, edits and removes them.
    ///   - fields: What can be filtered on, in the field menu's order.
    ///   - matchMode: A leading "Match all" / "Match any" chip that flips how
    ///     the conditions combine (pass it to `matches(_:value:)`); nil hides it.
    ///   - showsClearButton: The Clear button after the chips, when any can be cleared.
    ///   - alwaysShowsAddTitle: Keeps "Add filter" beside its icon once chips
    ///     exist (by default the title gives way to the chips).
    ///   - opensFieldMenuOnAppear: Opens the field menu as soon as the bar
    ///     appears with no conditions, so a brand-new filter lands straight in
    ///     the field picker instead of costing a click on Filter.
    ///   - onMenusClosed: Fires when the last open menu closes — the host can
    ///     take keyboard focus back (the menus consume typing for their own
    ///     typeahead while open).
    public init(
        conditions: Binding<[FilterCondition]>,
        fields: [FilterField],
        matchMode: Binding<FilterMatchMode>? = nil,
        showsClearButton: Bool = true,
        alwaysShowsAddTitle: Bool = false,
        opensFieldMenuOnAppear: Bool = false,
        onMenusClosed: (() -> Void)? = nil
    ) {
        self._conditions = conditions
        self.fields = fields
        self.matchMode = matchMode
        self.showsClearButton = showsClearButton
        self.alwaysShowsAddTitle = alwaysShowsAddTitle
        self.opensFieldMenuOnAppear = opensFieldMenuOnAppear
        self.onMenusClosed = onMenusClosed
    }

    private var hasClearableConditions: Bool {
        conditions.contains { !$0.isLocked }
    }

    public var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            if let matchMode {
                MatchModeChip(mode: matchMode)
            }
            ForEach($conditions) { $condition in
                FilterConditionChip(
                    condition: $condition,
                    field: field(for: condition),
                    isValueMenuOpen: valueMenuBinding(for: condition.id),
                    onRemove: { remove(condition.id) }
                )
            }
            addButton
            if showsClearButton, hasClearableConditions {
                clearButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard opensFieldMenuOnAppear, conditions.isEmpty else { return }
            Task {
                try? await Task.sleep(for: FilterBarMetrics.fieldMenuOpenDelay)
                showingFieldMenu = true
            }
        }
    }

    // MARK: - Filter button

    private var addButton: some View {
        let title = String(localized: "Add filter", bundle: .module)
        return Button {
            showingFieldMenu.toggle()
        } label: {
            HStack(spacing: Spacing.xxs) {
                BlissSymbol("line.3.horizontal.decrease")
                    .font(Typography.captionSmall)
                if conditions.isEmpty || alwaysShowsAddTitle {
                    Text(verbatim: title)
                }
            }
            .font(Typography.labelSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: FilterBarMetrics.chipHeight)
            .overlay {
                RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
        }
        .buttonStyle(ChipSegmentButtonStyle(isActive: showingFieldMenu))
        .clipShape(RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous))
        .accessibilityLabel(Text(verbatim: title))
        .tooltip(configuration: .iconHint, position: .above) {
            Text(verbatim: title).font(Typography.labelSmall)
        }
        .floatingMenu(
            isPresented: $showingFieldMenu,
            itemCount: Self.visibleFields(fields, query: fieldQuery).count,
            focusedIndex: $fieldFocusedIndex,
            xPosition: .leading,
            yPosition: .below,
            onSelect: { index in
                let visible = Self.visibleFields(fields, query: fieldQuery)
                guard visible.indices.contains(index) else { return }
                addCondition(for: visible[index])
            },
            onTypeahead: { query in
                fieldQuery = query
                fieldFocusedIndex = Self.visibleFields(fields, query: query).isEmpty ? nil : 0
            }
        ) {
            FilterFieldMenu(fields: fields, query: $fieldQuery, focusedIndex: $fieldFocusedIndex, onPick: addCondition)
        }
        .onChange(of: showingFieldMenu) { _, isOpen in
            if !isOpen {
                fieldQuery = ""
                notifyIfIdle()
            }
        }
    }

    private var clearButton: some View {
        Button {
            openValueMenuID = nil
            conditions.removeAll { !$0.isLocked }
        } label: {
            Text("Clear", bundle: .module)
                .font(Typography.labelSmall)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.sm)
                .frame(height: FilterBarMetrics.chipHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                }
        }
        .buttonStyle(ChipSegmentButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous))
    }

    // MARK: - Actions

    /// The fields whose title contains the typed query. The `isEmpty` guard is
    /// load-bearing — `localizedCaseInsensitiveContains("")` is false.
    static func visibleFields(_ fields: [FilterField], query: String) -> [FilterField] {
        guard !query.isEmpty else { return fields }
        return fields.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func field(for condition: FilterCondition) -> FilterField {
        fields.first { $0.id == condition.fieldID } ?? .placeholder(for: condition)
    }

    private func addCondition(for field: FilterField) {
        showingFieldMenu = false
        // An option field already on the bar reopens its values instead of adding
        // a second chip (multi-select covers "any of"). Text fields can repeat.
        if !field.isText, let existing = conditions.first(where: { $0.fieldID == field.id && $0.operator == .is }) {
            openValueMenu(existing.id)
            return
        }
        let condition = FilterCondition(field: field)
        conditions.append(condition)
        openValueMenu(condition.id)
    }

    /// Deferred so the field menu finishes closing and the new chip has a laid-out
    /// frame for its value menu to anchor to.
    private func openValueMenu(_ id: UUID) {
        pendingValueMenuID = id
        Task {
            try? await Task.sleep(for: FilterBarMetrics.valueMenuOpenDelay)
            openValueMenuID = id
            pendingValueMenuID = nil
        }
    }

    /// Reports "nothing is open" once — and only once the pending value menu has
    /// either opened or been dropped.
    private func notifyIfIdle() {
        guard !showingFieldMenu, openValueMenuID == nil, pendingValueMenuID == nil else { return }
        onMenusClosed?()
    }

    private func remove(_ id: UUID) {
        if openValueMenuID == id { openValueMenuID = nil }
        conditions.removeAll { $0.id == id }
    }

    private func valueMenuBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { openValueMenuID == id },
            set: { isOpen in
                if isOpen {
                    openValueMenuID = id
                } else if openValueMenuID == id {
                    openValueMenuID = nil
                    // Closed before anything was picked: drop the empty chip
                    // (a locked one stays, it was put there on purpose).
                    conditions.removeAll { $0.id == id && $0.values.isEmpty && !$0.isLocked }
                    notifyIfIdle()
                }
            }
        )
    }
}

// MARK: - Match mode chip

/// "Match all ▾" / "Match any ▾": a click flips it.
private struct MatchModeChip: View {
    @Binding var mode: FilterMatchMode

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous)
    }

    private var title: Text {
        switch mode {
        case .all: Text("Match all", bundle: .module)
        case .any: Text("Match any", bundle: .module)
        }
    }

    var body: some View {
        Button {
            withAnimation(Animations.selection) {
                mode = mode == .all ? .any : .all
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                title
                BlissSymbol("chevron.up.chevron.down")
                    .font(Typography.labelXTiny)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .font(Typography.labelSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.sm)
            .frame(height: FilterBarMetrics.chipHeight)
            .background(shape.fill(Color.restingFill))
            .overlay(shape.strokeBorder(Color.menuBorder, lineWidth: 1))
        }
        .buttonStyle(ChipSegmentButtonStyle())
        .clipShape(shape)
        .accessibilityLabel(Text("Match", bundle: .module))
        .accessibilityValue(title)
    }
}

// MARK: - Condition chip

private struct FilterConditionChip: View {
    @Binding var condition: FilterCondition
    let field: FilterField
    @Binding var isValueMenuOpen: Bool
    let onRemove: () -> Void

    static let height: CGFloat = FilterBarMetrics.chipHeight

    @Environment(\.colorScheme) private var scheme
    @State private var showingOperatorMenu = false
    @State private var operatorFocusedIndex: Int?
    @State private var valueFocusedIndex: Int?
    @State private var valueQuery = ""
    /// Values already selected when the value menu opened. They lead the list for
    /// the whole session, so rows don't jump under the cursor while ticking.
    @State private var pinnedValues: [String] = []

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FilterBarMetrics.cornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 0) {
            fieldSegment
            separator
            operatorSegment
            separator
            valueSegment
            if !condition.isLocked {
                separator
                removeButton
            }
        }
        .frame(height: Self.height)
        // A surface, not the hover wash: a hovered segment must still read.
        .background(shape.fill(Color.restingFill))
        .overlay(shape.strokeBorder(Color.menuBorder, lineWidth: 1))
        .clipShape(shape)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: field.title))
        .onChange(of: isValueMenuOpen) { _, isOpen in
            if isOpen { pinnedValues = condition.values }
            valueQuery = ""
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(width: 1)
    }

    private var fieldSegment: some View {
        HStack(spacing: Spacing.xxs) {
            if condition.isLocked {
                BlissSymbol("lock.fill")
                    .font(Typography.labelXTiny)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(Text("Locked", bundle: .module))
            }
            if let icon = field.icon {
                IconGlyph(name: icon, color: .secondary, size: Sizing.iconTiny)
            }
            Text(verbatim: field.title)
        }
        .font(Typography.labelSmall)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Spacing.sm)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var operatorSegment: some View {
        let label = Text(verbatim: condition.operator.title(valueCount: condition.values.count))
            .font(Typography.labelSmall)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs)
            .frame(maxHeight: .infinity)
        if condition.isLocked {
            // Inert: a locked condition keeps its operator.
            label
        } else {
            Button {
                showingOperatorMenu.toggle()
            } label: {
                label
            }
            .buttonStyle(ChipSegmentButtonStyle(isActive: showingOperatorMenu))
            .floatingMenu(
                isPresented: $showingOperatorMenu,
                itemCount: field.operators.count,
                focusedIndex: $operatorFocusedIndex,
                xPosition: .leading,
                yPosition: .below,
                onSelect: { index in
                    let operators = field.operators
                    guard operators.indices.contains(index) else { return }
                    condition.operator = operators[index]
                }
            ) {
                FilterOperatorMenu(
                    condition: $condition,
                    operators: field.operators,
                    focusedIndex: $operatorFocusedIndex,
                    onPick: { pickedOperator in
                        condition.operator = pickedOperator
                        showingOperatorMenu = false
                    }
                )
            }
        }
    }

    private var valueSegment: some View {
        Button {
            isValueMenuOpen.toggle()
        } label: {
            valueLabel
                .font(Typography.labelSmall)
                .foregroundStyle(.primary)
                .padding(.horizontal, Spacing.xs)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(ChipSegmentButtonStyle(isActive: isValueMenuOpen))
        .accessibilityLabel(valueAccessibilityLabel)
        .floatingMenu(
            isPresented: $isValueMenuOpen,
            itemCount: valueItemCount(for: valueQuery),
            focusedIndex: $valueFocusedIndex,
            xPosition: .leading,
            yPosition: .below,
            onSelect: pickValue,
            onTypeahead: { query in
                valueQuery = query
                valueFocusedIndex = valueItemCount(for: query) > 0 ? 0 : nil
            }
        ) {
            FilterValueMenu(
                condition: $condition,
                field: field,
                query: $valueQuery,
                pinned: $pinnedValues,
                focusedIndex: $valueFocusedIndex,
                onPickText: { text in
                    condition.values = [text]
                    isValueMenuOpen = false
                }
            )
        }
    }

    @ViewBuilder
    private var valueLabel: some View {
        let values = condition.values
        if values.isEmpty {
            Text(verbatim: "…")
                .foregroundStyle(.tertiary)
        } else if field.isText {
            Text(verbatim: values[0])
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: FilterBarMetrics.maximumTextValueWidth)
        } else if values.count == 1 {
            HStack(spacing: Spacing.xxs) {
                FilterOptionMark(option: field.option(forValue: values[0]))
                Text(verbatim: field.title(forValue: values[0]))
                    .lineLimit(1)
            }
        } else {
            let marked = values.compactMap(field.option(forValue:)).filter { $0.markName != nil }
            HStack(spacing: Spacing.xxs) {
                if !marked.isEmpty {
                    HStack(spacing: FilterBarMetrics.markSpacing) {
                        ForEach(marked.prefix(FilterBarMetrics.maximumMarks)) { option in
                            FilterOptionMark(option: option)
                        }
                    }
                }
                Text("\(values.count) selected", bundle: .module)
            }
        }
    }

    private var valueAccessibilityLabel: Text {
        let values = condition.values
        guard !values.isEmpty else { return Text("Choose values", bundle: .module) }
        let titles = values.map(field.title(forValue:))
        return Text(verbatim: ListFormatter.localizedString(byJoining: titles))
    }

    private var removeButton: some View {
        let title = String(localized: "Remove filter", bundle: .module)
        return Button(action: onRemove) {
            BlissSymbol("xmark")
                .font(Typography.labelXTiny)
                .foregroundStyle(.secondary)
                // A square a hairline inside the chip's height.
                .frame(width: Self.height - Spacing.hairline)
                .frame(maxHeight: .infinity)
        }
        .buttonStyle(ChipSegmentButtonStyle())
        .tooltip(configuration: .iconHint, position: .above) {
            Text(verbatim: title).font(Typography.labelSmall)
        }
        .accessibilityLabel(Text(verbatim: title))
    }

    // MARK: Values

    private func valueItemCount(for query: String) -> Int {
        if field.isText { return query.isEmpty ? 0 : 1 }
        return FilterValueOrder.visible(field.options, pinned: pinnedValues, query: query).count
    }

    /// Return picks the focused row: the typed text for a text field, else
    /// toggles the option.
    private func pickValue(at index: Int) {
        if field.isText {
            guard !valueQuery.isEmpty else { return }
            condition.values = [valueQuery]
            return
        }
        let visible = FilterValueOrder.visible(field.options, pinned: pinnedValues, query: valueQuery)
        guard visible.indices.contains(index) else { return }
        condition.toggleValue(visible[index].id)
    }
}

// MARK: - Menus

enum FilterValueOrder {
    /// The pinned (selected-at-open) options first, then the rest, narrowed by
    /// the typed query. The `isEmpty` guard is load-bearing — contains("") is false.
    static func visible(_ options: [FilterOption], pinned: [String], query: String) -> [FilterOption] {
        let pinnedOptions = pinned.compactMap { value in options.first { $0.id == value } }
        let ordered = pinnedOptions + options.filter { !pinned.contains($0.id) }
        guard !query.isEmpty else { return ordered }
        return ordered.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

private struct FilterFieldMenu: View {
    let fields: [FilterField]
    @Binding var query: String
    @Binding var focusedIndex: Int?
    let onPick: (FilterField) -> Void

    var body: some View {
        let visible = FilterBar.visibleFields(fields, query: query)
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            FilterMenuSearchHeader(
                query: query,
                placeholder: .verbatim(String(localized: "Filter…", bundle: .module)),
                showsNoMatches: visible.isEmpty
            )
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, field in
                FilterMenuRow(.verbatim(field.title), isFocused: focusedIndex == index) {
                    onPick(field)
                } leading: {
                    Group {
                        if let icon = field.icon {
                            IconGlyph(name: icon, color: .secondary, size: Sizing.iconTiny)
                        }
                    }
                    .frame(width: Sizing.iconDefault)
                }
                .onHover { hovering in
                    if hovering { focusedIndex = index }
                }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: Sizing.menuMinWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct FilterOperatorMenu: View {
    @Binding var condition: FilterCondition
    let operators: [FilterOperator]
    @Binding var focusedIndex: Int?
    let onPick: (FilterOperator) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            ForEach(Array(operators.enumerated()), id: \.element) { index, candidate in
                let isCurrent = condition.operator == candidate
                FilterMenuRow(
                    .verbatim(candidate.title(valueCount: condition.values.count)),
                    isFocused: focusedIndex == index,
                    isSelected: isCurrent
                ) {
                    onPick(candidate)
                } trailing: {
                    FilterMenuCheckmark(isShown: isCurrent)
                }
                .onHover { hovering in
                    if hovering { focusedIndex = index }
                }
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: Sizing.menuMinWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct FilterValueMenu: View {
    @Binding var condition: FilterCondition
    let field: FilterField
    @Binding var query: String
    @Binding var pinned: [String]
    @Binding var focusedIndex: Int?
    let onPickText: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            if case .text(let placeholder) = field.kind {
                textRows(placeholder: placeholder)
            } else {
                optionRows
            }
        }
        .padding(Spacing.menuPadding)
        .frame(minWidth: Sizing.menuMinWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var optionRows: some View {
        let visible = FilterValueOrder.visible(field.options, pinned: pinned, query: query)
        let pinnedCount = visible.filter { pinned.contains($0.id) }.count
        FilterMenuSearchHeader(query: query, placeholder: .verbatim(field.title), showsNoMatches: visible.isEmpty)
        ForEach(Array(visible.enumerated()), id: \.element.id) { index, option in
            let isOn = condition.values.contains(option.id)
            FilterMenuRow(.verbatim(option.title), isFocused: focusedIndex == index, isSelected: isOn) {
                condition.toggleValue(option.id)
            } leading: {
                HStack(spacing: Spacing.sm) {
                    CheckboxGlyph(isOn: isOn)
                    if option.markName != nil {
                        FilterOptionMark(option: option, size: Sizing.iconSmall)
                    }
                }
            }
            .onHover { hovering in
                if hovering { focusedIndex = index }
            }
            if index == pinnedCount - 1, pinnedCount < visible.count {
                Divider().padding(.vertical, Spacing.hairline)
            }
        }
    }

    @ViewBuilder
    private func textRows(placeholder: String?) -> some View {
        FilterMenuSearchHeader(
            query: query,
            placeholder: .verbatim(placeholder ?? String(localized: "Type to match", bundle: .module))
        )
        if !query.isEmpty {
            FilterMenuRow(.verbatim(query), isFocused: focusedIndex == 0) {
                onPickText(query)
            } leading: {
                BlissSymbol("text.magnifyingglass")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: Sizing.iconDefault)
            }
            .onHover { hovering in
                if hovering { focusedIndex = 0 }
            }
        } else if let current = condition.values.first {
            FilterMenuRow(.verbatim(current), isFocused: false, isSelected: true) {
                onPickText(current)
            } trailing: {
                FilterMenuCheckmark(isShown: true)
            }
        }
    }
}

// MARK: - Pieces

/// The trailing check of a menu's current choice, laid out even while hidden
/// so the rows' titles don't shift.
private struct FilterMenuCheckmark: View {
    let isShown: Bool

    var body: some View {
        BlissSymbol("checkmark")
            .font(Typography.labelSmall)
            .foregroundStyle(.secondary)
            .opacity(isShown ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// An option's mark — its icon or color dot — drawn by `IconGlyph`, or
/// nothing for an option without one.
private struct FilterOptionMark: View {
    let option: FilterOption?
    var size: CGFloat = Sizing.iconTiny

    var body: some View {
        if let option, let name = option.markName {
            IconGlyph(name: name, color: option.color ?? .secondary, size: size)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Flush hover tint for a chip segment (no inset, no press scale), so a chip reads
/// as one control split into clickable parts. `FocusablePlainButtonStyle` draws
/// no hover, and its ring would sit on the chip's clipped edge.
private struct ChipSegmentButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        Group {
            ChipSegmentBody(configuration: configuration, isActive: isActive)
        }
        .interactiveCursor()
    }

    private struct ChipSegmentBody: View {
        let configuration: ButtonStyleConfiguration
        let isActive: Bool

        @Environment(\.colorScheme) private var scheme
        @State private var isHovering = false
        @FocusState private var isFocused: Bool

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .background(isHovering || isActive || configuration.isPressed ? RowTint.hover(scheme) : Color.clear)
                // Inset, so the chip's clip shape can't cut the band off.
                .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusSmall, padding: Spacing.hairline)
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .onHover { isHovering = $0 }
                .animation(Animations.hover, value: isHovering)
        }
    }
}

// MARK: - Preview

private struct FilterBarPreview: View {
    @State private var conditions = [
        FilterCondition(fieldID: "status", operator: .is, values: ["active"], isLocked: true),
        FilterCondition(fieldID: "label", operator: .is, values: ["design", "bug"]),
        FilterCondition(fieldID: "title", operator: .contains, values: ["onboarding"]),
    ]
    @State private var matchMode = FilterMatchMode.all

    private let fields = [
        FilterField(id: "status", title: "Status", icon: "circle.dashed", kind: .options([
            FilterOption(id: "active", title: "Active", color: Success.success500),
            FilterOption(id: "paused", title: "Paused", color: Grey.grey400),
        ])),
        FilterField(id: "label", title: "Label", icon: "tag", kind: .options([
            FilterOption(id: "design", title: "Design", icon: "paintpalette"),
            FilterOption(id: "bug", title: "Bug", icon: "ladybug"),
            FilterOption(id: "docs", title: "Docs", icon: "doc.text"),
        ])),
        FilterField(id: "title", title: "Title", icon: "textformat", kind: .text()),
    ]

    var body: some View {
        FilterBar(conditions: $conditions, fields: fields, matchMode: $matchMode)
            .padding(Spacing.lg)
    }
}

#Preview("Filter bar", traits: .fixedLayout(width: 560, height: 120)) {
    FilterBarPreview()
}
