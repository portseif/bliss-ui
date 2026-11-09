//
//  DropZone.swift
//  BlissUI
//
//  A file drop target: a dashed card that lights up in the accent while a drag
//  hovers it, and (by default) doubles as a Browse button — click it, or press
//  Space / Return with it focused, and an `NSOpenPanel` opens with the same
//  file rules the drop enforces. One control, one Tab stop: the Browse call to
//  action is drawn inside the card rather than nested as a second button, so
//  Tab lands once and VoiceOver reads one button.
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
public struct DropZone: View {
    private let title: LocalizedStringKey
    private let hint: LocalizedStringKey?
    private let systemImage: String
    private let allowedContentTypes: [UTType]
    private let allowsMultiple: Bool
    private let canChooseDirectories: Bool
    private let allowsBrowsing: Bool
    private let onDrop: ([URL]) -> Void

    @State private var isTargeted = false
    @State private var isHovering = false

    /// - Parameters:
    ///   - title: What to drop ("Drop files here").
    ///   - hint: The rules in a line ("PNG or JPEG, up to 10 MB").
    ///   - systemImage: The glyph above the title.
    ///   - allowedContentTypes: Dropped and browsed files must conform to one
    ///     of these; empty takes any file.
    ///   - allowsMultiple: Take every item dropped, or only the first.
    ///   - canChooseDirectories: Folders count too (dropped or browsed).
    ///   - allowsBrowsing: Clicking the zone (or Space / Return) opens an
    ///     `NSOpenPanel` with the same rules.
    ///   - onDrop: The accepted URLs, never empty.
    public init(
        _ title: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        systemImage: String = "arrow.down.doc",
        allowedContentTypes: [UTType] = [],
        allowsMultiple: Bool = true,
        canChooseDirectories: Bool = false,
        allowsBrowsing: Bool = true,
        onDrop: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.hint = hint
        self.systemImage = systemImage
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultiple = allowsMultiple
        self.canChooseDirectories = canChooseDirectories
        self.allowsBrowsing = allowsBrowsing
        self.onDrop = onDrop
    }

    public var body: some View {
        Group {
            if allowsBrowsing {
                Button(action: browse) { card }
                    .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusLarge))
            } else {
                card
                    .accessibilityElement(children: .combine)
            }
        }
        .onHover { isHovering = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            let accepted = accept(urls)
            guard !accepted.isEmpty else { return false }
            onDrop(accepted)
            return true
        } isTargeted: { isTargeted = $0 }
        .animation(Animations.hover, value: isTargeted)
        .animation(Animations.hover, value: isHovering)
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(Typography.displaySmall)
                .foregroundStyle(isTargeted ? Color.accent : Color.secondary)
                .accessibilityHidden(true)

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
                // The call to action, drawn (not a nested button) so the zone
                // stays one control. Accent only on hover, like a link.
                Text("Browse", bundle: .module)
                    .font(Typography.labelMedium)
                    .foregroundStyle(isHovering ? Color.accent : Color.secondary)
                    .underline(isHovering, pattern: .dot)
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(isTargeted ? Color.accent.opacity(0.06) : Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accent : Color.menuBorder,
                    style: StrokeStyle(lineWidth: 1, dash: isTargeted ? [] : [4])
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
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

// MARK: - Preview

#Preview("Drop zone", traits: .fixedLayout(width: 480, height: 220)) {
    DropZone("Drop images here", hint: "PNG or JPEG, up to 10 MB", systemImage: "photo.on.rectangle", allowedContentTypes: [.png, .jpeg]) { _ in }
        .padding(Spacing.xl)
}

#Preview("Drop only", traits: .fixedLayout(width: 480, height: 220)) {
    DropZone("Drop a folder here", hint: "Its files are imported in place", systemImage: "folder", allowsMultiple: false, canChooseDirectories: true, allowsBrowsing: false) { _ in }
        .padding(Spacing.xl)
}
