//
//  ConfirmationSheet.swift
//  BlissUI
//
//  "Are you sure?" as an app sheet, in place of `.alert` and
//  `.confirmationDialog`: the question and what it means beside the ✕, over
//  Cancel and the action — Return confirms, Esc (the ✕) cancels.
//

import SwiftUI

// MARK: - Confirmation Sheet

/// The confirmation card: a title and message over Cancel and the action.
/// `.confirmationSheet(isPresented:…)` presents it; present it yourself with
/// `.appSheet(item:contentSized: true)` to confirm something about one item.
/// It closes itself through `\.appSheetDismiss` — on Cancel, Esc, or after
/// running `onConfirm`.
///
/// The ✕ owns Esc and Cancel doesn't: two Esc bindings race. `style` puts a
/// status glyph beside the question, as an alert's icon does.
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                if let style {
                    BlissSymbol(style.defaultIcon)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(style.mark)
                        .accessibilityLabel(style.accessibilityName)
                }
                // `SheetHeader`'s title and subtitle.
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message)
                            .font(Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SheetCloseButton(action: cancel)
                    .offset(x: SheetCloseButton.cornerTuck, y: -SheetCloseButton.cornerTuck)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            HStack(spacing: Spacing.sm) {
                Spacer()
                Button(String(localized: cancelTitle), action: cancel)
                    .buttonStyle(SecondaryButtonStyle())
                confirmButton
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.lg)
        .frame(width: width)
    }

    @ViewBuilder
    private var confirmButton: some View {
        if isDestructive {
            Button(String(localized: confirmTitle), action: confirm)
                .buttonStyle(DestructiveButtonStyle(prominent: true))
        } else {
            Button(String(localized: confirmTitle), action: confirm)
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func cancel() {
        onCancel?()
        dismiss()
    }

    /// Closed first, so an action that opens another sheet stacks it over the
    /// page rather than over this card.
    private func confirm() {
        dismiss()
        onConfirm()
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
