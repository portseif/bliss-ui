import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the reorderable list, built
/// the way an app would build it.
@MainActor
@Suite struct ReorderableListAPITests {
    private struct Step: Identifiable {
        let id: Int
        let title: String
    }

    @Test func reorderableListIsReachable() {
        let steps = [Step(id: 1, title: "Build"), Step(id: 2, title: "Test"), Step(id: 3, title: "Deploy")]
        _ = ReorderableList(.constant(steps)) { step in Text(verbatim: step.title) }
        _ = ReorderableList(.constant(steps), gripPlacement: .trailing, divided: true) { step in
            Label(step.title, systemImage: "hammer")
        }
        let placements: [ReorderGripPlacement] = [.leading, .trailing]
        #expect(placements.count == 2)
    }
}
