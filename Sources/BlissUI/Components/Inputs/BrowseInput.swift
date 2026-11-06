//
//  BrowseInput.swift
//  BlissUI
//
//  Linear-inspired browse input:
//  - Path rendered as a `PathHoverChip` (hover → frosted droplet with Copy +
//    Open-in-Finder actions)
//  - Underline to match LargePaddedTextFieldStyle
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
    @Environment(\.colorScheme) private var colorScheme

    public init(
        path: String,
        placeholder: String = String(localized: "No folder selected"),
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
    public init(
        path: Binding<String>,
        placeholder: String = String(localized: "No folder selected"),
        icon: String = "folder",
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
    }

    /// Matches the muted underline of an unfocused LargePaddedTextFieldStyle.
    private var lineColor: Color {
        colorScheme == .dark ? Grey.grey600 : Grey.grey300
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            // Path — hovering morphs it into a droplet chip with Copy + Reveal.
            PathHoverChip(path: path, placeholder: placeholder)

            // The gap (≥ Spacing.sm) keeps the chip's hover actions clear of the
            // persistent browse button.
            Spacer(minLength: Spacing.sm)

            // Browse — text button on the trailing end of the underline.
            Button("Browse") {
                onBrowse()
            }
            .buttonStyle(SecondaryButtonStyle(compact: true, accent: true))
        }
        .padding(.vertical, Spacing.inlineSpacing + 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(lineColor)
                .frame(height: 1)
        }
    }
}

#Preview {
    @Previewable @State var boundPath = ""

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
            BrowseInput(path: $boundPath)
        }
    }
    .frame(width: 400)
}
