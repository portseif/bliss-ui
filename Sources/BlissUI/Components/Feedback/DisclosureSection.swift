//
//  DisclosureSection.swift
//  BlissUI
//
//  An accordion section, in place of the native `DisclosureGroup`: a header
//  row with a chevron that turns as it opens, and content that fades in below
//  it. The header is a Tab stop with the shared ring; Space or Return toggles
//  it, → opens it and ← closes it.
//

import SwiftUI

/// A section that opens and closes under its header.
///
/// ```swift
/// DisclosureSection("Advanced") {
///     SettingsToggleRow("Verbose logging", isOn: $verbose)
/// }
/// ```
///
/// Pass `isExpanded` to own the state (to open it from elsewhere, or remember
/// it); otherwise the section keeps it, starting from `initiallyExpanded`. The
/// content is only built while open, and lines up with the header's title.
public struct DisclosureSection<Label: View, Content: View>: View {
    private let externalIsExpanded: Binding<Bool>?
    private let label: Label
    private let content: () -> Content

    @State private var internalIsExpanded: Bool
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private let chevronWidth: CGFloat = Sizing.iconTiny

    /// - Parameters:
    ///   - isExpanded: Whether the section is open; nil lets the section keep it.
    ///   - initiallyExpanded: The starting state when the section keeps it.
    ///   - content: Shown while open.
    ///   - label: The header, beside the chevron.
    public init(
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.externalIsExpanded = isExpanded
        self.label = label()
        self.content = content
        self._internalIsExpanded = State(initialValue: initiallyExpanded)
    }

    private var isExpanded: Binding<Bool> { externalIsExpanded ?? $internalIsExpanded }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded.wrappedValue {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, chevronWidth + Spacing.xs)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .transition(.motion(AnyTransition(.blurReplace)))
            }
        }
    }

    private var header: some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chevron.right")
                    .font(Typography.labelTinySemibold)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                    // The turn is a small affordance, but still motion: under
                    // Reduce Motion it snaps.
                    .animation(prefersReducedMotion ? nil : Animations.accordion, value: isExpanded.wrappedValue)
                    .frame(width: chevronWidth)
                    .accessibilityHidden(true)
                label
                    .font(Typography.bodySmallSemibold)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .listRowHover(isHovering: isHovering, scheme: colorScheme, verticalPadding: Spacing.xs)
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium, bleed: Spacing.sm))
        .onHover { hovering in withAnimation(Animations.hover) { isHovering = hovering } }
        .onKeyPress(.rightArrow) { setExpanded(true) }
        .onKeyPress(.leftArrow) { setExpanded(false) }
        .accessibilityValue(isExpanded.wrappedValue ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))
        .accessibilityAddTraits(.isHeader)
    }

    private func toggle() {
        withAnimation(Animations.accordion) { isExpanded.wrappedValue.toggle() }
    }

    /// → opens and ← closes, like an outline row; a key that changes nothing
    /// passes on (← in a section that's already closed).
    private func setExpanded(_ expanded: Bool) -> KeyPress.Result {
        guard isExpanded.wrappedValue != expanded else { return .ignored }
        withAnimation(Animations.accordion) { isExpanded.wrappedValue = expanded }
        return .handled
    }
}

extension DisclosureSection where Label == Text {
    /// A section with a text header.
    /// - Parameters:
    ///   - title: The header. Looked up in your app's strings.
    ///   - isExpanded: Whether the section is open; nil lets the section keep it.
    ///   - initiallyExpanded: The starting state when the section keeps it.
    ///   - content: Shown while open.
    public init(
        _ title: LocalizedStringKey,
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(isExpanded: isExpanded, initiallyExpanded: initiallyExpanded, content: content) {
            Text(title)
        }
    }
}

// MARK: - Previews

#Preview("Disclosure sections", traits: .fixedLayout(width: 420, height: 260)) {
    @Previewable @State var isOpen = true
    VStack(alignment: .leading, spacing: Spacing.xs) {
        DisclosureSection("Advanced", isExpanded: $isOpen) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SettingsToggleRow("Verbose logging", detail: "Writes every request to the log.", isOn: .constant(true))
                SettingsToggleRow("Use beta features", isOn: .constant(false))
            }
        }
        DisclosureSection("Network") {
            Text("Proxy settings go here.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
    }
    .padding(Spacing.lg)
}
