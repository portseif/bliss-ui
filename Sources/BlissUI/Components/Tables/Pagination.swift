//
//  Pagination.swift
//  BlissUI
//
//  Page controls for a table or a list that's cut into pages: previous, the
//  page numbers, next. The first and last page always show, with the current
//  page and its neighbors between them and an ellipsis where pages are
//  skipped — unless the ellipsis would hide a single page, which shows instead.
//  Every control is one of the secondary icon buttons, so the row reads like
//  a toolbar; the current page is the filled one.
//

import SwiftUI

/// Page controls bound to a 1-based page number.
///
/// ```swift
/// Pagination(page: $page, pageCount: 12)
/// ```
///
/// Renders nothing for a single page. `page` is clamped into
/// `1...pageCount` when the control appears and whenever `pageCount` changes.
public struct Pagination: View {
    @Binding private var page: Int
    private let pageCount: Int
    private let siblingCount: Int

    /// - Parameters:
    ///   - page: The current page, 1-based.
    ///   - pageCount: How many pages there are.
    ///   - siblingCount: Pages shown on each side of the current one.
    public init(page: Binding<Int>, pageCount: Int, siblingCount: Int = 1) {
        self._page = page
        self.pageCount = pageCount
        self.siblingCount = max(siblingCount, 0)
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

    public var body: some View {
        if pageCount > 1 {
            HStack(spacing: Spacing.xxs) {
                arrowButton(systemImage: "chevron.left", label: Text("Previous page", bundle: .module), isEnabled: page > 1) {
                    page -= 1
                }
                ForEach(slots, id: \.self) { slot in
                    slotView(slot)
                }
                arrowButton(systemImage: "chevron.right", label: Text("Next page", bundle: .module), isEnabled: page < pageCount) {
                    page += 1
                }
            }
            .accessibilityElement(children: .contain)
            .onAppear(perform: clampPage)
            .onChange(of: pageCount) { _, _ in clampPage() }
        }
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

#Preview("Pagination", traits: .fixedLayout(width: 480, height: 160)) {
    @Previewable @State var page = 6
    @Previewable @State var shortPage = 2
    VStack(spacing: Spacing.lg) {
        Pagination(page: $page, pageCount: 24)
        Pagination(page: $shortPage, pageCount: 5)
        Pagination(page: .constant(1), pageCount: 9, siblingCount: 2)
    }
    .padding(Spacing.xl)
}
