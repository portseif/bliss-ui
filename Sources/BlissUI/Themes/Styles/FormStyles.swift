//
//  FormStyles.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/21/25.
//

import AppKit
import SwiftUI

// MARK: - Focus Ring Modifier

/// An adaptive focus ring that matches the element's border radius
/// Use this modifier to add consistent focus indication to any focusable component
///
/// Usage:
/// ```swift
/// .focusRing(isFocused: isFocused, cornerRadius: Sizing.radiusMedium)
/// .focusRing(isFocused: isFocused, shape: .capsule)
/// ```
struct FocusRingModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat?
    let isCapsule: Bool
    let color: Color
    let lineWidth: CGFloat
    let padding: CGFloat
    /// Text inputs show their ring on a click too; everything else only after
    /// keyboard input (`FocusVisibilityService`).
    var showsOnPointerFocus = false

    @State private var controlID = UUID()
    /// A sheet disables the page under it without taking its focus away.
    @Environment(\.isEnabled) private var isEnabled

    private var ringIsVisible: Bool {
        isFocused && isEnabled && (showsOnPointerFocus || FocusVisibilityService.shared.showsFocusRings)
    }

    /// The theme's accent (`Color.accent`: the theme, a custom accent, or the
    /// system one) — the color macOS itself uses for keyboard focus, so a
    /// focused control reads the same as a focused field.
    private var ringColor: Color {
        if color != .clear {
            return color
        }
        return Color.accent
    }

    /// The translucent band just outside the solid ring — the halo web focus
    /// rings use, so focus reads as focus rather than as a thicker border.
    private let bandWidth: CGFloat = 2
    private let bandOpacity = 0.3

    func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .overlay {
                if ringIsVisible {
                    if isCapsule {
                        Capsule()
                            .strokeBorder(ringColor, lineWidth: lineWidth)
                            .padding(padding)
                        Capsule()
                            .strokeBorder(ringColor.opacity(bandOpacity), lineWidth: bandWidth)
                            .padding(padding - bandWidth)
                    } else {
                        // The solid ring sits on the element's edge (inset by
                        // `padding`) and the band hugs it from outside, each with
                        // a concentric radius so both curves track the corners.
                        let ringRadius = max(1, (cornerRadius ?? Sizing.radiusDefault) - padding)
                        RoundedRectangle(cornerRadius: ringRadius, style: .continuous)
                            .strokeBorder(ringColor, lineWidth: lineWidth)
                            .padding(padding)
                        RoundedRectangle(cornerRadius: ringRadius + bandWidth, style: .continuous)
                            .strokeBorder(ringColor.opacity(bandOpacity), lineWidth: bandWidth)
                            .padding(padding - bandWidth)
                    }
                }
            }
            // No animation: focus moves with Tab, and keyboard actions answer
            // at once.
            .onAppear {
                FocusVisibilityService.shared.startIfNeeded()
                noteFocus(isFocused)
            }
            .onChange(of: isFocused) { _, focused in noteFocus(focused) }
            // A sheet opening over a focused control disables it but leaves it
            // focused: unregistering keeps Return for the sheet's default action.
            .onChange(of: isEnabled) { _, _ in noteFocus(isFocused) }
            .onDisappear { noteFocus(false) }
    }

    /// Lets Return press this control while its ring shows. Text inputs keep
    /// Return for themselves, and a disabled control can't take it.
    private func noteFocus(_ focused: Bool) {
        guard !showsOnPointerFocus else { return }
        FocusVisibilityService.shared.noteFocus(focused && isEnabled, control: controlID)
    }
}

extension View {
    /// Adds an adaptive focus ring that matches the element's corner radius
    /// - Parameters:
    ///   - isFocused: Whether the element is currently focused
    ///   - cornerRadius: The corner radius to match (uses Sizing.radiusDefault by default)
    ///   - color: Custom ring color (uses accent color by default)
    ///   - lineWidth: The solid ring's width (default: 1); a 2pt translucent band sits outside it
    ///   - padding: Inset from the element's edge (default: 0)
    ///   - showsOnPointerFocus: Also show it when a click gave focus — for text
    ///     inputs. Other controls show it only after keyboard input.
    public func focusRing(
        isFocused: Bool,
        cornerRadius: CGFloat = Sizing.radiusDefault,
        color: Color = .clear,
        lineWidth: CGFloat = 1,
        padding: CGFloat = 0,
        showsOnPointerFocus: Bool = false
    ) -> some View {
        modifier(
            FocusRingModifier(
                isFocused: isFocused,
                cornerRadius: cornerRadius,
                isCapsule: false,
                color: color,
                lineWidth: lineWidth,
                padding: padding,
                showsOnPointerFocus: showsOnPointerFocus
            )
        )
    }

    /// Adds an adaptive focus ring with capsule shape
    /// - Parameters:
    ///   - isFocused: Whether the element is currently focused
    ///   - color: Custom ring color (uses accent color by default)
    ///   - lineWidth: The solid ring's width (default: 1); a 2pt translucent band sits outside it
    ///   - padding: Padding from element edge (negative expands outward, default: 0)
    ///   - showsOnPointerFocus: Also show it when a click gave focus — for text
    ///     inputs. Other controls show it only after keyboard input.
    public func focusRingCapsule(
        isFocused: Bool,
        color: Color = .clear,
        lineWidth: CGFloat = 1,
        padding: CGFloat = 0,
        showsOnPointerFocus: Bool = false
    ) -> some View {
        modifier(
            FocusRingModifier(
                isFocused: isFocused,
                cornerRadius: nil,
                isCapsule: true,
                color: color,
                lineWidth: lineWidth,
                padding: padding,
                showsOnPointerFocus: showsOnPointerFocus
            )
        )
    }
}

// MARK: - Flat Switch Toggle Style

/// BlissUI's switch, in place of the native `.switch` style: a Tab stop with
/// the shared focus ring that Space flips (the native one shows the system's
/// ring, and only when Keyboard navigation is on in System Settings). It
/// follows `.controlSize` like the native switch (`.mini` / `.small` /
/// regular). `.labelsHidden()` doesn't reach a custom style's label, so the
/// label is drawn only with `showsLabel: true`; VoiceOver hears it either way.
public struct FlatSwitchToggleStyle: ToggleStyle {
    var showsLabel = false

    /// - Parameter showsLabel: Draw the toggle's label beside the switch.
    ///   VoiceOver hears the label either way.
    public init(showsLabel: Bool = false) {
        self.showsLabel = showsLabel
    }

    public func makeBody(configuration: Configuration) -> some View {
        FlatSwitchToggle(configuration: configuration, showsLabel: showsLabel)
    }
}

private struct FlatSwitchToggle: View {
    let configuration: ToggleStyleConfiguration
    let showsLabel: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    /// Track width, track height and thumb size for the control size.
    private var metrics: (trackWidth: CGFloat, trackHeight: CGFloat, thumbSize: CGFloat) {
        switch controlSize {
        case .mini: return (26, 15, 11)
        case .small: return (32, 18, 14)
        default: return (38, 22, 18)
        }
    }

    private var trackColor: Color {
        if configuration.isOn {
            return Color.accent
        }
        return colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }

    private func flip() {
        guard isEnabled else { return }
        configuration.isOn.toggle()
    }

    var body: some View {
        let metrics = metrics
        HStack {
            if showsLabel {
                configuration.label
            }

            RoundedRectangle(cornerRadius: metrics.trackHeight / 2, style: .continuous)
                .fill(trackColor)
                .frame(width: metrics.trackWidth, height: metrics.trackHeight)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                        .frame(width: metrics.thumbSize, height: metrics.thumbSize)
                        .padding(2)
                }
                .opacity(isEnabled ? 1 : 0.45)
                .focusRing(isFocused: isFocused, cornerRadius: metrics.trackHeight / 2)
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                // Space, like every button (Return arrives as Space through
                // FocusVisibilityService while the ring shows). Key-down only:
                // a held key would flip it back and forth.
                .onKeyPress(.space, phases: .down) { _ in
                    flip()
                    return .handled
                }
                .animation(Animations.interactionReveal, value: configuration.isOn)
                .onTapGesture { flip() }
        }
        // VoiceOver and Voice Control get a real switch with the label.
        .accessibilityRepresentation {
            // The native style: inheriting `.flatSwitch` from the environment,
            // this Toggle would build another representation, and so on.
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }
}

extension ToggleStyle where Self == FlatSwitchToggleStyle {
    public static var flatSwitch: FlatSwitchToggleStyle { FlatSwitchToggleStyle() }
    public static func flatSwitch(showsLabel: Bool) -> FlatSwitchToggleStyle { FlatSwitchToggleStyle(showsLabel: showsLabel) }
}

// MARK: - Bottom Border Modifier

/// A view modifier that adds a bottom border line to a view
struct BottomBorderModifier: ViewModifier {
    var color: Color
    var height: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(color)
                    .frame(height: height)
            }
    }
}

extension View {
    /// Adds a bottom border to the view
    /// - Parameters:
    ///   - color: The color of the border (default: subtle gray)
    ///   - height: The thickness of the border (default: 1)
    public func bottomBorder(color: Color = Color.primary.opacity(0.1), height: CGFloat = 1) -> some View {
        modifier(BottomBorderModifier(color: color, height: height))
    }
}

// MARK: - Empty State Modifier

/// View modifier to show the canonical `EmptyState` view when a condition is
/// met. Used by the `.emptyState(isEmpty:icon:title:description:)`
/// convenience modifier below.
///
/// It renders the shared `EmptyState` (in `Components/Display/EmptyState.swift`)
/// rather than a look of its own, so every empty state reads the same.
struct EmptyStateModifier: ViewModifier {
    let isEmpty: Bool
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    func body(content: Content) -> some View {
        if isEmpty {
            EmptyState(icon: icon, title: title, subtitle: description)
        } else {
            content
        }
    }
}

extension View {
    /// Shows an empty state view when the condition is true
    /// - Parameters:
    ///   - isEmpty: Whether to show the empty state
    ///   - icon: SF Symbol name for the icon
    ///   - title: Title text
    ///   - description: Description text
    public func emptyState(isEmpty: Bool, icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        modifier(EmptyStateModifier(isEmpty: isEmpty, icon: icon, title: title, description: description))
    }
}

// MARK: - Settings Form Container

private struct SettingsFormPlainKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, `SettingsForm` drops its outer padding so its sections align
    /// flush with the host's own layout — for a host that provides the
    /// horizontal insets itself, like settings embedded in a larger page.
    /// Defaults to false, the padded form a Settings window wants.
    public var settingsFormPlain: Bool {
        get { self[SettingsFormPlainKey.self] }
        set { self[SettingsFormPlainKey.self] = newValue }
    }
}

/// A container that provides proper spacing for RoundedSection items
public struct SettingsForm<Content: View>: View {
    let content: Content
    @Environment(\.settingsFormPlain) private var isPlain

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            content
        }
        .padding(.all, isPlain ? 0 : nil)
    }
}

#Preview("Flat Switch Toggle", traits: .fixedLayout(width: 300, height: 180)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Toggle("Enable feature", isOn: .constant(true))
            .toggleStyle(.flatSwitch(showsLabel: true))
            .controlSize(.small)

        Toggle("Disable feature", isOn: .constant(false))
            .toggleStyle(.flatSwitch(showsLabel: true))
            .controlSize(.small)

        Toggle("Regular size", isOn: .constant(true))
            .toggleStyle(.flatSwitch)

        Toggle("Disabled", isOn: .constant(true))
            .toggleStyle(.flatSwitch)
            .controlSize(.small)
            .disabled(true)
    }
    .padding()
}

#Preview("Settings Form") {
    SettingsForm {
        RoundedSection("Window") {
            Toggle("Keep window on top", isOn: .constant(false))
            Toggle("Launch at login", isOn: .constant(true))
        }

        RoundedSection {
            Toggle("Show hidden files", isOn: .constant(false))
        } header: {
            HStack(spacing: 6) {
                Text("File Browser")
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .frame(width: 450, height: 300)
}

#Preview("Empty State View") {
    EmptyState(
        icon: "folder",
        title: "No Items",
        subtitle: "Add an item to get started"
    )
    .frame(width: 400, height: 300)
    .background(Color.windowBackground)
}

#Preview("Focus Ring", traits: .fixedLayout(width: 400, height: 300)) {
    // `showsOnPointerFocus`: a preview never gets the key press that turns
    // keyboard-only rings on.
    VStack(spacing: Spacing.xl) {
        Text("Focus Ring Examples")
            .font(Typography.headingMedium)

        HStack(spacing: Spacing.lg) {
            // Small radius
            RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                .fill(Color.accent.opacity(0.2))
                .frame(width: 60, height: 32)
                .focusRing(isFocused: true, cornerRadius: Sizing.radiusSmall, showsOnPointerFocus: true)

            // Medium radius (default)
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(Color.accent.opacity(0.2))
                .frame(width: 80, height: 36)
                .focusRing(isFocused: true, cornerRadius: Sizing.radiusMedium, showsOnPointerFocus: true)

            // Large radius
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.accent.opacity(0.2))
                .frame(width: 100, height: 44)
                .focusRing(isFocused: true, cornerRadius: Sizing.radiusLarge, showsOnPointerFocus: true)
        }

        HStack(spacing: Spacing.lg) {
            // Capsule
            Capsule()
                .fill(Color.accent.opacity(0.2))
                .frame(width: 80, height: 28)
                .focusRingCapsule(isFocused: true, showsOnPointerFocus: true)

            // Custom color (destructive)
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(Danger.tint.opacity(0.2))
                .frame(width: 80, height: 36)
                .focusRing(isFocused: true, cornerRadius: Sizing.radiusMedium, color: Danger.danger400.opacity(0.6), showsOnPointerFocus: true)
        }

        Text("Ring adapts to corner radius")
            .font(Typography.caption)
            .foregroundStyle(.secondary)
    }
    .padding(Spacing.xl)
}

// MARK: - Focus Clearing Modifier

/// A view modifier that clears keyboard focus when clicking anywhere in the window
/// Uses NSEvent local monitor to capture clicks in toolbar and all window areas
struct FocusClearingModifier: ViewModifier {
    @State private var eventMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                setupEventMonitor()
            }
            .onDisappear {
                removeEventMonitor()
            }
    }

    private func setupEventMonitor() {
        // Only set up once
        guard eventMonitor == nil else { return }

        // Monitor left mouse down events in the local (app) scope
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            // Check if click is on a focusable control - if not, clear focus
            // We let the event pass through regardless
            clearFocusIfNeeded(for: event)
            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func clearFocusIfNeeded(for event: NSEvent) {
        guard let window = event.window else { return }

        // Get the view under the click
        let locationInWindow = event.locationInWindow
        guard let contentView = window.contentView else { return }

        let hitView = contentView.hitTest(locationInWindow)

        // If the click is on empty space or non-focusable view, clear focus
        // We check if the hit view or its superview chain contains a focusable control
        if !isClickOnFocusableControl(hitView) {
            window.makeFirstResponder(nil)
        }
    }

    private func isClickOnFocusableControl(_ view: NSView?) -> Bool {
        var currentView = view

        while let view = currentView {
            // Check for common focusable control types
            if view is NSButton || view is NSTextField || view is NSTextView || view is NSSegmentedControl
                || view is NSSlider || view is NSSwitch || view is NSPopUpButton || view is NSComboBox
            {
                return true
            }

            // Check if the view accepts first responder
            if view.acceptsFirstResponder && view.canBecomeKeyView {
                return true
            }

            currentView = view.superview
        }

        return false
    }
}

extension View {
    /// Clears keyboard focus when clicking on non-focusable areas anywhere in the window
    /// Includes toolbar, sidebar, and all content areas
    public func clearFocusOnBackgroundTap() -> some View {
        modifier(FocusClearingModifier())
    }
}

#Preview("Empty State Modifier") {
    List {
        Text("Item 1")
        Text("Item 2")
    }
    .emptyState(
        isEmpty: true,
        icon: "magnifyingglass",
        title: "No Results",
        description: "Try a different search term"
    )
    .frame(width: 400, height: 300)
}
