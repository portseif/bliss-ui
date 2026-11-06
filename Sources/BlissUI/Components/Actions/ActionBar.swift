//
//  ActionBar.swift
//  BlissUI
//
//  The footer for sheets and modals: an optional leading accessory, then
//  Cancel beside the confirm action on the trailing edge.
//

import SwiftUI

    /// A bottom action bar for sheets and modals with cancel/confirm buttons.
    /// Compact buttons and `Spacing.lg` padding, like every other sheet footer.
public struct ActionBar: View {
    let cancelTitle: String?
    let confirmTitle: String
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void
    var isConfirmDisabled: Bool = false
    var isDestructive: Bool = false
    var material: Material = .ultraThinMaterial
    var useKeyboardShortcuts: Bool = false
    /// Esc on the cancel button. Off when it reads "Back": the sheet's ✕ owns
    /// Esc, and two Esc bindings race (whichever is found first fires).
    var cancelUsesEscape: Bool = true
    var showBackground: Bool = true
    /// Optional content pinned at the leading edge (e.g. a "Reset to Defaults"
    /// button or a keyboard-hint cluster).
    var leadingContent: AnyView? = nil

    public init(
        cancelTitle: String? = String(localized: "Cancel", bundle: .blissUI),
        confirmTitle: String = String(localized: "Save", bundle: .blissUI),
        isConfirmDisabled: Bool = false,
        isDestructive: Bool = false,
        material: Material = .ultraThinMaterial,
        useKeyboardShortcuts: Bool = false,
        cancelUsesEscape: Bool = true,
        showBackground: Bool = true,
        leadingContent: AnyView? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.isDestructive = isDestructive
        self.material = material
        self.useKeyboardShortcuts = useKeyboardShortcuts
        self.cancelUsesEscape = cancelUsesEscape
        self.showBackground = showBackground
        self.leadingContent = leadingContent
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    // Cancel sits beside the action, as in every other sheet footer, so the
    // pointer finds it in the same place on each sheet.
    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if let leadingContent {
                leadingContent
            }
            Spacer()
            if let cancelTitle, let onCancel {
                cancelButton(title: cancelTitle, action: onCancel)
            }
            confirmButton
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(showBackground ? AnyShapeStyle(material) : AnyShapeStyle(.clear))
    }

    @ViewBuilder
    private func cancelButton(title: String, action: @escaping () -> Void) -> some View {
        if useKeyboardShortcuts && cancelUsesEscape {
            Button(title, action: action)
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .keyboardShortcut(.cancelAction)
        } else {
            Button(title, action: action)
                .buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }

    /// The confirm button with its style + disabled state, before any shortcut.
    @ViewBuilder
    private var styledConfirmButton: some View {
        Group {
            if isDestructive {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(DestructiveButtonStyle(compact: true))
            } else {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
        .disabled(isConfirmDisabled)
        .opacity(isConfirmDisabled ? 0.6 : 1)
    }

    @ViewBuilder
    private var confirmButton: some View {
        if useKeyboardShortcuts {
            styledConfirmButton
                .keyboardShortcut(.defaultAction)
        } else {
            styledConfirmButton
        }
    }
}

    // MARK: - Convenience Initializers

extension ActionBar {
        /// Simple cancel/confirm action bar
    public static func cancelConfirm(
        confirmTitle: String = String(localized: "Save", bundle: .blissUI),
        isConfirmDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> ActionBar {
        ActionBar(
            confirmTitle: confirmTitle,
            isConfirmDisabled: isConfirmDisabled,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }
}

#Preview("Action Bar", traits: .fixedLayout(width: 400, height: 300)) {
    VStack {
        Spacer()

        ActionBar(
            confirmTitle: "Import",
            isConfirmDisabled: false,
            onCancel: { print("Cancel") },
            onConfirm: { print("Import") }
        )

        ActionBar(
            confirmTitle: "Save",
            isConfirmDisabled: true,
            onCancel: { print("Cancel") },
            onConfirm: { print("Save") }
        )

        ActionBar(
            cancelTitle: "Back",
            confirmTitle: "Next",
            onCancel: { print("Back") },
            onConfirm: { print("Next") }
        )
    }
}

