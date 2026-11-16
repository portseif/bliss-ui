//
//  SheetHeader.swift
//  BlissUI
//
//  A consistent header component for modal sheets:
//  - Leading-aligned title and subtitle
//  - Optional leading icon in a tinted rounded container
//  - Optional trailing controls and dismiss (✕) button
//  - Consistent padding and typography
//

import SwiftUI

/// A standardized header component for modal sheets
///
/// Usage examples:
/// ```swift
/// // Basic header
/// SheetHeader(
///     title: "Create Backup",
///     subtitle: "Save a copy of your current settings"
/// )
///
/// // With icon
/// SheetHeader(
///     title: "Import Files",
///     subtitle: "Add existing files to your library",
///     icon: "square.and.arrow.down"
/// )
///
/// // With dismiss button
/// SheetHeader(
///     title: "Add Secret",
///     subtitle: "Store sensitive data securely",
///     onDismiss: { dismiss() }
/// )
///
/// // With colored icon
/// SheetHeader(
///     title: "Delete Item",
///     subtitle: "This action cannot be undone",
///     icon: "trash",
///     iconColor: .red
/// )
/// ```
public struct SheetHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    var compact: Bool = false
    var onDismiss: (() -> Void)? = nil
    /// Controls before the ✕: a step counter, a "Learn more" link.
    var actions: AnyView? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appSheetInteractiveDismissDisabled) private var dismissDisabled

    /// - Parameters:
    ///   - title: The sheet's title.
    ///   - subtitle: A secondary line under it.
    ///   - icon: An SF Symbol in a tinted rounded box before the title.
    ///   - iconColor: The box's tint; the accent when nil.
    ///   - compact: A smaller header (the small heading, `Spacing.md` inset)
    ///     for a confirmation or picker sheet.
    ///   - onDismiss: Shows the ✕, which runs this (and Esc).
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        compact: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.compact = compact
        self.onDismiss = onDismiss
    }

    /// A header with controls on its trailing edge, before the ✕ — a
    /// `StepIndicator`, a "Learn more" `TextLink`.
    ///
    /// - Parameters:
    ///   - title: The sheet's title.
    ///   - subtitle: A secondary line under it.
    ///   - icon: An SF Symbol in a tinted rounded box before the title.
    ///   - iconColor: The box's tint; the accent when nil.
    ///   - compact: A smaller header.
    ///   - onDismiss: Shows the ✕, which runs this (and Esc).
    ///   - actions: The trailing controls.
    public init<Actions: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        compact: Bool = false,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.compact = compact
        self.onDismiss = onDismiss
        self.actions = AnyView(actions())
    }

    // MARK: - Body

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if let icon {
                iconBox(icon)
            }

            // Title + subtitle, left-aligned
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(compact ? Typography.headingSmall : Typography.headingLarge)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Spacing.sm)

            if let actions {
                actions
            }

            // Dismiss button (trailing), nudged up into the header's padding.
            // Not while the sheet forbids interactive dismissal (saving).
            if let onDismiss, !dismissDisabled {
                SheetCloseButton(action: onDismiss)
                    .offset(y: compact ? 0 : -Spacing.md)
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? Spacing.md : Spacing.lg)
    }

    /// The icon in its tinted rounded box: the status wash in the icon's color.
    private func iconBox(_ icon: String) -> some View {
        let color = iconColor ?? Color.accent
        return Image(systemName: icon)
            .font(compact ? Typography.labelMedium : Typography.headingSmall)
            .foregroundStyle(color)
            .frame(width: compact ? Sizing.controlDefault : Sizing.controlMedium, height: compact ? Sizing.controlDefault : Sizing.controlMedium)
            .background {
                RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                    .fill(StatusWash.fill(color, colorScheme))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Sheet Close Button

/// The standard circular "✕" dismiss button shared by every sheet and panel
/// header. Single source of truth so all close buttons look identical to the
/// one `SheetHeader` renders: a `Sizing.controlSmall` circle on the resting
/// fill with the row hover. Use it instead of hand-rolling an `xmark` button.
///
/// The caller positions it and adds a keyboard shortcut if desired, e.g.:
/// ```swift
/// SheetCloseButton { dismiss() }
///     .keyboardShortcut(.escape, modifiers: [])
///     .padding(Spacing.md)
/// ```
public struct SheetCloseButton: View {
    let action: () -> Void
    /// A nudge off the row's centerline; `SheetHeader` applies its own.
    let verticalOffset: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(action: @escaping () -> Void, verticalOffset: CGFloat = 0) {
        self.action = action
        self.verticalOffset = verticalOffset
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Typography.labelTinySemibold)
                .foregroundStyle(.secondary)
                .frame(width: Sizing.controlSmall, height: Sizing.controlSmall)
                .background {
                    Circle()
                        .fill(isHovered ? RowTint.hover(colorScheme) : Color.restingFill)
                }
        }
        .offset(y: verticalOffset)
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
        .onHover { isHovered = $0 }
        .animation(Animations.hover, value: isHovered)
        .accessibilityLabel(Text("Close", bundle: .module))
    }
}

// MARK: - Variants

extension SheetHeader {
    /// Create a header for destructive actions (red icon)
    public static func destructive(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String = "exclamationmark.triangle") -> SheetHeader {
        SheetHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: Danger.danger500
        )
    }

    /// Create a header for success states (green icon)
    public static func success(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String = "checkmark.circle") -> SheetHeader {
        SheetHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: Success.success500
        )
    }

    /// Create a header for warning states (orange icon)
    public static func warning(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String = "exclamationmark.triangle") -> SheetHeader {
        SheetHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconColor: Warning.warning500
        )
    }
}

// MARK: - Preview

#Preview("Sheet Headers", traits: .fixedLayout(width: 400, height: 460)) {
    VStack(spacing: 0) {
        // With dismiss button
        SheetHeader(
            title: "Add Secret",
            subtitle: "Store sensitive data securely",
            icon: "key.fill",
            onDismiss: {}
        )

        Divider()

        // Basic header (no dismiss)
        SheetHeader(
            title: "Create Backup",
            subtitle: "Save a copy of your current settings"
        )

        Divider()

        // Trailing controls
        SheetHeader(title: "New Project", subtitle: "Step 2 of 3", compact: true, onDismiss: {}) {
            StepIndicator(stepCount: 3, currentIndex: 1)
        }

        Divider()

        // Destructive
        SheetHeader.destructive(
            title: "Delete Item",
            subtitle: "This action cannot be undone"
        )

        Divider()

        // Success
        SheetHeader.success(
            title: "Backup Complete",
            subtitle: "Your settings have been saved"
        )
    }
    .background(Color.windowBackground)
}

#Preview("Sheet Close Button", traits: .fixedLayout(width: 160, height: 120)) {
    SheetCloseButton {}
        .padding(Spacing.xl)
        .background(Color.windowBackground)
}
