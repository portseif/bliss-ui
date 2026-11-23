//
//  Banner.swift
//  BlissUI
//
//  An inline callout: a status icon, a title and a line of detail on the
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
/// The status shows in the icon (the `*500` mark) and `StatusWash`'s fill and
/// hairline, never by flooding the surface; the title stays primary. The action
/// is a text button — a filled one out-weighs the banner it sits in — beside
/// the text, or under it when the banner is narrower than 360pt (an inspector),
/// so the message isn't squeezed into a column. `compact: true` is one line
/// for a note under a field or inside a card. Remove the banner inside
/// `withAnimation` and it fades out.
public struct Banner<Actions: View>: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let style: BannerStyle
    private let icon: String?
    private let showsIcon: Bool
    private let compact: Bool
    private let cornerRadius: CGFloat
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?
    private let actions: Actions
    private let onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    /// Narrow enough that the action moves under the message.
    @State private var isNarrow = false

    private static var stackedActionWidth: CGFloat { 360 }

    /// - Parameters:
    ///   - title: What's going on. Looked up in your app's strings.
    ///   - message: A line of detail under the title.
    ///   - style: The status: info, success, warning or danger.
    ///   - icon: An SF Symbol in place of the style's own.
    ///   - showsIcon: Whether the icon is drawn at all.
    ///   - compact: One line in caption type, for a note under a field.
    ///   - cornerRadius: The card's corners; 0 for a banner across a pane's top edge.
    ///   - actionTitle: The action's label; shown when `action` is set too.
    ///   - action: The fix ("Locate…", "Retry").
    ///   - onDismiss: Shows a ✕ that calls it — remove the banner there.
    ///   - actions: Several actions, in place of `actionTitle` / `action`.
    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        style: BannerStyle = .info,
        icon: String? = nil,
        showsIcon: Bool = true,
        compact: Bool = false,
        cornerRadius: CGFloat = Sizing.radiusMedium,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.icon = icon
        self.showsIcon = showsIcon
        self.compact = compact
        self.cornerRadius = cornerRadius
        self.actionTitle = actionTitle
        self.action = action
        self.onDismiss = onDismiss
        self.actions = actions()
    }

    private var hasActions: Bool {
        (actionTitle != nil && action != nil) || Actions.self != EmptyView.self
    }

    public var body: some View {
        let stacksAction = isNarrow && hasActions && !compact
        HStack(spacing: Spacing.sm) {
            // The icon rides the title's baseline, so it stays with the title
            // when the message wraps below it.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                if showsIcon {
                    Image(systemName: icon ?? style.defaultIcon)
                        .font(compact ? Typography.captionSmall : Typography.bodySmall)
                        .foregroundStyle(style.mark)
                        // One width for every symbol, so titles line up down a
                        // stack of banners (the triangle is wider than the circle).
                        .frame(width: compact ? Sizing.iconSmall : Sizing.iconDefault)
                        .accessibilityLabel(style.accessibilityName)
                }
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(compact ? Typography.captionSmallSemibold : Typography.captionSemibold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message, !compact {
                        Text(message)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if stacksAction {
                        actionRow
                            .padding(.top, Spacing.xxs)
                    }
                }
            }
            Spacer(minLength: Spacing.sm)
            if !stacksAction {
                actionRow
            }
            if let onDismiss {
                HoverIconButton(systemImage: "xmark", size: .regular, help: String(localized: "Dismiss", bundle: .module), action: onDismiss)
            }
        }
        .padding(.horizontal, compact ? Spacing.sm : Spacing.md)
        .padding(.vertical, compact ? Spacing.xxs : Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: compact ? Sizing.controlDefault : Sizing.controlMedium, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(StatusWash.fill(style.mark, colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(StatusWash.border(style.mark, colorScheme), lineWidth: 1)
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < Self.stackedActionWidth } action: { isNarrow = $0 }
        .accessibilityElement(children: .contain)
        .transition(.motion(.opacity.combined(with: .scale(scale: 0.98, anchor: .top))))
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: Spacing.sm) {
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(GhostButtonStyle(compact: true))
            }
            actions
        }
    }
}

extension Banner where Actions == EmptyView {
    /// A banner with at most one action.
    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        style: BannerStyle = .info,
        icon: String? = nil,
        showsIcon: Bool = true,
        compact: Bool = false,
        cornerRadius: CGFloat = Sizing.radiusMedium,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            title,
            message: message,
            style: style,
            icon: icon,
            showsIcon: showsIcon,
            compact: compact,
            cornerRadius: cornerRadius,
            actionTitle: actionTitle,
            action: action,
            onDismiss: onDismiss,
            actions: { EmptyView() }
        )
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

#Preview("Banners", traits: .fixedLayout(width: 520, height: 340)) {
    VStack(spacing: Spacing.sm) {
        Banner("A new version is available", message: "Version 2.1 adds the Low Glare theme.", actionTitle: "Update", action: {}, onDismiss: {})
        Banner("Backup complete", style: .success, onDismiss: {})
        Banner("This folder no longer exists", message: "~/Projects/site", style: .warning, actionTitle: "Locate…", action: {})
        Banner("Couldn't connect", message: "The server didn't answer. Check your connection and try again.", style: .danger, actionTitle: "Retry", action: {})
        Banner("Saved to the cloud", style: .success, compact: true)
    }
    .padding(Spacing.lg)
}

#Preview("Narrow", traits: .fixedLayout(width: 300, height: 200)) {
    Banner("Not tracking a remote branch", message: "The clone doesn't follow a branch on its remote, so there's nothing to check against.", style: .warning, actionTitle: "Track Remote Branch…", action: {})
        .padding(Spacing.lg)
}

#Preview("Several actions, edge to edge", traits: .fixedLayout(width: 520, height: 120)) {
    Banner("You're offline", message: "Changes are kept on this Mac until you reconnect.", style: .warning, cornerRadius: 0) {
        Button("Retry") {}
            .buttonStyle(GhostButtonStyle(compact: true))
        Button("Work offline") {}
            .buttonStyle(SecondaryButtonStyle(compact: true))
    }
}
