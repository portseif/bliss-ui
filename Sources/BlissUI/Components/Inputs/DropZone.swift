//
//  DropZone.swift
//  BlissUI
//
//  A file drop target: a dashed card that lights up in the accent while a drag
//  hovers it, with (by default) a Browse button inside, the way an empty state
//  carries its action: it opens an `NSOpenPanel` with the same file rules the
//  drop enforces, and it's the card's one Tab stop.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A drop target for files and folders, with a browse panel as the keyboard
/// and pointer alternative.
///
/// ```swift
/// DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", allowedContentTypes: [.png, .jpeg]) { urls in
///     import(urls)
/// }
/// ```
///
/// Inside a `FormField` with an error the dashed border turns red, like every
/// boxed input.
public struct DropZone: View {
    private let title: LocalizedStringKey
    private let hint: LocalizedStringKey?
    private let systemImage: String
    private let allowedContentTypes: [UTType]
    private let allowsMultiple: Bool
    private let canChooseDirectories: Bool
    private let allowsBrowsing: Bool
    private let compact: Bool
    private let isLoading: Bool
    private let onDrop: ([URL]) -> Void

    @State private var isTargeted = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.formFieldIsInvalid) private var isInvalid

    /// - Parameters:
    ///   - title: What to drop ("Drop files here").
    ///   - hint: The rules in a line ("PNG or JPEG, up to 10 MB").
    ///   - systemImage: The glyph above the title.
    ///   - allowedContentTypes: Dropped and browsed files must conform to one
    ///     of these; empty takes any file.
    ///   - allowsMultiple: Take every item dropped, or only the first.
    ///   - canChooseDirectories: Folders count too (dropped or browsed).
    ///   - allowsBrowsing: A Browse button in the card opens an
    ///     `NSOpenPanel` with the same rules.
    ///   - compact: One line — glyph, title, hint and Browse across — at
    ///     `Sizing.controlLarge`, for a composer footer or an inspector.
    ///   - isLoading: An import in flight: a spinner replaces the glyph, drops
    ///     are refused and Browse is off.
    ///   - onDrop: The accepted URLs, never empty.
    public init(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        systemImage: String = "arrow.down.doc",
        allowedContentTypes: [UTType] = [],
        allowsMultiple: Bool = true,
        canChooseDirectories: Bool = false,
        allowsBrowsing: Bool = true,
        compact: Bool = false,
        isLoading: Bool = false,
        onDrop: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.hint = hint
        self.systemImage = systemImage
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultiple = allowsMultiple
        self.canChooseDirectories = canChooseDirectories
        self.allowsBrowsing = allowsBrowsing
        self.compact = compact
        self.isLoading = isLoading
        self.onDrop = onDrop
    }

    public var body: some View {
        card
            .accessibilityElement(children: .contain)
            .accessibilityValue(isLoading ? Text("Loading", bundle: .module) : Text(verbatim: ""))
            .dropDestination(for: URL.self) { urls, _ in
                guard !isLoading else { return false }
                let accepted = accept(urls)
                guard !accepted.isEmpty else { return false }
                onDrop(accepted)
                return true
            } isTargeted: { isTargeted = $0 && !isLoading }
            .animation(Animations.hover, value: isTargeted)
    }

    // MARK: - Card

    @ViewBuilder
    private var card: some View {
        if compact {
            HStack(spacing: Spacing.sm) {
                glyph(font: Typography.labelMedium)
                Text(title)
                    .font(Typography.bodySmallSemibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let hint {
                    Text(hint)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Spacing.sm)
                if allowsBrowsing {
                    browseButton
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Sizing.controlLarge)
            .background { background }
            .overlay { border }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
        } else {
            VStack(spacing: Spacing.sm) {
                glyph(font: Typography.displaySmall)

                VStack(spacing: Spacing.xxs) {
                    Text(title)
                        .font(Typography.bodySmallSemibold)
                        .foregroundStyle(.primary)
                    if let hint {
                        Text(hint)
                            .font(Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)

                if allowsBrowsing {
                    browseButton
                        .padding(.top, Spacing.xxs)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, minHeight: DropZoneMetrics.minimumHeight)
            .background { background }
            .overlay { border }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
        }
    }

    /// The glyph, or the spinner while an import runs.
    @ViewBuilder
    private func glyph(font: Font) -> some View {
        if isLoading {
            ThinkingSpinner(size: compact ? Sizing.iconDefault : Sizing.iconMedium)
                .accessibilityHidden(true)
        } else {
            Image(systemName: systemImage)
                .font(font)
                .foregroundStyle(isTargeted ? Color.accent : Color.secondary)
                .accessibilityHidden(true)
        }
    }

    /// The keyboard and pointer way in, the button an empty state carries.
    private var browseButton: some View {
        Button(String(localized: "Browse", bundle: .module), action: browse)
            .buttonStyle(SecondaryButtonStyle(compact: true))
            .disabled(isLoading)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
            .fill(isTargeted ? StatusWash.fill(Color.accent, colorScheme) : Color.restingFill)
    }

    private var borderColor: Color {
        if isInvalid { return Danger.danger500 }
        return isTargeted ? Color.accent : Color.menuBorder
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
            .strokeBorder(
                borderColor,
                style: StrokeStyle(lineWidth: 1, dash: isTargeted || isInvalid ? [] : [Spacing.xxs])
            )
    }

    // MARK: - Files

    /// The dropped URLs that pass the zone's rules, in order; only the first
    /// when the zone takes one.
    private func accept(_ urls: [URL]) -> [URL] {
        let passing = urls.filter(allows)
        guard allowsMultiple else { return Array(passing.prefix(1)) }
        return passing
    }

    private func allows(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        if values?.isDirectory == true { return canChooseDirectories }
        guard !allowedContentTypes.isEmpty else { return true }
        guard let type = values?.contentType else { return false }
        return allowedContentTypes.contains { type.conforms(to: $0) }
    }

    /// The pointer and keyboard way in: an open panel with the drop's rules.
    private func browse() {
        guard !isLoading else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = allowsMultiple
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        guard panel.runModal() == .OK else { return }
        let accepted = accept(panel.urls)
        if !accepted.isEmpty { onDrop(accepted) }
    }
}

private enum DropZoneMetrics {
    /// The full card's floor: room for the glyph, two lines and Browse.
    static let minimumHeight: CGFloat = 140
}

// MARK: - Preview

#Preview("Drop zone", traits: .fixedLayout(width: 480, height: 220)) {
    DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", systemImage: "photo.on.rectangle", allowedContentTypes: [.png, .jpeg]) { _ in }
        .padding(Spacing.xl)
}

#Preview("Drop only", traits: .fixedLayout(width: 480, height: 220)) {
    DropZone("Drop a folder here", hint: "Its files are imported in place", systemImage: "folder", allowsMultiple: false, canChooseDirectories: true, allowsBrowsing: false) { _ in }
        .padding(Spacing.xl)
}

#Preview("Compact and loading", traits: .fixedLayout(width: 480, height: 160)) {
    VStack(spacing: Spacing.md) {
        DropZone("Attach files", hint: "Up to 25 MB", systemImage: "paperclip", compact: true) { _ in }
        DropZone("Importing…", systemImage: "photo.on.rectangle", compact: true, isLoading: true) { _ in }
    }
    .padding(Spacing.xl)
}
