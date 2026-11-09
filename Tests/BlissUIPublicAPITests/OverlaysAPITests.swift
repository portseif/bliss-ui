import AppKit
import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API. Nothing here opens a panel or a
/// window: menus and tooltips are only attached, never presented.
@MainActor
@Suite struct OverlaysAPITests {
    @Test func floatingMenuIsReachable() {
        _ = Text("x").floatingMenu(isPresented: .constant(false)) { Text("Menu") }
        _ = Text("x").floatingMenu(
            isPresented: .constant(false),
            itemCount: 3,
            focusedIndex: .constant(nil),
            xPosition: .trailing,
            yPosition: .below,
            menuGap: 4,
            xOffset: 2,
            yOffset: -2,
            onSelect: { _ in },
            onMoveRight: { false },
            onMoveLeft: { false },
            onTypeahead: { _ in },
            onActivate: { _ in .keepOpen }
        ) {
            Text("Menu")
        }

        let xPositions: [FloatingMenuXPosition] = [.leading, .center, .trailing, .afterTrailing]
        let yPositions: [FloatingMenuYPosition] = [.above, .below]
        let activations: [FloatingMenuActivation] = [.dismiss, .keepOpen]
        #expect(xPositions.count == 4 && yPositions.count == 2 && activations.count == 2)
        #expect(EnvironmentValues().floatingMenuActive == false)
    }

    @Test func tooltipIsReachable() {
        _ = Text("x").tooltip("Hint", position: .below)
        _ = Text("x").tooltip("Hint", position: .leading, maxWidth: 180)
        _ = Text("x").tooltip(configuration: .compact, position: .trailing) { Text("Custom") }
        _ = Text("x").interactiveTooltip(configuration: .wide) { Button("Act") {} }
        _ = Text("x").tooltip("token-1234", actions: [.copy("token-1234")])
        _ = Text("x").tooltipsDisabled()
        #expect(EnvironmentValues().tooltipsDisabled == false)

        let configuration = TooltipConfiguration(maxWidth: 300, maxHeight: 120, interactive: true)
        #expect(configuration.maxWidth == 300)
        #expect(configuration.interactive)
        #expect(TooltipConfiguration.default.horizontalPadding == 10)
        #expect(TooltipConfiguration.iconHint.maxHeight == 44)

        let action = TooltipAction(icon: "star", label: "Favorite", confirmation: "Saved") {}
        #expect(action.label == "Favorite")
        #expect(TooltipAction.copy("value").confirmation != nil)
    }

    @Test func scrollViewsAreReachable() {
        _ = ScrollViewWithThinIndicator { Text("Row") }
        _ = ScrollViewWithThinIndicator(
            .vertical,
            showFadeMask: true,
            fillsViewport: true,
            indicatorTopPadding: 0,
            indicatorBottomPadding: 0
        ) {
            Text("Row")
        }
        _ = AutoHeightScroll { Text("Row") }
        _ = AutoHeightScroll(
            showFadeMask: true,
            maxHeight: 200,
            indicatorTopPadding: 4,
            indicatorBottomPadding: 4,
            hugsWidth: true,
            resizeAnimation: .default
        ) {
            Text("Row")
        }
    }

    @Test func progressOverlayIsReachable() {
        _ = ProgressOverlay(title: "Importing", subtitle: "Library", currentItem: "a.jpg")
        let counter = ProgressOverlay.Counter(systemImage: "photo", value: 2, highlightsWhenNonzero: true)
        let item = ProgressOverlay.ActiveItem(name: "Shared", detail: "Family")
        _ = ProgressOverlay(
            title: "Importing",
            subtitle: "Library",
            systemImage: "photo.stack",
            currentItem: "a.jpg",
            counters: [counter],
            activeItems: [item],
            activeItemsTitle: "Following 1 linked folder...",
            activeItemsSystemImage: "link"
        )
        #expect(counter.value == 2)
    }

    @Test func toastDataIsReachable() {
        let failure = ToastFailure(path: "a/b.txt", code: "EACCES", message: "Permission denied")
        let segment = ToastSegment("3 items", isProminent: true)
        let action = ToastAction(label: "Retry", icon: "arrow.clockwise") {}
        let detail = ToastDetailItem(id: "one", name: "First", state: .working, text: "starting")

        let error = ToastData.error(
            title: "Upload failed",
            message: "",
            segments: [segment],
            failures: [failure],
            totalItems: 10,
            failedAt: Date(),
            actions: [action]
        )
        #expect(error.style == .error)
        #expect(error.hasDetails)
        #expect(error.actions == [action])

        let progress = ToastData(
            title: "Uploading",
            message: "Uploading photos...",
            style: .progress(0.5),
            startedAt: Date(),
            detailItems: [detail],
            primaryAction: {}
        )
        #expect(progress.style.isOngoing)
        #expect(progress.style.progressValue == 0.5)
        #expect(progress.detailItems.first?.state == .working)

        _ = ToastData.success(title: "Done", message: "Saved", icon: "checkmark")
        _ = ToastData.warning(title: "Imported", message: "3 rows skipped", failures: [failure])
        _ = ToastData.info(title: "Update available", message: "2.4.0")
        _ = ToastData.inProgress(title: "Preparing", message: "Indexing...")
        _ = ToastData.progress(title: "Exporting", message: "Writing...", progress: 0.2)
        _ = ToastStyle.warning.icon
        _ = ToastStyle.success.glyph
        _ = ToastStyle.info.iconColor
        #expect(ToastStyle.inProgress.isInProgress)
    }

    @Test func toastViewsAndModifiersAreReachable() {
        _ = Color.clear.globalToast()
        _ = Color.clear.toast(.constant(nil), autoDismissDelay: 2)
        _ = Color.clear.toastsRestAbove()
        _ = ToastNotification(toast: .success(title: "Done", message: ""), onDismiss: {}, onCancel: nil)
    }

    @Test func toastServiceStacksAndCancels() {
        // `show` posts a VoiceOver announcement through `NSApp`.
        _ = NSApplication.shared
        let service = ToastService.shared
        let toast = ToastData.error(title: "Failed", message: "Network timeout")
        defer { service.dismiss(id: toast.id) }

        service.show(toast)
        #expect(service.toasts.first?.id == toast.id)
        #expect(ToastService.maxToasts == 5)

        var cancelled = false
        service.registerCancel(for: toast.id) { cancelled = true }
        #expect(service.isCancellable(toast.id))
        service.cancel(toast.id)
        #expect(cancelled)
        #expect(!service.isCancellable(toast.id))

        service.dismiss(id: toast.id)
        #expect(!service.toasts.contains { $0.id == toast.id })

        // Reachable, not run: each would schedule or show more.
        let shows: [() -> Void] = [
            { service.showSuccess(title: "Saved", message: "") },
            { service.showError(title: "Failed", message: "", fullMessage: "Details") },
            { service.showInfo(title: "Note", message: "") },
            { service.showProgress(title: "Uploading", message: "", progress: 0.3) },
            { service.clearCancel(for: toast.id) },
        ]
        #expect(shows.count == 5)
    }

    @Test func popupMenuServiceIsReachable() {
        let service = PopupMenuService.shared
        // Nothing is open, so this is a no-op.
        service.hide()
        // Reachable, not run: `show` opens a panel.
        let open: () -> Void = {
            service.show(at: .zero) { Text("Item") }
            service.highlightFirstRowForKeyboard()
        }
        _ = open
    }

    @Test func contextMenuIsReachable() {
        _ = Text("Row").blissContextMenu {
            QuickActionMenuItem(title: "Rename", icon: "pencil") {}
            MenuDivider()
            QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true) {}
        }
        _ = MenuDivider()
    }
}
