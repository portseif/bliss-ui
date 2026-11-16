//
//  ActionBar.swift
//  BlissUI
//
//  The footer for sheets and modals: an optional leading accessory, an
//  optional secondary action, then Cancel beside the confirm action on the
//  trailing edge.
//

import SwiftUI

    /// A bottom action bar for sheets and modals with cancel/confirm buttons.
    /// Compact buttons and `Spacing.lg` padding, like every other sheet footer;
    /// `compact: false` for a full-page footer with the regular buttons.
public struct ActionBar: View {
    let cancelTitle: String?
    let confirmTitle: String
    let onCancel: (() -> Void)?
    let onConfirm: () -> Void
    var isConfirmDisabled: Bool = false
    var isConfirmLoading: Bool = false
    var isDestructive: Bool = false
    var compact: Bool = true
    var material: Material = .ultraThinMaterial
    @Environment(\.colorScheme) private var colorScheme
    var useKeyboardShortcuts: Bool = false
    /// Esc on the cancel button. Off when it reads "Back": the sheet's ✕ owns
    /// Esc, and two Esc bindings race (whichever is found first fires).
    var cancelUsesEscape: Bool = true
    var showBackground: Bool = true
    /// Optional content pinned at the leading edge (e.g. a "Reset to Defaults"
    /// button or a keyboard-hint cluster).
    var leadingContent: AnyView? = nil
    /// The third button of the save trio ("Don't Save"), leading the pair.
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    /// - Parameters:
    ///   - cancelTitle: The cancel button's label; nil hides it.
    ///   - confirmTitle: The action's label.
    ///   - isConfirmDisabled: Greys the action out.
    ///   - isConfirmLoading: A spinner in the action while it runs (`.buttonLoading`).
    ///   - isDestructive: Draws the action as the destructive button.
    ///   - compact: The 28pt buttons (a sheet); false for the regular ones (a page footer).
    ///   - material: The bar's material under System.
    ///   - useKeyboardShortcuts: Return confirms and Esc cancels.
    ///   - cancelUsesEscape: Whether Cancel takes Esc.
    ///   - showBackground: The bar's surface.
    ///   - leadingContent: Content pinned at the leading edge.
    ///   - secondaryTitle: A third action ("Don't Save"), leading the pair.
    ///   - onSecondary: What the third action does.
    ///   - onCancel: Cancel's action; nil hides the button.
    ///   - onConfirm: The action.
    public init(
        cancelTitle: String? = String(localized: "Cancel", bundle: .blissUI),
        confirmTitle: String = String(localized: "Save", bundle: .blissUI),
        isConfirmDisabled: Bool = false,
        isConfirmLoading: Bool = false,
        isDestructive: Bool = false,
        compact: Bool = true,
        material: Material = .ultraThinMaterial,
        useKeyboardShortcuts: Bool = false,
        cancelUsesEscape: Bool = true,
        showBackground: Bool = true,
        leadingContent: AnyView? = nil,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isConfirmDisabled = isConfirmDisabled
        self.isConfirmLoading = isConfirmLoading
        self.isDestructive = isDestructive
        self.compact = compact
        self.material = material
        self.useKeyboardShortcuts = useKeyboardShortcuts
        self.cancelUsesEscape = cancelUsesEscape
        self.showBackground = showBackground
        self.leadingContent = leadingContent
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
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
            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(SecondaryButtonStyle(compact: compact))
            }
            Spacer()
            if let cancelTitle, let onCancel {
                cancelButton(title: cancelTitle, action: onCancel)
            }
            confirmButton
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(barBackground)
    }

    /// Under a color theme, the theme's tint over the surface it sits on (a
    /// system material reads as a gray band on a tinted sheet); else the material.
    private var barBackground: AnyShapeStyle {
        guard showBackground else { return AnyShapeStyle(.clear) }
        if ThemeColors.activePalette != nil { return AnyShapeStyle(RowTint.hover(colorScheme)) }
        return AnyShapeStyle(material)
    }

    @ViewBuilder
    private func cancelButton(title: String, action: @escaping () -> Void) -> some View {
        if useKeyboardShortcuts && cancelUsesEscape {
            Button(title, action: action)
                .buttonStyle(SecondaryButtonStyle(compact: compact))
                .keyboardShortcut(.cancelAction)
        } else {
            Button(title, action: action)
                .buttonStyle(SecondaryButtonStyle(compact: compact))
        }
    }

    /// The confirm button with its style, loading and disabled state, before
    /// any shortcut. The style draws the disabled look itself.
    @ViewBuilder
    private var styledConfirmButton: some View {
        Group {
            if isDestructive {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(DestructiveButtonStyle(compact: compact))
            } else {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(PrimaryButtonStyle(compact: compact))
            }
        }
        .buttonLoading(isConfirmLoading)
        .disabled(isConfirmDisabled)
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

#Preview("Action Bar", traits: .fixedLayout(width: 420, height: 340)) {
    VStack {
        Spacer()

        ActionBar(
            confirmTitle: "Import",
            isConfirmDisabled: false,
            onCancel: {},
            onConfirm: {}
        )

        ActionBar(
            confirmTitle: "Save",
            isConfirmDisabled: true,
            onCancel: {},
            onConfirm: {}
        )

        ActionBar(
            confirmTitle: "Saving",
            isConfirmLoading: true,
            onCancel: {},
            onConfirm: {}
        )

        ActionBar(
            cancelTitle: "Back",
            confirmTitle: "Next",
            secondaryTitle: "Don't Save",
            onSecondary: {},
            onCancel: {},
            onConfirm: {}
        )
    }
}
