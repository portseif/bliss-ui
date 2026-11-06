//
//  SettingsRows.swift
//  BlissUI
//
//  The rows a settings form is built from: a title and a line on what it does,
//  with the control beside it. `SettingsRow` puts any control on the trailing
//  edge (a picker, a button, a value), `SettingsToggleRow` is a switch with
//  its text, and `SettingsActionRow` is a whole row that does something when
//  clicked (opens a pane, resets a setting).
//

import AppKit
import SwiftUI

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
    private let control: Control

    /// - Parameters:
    ///   - title: What the setting is. Looked up in your app's strings.
    ///   - detail: A line on what it does, under the title.
    ///   - control: The control on the trailing edge.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            SettingsRowText(title: title, detail: detail)
            Spacer(minLength: Spacing.md)
            control
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
    @Binding private var isOn: Bool

    /// - Parameters:
    ///   - title: What the switch turns on. Looked up in your app's strings.
    ///   - detail: A line on what it does, under the title.
    ///   - isOn: The setting.
    public init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.flatSwitch)
                .controlSize(.small)
                // A switch has no text, so its baseline is its bottom edge and it
                // sat above the title; center it on the title's capitals instead.
                .centeredOnFirstTextLine(capHeight: SettingsRowText.titleCapHeight)
                .accessibilityHint(detail.map { Text($0) } ?? Text(verbatim: ""))
            SettingsRowText(title: title, detail: detail)
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
    private let systemImage: String
    private let isDestructive: Bool
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
    ///   - systemImage: The trailing glyph.
    ///   - isDestructive: Sets the title in the danger mark.
    ///   - action: Runs on a click, Space or Return.
    public init(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey? = nil,
        systemImage: String = "chevron.right",
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                SettingsRowText(
                    title: title,
                    detail: detail,
                    titleColor: isDestructive ? Danger.danger500 : Color.primary
                )
                Spacer(minLength: Spacing.md)
                Image(systemName: systemImage)
                    .font(Typography.captionSmallSemibold)
                    .foregroundStyle(isHovering ? .secondary : .tertiary)
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
        .opacity(isEnabled ? 1 : 0.5)
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
    }
}

// MARK: - Shared Text

/// Title over detail, the same in every settings row.
struct SettingsRowText: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    var titleColor: Color = .primary

    /// The title's cap height (`Typography.bodySmall`'s size), for centering a
    /// switch or a status glyph on the title's line.
    static let titleCapHeight = NSFont.systemFont(ofSize: FontSize.footnote).capHeight

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(titleColor)
            if let detail {
                Text(detail)
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

#Preview("Settings rows", traits: .fixedLayout(width: 480, height: 300)) {
    @Previewable @State var launchAtLogin = true
    @Previewable @State var sendReports = false
    RoundedSection("General", divided: true) {
        SettingsToggleRow("Launch at login", detail: "Opens in the menu bar when you log in.", isOn: $launchAtLogin)
        SettingsToggleRow("Send crash reports", isOn: $sendReports)
        SettingsRow("Updates", detail: "Checks once a day.") {
            Button("Check Now") {}.buttonStyle(SecondaryButtonStyle(compact: true))
        }
        SettingsActionRow("Login Items", detail: "Manage what opens at login in System Settings.", systemImage: "arrow.up.right") {}
        SettingsActionRow("Reset All Settings…", isDestructive: true) {}
    }
    .padding(Spacing.lg)
}
