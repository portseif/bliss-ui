//
//  RoundedSection.swift
//  BlissUI
//
//  The settings / form card: a `bodySmall` secondary title above a rounded
//  card (`Sizing.radiusLarge`, a `Color.menuBorder` hairline, the raised
//  surface) with `Spacing.cardPadding` inside it, or divided rows at
//  `Spacing.listRowPadding` each. An optional footer caption sits under the
//  card at the header's inset.
//

import SwiftUI

// MARK: - Plain (chrome-less) environment flag

extension EnvironmentValues {
    /// When true, `RoundedSection` drops its card chrome (fill + border + horizontal
    /// inset) and renders flat. Use it when embedding sections inside an outer
    /// card of your own so they don't nest card-in-card. Defaults to false, so
    /// every other call site is unchanged.
    @Entry public var roundedSectionPlain: Bool = false
}

// MARK: - Rounded Section

/// A reusable rounded section container with optional header and footer.
/// Use for grouping related content on a card with a hairline.
/// Set `divided: true` to add dividers between child views.
public struct RoundedSection<Content: View, Header: View, Footer: View>: View {
    let content: Content
    let header: Header?
    let footer: Footer?
    var showHeader: Bool = true
    let divided: Bool
    /// Whether the header lines up with the content inside the card (inset by
    /// `padding`) or with the card's own edge.
    var insetsHeader: Bool = true
    /// The card's inset; 0 lets a table or a code block run edge to edge.
    var padding: CGFloat = Spacing.cardPadding
    /// Overrides the hairline color — the "this section is confirmed" signal
    /// (e.g. `Success.tint.opacity(0.3)` after a connection test passes).
    /// Deliberately border-only: a full status FILL would out-weight the
    /// section's own controls, and status elsewhere in BlissUI is carried by
    /// tints, dots and inline text, never by flooding a surface.
    var borderTint: Color? = nil
    /// An accessory on the header line, space-between with the title: an
    /// "Edit" ghost button, a toggle.
    var headerTrailing: AnyView? = nil
    @Environment(\.colorScheme) private var colorScheme
    /// When set by an ancestor, render flat (no fill/border/horizontal inset).
    @Environment(\.roundedSectionPlain) private var isPlain

    /// The dark card's lift over whatever pane it sits on.
    private static var darkFillOpacity: Double { 0.04 }

    private var backgroundColor: Color {
        // Light: the theme's raised surface (cream under Low Glare), white for
        // System. Dark: a faint lift over whatever pane it sits on.
        colorScheme == .dark ? Color.white.opacity(Self.darkFillOpacity) : (ThemeColors.activePalette?.elevatedBackground.color ?? .white)
    }

    private var borderColor: Color {
        borderTint ?? Color.menuBorder
    }

    /// - Parameters:
    ///   - divided: A divider between each child view.
    ///   - borderTint: Overrides the hairline color.
    ///   - insetsHeader: Lines the header up with the content inside the card;
    ///     false puts it flush with the card's edge, like a heading above it.
    ///   - padding: The card's inset; 0 for content that runs edge to edge.
    ///   - content: The section's rows.
    ///   - header: The title above the card.
    ///   - footer: A caption under the card ("Changes apply on relaunch").
    public init(
        divided: Bool = false,
        borderTint: Color? = nil,
        insetsHeader: Bool = true,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
        self.showHeader = true
        self.divided = divided
        self.insetsHeader = insetsHeader
        self.padding = padding
        self.borderTint = borderTint
    }

    private var inset: CGFloat { isPlain ? 0 : padding }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.inlineSpacing) {
            if showHeader, let header {
                HStack(spacing: Spacing.sm) {
                    header
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.secondary)
                    if let headerTrailing {
                        Spacer(minLength: 0)
                        headerTrailing
                    }
                }
                .padding(.horizontal, isPlain || !insetsHeader ? 0 : padding)
            }

            if divided {
                _VariadicView.Tree(DividedVStackLayout()) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, inset)
                // Each row carries `Spacing.listRowPadding` of its own, so the
                // first and last sit `padding` from the edge, like the sides.
                .padding(.vertical, max(inset - Spacing.listRowPadding, 0))
                .background { card }
                .overlay { hairline }
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // The same inset on every side.
                .padding(inset)
                .background { card }
                .overlay { hairline }
            }

            if let footer {
                footer
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, isPlain || !insetsHeader ? 0 : padding)
            }
        }
    }

    @ViewBuilder
    private var card: some View {
        if !isPlain {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(backgroundColor)
        }
    }

    @ViewBuilder
    private var hairline: some View {
        if !isPlain {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
    }

    /// The section with an accessory on its header line.
    public func headerTrailing<Trailing: View>(@ViewBuilder _ trailing: () -> Trailing) -> RoundedSection {
        var section = self
        section.headerTrailing = AnyView(trailing())
        return section
    }
}

// MARK: - Convenience Initializers

extension RoundedSection where Footer == EmptyView {
    /// A section with a custom header and no footer.
    public init(
        divided: Bool = false,
        borderTint: Color? = nil,
        insetsHeader: Bool = true,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.content = content()
        self.header = header()
        self.footer = nil
        self.showHeader = true
        self.divided = divided
        self.insetsHeader = insetsHeader
        self.padding = padding
        self.borderTint = borderTint
    }
}

extension RoundedSection where Header == Text {
    /// A section with a string title and a footer caption under the card.
    public init(
        _ title: LocalizedStringKey,
        divided: Bool = false,
        borderTint: Color? = nil,
        insetsHeader: Bool = true,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = Text(title)
        self.footer = footer()
        self.showHeader = true
        self.divided = divided
        self.insetsHeader = insetsHeader
        self.padding = padding
        self.borderTint = borderTint
    }
}

extension RoundedSection where Header == Text, Footer == EmptyView {
    /// Initialize with a simple string title. `insetsHeader: false` puts the
    /// title flush with the card's edge instead of in line with its content.
    public init(
        _ title: LocalizedStringKey,
        divided: Bool = false,
        borderTint: Color? = nil,
        insetsHeader: Bool = true,
        padding: CGFloat = Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.header = Text(title)
        self.footer = nil
        self.showHeader = true
        self.divided = divided
        self.insetsHeader = insetsHeader
        self.padding = padding
        self.borderTint = borderTint
    }
}

extension RoundedSection where Header == EmptyView, Footer == EmptyView {
    /// Initialize without a header
    public init(divided: Bool = false, borderTint: Color? = nil, padding: CGFloat = Spacing.cardPadding, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.header = nil
        self.footer = nil
        self.showHeader = false
        self.divided = divided
        self.padding = padding
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
                    .padding(.vertical, Spacing.listRowPadding)

                if child.id != last {
                    Divider()
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("With String Header", traits: .fixedLayout(width: 420, height: 300)) {
    VStack(spacing: Spacing.lg) {
        RoundedSection("Window Settings") {
            Toggle("Keep window on top", isOn: .constant(false)).toggleStyle(.flatSwitch(showsLabel: true))
            Toggle("Launch at login", isOn: .constant(true)).toggleStyle(.flatSwitch(showsLabel: true))
        } footer: {
            Text("Changes apply on relaunch.")
        }

        RoundedSection("File Browser") {
            Toggle("Show hidden files", isOn: .constant(false)).toggleStyle(.flatSwitch(showsLabel: true))
        }
        .headerTrailing {
            Button("Reset") {}.buttonStyle(GhostButtonStyle(compact: true, hugsLabel: true))
        }
    }
    .padding()
}

#Preview("With Custom Header", traits: .fixedLayout(width: 420, height: 160)) {
    RoundedSection {
        Toggle("Show hidden files", isOn: .constant(false)).toggleStyle(.flatSwitch(showsLabel: true))
    } header: {
        HStack(spacing: Spacing.xs) {
            Text("File Browser")
            Image(systemName: "info.circle")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

#Preview("Edge to edge", traits: .fixedLayout(width: 420, height: 200)) {
    RoundedSection("Members", padding: 0) {
        VStack(spacing: 0) {
            ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing"], id: \.self) { name in
                PersonRow(name: name, detail: "Editor")
                    .padding(.horizontal, Spacing.cardPadding)
                    .padding(.vertical, Spacing.listRowPadding)
            }
        }
    }
    .padding()
}

#Preview("Divided Section", traits: .fixedLayout(width: 420, height: 260)) {
    RoundedSection("Tools", divided: true) {
        ForEach(["Xcode", "Homebrew", "Git"], id: \.self) { tool in
            HStack {
                Image(systemName: "hammer")
                VStack(alignment: .leading) {
                    Text(verbatim: tool)
                    Text("Developer tool")
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Success.success500)
            }
        }
    }
    .padding()
}
