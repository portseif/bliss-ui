import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the timeline and the person
/// row, built the way an app would build them.
@MainActor
@Suite struct TimelinePersonAPITests {
    private struct Event: Identifiable {
        let id: Int
        let title: String
        let date: Date
    }

    private struct LogLine {
        let key: String
        let message: String
    }

    @Test func timelineIsReachable() {
        let events = [
            Event(id: 1, title: "Deploy finished", date: .now),
            Event(id: 2, title: "Build started", date: .now.addingTimeInterval(-600)),
        ]
        _ = Timeline(events) { event in
            TimelineItem(mark: .icon("checkmark", Success.success500), time: Text(event.date, style: .relative)) {
                Text(verbatim: event.title)
            }
        }
        let lines = [LogLine(key: "a", message: "Started"), LogLine(key: "b", message: "Done")]
        _ = Timeline(lines, id: \.key) { line in
            TimelineItem(mark: .dot(.secondary)) {
                Text(verbatim: line.message)
            }
        }
        _ = Timeline(events) { event in
            TimelineItem {
                VStack(alignment: .leading) {
                    Text(verbatim: event.title)
                    Text("Details")
                }
            }
        }
        let marks: [TimelineMark] = [.dot(Warning.warning500), .icon("exclamationmark.triangle", Danger.danger500)]
        #expect(marks.count == 2)
    }

    @Test func personRowIsReachable() {
        _ = PersonRow(name: "Ada Lovelace")
        _ = PersonRow(name: "Ada Lovelace", detail: "ada@example.com", size: .large, status: .online)
        _ = PersonRow(name: "Grace Hopper", detail: "Reviewer", status: .away) {
            Badge("Owner").badgeSize(.small)
        }
        _ = PersonRow(name: "Alan Turing", size: .small) {
            Button("Invite") {}.buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }
}
