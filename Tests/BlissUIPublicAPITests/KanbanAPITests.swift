import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the kanban board, built the
/// way an app would build it.
@MainActor
@Suite struct KanbanAPITests {
    private struct Task: Identifiable {
        let id: Int
        let title: String
    }

    private var columns: [KanbanColumn<Task>] {
        [
            KanbanColumn(id: "todo", title: "To do", cards: [Task(id: 1, title: "Write notes"), Task(id: 2, title: "Audit rings")], color: Grey.grey500),
            KanbanColumn(id: "doing", title: "In progress", cards: [Task(id: 3, title: "Ship the theme")], color: Warning.warning500),
            KanbanColumn(id: "done", title: "Done", cards: []),
        ]
    }

    @Test func columnsAreDataAnAppCanSupply() {
        var column = KanbanColumn(id: "todo", title: "To do", cards: [Task(id: 1, title: "Write notes")])
        #expect(column.id == "todo")
        #expect(column.color == nil)
        column.cards.append(Task(id: 2, title: "Audit rings"))
        column.title = "Backlog"
        #expect(column.cards.count == 2)
        #expect(column.title == "Backlog")
    }

    @Test func kanbanBoardIsReachable() {
        _ = KanbanBoard(columns: .constant(columns)) { task in
            Text(verbatim: task.title)
        }
        _ = KanbanBoard(columns: .constant(columns), columnWidth: 300, onMove: { task, from, to in
            _ = (task.id, from, to)
        }) { task in
            Text(verbatim: task.title)
        } columnFooter: { column in
            Button("Add to \(column.title)") {}
                .buttonStyle(GhostButtonStyle(compact: true))
        }
    }
}
