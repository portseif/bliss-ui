import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the multi-select picker, built
/// the way an app would build it.
@MainActor
@Suite struct MultiSelectAPITests {
    private enum Team: String, CaseIterable, Hashable {
        case design, engineering, marketing
    }

    @Test func multiSelectPickerIsReachable() {
        _ = MultiSelectPicker("Teams", selection: .constant([Team.design]), options: Team.allCases, optionTitle: \.rawValue)
        _ = MultiSelectPicker(
            "Teams",
            selection: .constant(Set(Team.allCases)),
            options: Team.allCases,
            optionTitle: { $0.rawValue.capitalized },
            optionIcon: { _ in "person.2" },
            placeholder: "Any team",
            showsTitle: false,
            maximumChips: 2
        )
        _ = MultiSelectPicker("Regions", selection: .constant(Set<String>()), options: ["Europe", "Americas"], optionTitle: { $0 })
    }
}
