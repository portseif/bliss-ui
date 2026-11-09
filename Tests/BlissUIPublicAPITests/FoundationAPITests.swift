import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API.
@MainActor
@Suite struct FoundationAPITests {
    @Test func themesAreReachable() {
        #expect(BlissTheme.builtIn.map(\.id) == ["system", "high-contrast", "color-blind-safe", "low-glare"])
        #expect(BlissTheme.system.isSystem)
        #expect(BlissTheme.highContrast.minimumStatusContrast == 7)
        _ = ThemeRGB(0xFF0000).color
        _ = Text("Hi").blissTheme()
    }

    @Test func tokensAreReachable() {
        _ = Spacing.md
        _ = Sizing.radiusMedium
        _ = Typography.bodySmall
        _ = Animations.hover
        _ = Color.accent
        _ = Success.success500
    }

    @Test func windowModifiersAreReachable() {
        _ = Color.clear
            .blissWindowChrome()
            .trafficLightOffset(CGPoint(x: 4, y: -8))
            .persistsWindowFrame(key: "test.frame")
            .windowDragDisabled()
            .borderlessCardWindow(isActive: false)
            .onWindow { _ in }
    }

    @Test func windowTitleBarIsReachable() {
        _ = WindowTitleBar { Button("Back") {} } center: { Text("Inbox") } trailing: { Button("New") {} }
        _ = WindowTitleBar(height: 52, insetsForTrafficLights: false, showsDivider: true) { Text("Settings") }
        _ = WindowTitleBar { EmptyView() } trailing: { Button("New") {} }
        #expect(WindowTitleBar<EmptyView, Text, EmptyView>.trafficLightClearance > 0)
        #expect(Sizing.titleBarHeight == 44)
        #expect(Sizing.sidebarCollapsedWidth > 0)
    }
}
