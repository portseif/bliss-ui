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
///         Button { isSidebarCollapsed.toggle() } label: { BlissSymbol("sidebar.left") }
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
    /// Where AppKit's zoom button ends: the close, minimize and zoom buttons
    /// sit at 7 / 27 / 47 from the window's edge, 12pt each.
    private static var trafficLightsSpan: CGFloat { 59 }

    /// Room on the leading edge for the traffic lights, at their offset spot:
    /// `.blissWindowChrome()`'s offset, the buttons, and a `Spacing.lg` gap.
    public static var trafficLightClearance: CGFloat {
        TrafficLightOffset.defaultOffset.x + trafficLightsSpan + Spacing.lg
    }

    private let height: CGFloat
    private let insetsForTrafficLights: Bool
    private let showsDivider: Bool
    private let centerInset: CGFloat
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
    ///   - centerInset: Shifts the title's centering right by this much — pass
    ///     the sidebar's width to center it over the content pane.
    ///   - leading: Controls after the traffic lights (a sidebar toggle, Back).
    ///   - center: The title, centered in the window whatever the sides hold.
    ///   - trailing: Controls on the trailing edge (New, Search, a bell).
    public init(
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false,
        centerInset: CGFloat = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.height = height
        self.insetsForTrafficLights = insetsForTrafficLights
        self.showsDivider = showsDivider
        self.centerInset = centerInset
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
                // Centered over the content pane, right of a sidebar.
                .padding(.leading, max(centerInset - leadingInset, 0))
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

/// The text a `WindowTitleBar(title:subtitle:)` centers: the title over a
/// secondary line, like Mail's "Inbox" over "12 unread".
public struct WindowTitleBarTitle: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?

    public init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Typography.bodySmallSemibold)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

extension WindowTitleBar where Center == WindowTitleBarTitle {
    /// A title bar with a title (and a secondary line under it) between its
    /// controls, so apps don't restyle the `center` slot by hand.
    ///
    /// - Parameters:
    ///   - title: The window's title, looked up in your app's strings.
    ///   - subtitle: A secondary line under it ("12 unread").
    ///   - height: The bar's height.
    ///   - insetsForTrafficLights: Room for the traffic lights before `leading`.
    ///   - showsDivider: A hairline along the bottom edge.
    ///   - centerInset: Shifts the title's centering right (a sidebar's width).
    ///   - leading: Controls after the traffic lights.
    ///   - trailing: Controls on the trailing edge.
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false,
        centerInset: CGFloat = 0,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            height: height,
            insetsForTrafficLights: insetsForTrafficLights,
            showsDivider: showsDivider,
            centerInset: centerInset,
            leading: leading,
            center: { WindowTitleBarTitle(title, subtitle: subtitle) },
            trailing: trailing
        )
    }
}

extension WindowTitleBar where Leading == EmptyView, Center == WindowTitleBarTitle, Trailing == EmptyView {
    /// A title bar with only a title and a secondary line.
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        height: CGFloat = Sizing.titleBarHeight,
        insetsForTrafficLights: Bool = true,
        showsDivider: Bool = false
    ) {
        self.init(
            height: height,
            insetsForTrafficLights: insetsForTrafficLights,
            showsDivider: showsDivider,
            leading: { EmptyView() },
            center: { WindowTitleBarTitle(title, subtitle: subtitle) },
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("Window title bar", traits: .fixedLayout(width: 640, height: 120)) {
    VStack(spacing: Spacing.lg) {
        WindowTitleBar(showsDivider: true) {
            Button {} label: { BlissSymbol("sidebar.left") }
                .buttonStyle(ToolbarIconButtonStyle())
                .accessibilityLabel(Text("Toggle Sidebar"))
        } center: {
            Text("Inbox")
        } trailing: {
            Button {} label: { BlissSymbol("magnifyingglass") }
                .buttonStyle(ToolbarIconButtonStyle())
                .accessibilityLabel(Text("Search"))
            Button("New") {}
                .buttonStyle(OutlineButtonStyle(compact: true))
        }
        WindowTitleBar(title: "Inbox", subtitle: "12 unread")
    }
    .background(Color.appShell)
}
