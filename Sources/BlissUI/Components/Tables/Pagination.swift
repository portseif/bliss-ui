//
//  Pagination.swift
//  BlissUI
//
//  Page controls for a table or a list that's cut into pages: previous, the
//  page numbers, next. The first and last page always show, with the current
//  page and its neighbors between them and an ellipsis where pages are
//  skipped — unless the ellipsis would hide a single page, which shows instead.
//  Every control is one of the secondary icon buttons, so the row reads like
//  a toolbar; the current page is the filled one. A data table's footer can
//  add the item range ("1–25 of 312") on the left and a page-size picker on
//  the right.
//

import SwiftUI

/// Page controls bound to a 1-based page number.
///
/// ```swift
/// Pagination(page: $page, pageCount: 12)
/// Pagination(page: $page, pageCount: 13, totalItems: 312, pageSize: $pageSize)
/// ```
///
/// Renders nothing for a single page unless it has a range or a page-size
/// picker to show. `page` is clamped into `1...pageCount` when the control
/// appears and whenever `pageCount` changes.
public struct Pagination: View {
    @Binding private var page: Int
    private let pageCount: Int
    private let siblingCount: Int
    private let totalItems: Int?
    private let pageSize: Binding<Int>?
    private let pageSizeOptions: [Int]
    private let showsFirstLast: Bool

    /// - Parameters:
    ///   - page: The current page, 1-based.
    ///   - pageCount: How many pages there are.
    ///   - siblingCount: Pages shown on each side of the current one.
    ///   - totalItems: How many items the pages hold; shows "1–25 of 312" leading.
    ///   - pageSize: Items per page, bound to a trailing picker over `pageSizeOptions`.
    ///   - pageSizeOptions: The picker's choices.
    ///   - showsFirstLast: Jump-to-first and jump-to-last buttons outside the arrows.
    public init(
        page: Binding<Int>,
        pageCount: Int,
        siblingCount: Int = 1,
        totalItems: Int? = nil,
        pageSize: Binding<Int>? = nil,
        pageSizeOptions: [Int] = [25, 50, 100],
        showsFirstLast: Bool = false
    ) {
        self._page = page
        self.pageCount = pageCount
        self.siblingCount = max(siblingCount, 0)
        self.totalItems = totalItems
        self.pageSize = pageSize
        self.pageSizeOptions = pageSizeOptions
        self.showsFirstLast = showsFirstLast
    }

    // MARK: Slots

    /// One spot in the row: a page, or the ellipsis standing in for a run.
    private enum Slot: Hashable {
        case page(Int)
        /// Identified by the run's first page so two ellipses stay distinct.
        case ellipsis(after: Int)
    }

    /// The row's slots: first, the window around the current page, last, with
    /// an ellipsis for each skipped run — or the page itself when the run is
    /// only one page long.
    private var slots: [Slot] {
        guard pageCount > 1 else { return [] }
        let current = min(max(page, 1), pageCount)
        let windowStart = max(current - siblingCount, 1)
        let windowEnd = min(current + siblingCount, pageCount)

        var slots: [Slot] = []
        if windowStart > 1 {
            slots.append(.page(1))
            Self.appendGap(from: 2, to: windowStart - 1, into: &slots)
        }
        for number in windowStart...windowEnd {
            slots.append(.page(number))
        }
        if windowEnd < pageCount {
            Self.appendGap(from: windowEnd + 1, to: pageCount - 1, into: &slots)
            slots.append(.page(pageCount))
        }
        return slots
    }

    /// A skipped run of pages: nothing when empty, the page when it's one,
    /// an ellipsis when it's more.
    private static func appendGap(from first: Int, to last: Int, into slots: inout [Slot]) {
        guard first <= last else { return }
        if first == last {
            slots.append(.page(first))
        } else {
            slots.append(.ellipsis(after: first))
        }
    }

    // MARK: Body

    private var hasFooterExtras: Bool {
        totalItems != nil || pageSize != nil
    }

    public var body: some View {
        if pageCount > 1 || hasFooterExtras {
            HStack(spacing: Spacing.md) {
                if let rangeLabel {
                    rangeLabel
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if hasFooterExtras { Spacer(minLength: 0) }
                if pageCount > 1 {
                    pageControls
                }
                if hasFooterExtras { Spacer(minLength: 0) }
                if let pageSize {
                    pageSizePicker(pageSize)
                }
            }
            .onAppear(perform: clampPage)
            .onChange(of: pageCount) { _, _ in clampPage() }
        }
    }

    private var pageControls: some View {
        HStack(spacing: Spacing.xxs) {
            if showsFirstLast {
                arrowButton(systemImage: "chevron.left.2", label: Text("First page", bundle: .module), isEnabled: page > 1) {
                    page = 1
                }
            }
            arrowButton(systemImage: "chevron.left", label: Text("Previous page", bundle: .module), isEnabled: page > 1) {
                page -= 1
            }
            ForEach(slots, id: \.self) { slot in
                slotView(slot)
            }
            arrowButton(systemImage: "chevron.right", label: Text("Next page", bundle: .module), isEnabled: page < pageCount) {
                page += 1
            }
            if showsFirstLast {
                arrowButton(systemImage: "chevron.right.2", label: Text("Last page", bundle: .module), isEnabled: page < pageCount) {
                    page = pageCount
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// "1–25 of 312": the page's first and last item. The page size comes
    /// from the binding, else from the total spread over the pages.
    private var rangeLabel: Text? {
        guard let totalItems else { return nil }
        let size = pageSize?.wrappedValue ?? Int((Double(totalItems) / Double(max(pageCount, 1))).rounded(.up))
        guard size > 0, totalItems > 0 else { return Text("\(0)–\(0) of \(totalItems)", bundle: .module) }
        let current = min(max(page, 1), max(pageCount, 1))
        let first = (current - 1) * size + 1
        let last = min(current * size, totalItems)
        return Text("\(first)–\(last) of \(totalItems)", bundle: .module)
    }

    private func pageSizePicker(_ pageSize: Binding<Int>) -> some View {
        FloatingMenuPicker(
            String(localized: "Per page", bundle: .module),
            selection: Binding(
                get: { Self.pageSizeTitle(pageSize.wrappedValue) },
                set: { title in
                    if let picked = pageSizeOptions.first(where: { Self.pageSizeTitle($0) == title }) {
                        pageSize.wrappedValue = picked
                    }
                }
            ),
            options: pageSizeOptions,
            optionTitle: Self.pageSizeTitle,
            showsTitle: false
        )
    }

    private static func pageSizeTitle(_ size: Int) -> String {
        String(localized: "\(size) per page", bundle: .module)
    }

    @ViewBuilder
    private func slotView(_ slot: Slot) -> some View {
        switch slot {
        case .page(let number):
            pageButton(number)
        case .ellipsis:
            Text(verbatim: "…")
                .font(Typography.labelMedium)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.controlDefault, height: Sizing.controlDefault)
                .accessibilityHidden(true)
        }
    }

    private func pageButton(_ number: Int) -> some View {
        let isCurrent = number == page
        return Button {
            page = number
        } label: {
            Text(verbatim: "\(number)")
                .font(Typography.labelMedium.monospacedDigit())
        }
        .buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: true, accent: isCurrent))
        .accessibilityLabel(Text("Page \(number)", bundle: .module))
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    private func arrowButton(systemImage: String, label: Text, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Typography.labelMedium)
        }
        .buttonStyle(SecondaryButtonStyle(compact: true, iconOnly: true))
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func clampPage() {
        let clamped = min(max(page, 1), max(pageCount, 1))
        if clamped != page { page = clamped }
    }
}

// MARK: - Preview

#Preview("Pagination", traits: .fixedLayout(width: 560, height: 200)) {
    @Previewable @State var page = 6
    @Previewable @State var shortPage = 2
    @Previewable @State var pageSize = 25
    VStack(spacing: Spacing.lg) {
        Pagination(page: $page, pageCount: 24)
        Pagination(page: $shortPage, pageCount: 5, showsFirstLast: true)
        Pagination(page: .constant(1), pageCount: 9, siblingCount: 2)
        Pagination(page: $page, pageCount: 13, totalItems: 312, pageSize: $pageSize)
    }
    .padding(Spacing.xl)
}
