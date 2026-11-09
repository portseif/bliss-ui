import SwiftUI
import Testing
import UniformTypeIdentifiers
import BlissUI

/// Compiles only against BlissUI's public API: the drop zone, built the way an
/// app would build it.
@MainActor
@Suite struct DropZoneAPITests {
    @Test func dropZoneIsReachable() {
        _ = DropZone("Drop files here") { _ in }
        _ = DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", systemImage: "photo.on.rectangle", allowedContentTypes: [.png, .jpeg]) { urls in
            _ = urls.count
        }
        _ = DropZone("Drop a folder here", allowsMultiple: false, canChooseDirectories: true, allowsBrowsing: false) { _ in }
        _ = DropZone("Drop a CSV", hint: "One file", systemImage: "tablecells", allowedContentTypes: [.commaSeparatedText], allowsMultiple: false, canChooseDirectories: false, allowsBrowsing: true) { _ in }
            .frame(maxWidth: 480)
    }
}
