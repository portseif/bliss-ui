//
//  Banner.swift
//  BlissUI
//
//  An inline callout: a status icon, a title and a line of detail on a faint
//  status wash, with an optional action and a dismiss button. For a state the
//  page is in ("This folder no longer exists", "You're offline") — a toast is
//  for something that just happened.
//

import SwiftUI

// MARK: - Style

/// A banner's status: its icon and its wash.
public nonisolated enum BannerStyle: Sendable, Hashable, CaseIterable {
    case info
    case success
    case warning
    case danger
}

// MARK: - Banner

/// An inline callout for a state worth interrupting for, with the action that
/// resolves it.
///
/// ```swift
/// Banner("This folder no longer exists", message: "~/Projects/site",
///        style: .warning, actionTitle: "Locate…", action: locate)
/// ```
///
/// The status shows in the icon (the `*500` mark) and a faint wash and edge of
/// the palette's `tint`, never by flooding the surface; the title stays
/// primary. The action is a text button — a filled one out-weighs the banner it
/// sits in. Remove the banner inside `withAnimation` and it fades out.
public struct Banner: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let style: BannerStyle
    private let icon: String?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?
    private let onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - title: What's going on. Looked up in your app's strings.
    ///   - message: A line of detail under the title.
    ///   - style: The status: info, success, warning or danger.
    ///   - icon: An SF Symbol in place of the style's own.
    ///   - actionTitle: The action's label; shown when `action` is set too.
    ///   - action: The fix ("Locate…", "Retry").
    ///   - onDismiss: Shows a ✕ that calls it — remove the banner there.
    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        style: BannerStyle = .info,
        icon: String? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            // The icon rides the title's baseline, so it stays with the title
            // when the message wraps below it.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Image(systemName: icon ?? style.defaultIcon)
                    .font(Typography.bodySmall)
                    .foregroundStyle(style.mark)
                    // One width for every symbol, so titles line up down a
                    // stack of banners (the triangle is wider than the circle).
                    .frame(width: Sizing.iconDefault)
                    .accessibilityLabel(style.accessibilityName)
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.bodySmallSemibold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: Spacing.sm)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusDefault, outset: 3))
                    .font(Typography.labelSmall)
                    .foregroundStyle(Color.accent)
            }
            if let onDismiss {
                dismissButton(onDismiss)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(style.tint.opacity(colorScheme == .dark ? 0.14 : 0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .strokeBorder(style.tint.opacity(borderOpacity), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .transition(.motion(.opacity.combined(with: .scale(scale: 0.98, anchor: .top))))
    }

    private var borderOpacity: Double {
        if prefersIncreasedContrast { return 0.6 }
        return colorScheme == .dark ? 0.3 : 0.25
    }

    private func dismissButton(_ onDismiss: @escaping () -> Void) -> some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(Typography.labelTinySemibold)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.iconMedium, height: Sizing.iconMedium)
                .contentShape(Rectangle())
        }
        .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
        .tooltip(configuration: .iconHint, position: .above) {
            Text("Dismiss", bundle: .module).font(Typography.labelSmall)
        }
        .accessibilityLabel(Text("Dismiss", bundle: .module))
    }
}

// MARK: - Style values

extension BannerStyle {
    /// The icon, text-and-glyph tone.
    var mark: Color {
        switch self {
        case .info: Info.info500
        case .success: Success.success500
        case .warning: Warning.warning500
        case .danger: Danger.danger500
        }
    }

    /// The deep tone under the wash and the edge — a lifted mark at low
    /// opacity goes grey on a dark surface.
    var tint: Color {
        switch self {
        case .info: Info.tint
        case .success: Success.tint
        case .warning: Warning.tint
        case .danger: Danger.tint
        }
    }

    var defaultIcon: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.octagon.fill"
        }
    }

    /// What VoiceOver says for the icon, so the status isn't only a color.
    var accessibilityName: Text {
        switch self {
        case .info: Text("Info", bundle: .module)
        case .success: Text("Success", bundle: .module)
        case .warning: Text("Warning", bundle: .module)
        case .danger: Text("Error", bundle: .module)
        }
    }
}

// MARK: - Previews

#Preview("Banners", traits: .fixedLayout(width: 520, height: 300)) {
    VStack(spacing: Spacing.sm) {
        Banner("A new version is available", message: "Version 2.1 adds the Low Glare theme.", actionTitle: "Update", action: {}, onDismiss: {})
        Banner("Backup complete", style: .success, onDismiss: {})
        Banner("This folder no longer exists", message: "~/Projects/site", style: .warning, actionTitle: "Locate…", action: {})
        Banner("Couldn't connect", message: "The server didn't answer. Check your connection and try again.", style: .danger, actionTitle: "Retry", action: {})
    }
    .padding(Spacing.lg)
}
