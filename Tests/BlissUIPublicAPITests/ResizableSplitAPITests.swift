import CoreGraphics
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the resizable split, built the
/// way an app would build it.
@MainActor
@Suite struct ResizableSplitAPITests {
    @Test func resizableSplitIsReachable() {
        _ = ResizableSplit(width: .constant(240)) {
            Text("Sidebar")
        } trailing: {
            Text("Content")
        }
        _ = ResizableSplit(width: .constant(280), in: 200...400, resizes: .trailing, persistenceKey: "test.inspectorWidth") {
            Text("Content")
        } trailing: {
            Text("Inspector")
        }
        _ = ResizableSplit(width: .constant(CGFloat(Sizing.sidebarDefaultWidth)), in: Sizing.sidebarMinWidth...Sizing.sidebarMaxWidth, resizes: .leading) {
            Color.clear
        } trailing: {
            Color.clear
        }
    }
}
