//
//  SettingsRows.swift
//  BlissUI
//
//  The rows a settings form is built from: a title and a line on what it does,
//  with the control beside it. `SettingsRow` puts any control on the trailing
//  edge (a picker, a button, a value), `SettingsToggleRow` is a switch with
//  its text, and `SettingsActionRow` is a whole row that does something when
//  clicked (opens a pane, resets a setting). All three keep the control on
//  the title's line: a switch, a picker and a chevron sit at one height in a
//  divided section.
//

import AppKit
import SwiftUI

// MARK: - Metrics

enum SettingsRowMetrics {
    /// The leading icon's slot, so titles line up with and without one.
    static let iconSlot: CGFloat = Sizing.iconDefault
    /// Between the text and the control, and between the icon and the text.
    static let spacing: CGFloat = Spacing.md
    /// The action row's spinner, drawn at the chevron's size.
    static let spinnerLineWidth: CGFloat = 1.5
}

// MARK: - Settings Row

/// A settings row: title and detail on the leading edge, a control on the
/// trailing edge (`FloatingMenuPicker`, a compact button, a `.flatSwitch`
/// toggle, a value). Rows read identically whatever the control, so a form of
/// mixed rows lines up. Put them in a `RoundedSection(divided: true)`.
///
/// ```swift
/// SettingsRow("Language", detail: "Used for menus and messages.") {
///     FloatingMenuPicker("Language", selection: $language, options: languages, optionTitle: { $0 }, showsTitle: false)
/// }
/// ```
public struct SettingsRow<Control: View>: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let systemImage: String?
    private let badge: Badge?
    private let error: LocalizedStringKey?
    private let alignsControlToTitle: Bool
    private let control: Control

    /// - Parameters:
    ///   - title: What the setting is. Looked up in your app's strings.
    ///   - detail: A line on what it does, under the title.
    ///   - systemImage: An SF Symbol before the title (System Settings' rows).
    ///   - badge: A badge beside the title ("Beta", "Pro").
    ///   - error: A problem with the value, in the danger mark under the
    ///     detail ("Port must be 1 to 65535"). It also reaches the control
    ///     through `\.formFieldIsInvalid`.
    ///   - alignsControlToTitle: The control centered on the title's line (the
    ///     switch row's recipe); off, on the whole text block.
    ///   - control: The control on the trailing edge.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        badge: Badge? = nil,
        error: LocalizedStringKey? = nil,
        alignsControlToTitle: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.badge = badge
        self.error = error
        self.alignsControlToTitle = alignsControlToTitle
        self.control = control()
    }

    public var body: some View {
        HStack(alignment: alignsControlToTitle ? .firstTextBaseline : .center, spacing: SettingsRowMetrics.spacing) {
            SettingsRowText(title: title, detail: detail, systemImage: systemImage, badge: badge, error: error)
            Spacer(minLength: SettingsRowMetrics.spacing)
            if alignsControlToTitle {
                control
                    .environment(\.formFieldIsInvalid, error != nil)
                    .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
            } else {
                control
                    .environment(\.formFieldIsInvalid, error != nil)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings Toggle Row

/// A settings switch with its title and a line on what it does: the switch on
/// the leading edge, the text beside it, the switch centered on the title's
/// first line. VoiceOver hears one switch, titled, with the detail as its hint.
public struct SettingsToggleRow: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let systemImage: String?
    private let badge: Badge?
    @Binding private var isOn: Bool

    /// - Parameters:
    ///   - title: What the switch turns on. Looked up in your app's strings.
    ///   - detail: A line on what it does, under the title.
    ///   - systemImage: An SF Symbol before the title.
    ///   - badge: A badge beside the title ("Beta", "Pro").
    ///   - isOn: The setting.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        badge: Badge? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.badge = badge
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsRowMetrics.spacing) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.flatSwitch)
                .controlSize(.small)
                // A switch has no text, so its baseline is its bottom edge and it
                // sat above the title; center it on the title's capitals instead.
                .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
                .accessibilityHint(detail.map { Text($0) } ?? Text(verbatim: ""))
            SettingsRowText(title: title, detail: detail, systemImage: systemImage, badge: badge)
                // The switch already carries the title (and the detail as its
                // hint), so VoiceOver doesn't read them twice.
                .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Settings Action Row

/// A settings row that's a button: title and detail, with a trailing glyph
/// (a chevron by default, `arrow.up.right` for something that opens outside
/// the app). The whole row takes the click, hovers with the list rows' fill and
/// is a Tab stop with the shared ring. `isDestructive` sets the title in the
/// danger mark ("Reset All Settings…").
public struct SettingsActionRow: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let value: LocalizedStringKey?
    private let systemImage: String
    private let leadingSystemImage: String?
    private let badge: Badge?
    private let isDestructive: Bool
    private let isLoading: Bool
    private let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    /// The hover fill and focus ring reach past the row by this much, outside
    /// its layout, so the row lines up with its neighbors in a divided section.
    private let verticalOutset = Spacing.xs
    private let horizontalOutset = Spacing.sm

    /// - Parameters:
    ///   - title: What the row does. Looked up in your app's strings.
    ///   - detail: A line on what happens, under the title.
    ///   - value: The current value before the glyph ("English ›"), the most
    ///     common System Settings row.
    ///   - systemImage: The trailing glyph.
    ///   - leadingSystemImage: An SF Symbol before the title.
    ///   - badge: A badge beside the title ("Beta", "Pro").
    ///   - isDestructive: Sets the title in the danger mark.
    ///   - isLoading: The spinner in the glyph's place while the action runs
    ///     (a reset, a sign-out); the row doesn't take clicks meanwhile.
    ///   - action: Runs on a click, Space or Return.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        value: LocalizedStringKey? = nil,
        systemImage: String = "chevron.right",
        leadingSystemImage: String? = nil,
        badge: Badge? = nil,
        isDestructive: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.systemImage = systemImage
        self.leadingSystemImage = leadingSystemImage
        self.badge = badge
        self.isDestructive = isDestructive
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: SettingsRowMetrics.spacing) {
                SettingsRowText(
                    title: title,
                    detail: detail,
                    systemImage: leadingSystemImage,
                    badge: badge,
                    titleColor: isDestructive ? Danger.danger500 : Color.primary
                )
                Spacer(minLength: SettingsRowMetrics.spacing)
                if let value {
                    Text(value)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Group {
                    if isLoading {
                        ThinkingSpinner(size: Sizing.iconTiny, lineWidth: SettingsRowMetrics.spinnerLineWidth)
                    } else {
                        BlissSymbol(systemImage)
                            .font(Typography.captionSmallSemibold)
                            .foregroundStyle(isHovering ? .secondary : .tertiary)
                    }
                }
                .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(isHovering && isEnabled ? RowTint.hover(colorScheme) : Color.clear)
                    .padding(.vertical, -verticalOutset)
                    .padding(.horizontal, -horizontalOutset)
            }
        }
        // The ring traces the hover fill: out by `verticalOutset` all round
        // and by the rest of `horizontalOutset` sideways, its radius growing
        // with the outset to land on the fill's corners.
        .buttonStyle(FocusablePlainButtonStyle(
            cornerRadius: Sizing.radiusMedium - verticalOutset,
            outset: verticalOutset,
            bleed: horizontalOutset - verticalOutset
        ))
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .accessibilityValue(value.map { Text($0) } ?? Text(verbatim: ""))
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
    }
}

// MARK: - Shared Text

/// Title over detail, the same in every settings row: an optional icon before
/// the title, an optional badge after it, an optional error under the detail.
struct SettingsRowText: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    var systemImage: String? = nil
    var badge: Badge? = nil
    var error: LocalizedStringKey? = nil
    var titleColor: Color = .primary

    /// The title's cap height (`Typography.bodySmall`'s size in the user's UI
    /// font), for centering a switch or a status glyph on the title's line.
    static var titleCapHeight: CGFloat {
        FontResolver.nsFont(.ui, size: FontSize.footnote, weight: .regular).capHeight
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsRowMetrics.spacing) {
            if let systemImage {
                BlissSymbol(systemImage)
                    .font(Typography.labelMedium)
                    .foregroundStyle(.secondary)
                    .frame(width: SettingsRowMetrics.iconSlot)
                    .centeredOnFirstTextLine(capHeight: Self.titleCapHeight)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(titleColor)
                    if let badge {
                        badge.badgeSize(.small)
                    }
                }
                if let detail {
                    Text(detail)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error {
                    Text(error)
                        .font(Typography.captionSmall)
                        .foregroundStyle(Danger.danger500)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

extension View {
    /// A view with no text (a switch, a glyph) has its bottom edge as its
    /// first baseline, so in an `HStack(alignment: .firstTextBaseline)` it rides
    /// above its label. This centers it on the capitals of the label's first
    /// line instead.
    func centeredOnFirstTextLine(capHeight: CGFloat) -> some View {
        alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center] + capHeight / 2
        }
    }
}

// MARK: - Previews

#Preview("Settings rows", traits: .fixedLayout(width: 480, height: 340)) {
    @Previewable @State var launchAtLogin = true
    @Previewable @State var sendReports = false
    RoundedSection("General", divided: true) {
        SettingsToggleRow("Launch at login", detail: "Opens in the menu bar when you log in.", systemImage: "power", isOn: $launchAtLogin)
        SettingsToggleRow("Send crash reports", badge: Badge("Beta").badgeStyle(.info), isOn: $sendReports)
        SettingsRow("Updates", detail: "Checks once a day.") {
            Button("Check Now") {}.buttonStyle(SecondaryButtonStyle(compact: true))
        }
        SettingsRow("Port", error: "Port must be 1 to 65535") {
            NumberField("Port", value: .constant(70_000), in: 1...65_535)
        }
        SettingsActionRow("Language", value: "English", leadingSystemImage: "globe") {}
        SettingsActionRow("Login Items", detail: "Manage what opens at login in System Settings.", systemImage: "arrow.up.right") {}
        SettingsActionRow("Reset All Settings…", isDestructive: true) {}
    }
    .padding(Spacing.lg)
}
