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

/// Which side of the header the chevron sits on.
public enum DisclosureChevronPlacement: Hashable, Sendable {
    /// Before the title, as in an outline.
    case leading
    /// After the title, as in System Settings.
    case trailing
}

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
/// content is only built while open, and lines up with the header's title
/// (`indentsContent: false` runs it to the header's leading edge, for a table
/// or a code block). `trailing` puts a count, a toggle or a "Reset" button on
/// the header line.
public struct DisclosureSection<Label: View, Content: View, Trailing: View>: View {
    private let externalIsExpanded: Binding<Bool>?
    private let label: Label
    private let trailing: Trailing
    private let chevronPlacement: DisclosureChevronPlacement
    private let indentsContent: Bool
    private let content: () -> Content

    @State private var internalIsExpanded: Bool
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    private let chevronWidth: CGFloat = Sizing.iconTiny

    /// - Parameters:
    ///   - isExpanded: Whether the section is open; nil lets the section keep it.
    ///   - initiallyExpanded: The starting state when the section keeps it.
    ///   - chevronPlacement: The chevron before or after the title.
    ///   - indentsContent: Lines the content up with the title (true) or the header's edge.
    ///   - content: Shown while open.
    ///   - label: The header, beside the chevron.
    ///   - trailing: An accessory on the header's trailing edge.
    public init(
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        chevronPlacement: DisclosureChevronPlacement = .leading,
        indentsContent: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: () -> Label,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.externalIsExpanded = isExpanded
        self.label = label()
        self.trailing = trailing()
        self.chevronPlacement = chevronPlacement
        self.indentsContent = indentsContent
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
                    .padding(.leading, indentsContent && chevronPlacement == .leading ? chevronWidth + Spacing.xs : 0)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .transition(.motion(AnyTransition(.blurReplace)))
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: toggle) {
                HStack(spacing: Spacing.xs) {
                    if chevronPlacement == .leading { chevron }
                    label
                        .font(Typography.bodySmallSemibold)
                        .foregroundStyle(.primary)
                    if chevronPlacement == .trailing { chevron }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .listRowHover(isHovering: isHovering, scheme: colorScheme, verticalPadding: Spacing.listRowPadding)
            }
            .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium, bleed: Spacing.sm))
            .onHover { hovering in withAnimation(Animations.hover) { isHovering = hovering } }
            .onKeyPress(.rightArrow) { setExpanded(true) }
            .onKeyPress(.leftArrow) { setExpanded(false) }
            .accessibilityValue(isExpanded.wrappedValue ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))
            .accessibilityAddTraits(.isHeader)
            trailing
        }
    }

    private var chevron: some View {
        BlissSymbol("chevron.right")
            .font(Typography.labelTinySemibold)
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
            // The turn is a small affordance, but still motion: under
            // Reduce Motion it snaps.
            .animation(prefersReducedMotion ? nil : Animations.accordion, value: isExpanded.wrappedValue)
            .frame(width: chevronWidth)
            .accessibilityHidden(true)
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

extension DisclosureSection where Trailing == EmptyView {
    /// A section with a custom header and no trailing accessory.
    public init(
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        chevronPlacement: DisclosureChevronPlacement = .leading,
        indentsContent: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        self.init(
            isExpanded: isExpanded,
            initiallyExpanded: initiallyExpanded,
            chevronPlacement: chevronPlacement,
            indentsContent: indentsContent,
            content: content,
            label: label,
            trailing: { EmptyView() }
        )
    }
}

extension DisclosureSection where Label == Text {
    /// A section with a text header and a trailing accessory.
    /// - Parameters:
    ///   - title: The header. Looked up in your app's strings.
    ///   - isExpanded: Whether the section is open; nil lets the section keep it.
    ///   - initiallyExpanded: The starting state when the section keeps it.
    ///   - chevronPlacement: The chevron before or after the title.
    ///   - indentsContent: Lines the content up with the title.
    ///   - content: Shown while open.
    ///   - trailing: An accessory on the header's trailing edge.
    public init(
        _ title: LocalizedStringKey,
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        chevronPlacement: DisclosureChevronPlacement = .leading,
        indentsContent: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            isExpanded: isExpanded,
            initiallyExpanded: initiallyExpanded,
            chevronPlacement: chevronPlacement,
            indentsContent: indentsContent,
            content: content,
            label: { Text(title) },
            trailing: trailing
        )
    }
}

extension DisclosureSection where Label == Text, Trailing == EmptyView {
    /// A section with a text header.
    /// - Parameters:
    ///   - title: The header. Looked up in your app's strings.
    ///   - isExpanded: Whether the section is open; nil lets the section keep it.
    ///   - initiallyExpanded: The starting state when the section keeps it.
    ///   - chevronPlacement: The chevron before or after the title.
    ///   - indentsContent: Lines the content up with the title.
    ///   - content: Shown while open.
    public init(
        _ title: LocalizedStringKey,
        isExpanded: Binding<Bool>? = nil,
        initiallyExpanded: Bool = false,
        chevronPlacement: DisclosureChevronPlacement = .leading,
        indentsContent: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isExpanded: isExpanded,
            initiallyExpanded: initiallyExpanded,
            chevronPlacement: chevronPlacement,
            indentsContent: indentsContent,
            content: content,
            label: { Text(title) },
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Previews

#Preview("Disclosure sections", traits: .fixedLayout(width: 420, height: 300)) {
    @Previewable @State var isOpen = true
    VStack(alignment: .leading, spacing: Spacing.xs) {
        DisclosureSection("Advanced", isExpanded: $isOpen) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SettingsToggleRow("Verbose logging", detail: "Writes every request to the log.", isOn: .constant(true))
                SettingsToggleRow("Use beta features", isOn: .constant(false))
            }
        } trailing: {
            Badge(count: 2).badgeStyle(.secondary).badgeSize(.small)
        }
        DisclosureSection("Network", chevronPlacement: .trailing) {
            Text("Proxy settings go here.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
        }
    }
    .padding(Spacing.lg)
}
