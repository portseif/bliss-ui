//
//  RoundedSection.swift
//  BlissUI
//
//  iOS-inspired section container:
//  - Soft shadows instead of borders
//  - Clean, refined visual weight
//  - Consistent rounded corners (12px)
//

import SwiftUI

// MARK: - Plain (chrome-less) environment flag

private struct RoundedSectionPlainKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When true, `RoundedSection` drops its card chrome (fill + border + horizontal
    /// inset) and renders flat. Use it when embedding sections inside an outer
    /// card of your own so they don't nest card-in-card. Defaults to false, so
    /// every other call site is unchanged.
    public var roundedSectionPlain: Bool {
        get { self[RoundedSectionPlainKey.self] }
        set { self[RoundedSectionPlainKey.self] = newValue }
    }
}

// MARK: - Rounded Section

/// A reusable rounded section container with optional header
/// Use for grouping related content with a subtle background and shadow
/// Set `divided: true` to add dividers between child views
public struct RoundedSection<Content: View, Header: View>: View {
    let content: Content
    let header: Header?
    var showHeader: Bool = true
    let divided: Bool
    /// Overrides the hairline color — the "this section is confirmed" signal
    /// (e.g. `Success.tint.opacity(0.3)` after a connection test passes).
    /// Deliberately border-only: a full status FILL would out-weight the
    /// section's own controls, and status elsewhere in BlissUI is carried by
    /// tints, dots and inline text, never by flooding a surface.
    var borderTint: Color? = nil
    @Environment(\.colorScheme) private var colorScheme
    /// When set by an ancestor, render flat (no fill/border/horizontal inset).
    @Environment(\.roundedSectionPlain) private var isPlain

    private var backgroundColor: Color {
        // Light: the theme's raised surface (cream under Low Glare), white for
        // System. Dark: a faint lift over whatever pane it sits on.
        colorScheme == .dark ? Color.white.opacity(0.04) : (ThemeColors.activePalette?.elevatedBackground.color ?? .white)
    }

    private var borderColor: Color {
        borderTint ?? (colorScheme == .dark ? Grey.grey700 : Grey.grey200)
    }

    public init(
        divided: Bool = false,
        borderTint: Color? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.content = content()
        self.header = header()
        self.showHeader = true
        self.divided = divided
        self.borderTint = borderTint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.inlineSpacing) {
            if showHeader, let header {
                header
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, isPlain ? 0 : Spacing.md)
            }

            if divided {
                _VariadicView.Tree(DividedVStackLayout()) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isPlain ? 0 : Spacing.md)
                // Each row carries `Spacing.sm` of its own, so the first and last
                // sit `Spacing.md` from the edge, like the sides.
                .padding(.vertical, isPlain ? 0 : Spacing.md - Spacing.sm)
                .background {
                    if !isPlain {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .fill(backgroundColor)
                    }
                }
                .overlay {
                    if !isPlain {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.cardPadding) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The same inset on every side.
                .padding(isPlain ? 0 : Spacing.md)
                .background {
                    if !isPlain {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .fill(backgroundColor)
                    }
                }
                .overlay {
                    if !isPlain {
                        RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension RoundedSection where Header == Text {
    /// Initialize with a simple string title
    public init(
        _ title: LocalizedStringKey,
        divided: Bool = false,
        borderTint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.header = Text(title)
        self.showHeader = true
        self.divided = divided
        self.borderTint = borderTint
    }
}

extension RoundedSection where Header == EmptyView {
    /// Initialize without a header
    public init(divided: Bool = false, borderTint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.header = nil
        self.showHeader = false
        self.divided = divided
        self.borderTint = borderTint
    }
}

// MARK: - Divided VStack Layout

/// Layout that inserts dividers between variadic view children
private struct DividedVStackLayout: _VariadicView_UnaryViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(children) { child in
                child
                    .padding(.vertical, Spacing.sm)

                if child.id != last {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("With String Header") {
    VStack(spacing: 20) {
        RoundedSection("Window Settings") {
            Toggle("Keep window on top", isOn: .constant(false))
            Toggle("Launch at login", isOn: .constant(true))
        }

        RoundedSection("File Browser") {
            Toggle("Show hidden files", isOn: .constant(false))
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("With Custom Header") {
    RoundedSection {
        Toggle("Show hidden files", isOn: .constant(false))
    } header: {
        HStack(spacing: 6) {
            Text("File Browser")
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("Without Header") {
    RoundedSection {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
            Text("Documents")
            Spacer()
            Text("12")
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("Multiple Sections") {
    VStack(spacing: 16) {
        RoundedSection("Current Plan") {
            HStack {
                Text("Pro")
                    .font(.headline)
                Spacer()
                Text("$9/mo")
                    .foregroundStyle(.secondary)
            }
        }

        RoundedSection("Features") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Unlimited Storage", systemImage: "checkmark.circle.fill")
                Label("Sync Across Devices", systemImage: "checkmark.circle.fill")
                Label("Automatic Backups", systemImage: "checkmark.circle.fill")
            }
            .foregroundStyle(.green)
        }
    }
    .padding()
    .frame(width: 400)
}

#Preview("Divided Section") {
    VStack(spacing: 20) {
        RoundedSection("Tools", divided: true) {
            HStack {
                Image(systemName: "hammer")
                VStack(alignment: .leading) {
                    Text("Xcode")
                    Text("Apple developer tools")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("26.1")
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            HStack {
                Image(systemName: "shippingbox")
                VStack(alignment: .leading) {
                    Text("Homebrew")
                    Text("Package manager")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("4.6.3")
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            HStack {
                Image(systemName: "arrow.triangle.branch")
                VStack(alignment: .leading) {
                    Text("Git")
                    Text("Version control system")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("2.50.1")
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
    .padding()
    .frame(width: 400)
}
