//
//  UnderlineTabBar.swift
//  BlissUI
//
//  The app's underline tab bar, shared so every tabbed surface (a detail page,
//  a tabbed sheet) renders identically: title with an optional leading icon and
//  count chip, a sliding accent underline (matchedGeometryEffect), and a
//  hairline bottom rule. Items can right-align (e.g. a mono file-name tab) and
//  render mono.
//

import SwiftUI

/// One tab in an `UnderlineTabBar`.
public nonisolated struct UnderlineTabItem<Value: Hashable>: Identifiable {
    public let value: Value
    public let title: String
    /// Optional leading icon — SF Symbol, or a template asset from the app's
    /// catalog (`icon-` prefix).
    public var icon: String? = nil
    /// Trailing count chip (hidden when 0).
    public var count: Int = 0
    /// Mono title (e.g. a file-name tab).
    public var isMono: Bool = false
    /// Render after the Spacer, hugging the trailing edge.
    public var alignTrailing: Bool = false
    /// A greyed tab ("Logs" before the first run): not selectable, skipped by Tab.
    public var isEnabled: Bool = true
    /// The count on the accent fill (unread) instead of the neutral chip.
    public var isCountProminent: Bool = false

    public var id: Value { value }

    /// - Parameters:
    ///   - value: What selecting the tab sets.
    ///   - title: The tab's title, shown as is.
    ///   - icon: A leading SF Symbol or `icon-` asset.
    ///   - count: A trailing count chip; hidden at 0.
    ///   - isMono: A monospaced title (a file name).
    ///   - alignTrailing: Hugs the trailing edge, after the other tabs.
    ///   - isEnabled: A greyed tab that can't be selected.
    ///   - isCountProminent: The count on the accent fill.
    public init(
        value: Value,
        title: String,
        icon: String? = nil,
        count: Int = 0,
        isMono: Bool = false,
        alignTrailing: Bool = false,
        isEnabled: Bool = true,
        isCountProminent: Bool = false
    ) {
        self.value = value
        self.title = title
        self.icon = icon
        self.count = count
        self.isMono = isMono
        self.alignTrailing = alignTrailing
        self.isEnabled = isEnabled
        self.isCountProminent = isCountProminent
    }
}

extension UnderlineTabItem: Sendable where Value: Sendable {}

/// A row of tabs over a hairline rule, the selected one underlined in the
/// accent. Squeezed, it drops the count chips, then scrolls sideways.
public struct UnderlineTabBar<Value: Hashable>: View {
    let items: [UnderlineTabItem<Value>]
    @Binding var selection: Value
    /// Gap between tabs — the roomy default for a full-width page; a narrower
    /// host (a 550pt sheet with six tabs) passes a tighter value so titles
    /// never crowd out.
    var spacing: CGFloat = Spacing.xl
    /// The hairline rule along the bar's bottom (the selected underline rides on
    /// it). Off for hosts whose surrounding chrome already draws a separator.
    var showsBorder: Bool = true
    /// Insets the TAB ROW only — the bottom rule stays full width. Use instead of
    /// padding the whole bar (which would inset the rule too): the tabs sit on an
    /// edge-to-edge line, like a sheet's footer divider.
    var horizontalInset: CGFloat = 0
    /// A smaller bar for a sheet or an inspector: the label size, a tighter
    /// gap under the titles.
    var compact: Bool = false
    /// Icon-only tabs (an inspector's): the title moves into a tooltip and
    /// stays the tab's accessibility label.
    var showsTitles: Bool = true

    @Namespace private var tabNamespace
    @State private var hoveredTab: Value?

    /// The focus ring's clearance around a title: the ring's outset and its band.
    private static var ringClearance: CGFloat { Spacing.ringOutset + Spacing.hairline }

    /// - Parameters:
    ///   - items: The tabs, in order.
    ///   - selection: The selected tab's value.
    ///   - spacing: The gap between tabs.
    ///   - showsBorder: The hairline rule along the bottom.
    ///   - horizontalInset: Insets the tab row, not the rule.
    ///   - compact: The label size and a tighter gap, for a sheet or inspector.
    ///   - showsTitles: Off for icon-only tabs; titles become tooltips.
    public init(
        items: [UnderlineTabItem<Value>],
        selection: Binding<Value>,
        spacing: CGFloat = Spacing.xl,
        showsBorder: Bool = true,
        horizontalInset: CGFloat = 0,
        compact: Bool = false,
        showsTitles: Bool = true
    ) {
        self.items = items
        self._selection = selection
        self.spacing = spacing
        self.showsBorder = showsBorder
        self.horizontalInset = horizontalInset
        self.compact = compact
        self.showsTitles = showsTitles
    }

    private var leadingItems: [UnderlineTabItem<Value>] { items.filter { !$0.alignTrailing } }
    private var trailingItems: [UnderlineTabItem<Value>] { items.filter(\.alignTrailing) }

    /// How the row fits the width it's offered: everything, then without the
    /// count chips, then scrolling sideways (nine tabs in a narrow window, or
    /// in French, need more than the pane has).
    private enum Fit: String {
        case full, withoutCounts, scrolling
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            tabRow(.full)
            tabRow(.withoutCounts)
            ScrollView(.horizontal, showsIndicators: false) {
                // Room inside the scroll view for the focus ring, which it would
                // otherwise clip; the negative padding outside gives it back.
                tabRow(.scrolling)
                    .padding(Self.ringClearance)
            }
            .padding(-Self.ringClearance)
        }
        .padding(.horizontal, horizontalInset)
        .overlay(alignment: .bottom) {
            if showsBorder {
                Rectangle().fill(Color.menuBorder).frame(height: 1)
            }
        }
    }

    private var titleFont: Font {
        compact ? Typography.labelSmall : Typography.labelMedium
    }

    private func tabRow(_ fit: Fit) -> some View {
        HStack(spacing: spacing) {
            ForEach(leadingItems) { tabButton($0, fit: fit) }
            Spacer(minLength: 0)
            ForEach(trailingItems) { tabButton($0, fit: fit) }
        }
    }

    private func tabButton(_ item: UnderlineTabItem<Value>, fit: Fit) -> some View {
        let isSelected = selection == item.value
        // An unselected tab brightens under the pointer, like the sidebar rows.
        let isLit = isSelected || hoveredTab == item.value
        return Button {
            withAnimation(Animations.selection) { selection = item.value }
        } label: {
            HStack(spacing: Spacing.xs) {
                if let icon = item.icon {
                    iconView(icon)
                        .foregroundStyle(isLit ? .primary : .secondary)
                }
                if showsTitles {
                    Text(item.title)
                        .font(item.isMono ? Typography.codeSmall : titleFont)
                        .foregroundStyle(isLit ? .primary : .secondary)
                        // A tab title must never wrap ("Connecti / on") — hold one line
                        // and let the bar's spacing absorb the pressure instead.
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if item.count > 0 && fit == .full {
                    countChip(item)
                }
            }
            .padding(.bottom, compact ? Spacing.xs : Spacing.sm)
            .overlay(alignment: .bottom) {
                if isSelected {
                    RoundedRectangle(cornerRadius: Sizing.radiusFull)
                        .fill(Color.accent)
                        .frame(height: Spacing.hairline)
                        // One id per fit: ViewThatFits keeps every candidate
                        // row around for measuring, and two sources sharing an
                        // id would fight over the underline.
                        .matchedGeometryEffect(id: "tabUnderline-" + fit.rawValue, in: tabNamespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusFull))
        }
        // A Tab stop with the accent ring; only the fitting row is in the tree,
        // so ViewThatFits' other candidates add no hidden stops.
        // Outset so the ring clears the title's letters.
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusFull, outset: Spacing.ringOutset))
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : Animations.disabledOpacity)
        .onHover { hovering in
            withAnimation(Animations.hover) {
                // A disabled tab doesn't answer the pointer.
                if hovering, item.isEnabled {
                    hoveredTab = item.value
                } else if hoveredTab == item.value {
                    hoveredTab = nil
                }
            }
        }
        // Icon-only, the title moves into a tooltip and stays the label.
        .tooltip(.verbatim(item.title), position: .below)
        .tooltipsDisabled(showsTitles)
        .accessibilityLabel(Text(verbatim: item.title))
        // The underline is drawn only; tell VoiceOver which tab is current.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The count: the small neutral chip, or the accent fill for unread.
    @ViewBuilder
    private func countChip(_ item: UnderlineTabItem<Value>) -> some View {
        if item.isCountProminent {
            Badge(count: item.count)
                .badgeStyle(.custom(
                    text: AccentHue.contrastForeground,
                    icon: AccentHue.contrastForeground,
                    background: Color.accent,
                    border: nil
                ))
                .badgeSize(.small)
        } else {
            Badge(count: item.count)
                .badgeStyle(.secondary)
                .badgeSize(.small)
        }
    }

    @ViewBuilder
    private func iconView(_ icon: String) -> some View {
        if icon.hasPrefix("icon-") {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Sizing.iconTiny, height: Sizing.iconTiny)
        } else {
            Image(systemName: icon)
                .font(Typography.labelSmall)
        }
    }
}

// MARK: - Preview

private struct UnderlineTabBarPreview: View {
    @State private var selection = "Overview"

    var body: some View {
        UnderlineTabBar(
            items: [
                UnderlineTabItem(value: "Overview", title: "Overview"),
                UnderlineTabItem(value: "Activity", title: "Activity", count: 12),
                UnderlineTabItem(value: "Settings", title: "Settings"),
                UnderlineTabItem(value: "config.json", title: "config.json", isMono: true, alignTrailing: true),
            ],
            selection: $selection
        )
        .padding(Spacing.lg)
        .background(Color.windowBackground)
    }
}

#Preview("Underline Tab Bar", traits: .fixedLayout(width: 480, height: 80)) {
    UnderlineTabBarPreview()
}

#Preview("Underline Tab Bar · Narrow", traits: .fixedLayout(width: 260, height: 80)) {
    UnderlineTabBarPreview()
}
