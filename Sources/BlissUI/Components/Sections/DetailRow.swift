//
//  DetailRow.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/4/25.
//

import SwiftUI

public struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String
    var monospace: Bool = false
    var isLink: Bool = false
    var isPath: Bool = false
    var copyable: Bool = false
    @State private var isHovering = false
    @State private var showCopied = false
    @Environment(\.openURL) private var openURL

    public init(
        label: LocalizedStringKey,
        value: String,
        monospace: Bool = false,
        isLink: Bool = false,
        isPath: Bool = false,
        copyable: Bool = false
    ) {
        self.label = label
        self.value = value
        self.monospace = monospace
        self.isLink = isLink
        self.isPath = isPath
        self.copyable = copyable
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            if isLink {
                let urlString =
                    value.hasPrefix("http://") || value.hasPrefix("https://")
                    ? value : "https://\(value)"
                TextLink(
                    value,
                    font: .system(size: 12, design: monospace ? .monospaced : .default),
                    truncationMode: .middle
                ) {
                    if let url = URL(string: urlString) { openURL(url) }
                }
            } else if isPath {
                PathHoverChip(path: value, monospaced: true)
            } else {
                Text(value)
                    .font(monospace ? Typography.codeSmall : Typography.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            Spacer()

            // Path rows carry their own Copy action inside the hover chip; the
            // standalone copy button is only for non-path copyable values.
            if copyable && !isPath {
                CopyButton(value: value, showCopied: $showCopied)
                    .opacity(isHovering ? 1 : 0)
                    .disabled(!isHovering)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Animations.hover) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Copy Button

/// Small hover-highlight copy affordance. Its own type (not private to
/// `DetailRow`) so other surfaces can reuse it — a stat row, a key field.
public struct CopyButton: View {
    let value: String
    @Binding var showCopied: Bool
    /// A secret goes through `SecretClipboard` (Touch ID when asked for, concealed
    /// from clipboard managers, cleared after a minute).
    var isSecret = false
    @State private var isButtonHovering = false

    public init(value: String, showCopied: Binding<Bool>, isSecret: Bool = false) {
        self.value = value
        self._showCopied = showCopied
        self.isSecret = isSecret
    }

    public var body: some View {
        Button {
            Task {
                if isSecret {
                    guard await SecretClipboard.copy(value, reason: String(localized: "copy a secret", bundle: .module)) else { return }
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            }
        } label: {
            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                .font(Typography.captionTiny)
                .foregroundStyle(showCopied ? Success.success500 : isButtonHovering ? Color.accent : .secondary)
                .frame(width: 18, height: 18)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isButtonHovering && !showCopied ? Color.accent.opacity(0.1) : .clear)
                }
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall))
        .onHover { hovering in
            withAnimation(Animations.hover) {
                isButtonHovering = hovering
            }
        }
        .accessibilityLabel(Text("Copy", bundle: .module))
    }
}

#Preview("Detail Row", traits: .fixedLayout(width: 400, height: 150)) {
    VStack(spacing: 8) {
        DetailRow(label: "Type", value: "Swift Package")
        DetailRow(label: "Path", value: "/Users/test/Documents", monospace: true, copyable: true)
        DetailRow(label: "URL", value: "example.com", isLink: true)
    }
    .padding()
}

