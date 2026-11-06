//
//  ConfirmationSheet.swift
//  BlissUI
//
//  "Are you sure?" as an app sheet, in place of `.alert` and
//  `.confirmationDialog`: a `SheetHeader` with the question and what it means,
//  over the compact `ActionBar` — Cancel beside the action, Return confirms,
//  Esc cancels.
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
public struct ConfirmationSheet: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?
    private let confirmTitle: LocalizedStringResource
    private let isDestructive: Bool
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void

    @Environment(\.appSheetDismiss) private var dismiss

    /// - Parameters:
    ///   - title: The question ("Delete 3 Items?"). Looked up in your app's strings.
    ///   - message: What happens, and whether it can be undone.
    ///   - confirmTitle: The action's label ("Delete"). Looked up in your app's strings.
    ///   - isDestructive: Draws the action as the destructive button.
    ///   - onCancel: Runs on Cancel or Esc, before the sheet closes.
    ///   - onConfirm: Runs on the action or Return; the sheet closes first.
    public init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        confirmTitle: LocalizedStringResource,
        isDestructive: Bool = false,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: title, subtitle: message)
            ActionBar(
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
            // The header's bottom padding already parts the buttons from the
            // message.
            .padding(.top, -Spacing.sm)
        }
        .frame(width: Sizing.sheetWidthMedium)
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
    ///   - isDestructive: Draws the action as the destructive button.
    ///   - action: Runs when confirmed, after the sheet starts closing.
    public func confirmationSheet(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        confirmTitle: LocalizedStringResource,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        appSheet(isPresented: isPresented, contentSized: true) {
            ConfirmationSheet(
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                isDestructive: isDestructive,
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
        isDestructive: true
    ) {}
}
