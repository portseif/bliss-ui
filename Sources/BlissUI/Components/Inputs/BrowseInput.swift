//
//  BrowseInput.swift
//  BlissUI
//
//  Linear-inspired browse input:
//  - Path rendered as a `PathHoverChip` (hover → frosted droplet with Copy +
//    Open-in-Finder actions)
//  - Underline to match LargePaddedTextFieldStyle, red inside a `FormField`
//    with an error
//  - Inline browse button, kept clear of the chip's hover actions by a gap
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A text display with a browse button for selecting folders or files.
///
/// Bind a path to get a standard `NSOpenPanel` on Browse, or pass `onBrowse`
/// to run your own panel (or any other picker) and set the path yourself.
public struct BrowseInput: View {
    let path: String
    let placeholder: String
    let icon: String
    let onBrowse: () -> Void
    /// Clears the bound path; nil hides the clear button.
    var onClear: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.formFieldIsInvalid) private var isInvalid
    @State private var isHovering = false

    /// - Parameters:
    ///   - path: The chosen path; empty shows the placeholder.
    ///   - placeholder: Shown while no path is chosen.
    ///   - icon: The SF Symbol before the path.
    ///   - onBrowse: Runs your own picker.
    public init(
        path: String,
        placeholder: String = String(localized: "No folder selected", bundle: .blissUI),
        icon: String = "folder",
        onBrowse: @escaping () -> Void
    ) {
        self.path = path
        self.placeholder = placeholder
        self.icon = icon
        self.onBrowse = onBrowse
    }

    /// Browse runs an `NSOpenPanel` (one item, opened at the current path) and
    /// writes the chosen item's path into `path`. Folders by default; set
    /// `canChooseFiles` (and optionally `allowedContentTypes`) to pick files.
    ///
    /// - Parameters:
    ///   - path: The chosen path; empty shows the placeholder.
    ///   - placeholder: Shown while no path is chosen.
    ///   - icon: The SF Symbol before the path.
    ///   - isClearable: A clear button while a path is chosen and the pointer
    ///     is on the row; it empties `path`.
    ///   - canChooseFiles: Files can be picked.
    ///   - canChooseDirectories: Folders can be picked.
    ///   - allowedContentTypes: Picked files must conform to one of these.
    public init(
        path: Binding<String>,
        placeholder: String = String(localized: "No folder selected", bundle: .blissUI),
        icon: String = "folder",
        isClearable: Bool = false,
        canChooseFiles: Bool = false,
        canChooseDirectories: Bool = true,
        allowedContentTypes: [UTType] = []
    ) {
        self.init(path: path.wrappedValue, placeholder: placeholder, icon: icon) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = canChooseFiles
            panel.canChooseDirectories = canChooseDirectories
            panel.allowsMultipleSelection = false
            if !allowedContentTypes.isEmpty {
                panel.allowedContentTypes = allowedContentTypes
            }
            if !path.wrappedValue.isEmpty {
                panel.directoryURL = URL(fileURLWithPath: path.wrappedValue)
            }
            if panel.runModal() == .OK, let url = panel.url {
                path.wrappedValue = url.path
            }
        }
        if isClearable {
            onClear = { path.wrappedValue = "" }
        }
    }

    /// Matches the underline of an unfocused `LargePaddedTextFieldStyle`: red
    /// inside a `FormField` with an error, the theme's border, else muted grey.
    private var lineColor: Color {
        if isInvalid { return Danger.danger500 }
        if let palette = ThemeColors.activePalette { return palette.border.color }
        return colorScheme == .dark ? Grey.grey600 : Grey.grey300
    }

    private var showsClear: Bool {
        onClear != nil && !path.isEmpty && isHovering
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(Typography.labelMedium)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            // Path — hovering morphs it into a droplet chip with Copy + Reveal.
            PathHoverChip(path: path, placeholder: placeholder)

            // The gap (≥ Spacing.sm) keeps the chip's hover actions clear of the
            // persistent browse button.
            Spacer(minLength: Spacing.sm)

            if let onClear {
                // Mounted even while hidden, so the layout never jumps; disabled
                // while hidden, or Tab would land on it unseen.
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: Sizing.inlineIconButton, height: Sizing.inlineIconButton)
                }
                .buttonStyle(InlineIconButtonStyle(chipRadius: Sizing.radiusSmall))
                .opacity(showsClear ? 1 : 0)
                .disabled(!showsClear)
                .allowsHitTesting(showsClear)
                .accessibilityLabel(Text("Clear", bundle: .module))
            }

            // Browse — a ghost button on the trailing end of the underline, the
            // compact control height so the row sits level with the fields.
            Button(String(localized: "Browse", bundle: .module)) {
                onBrowse()
            }
            .buttonStyle(GhostButtonStyle(compact: true))
        }
        .frame(minHeight: Sizing.controlDefault)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(lineColor)
                .frame(height: 1)
        }
        .onHover { isHovering = $0 }
        .animation(Animations.hover, value: showsClear)
    }
}

#Preview("Browse input", traits: .fixedLayout(width: 400, height: 420)) {
    @Previewable @State var boundPath = "/Users/me/Documents"

    SettingsForm {
        RoundedSection("Empty State") {
            BrowseInput(path: "", onBrowse: {})
        }
        RoundedSection("With Path") {
            BrowseInput(
                path: "/Users/me/Documents/Reports",
                onBrowse: {}
            )
        }
        RoundedSection("Custom Placeholder") {
            BrowseInput(
                path: "",
                placeholder: "Select a file...",
                icon: "doc",
                onBrowse: {}
            )
        }
        RoundedSection("Open Panel") {
            BrowseInput(path: $boundPath, isClearable: true)
        }
    }
}
