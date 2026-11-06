//
//  DividedForEach.swift
//  BlissUI
//
//  A `ForEach` that puts a divider between each pair of rows and none after
//  the last — the shape of every flat list (settings rows, installed tools,
//  build steps…). The rows stack flush (no spacing around the
//  dividers). The divider defaults to a plain `Divider()`; pass `separator:`
//  for an inset or faded one.
//

import SwiftUI

public struct DividedForEach<Data: RandomAccessCollection, ID: Hashable, Row: View, Separator: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let row: (Data.Element) -> Row
    private let separator: () -> Separator

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder row: @escaping (Data.Element) -> Row,
        @ViewBuilder separator: @escaping () -> Separator
    ) {
        self.data = data
        self.id = id
        self.row = row
        self.separator = separator
    }

    public var body: some View {
        let lastID = data.last.map { $0[keyPath: id] }
        // Its own zero-spacing stack: rows sit flush against the dividers, however
        // the list's container spaces its other children (a header, a button).
        VStack(alignment: .leading, spacing: 0) {
            ForEach(data, id: id) { element in
                row(element)
                if element[keyPath: id] != lastID {
                    separator()
                }
            }
        }
    }
}

extension DividedForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(
        _ data: Data,
        @ViewBuilder row: @escaping (Data.Element) -> Row,
        @ViewBuilder separator: @escaping () -> Separator
    ) {
        self.init(data, id: \.id, row: row, separator: separator)
    }
}

extension DividedForEach where Separator == Divider {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.init(data, id: id, row: row, separator: { Divider() })
    }
}

extension DividedForEach where Data.Element: Identifiable, ID == Data.Element.ID, Separator == Divider {
    public init(_ data: Data, @ViewBuilder row: @escaping (Data.Element) -> Row) {
        self.init(data, id: \.id, row: row, separator: { Divider() })
    }
}

// MARK: - Preview

#Preview("Divided rows", traits: .fixedLayout(width: 320, height: 220)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        VStack(alignment: .leading, spacing: 0) {
            DividedForEach(["Inbox", "Drafts", "Archive"], id: \.self) { title in
                Text(verbatim: title).padding(.vertical, Spacing.sm)
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            DividedForEach(["Inbox", "Drafts", "Archive"], id: \.self) { title in
                Text(verbatim: title).padding(.vertical, Spacing.sm)
            } separator: {
                Divider().padding(.leading, Spacing.xl)
            }
        }
    }
    .padding(Spacing.lg)
}
