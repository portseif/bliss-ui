//
//  Breadcrumbs.swift
//  BlissUI
//
//  A path — Projects › BlissUI › Sources › Layout — where every segment but the
//  last goes back to that level. The links hover like a title bar's back link
//  (`GhostButtonStyle(hugsLabel:)`: the text stays put and the fill bleeds
//  past it); the last segment, where you are, is plain primary text. When the
//  path doesn't fit, the middle folds into a "…" menu, from the oldest level
//  forward, and the first segment and the current one always stay.
//

import SwiftUI

/// A clickable path of segments.
///
/// ```swift
/// Breadcrumbs(folders, title: \.name, systemImage: { _ in "folder" }) { folder in
///     open(folder)
/// }
/// ```
///
/// Titles are shown as-is (folder and project names); pass a
/// `String(localized:)` for a fixed one.
public struct Breadcrumbs<Item>: View {
    private let items: [Item]
    private let title: (Item) -> String
    private let systemImage: ((Item) -> String?)?
    private let font: Font
    private let onSelect: (Item) -> Void

    /// Each segment's natural width, measured off-screen.
    @State private var segmentWidths: [Int: CGFloat] = [:]
    @State private var chevronWidth: CGFloat = 0
    @State private var overflowWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0
    @State private var isOverflowMenuPresented = false
    @State private var focusedMenuIndex: Int?

    /// - Parameters:
    ///   - items: The path, root first; the last is the current location.
    ///   - title: Each segment's text.
    ///   - systemImage: An SF Symbol before a segment's text, or nil for none.
    ///   - font: The segments' font.
    ///   - onSelect: A click on any segment but the last.
    public init(
        _ items: [Item],
        title: @escaping (Item) -> String,
        systemImage: ((Item) -> String?)? = nil,
        font: Font = Typography.bodySmall,
        onSelect: @escaping (Item) -> Void
    ) {
        self.items = items
        self.title = title
        self.systemImage = systemImage
        self.font = font
        self.onSelect = onSelect
    }

    /// The gap on each side of a chevron. Wide enough that neighboring links'
    /// hover fills (which bleed `Spacing.md` past their text) barely touch.
    private static var separatorSpacing: CGFloat { Spacing.sm }

    private var collapsed: Range<Int> {
        guard segmentWidths.count >= items.count, availableWidth > 0 else { return 0..<0 }
        return BreadcrumbCollapse.collapsedRange(
            widths: items.indices.map { segmentWidths[$0] ?? 0 },
            separatorWidth: chevronWidth + Self.separatorSpacing * 2,
            overflowWidth: overflowWidth,
            availableWidth: availableWidth
        )
    }

    public var body: some View {
        let collapsed = self.collapsed
        HStack(spacing: Self.separatorSpacing) {
            ForEach(slots(collapsed: collapsed), id: \.self) { slot in
                switch slot {
                case .segment(let index):
                    if index > 0 { chevron }
                    segment(at: index)
                case .overflow:
                    chevron
                    overflowButton(collapsed: collapsed)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .background(alignment: .leading) { measuringRow }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Breadcrumbs", bundle: .module))
    }

    // MARK: Slots

    private enum Slot: Hashable {
        case segment(Int)
        case overflow
    }

    /// First segment, then "…" in place of the collapsed ones, then the rest.
    private func slots(collapsed: Range<Int>) -> [Slot] {
        guard !collapsed.isEmpty else { return items.indices.map(Slot.segment) }
        return [.segment(0), .overflow] + (collapsed.upperBound..<items.count).map(Slot.segment)
    }

    // MARK: Pieces

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(Typography.captionTiny)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func label(at index: Int) -> some View {
        let item = items[index]
        return HStack(spacing: Spacing.xs) {
            if let symbol = systemImage?(item) {
                Image(systemName: symbol)
            }
            Text(verbatim: title(item))
        }
        .font(font)
        .lineLimit(1)
    }

    @ViewBuilder
    private func segment(at index: Int) -> some View {
        if index == items.count - 1 {
            // Where you are: plain text, and the one that truncates when even
            // the collapsed path doesn't fit.
            label(at: index)
                .foregroundStyle(.primary)
                .truncationMode(.middle)
        } else {
            let item = items[index]
            Button { onSelect(item) } label: {
                label(at: index)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(GhostButtonStyle(hugsLabel: true))
            .fixedSize()
        }
    }

    private func overflowButton(collapsed: Range<Int>) -> some View {
        Button {
            isOverflowMenuPresented.toggle()
        } label: {
            overflowLabel
        }
        .buttonStyle(GhostButtonStyle(hugsLabel: true))
        .fixedSize()
        .tooltip(configuration: .iconHint, position: .below) {
            Text("Show full path", bundle: .module).font(Typography.labelSmall)
        }
        .accessibilityLabel(Text("Show full path", bundle: .module))
        .floatingMenu(
            isPresented: $isOverflowMenuPresented,
            itemCount: collapsed.count,
            focusedIndex: $focusedMenuIndex,
            xPosition: .leading,
            yPosition: .below,
            onSelect: { offset in
                isOverflowMenuPresented = false
                let index = collapsed.lowerBound + offset
                if items.indices.contains(index) { onSelect(items[index]) }
            }
        ) {
            BreadcrumbOverflowMenu(
                titles: collapsed.map { title(items[$0]) },
                symbols: collapsed.map { systemImage?(items[$0]) },
                isPresented: $isOverflowMenuPresented,
                focusedIndex: $focusedMenuIndex,
                onSelect: { offset in
                    let index = collapsed.lowerBound + offset
                    if items.indices.contains(index) { onSelect(items[index]) }
                }
            )
        }
    }

    private var overflowLabel: some View {
        Image(systemName: "ellipsis")
            .font(font)
            .foregroundStyle(.secondary)
            // The glyph sits low; a line's height keeps it on the text's center.
            .frame(minHeight: Sizing.iconDefault)
    }

    /// Every segment, the chevron and the "…" at their natural widths, hidden
    /// behind the row: what the collapse works from.
    private var measuringRow: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                label(at: index)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { segmentWidths[index] = $0 }
            }
            chevron
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chevronWidth = $0 }
            overflowLabel
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { overflowWidth = $0 }
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

// MARK: - Overflow menu

/// The collapsed segments, oldest first, as menu rows. A `View` with bindings,
/// as a floating menu's content must be (it's hosted when the menu opens).
private struct BreadcrumbOverflowMenu: View {
    let titles: [String]
    let symbols: [String?]
    @Binding var isPresented: Bool
    @Binding var focusedIndex: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(titles.indices, id: \.self) { index in
                row(at: index)
            }
        }
        .padding(Spacing.menuPadding)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        let select = {
            isPresented = false
            onSelect(index)
        }
        if let symbol = symbols[index] {
            QuickActionMenuItem(title: .verbatim(titles[index]), icon: symbol, isFocused: focusedIndex == index, action: select)
        } else {
            QuickActionMenuItem(title: .verbatim(titles[index]), iconView: AnyView(EmptyView()), isFocused: focusedIndex == index, action: select)
        }
    }
}

// MARK: - Collapse math

nonisolated enum BreadcrumbCollapse {
    /// The segments that fold into "…", given each one's width, the width a
    /// chevron and its spacing take, the "…" button's, and the room there is:
    /// empty when the whole path fits. The first and last segments always
    /// show; segments come back from the end (the nearest levels) while they
    /// fit. A path of one or two segments never collapses — the last one
    /// truncates instead — and neither does one where "…" is no narrower than
    /// what it would hide.
    static func collapsedRange(
        widths: [CGFloat],
        separatorWidth: CGFloat,
        overflowWidth: CGFloat,
        availableWidth: CGFloat
    ) -> Range<Int> {
        let count = widths.count
        guard count > 2 else { return 0..<0 }
        let fullWidth = widths.reduce(0, +) + separatorWidth * CGFloat(count - 1)
        // Half a point of slack: the measured widths are fractional.
        guard fullWidth > availableWidth + 0.5 else { return 0..<0 }

        var usedWidth = widths[0] + separatorWidth + overflowWidth + separatorWidth + widths[count - 1]
        var firstShown = count - 1
        // Bring segments back from the end while they fit. Reaching index 1
        // would mean the whole path fits, which it doesn't, so this stops at 2.
        while firstShown > 1 {
            let candidate = usedWidth + widths[firstShown - 1] + separatorWidth
            if candidate > availableWidth { break }
            usedWidth = candidate
            firstShown -= 1
        }
        // A "…" wider than what it hides would only make the path longer.
        guard usedWidth < fullWidth else { return 0..<0 }
        return 1..<max(firstShown, 2)
    }
}

// MARK: - Preview

private struct BreadcrumbsPreviewHost: View {
    private let path = ["Projects", "BlissUI", "Sources", "BlissUI", "Components", "Layout", "Breadcrumbs.swift"]
    @State private var selected = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Breadcrumbs(path, title: { $0 }) { selected = $0 }
            Breadcrumbs(path, title: { $0 }, systemImage: { $0.hasSuffix(".swift") ? "swift" : "folder" }) { selected = $0 }
                .frame(width: 300)
            Text(verbatim: selected)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.xl)
    }
}

#Preview(traits: .fixedLayout(width: 640, height: 160)) {
    BreadcrumbsPreviewHost()
}
