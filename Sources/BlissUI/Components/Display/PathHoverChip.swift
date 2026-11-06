//
//  PathHoverChip.swift
//  BlissUI
//
//  A file-path label that morphs into a frosted "droplet" chip on hover —
//  revealing Copy and Open-in-Finder buttons that spring in from the trailing
//  edge (the macOS Tahoe Spotlight feel). Used by `BrowseInput` and the
//  read-only path rows in `DetailRow`. The code variant (`.code(_:onRun:)`)
//  shows a command in the code font with Copy and Run instead — a setup or
//  install command the user can copy or run in place.
//
//  Layout contract: the action buttons live *inside* the chip's hit frame and
//  the frosted halo extends only `Spacing.xs` beyond it — narrower than the
//  `Spacing.sm` gap a caller leaves before any trailing control. So a caller
//  can safely place a persistent Browse button after a `Spacer(minLength:)`
//  without the droplet ever overlapping it.
//

import AppKit
import SwiftUI

public struct PathHoverChip: View {
    let path: String
    var placeholder: String = String(localized: "No path", bundle: .module)
    var monospaced: Bool = false
    /// Whether to offer "Open in Finder". Turn off for paths that don't exist
    /// on disk yet (e.g. a folder that's only planned) — Copy stays.
    var canReveal: Bool = true
    /// Set by the code variant: the text is a command, not a path.
    var isCode: Bool = false
    /// The code variant's Run button; nil hides it.
    var onRun: (() -> Void)? = nil

    public init(
        path: String,
        placeholder: String = String(localized: "No path", bundle: .blissUI),
        monospaced: Bool = false,
        canReveal: Bool = true
    ) {
        self.path = path
        self.placeholder = placeholder
        self.monospaced = monospaced
        self.canReveal = canReveal
    }

    /// A command in the code font, with Copy and (when `onRun` is set) Run.
    public static func code(_ command: String, onRun: (() -> Void)? = nil) -> PathHoverChip {
        var chip = PathHoverChip(path: command, canReveal: false)
        chip.isCode = true
        chip.onRun = onRun
        return chip
    }

    /// The hover buttons' glyph size; with `HoverIconButton`'s padding, the
    /// height the chip keeps at rest so they don't grow it (and shift the rows
    /// around it) when they appear.
    private static let actionGlyphSize: CGFloat = 11
    private static let actionHeight: CGFloat = actionGlyphSize + 6

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var justCopied = false

    private var hasPath: Bool { !path.isEmpty }

    /// The chip only "comes alive" when there's a real path to act on — empty
    /// fields just show their placeholder with no droplet.
    private var isActive: Bool { isHovering && hasPath }

    private var pathFont: Font {
        if isCode { return Typography.codeSmall }
        return monospaced ? Typography.code : Typography.labelMedium
    }

    private var copyHelp: String {
        isCode ? String(localized: "Copy command", bundle: .module) : String(localized: "Copy path", bundle: .module)
    }

    private var textColor: Color {
        guard hasPath else { return Grey.grey500 }
        return colorScheme == .dark ? .white : Grey.grey900
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    public var body: some View {
        HStack(spacing: Spacing.xxs - 1) {
            Text(hasPath ? path : placeholder)
                .font(pathFont)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.middle)

            if isActive {
                HoverIconButton(
                    systemImage: justCopied ? "checkmark" : "doc.on.doc",
                    size: Self.actionGlyphSize,
                    tint: justCopied ? Success.success500 : nil,
                    help: justCopied ? String(localized: "Copied", bundle: .module) : copyHelp,
                    action: copyPath
                )
                .transition(dropletInsertion(delay: 0))

                if let onRun {
                    HoverIconButton(
                        systemImage: "play.fill",
                        size: Self.actionGlyphSize,
                        help: String(localized: "Run in terminal", bundle: .module),
                        action: onRun
                    )
                    .transition(dropletInsertion(delay: 0.04))
                }

                if canReveal {
                    HoverIconButton(
                        systemImage: "arrow.up.forward.app",
                        size: Self.actionGlyphSize,
                        help: String(localized: "Open in Finder", bundle: .module),
                        action: reveal
                    )
                    .transition(dropletInsertion(delay: 0.04))
                }
            }
        }
        .frame(minHeight: Self.actionHeight)
        // Inner padding gives the glass a comfortable inset...
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .opacity(isActive ? 1 : 0)
                .scaleEffect(isActive ? 1 : 0.92)
        }
        .contentShape(Rectangle())
        // The buttons only appear under the pointer; VoiceOver reaches them here.
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if hasPath {
                Button(copyHelp) { copyPath() }
                if let onRun { Button(String(localized: "Run in terminal", bundle: .module), action: onRun) }
                if canReveal { Button(String(localized: "Open in Finder", bundle: .module)) { reveal() } }
            }
        }
        .onHover { hovering in
            // Blooms in on the droplet spring; leaves on the quick exit so it
            // doesn't bounce on the way out.
            withAnimation(hovering ? Animations.droplet : Animations.exit) { isHovering = hovering }
        }
        // ...then a matching negative pad cancels the footprint, so the frosted
        // chip reads as a halo around the text without shifting siblings.
        .padding(.horizontal, -Spacing.xs)
        .padding(.vertical, -Spacing.xxs)
    }

    /// Buttons bloom in from their trailing edge with a bouncy spring, lightly
    /// staggered so the pair cascades rather than popping in lockstep.
    private func dropletInsertion(delay: Double) -> AnyTransition {
        .motion(.scale(scale: 0.65, anchor: .trailing).combined(with: .opacity))
            .animation(Animations.droplet.delay(delay))
    }

    private func copyPath() {
        guard hasPath else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        withAnimation(Animations.hover) { justCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Animations.hover) { justCopied = false }
        }
    }

    private func reveal() {
        guard hasPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

#Preview {
    SettingsForm {
        RoundedSection("With Path") {
            HStack {
                PathHoverChip(path: "/Users/you/Developer/BlissUI/Sources")
                Spacer(minLength: Spacing.sm)
            }
        }
        RoundedSection("Monospaced") {
            HStack {
                PathHoverChip(path: "/opt/homebrew/bin/git", monospaced: true)
                Spacer(minLength: Spacing.sm)
            }
        }
        RoundedSection("Command") {
            HStack {
                PathHoverChip.code("swift package resolve --skip-update", onRun: {})
                Spacer(minLength: Spacing.sm)
            }
        }
        RoundedSection("Empty") {
            HStack {
                PathHoverChip(path: "", placeholder: "Auto-detect from system PATH")
                Spacer(minLength: Spacing.sm)
            }
        }
    }
    .frame(width: 420)
}
