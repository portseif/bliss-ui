//
//  DetailRow.swift
//  BlissUI
//
//  A label column and a value: a detail pane's facts. The value is text, a
//  link, or a path chip; a copyable value shows the copy button on hover.
//

import SwiftUI

public struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String
    var monospace: Bool = false
    var isLink: Bool = false
    var isPath: Bool = false
    var copyable: Bool = false
    var labelWidth: CGFloat = Sizing.detailLabelWidth
    var isSecret: Bool = false
    var lineLimit: Int? = 1
    @State private var isHovering = false
    @State private var showCopied = false
    @Environment(\.openURL) private var openURL

    /// - Parameters:
    ///   - label: The fact's name, in the label column.
    ///   - value: The fact.
    ///   - monospace: The value in the code font (a path, an id).
    ///   - isLink: The value opens as a URL.
    ///   - isPath: The value is a file path, with Copy and Reveal on hover.
    ///   - copyable: A copy button on hover.
    ///   - labelWidth: The label column's width.
    ///   - isSecret: Copies through `SecretClipboard` (a key, a token).
    ///   - lineLimit: How many lines the value may take; nil wraps freely.
    public init(
        label: LocalizedStringKey,
        value: String,
        monospace: Bool = false,
        isLink: Bool = false,
        isPath: Bool = false,
        copyable: Bool = false,
        labelWidth: CGFloat = Sizing.detailLabelWidth,
        isSecret: Bool = false,
        lineLimit: Int? = 1
    ) {
        self.label = label
        self.value = value
        self.monospace = monospace
        self.isLink = isLink
        self.isPath = isPath
        self.copyable = copyable
        self.labelWidth = labelWidth
        self.isSecret = isSecret
        self.lineLimit = lineLimit
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color.textSecondary)
                .frame(width: labelWidth, alignment: .leading)

            if isLink {
                let urlString =
                    value.hasPrefix("http://") || value.hasPrefix("https://")
                    ? value : "https://\(value)"
                TextLink(
                    value,
                    font: monospace ? Typography.codeSmall : Typography.caption,
                    truncationMode: .middle
                ) {
                    if let url = URL(string: urlString) { openURL(url) }
                }
            } else if isPath {
                PathHoverChip(path: value, monospaced: true, compact: true)
            } else {
                Text(value)
                    .font(monospace ? Typography.codeSmall : Typography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            // Path rows carry their own Copy action inside the hover chip; the
            // standalone copy button is only for non-path copyable values.
            if copyable && !isPath {
                CopyButton(value: value, showCopied: $showCopied, isSecret: isSecret)
                    .opacity(isHovering ? 1 : 0)
                    .disabled(!isHovering)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Animations.hover) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Copy Button

/// The copy affordance: a bare glyph, quiet at rest and full-strength under
/// the pointer, that turns into a green check for a moment after copying. Its
/// own type (not private to `DetailRow`) so other surfaces can reuse it — a
/// stat row, a key field.
public struct CopyButton: View {
    let value: String
    @Binding var showCopied: Bool
    /// A secret goes through `SecretClipboard` (Touch ID when asked for, concealed
    /// from clipboard managers, cleared after a minute).
    var isSecret = false

    /// How long the check shows after a copy.
    public static let confirmationDuration: TimeInterval = 1.5

    public init(value: String, showCopied: Binding<Bool>, isSecret: Bool = false) {
        self.value = value
        self._showCopied = showCopied
        self.isSecret = isSecret
    }

    @State private var isHovering = false

    private var help: String {
        showCopied ? String(localized: "Copied", bundle: .module) : String(localized: "Copy", bundle: .module)
    }

    private var glyphColor: Color {
        if showCopied { return Success.success500 }
        return isHovering ? Color.textPrimary : Color.textTertiary
    }

    public var body: some View {
        Button(action: copy) {
            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                .font(Typography.labelXSmall)
                .foregroundStyle(glyphColor)
                .frame(width: Sizing.inlineIconButton, height: Sizing.inlineIconButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall))
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
        .tooltip(.verbatim(help))
        .accessibilityLabel(Text(verbatim: help))
    }

    private func copy() {
        Task {
            if isSecret {
                guard await SecretClipboard.copy(value, reason: String(localized: "copy a secret", bundle: .module)) else { return }
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            }
            withAnimation(Animations.hover) { showCopied = true }
            try? await Task.sleep(for: .seconds(Self.confirmationDuration))
            withAnimation(Animations.hover) { showCopied = false }
        }
    }
}

#Preview("Detail Row", traits: .fixedLayout(width: 400, height: 150)) {
    VStack(spacing: Spacing.sm) {
        DetailRow(label: "Type", value: "Swift Package")
        DetailRow(label: "Path", value: "/Users/test/Documents", monospace: true, copyable: true)
        DetailRow(label: "URL", value: "example.com", isLink: true)
        DetailRow(label: "API key", value: "sk-live-4f9e…", monospace: true, copyable: true, isSecret: true)
    }
    .padding()
}
