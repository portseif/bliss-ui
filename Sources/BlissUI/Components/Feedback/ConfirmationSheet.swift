//
//  ConfirmationSheet.swift
//  BlissUI
//
//  "Are you sure?" as an app sheet, in place of `.alert` and
//  `.confirmationDialog`: the question and what it means, over the compact
//  `ActionBar` — Cancel beside the action, Return confirms, Esc cancels.
//

import SwiftUI

// MARK: - Confirmation Sheet

/// The confirmation card: a title and message over Cancel and the action.
/// `.confirmationSheet(isPresented:…)` presents it; present it yourself with
/// `.appSheet(item:contentSized: true)` to confirm something about one item.
/// It closes itself through `\.appSheetDismiss` — on Cancel, Esc, or after
/// running `onConfirm`.
///
/// There's no ✕ in the header: Cancel owns Esc, and two Esc bindings race.
/// `style` puts a status glyph beside the question, as an alert's icon does.
public struct ConfirmationSheet: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let confirmTitle: LocalizedStringResource
    private let cancelTitle: LocalizedStringResource
    private let isDestructive: Bool
    private let style: BannerStyle?
    private let width: CGFloat
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void

    @Environment(\.appSheetDismiss) private var dismiss

    /// - Parameters:
    ///   - title: The question ("Delete 3 Items?"). Looked up in your app's strings.
    ///   - message: What happens, and whether it can be undone.
    ///   - confirmTitle: The action's label ("Delete"). Looked up in your app's strings.
    ///   - cancelTitle: The cancel button's label ("Keep").
    ///   - isDestructive: Draws the action as the destructive button.
    ///   - style: A status glyph beside the title (`.warning` for a caution).
    ///   - width: The card's width; `Sizing.sheetWidthLarge` for a long message.
    ///   - onCancel: Runs on Cancel or Esc, before the sheet closes.
    ///   - onConfirm: Runs on the action or Return; the sheet closes first.
    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        confirmTitle: LocalizedStringResource,
        cancelTitle: LocalizedStringResource = LocalizedStringResource("Cancel", bundle: .atURL(Bundle.blissUI.bundleURL)),
        isDestructive: Bool = false,
        style: BannerStyle? = nil,
        width: CGFloat = Sizing.sheetWidthMedium,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.style = style
        self.width = width
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The sheet header's title and subtitle, inset `Spacing.lg` like
            // `SheetHeader`, with the footer's own inset parting the buttons
            // from the message.
            HStack(alignment: .top, spacing: Spacing.md) {
                if let style {
                    Image(systemName: style.defaultIcon)
                        .font(Typography.headingLarge)
                        .foregroundStyle(style.mark)
                        .accessibilityLabel(style.accessibilityName)
                }
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.headingLarge)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let message {
                        Text(message)
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionBar(
                cancelTitle: String(localized: cancelTitle),
                confirmTitle: String(localized: confirmTitle),
                isDestructive: isDestructive,
                useKeyboardShortcuts: true,
                showBackground: false,
                onCancel: {
                    onCancel?()
                    dismiss()
                },
                onConfirm: {
                    // Closed first, so an action that opens another sheet
                    // stacks it over the page rather than over this card.
                    dismiss()
                    onConfirm()
                }
            )
        }
        .frame(width: width)
    }
}

// MARK: - Presentation

extension View {
    /// Asks for confirmation in an app sheet while `isPresented` is true:
    /// the title and message over Cancel and the action. Return confirms, Esc
    /// cancels; either closes the sheet. Needs `.appSheetHost()` at the window
    /// root, like every app sheet.
    ///
    /// ```swift
    /// .confirmationSheet(
    ///     isPresented: $isConfirmingDelete,
    ///     title: "Delete \(count) Items?",
    ///     message: "They're removed from every device. This can't be undone.",
    ///     confirmTitle: "Delete",
    ///     isDestructive: true
    /// ) { deleteSelection() }
    /// ```
    /// - Parameters:
    ///   - isPresented: Shows the sheet; set back to false when it closes.
    ///   - title: The question. Looked up in your app's strings.
    ///   - message: What happens, and whether it can be undone.
    ///   - confirmTitle: The action's label. Looked up in your app's strings.
    ///   - cancelTitle: The cancel button's label.
    ///   - isDestructive: Draws the action as the destructive button.
    ///   - style: A status glyph beside the title.
    ///   - action: Runs when confirmed, after the sheet starts closing.
    public func confirmationSheet(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        confirmTitle: LocalizedStringResource,
        cancelTitle: LocalizedStringResource = LocalizedStringResource("Cancel", bundle: .atURL(Bundle.blissUI.bundleURL)),
        isDestructive: Bool = false,
        style: BannerStyle? = nil,
        action: @escaping () -> Void
    ) -> some View {
        appSheet(isPresented: isPresented, contentSized: true) {
            ConfirmationSheet(
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                cancelTitle: cancelTitle,
                isDestructive: isDestructive,
                style: style,
                onConfirm: action
            )
        }
    }
}

// MARK: - Previews

#Preview("Confirmation sheet", traits: .fixedLayout(width: 640, height: 420)) {
    @Previewable @State var isPresented = true
    ZStack {
        Color.appShell.ignoresSafeArea()
        Button("Delete…") { isPresented = true }
            .buttonStyle(DestructiveButtonStyle(compact: true))
    }
    .appSheetHost()
    .confirmationSheet(
        isPresented: $isPresented,
        title: "Delete 3 Items?",
        message: "They're removed from every device. This can't be undone.",
        confirmTitle: "Delete",
        isDestructive: true,
        style: .warning
    ) {}
}
