//
//  SheetHeader.swift
//  BlissUI
//
//  A consistent header component for modal sheets:
//  - Leading-aligned title and subtitle
//  - Optional leading icon in a tinted rounded container
//  - Optional trailing dismiss (✕) button
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
    var onDismiss: (() -> Void)? = nil

    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        icon: String? = nil,
        iconColor: Color? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    public var body: some View {
        // `icon` / `iconColor` are intentionally not rendered — sheet headers use
        // the plain title + subtitle treatment. The params stay for source
        // compatibility with existing call sites.
        HStack {
            // Title + subtitle, left-aligned
            VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                Text(title)
                    .font(Typography.headingLarge)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Spacing.sm)

            // Dismiss button (trailing)
            if let onDismiss {
                SheetCloseButton(action: onDismiss)
                    .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
    }
}

// MARK: - Sheet Close Button

/// The standard circular "✕" dismiss button shared by every sheet and panel
/// header. Single source of truth so all close buttons look identical to the
/// one `SheetHeader` renders: a 24pt circle with a subtle fill and a hover
/// highlight. Use it instead of hand-rolling an `xmark` button.
///
/// The caller positions it and adds a keyboard shortcut if desired, e.g.:
/// ```swift
/// SheetCloseButton { dismiss() }
///     .keyboardShortcut(.escape, modifiers: [])
///     .padding(Spacing.md)
/// ```
public struct SheetCloseButton: View {
    let action: () -> Void
    /// Sheet headers nudge the ✕ up into the header's top padding. Inline hosts
    /// (e.g. a side panel's header row) pass 0 to sit on the row's centerline.
    let verticalOffset: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    public init(action: @escaping () -> Void, verticalOffset: CGFloat = -12) {
        self.action = action
        self.verticalOffset = verticalOffset
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Typography.labelTinySemibold)
                .foregroundStyle(colorScheme == .dark ? Grey.grey400 : Grey.grey500)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(isHovered
                            ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
                            : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)))
                }
        }
        .offset(y: verticalOffset)
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull))
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text("Close"))
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

#Preview("Sheet Headers") {
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

        // With icon
        SheetHeader(
            title: "Import Files",
            subtitle: "Add existing files to your library",
            icon: "square.and.arrow.down",
            onDismiss: {}
        )

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
    .frame(width: 400)
    .background(Grey.grey100)
}

#Preview("Sheet Close Button", traits: .fixedLayout(width: 160, height: 120)) {
    SheetCloseButton {}
        .padding(Spacing.xl)
        .background(Color.windowBackground)
}
