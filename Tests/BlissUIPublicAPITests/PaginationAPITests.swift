import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the page controls and the
/// labeled divider, built the way an app would build them.
@MainActor
@Suite struct PaginationAPITests {
    @Test func paginationIsReachable() {
        _ = Pagination(page: .constant(1), pageCount: 12)
        _ = Pagination(page: .constant(6), pageCount: 24, siblingCount: 2)
        _ = Pagination(page: .constant(1), pageCount: 1)
        _ = Pagination(page: .constant(3), pageCount: 0)
    }

    @Test func labeledDividerIsReachable() {
        _ = LabeledDivider("or")
        _ = LabeledDivider("Yesterday", alignment: .leading)
        _ = LabeledDivider(alignment: .trailing) { Text("3 more") }
        _ = LabeledDivider { TimeAgoLabel(date: .now) }
    }
}
