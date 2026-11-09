//
//  WindowTitleBar.swift
//  BlissUI
//
//  The custom title bar of a `.hiddenTitleBar` window: leading controls that
//  clear the traffic lights, a centered title, trailing controls, and the
//  empty space drags the window. Pair it with `.blissWindowChrome()`, which
//  moves the traffic lights to sit centered in its `Sizing.titleBarHeight`.
//
//  Full screen hides the traffic lights (they live in the toolbar overlay
//  there), so the leading clearance goes with them.
//

import AppKit
import SwiftUI

/// A custom title bar for a hidden-title-bar window.
///
/// ```swift
/// VStack(spacing: 0) {
///     WindowTitleBar {
///         Button { isSidebarCollapsed.toggle() } label: { Image(systemName: "sidebar.left") }
///             .buttonStyle(ToolbarIconButtonStyle())
///     } center: {
///         Text("Inbox")
///     } trailing: {
///         Button("New") {}.buttonStyle(OutlineButtonStyle(compact: true))
///     }
///     content
/// }
/// ```
///
/// Controls in the leading and trailing slots don't drag the window; the rest
/// of the bar does. It has no background of its own: it sits on the window's
/// shell (`Color.appShell`).
public struct WindowTitleBar<Leading: View, Center: View, Trailing: View>: View {
    /// Room on the leading edge for the traffic lights, at their offset spot.
    public static var trafficLightClearance: CGFloat { 78 }

    private let height: CGFloat
    private let insetsForTrafficLights: Bool
    private let showsDivider: Bool
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    @State private var isFullScreen = false

    /// - Parameters:
    ///   - height: The bar's height; `Sizing.titleBarHeight` matches
    ///     `.blissWindowChrome()`'s traffic-light offset.
    ///   - insetsForTrafficLights: Leaves room for the traffic lights before the
    ///     leading controls (not in full screen, where there are none).
    ///   - showsDivider: A hairline along the bottom edge.
    ///   - leading: Controls after the traffic lights (a sidebar toggle, Back).
    ///   - center: The title, centered in the window whatever the sides hold.
    ///   - trailing: Controls on the trailing edge (New, Search, a bell).
    public init(
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.height = height
        self.insetsForTrafficLights = insetsForTrafficLights
        self.showsDivider = showsDivider
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    private var leadingInset: CGFloat {
        insetsForTrafficLights && !isFullScreen ? Self.trafficLightClearance : Spacing.md
    }

    public var body: some View {
        ZStack {
            // The empty bar drags the window; the controls on it don't.
            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())

            HStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) { leading }
                    .windowDragDisabled()
                Spacer(minLength: 0)
                HStack(spacing: Spacing.xs) { trailing }
                    .windowDragDisabled()
            }

            center
                .font(Typography.bodySmallSemibold)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, Spacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(Color.menuBorder)
                    .frame(height: 1)
            }
        }
        .animation(Animations.pane, value: isFullScreen)
        .onWindow { window in
            isFullScreen = window.styleMask.contains(.fullScreen)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .accessibilityElement(children: .contain)
    }
}

extension WindowTitleBar where Center == EmptyView {
    /// A title bar with controls on both sides and no title.
    public init(
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(height: height, insetsForTrafficLights: insetsForTrafficLights, showsDivider: showsDivider, leading: leading, center: { EmptyView() }, trailing: trailing)
    }
}

extension WindowTitleBar where Leading == EmptyView, Trailing == EmptyView {
    /// A title bar with only a centered title.
    public init(
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false,
        @ViewBuilder center: () -> Center
    ) {
        self.init(height: height, insetsForTrafficLights: insetsForTrafficLights, showsDivider: showsDivider, leading: { EmptyView() }, center: center, trailing: { EmptyView() })
    }
}

// MARK: - Preview

#Preview("Window title bar", traits: .fixedLayout(width: 640, height: 120)) {
    VStack(spacing: Spacing.lg) {
        WindowTitleBar(showsDivider: true) {
            Button {} label: { Image(systemName: "sidebar.left") }
                .buttonStyle(ToolbarIconButtonStyle())
                .accessibilityLabel(Text("Toggle Sidebar"))
        } center: {
            Text("Inbox")
        } trailing: {
            Button {} label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(ToolbarIconButtonStyle())
                .accessibilityLabel(Text("Search"))
            Button("New") {}
                .buttonStyle(OutlineButtonStyle(compact: true))
        }
        WindowTitleBar {
            Text("Settings")
        }
    }
    .background(Color.appShell)
}
