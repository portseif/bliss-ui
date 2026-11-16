import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the stat card and the rating,
/// built the way an app would build them.
@MainActor
@Suite struct StatRatingAPITests {
    @Test func statCardIsReachable() {
        _ = StatCard("Active users", value: "1,284")
        _ = StatCard("Active users", value: "1,284", change: StatChange("12%", direction: .up), detail: "vs last week", systemImage: "person.2", sparkline: [12, 14, 13, 17])
        _ = StatCard("Error rate", value: "0.4%", change: StatChange("0.1 pt", direction: .down, isPositive: false))
        let flat = StatChange("0", direction: .flat)
        #expect(flat.text == "0")
        #expect(flat.direction == .flat)
        #expect(flat.isPositive)
    }

    @Test func ratingIsReachable() {
        _ = Rating("Quality", value: .constant(3))
        _ = Rating("Priority", value: .constant(2), maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
        _ = Rating("Average", value: .constant(4)).disabled(true)
    }
}
