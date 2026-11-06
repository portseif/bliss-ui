//
//  SectionHeader.swift
//  BlissUI
//
//  The shared in-content section header for a page's sections: a
//  `headingMedium` + `.secondary` title, with an optional count (with an optional
//  unit suffix) in a filled `.secondary` pill and/or a `.caption` + `.tertiary`
//  caption, and a trailing `Spacer` that pushes the title group to the leading edge. Use it
//  instead of per-view `sectionHeader` / `sectionLabel` helpers.
//
//  NOT this component (deliberately separate):
//   - `TimelineHeaderLabel` — the timeline day-group label (its own padding/usage).
//   - A wizard step or settings section heading — a VERTICAL title+subtitle.
//   - A smaller `labelSmall`/`.secondary` inline group divider (a different
//     visual tier).
//

import SwiftUI

public struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var count: Int?
    var countSuffix: LocalizedStringKey?
    var caption: LocalizedStringKey?
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var horizontalPadding: CGFloat
    /// Optional accessory pinned to the trailing edge (defaults to nothing), so a
    /// header can carry an inline control space-between with its title.
    @ViewBuilder var trailing: () -> Trailing

    public init(
        _ title: LocalizedStringKey,
        count: Int? = nil,
        countSuffix: LocalizedStringKey? = nil,
        caption: LocalizedStringKey? = nil,
        topPadding: CGFloat = Spacing.md,
        bottomPadding: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.count = count
        self.countSuffix = countSuffix
        self.caption = caption
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.horizontalPadding = horizontalPadding
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(Typography.headingMedium)
                .foregroundStyle(.foreground)

            if let count {
                (countSuffix.map { Text(verbatim: "\(count) ") + Text($0) } ?? Text(verbatim: "\(count)"))
                    .font(Typography.caption)
                    .monospacedDigit()
                    // A filled pill with the window's color knocked out of it.
                    // (`.backgroundStyle` only sets the style a `.background()`
                    // would use; it draws nothing itself.)
                    .foregroundStyle(Color.windowBackground)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 1)
                    .background(.foreground, in: Capsule())
            }

            if let caption {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 220)) {
    VStack(alignment: .leading, spacing: 0) {
        SectionHeader("Popular")
        SectionHeader("All Items", topPadding: Spacing.xxl)
        SectionHeader("Drafts", count: 5, caption: "Not yet shared", topPadding: Spacing.lg)
        SectionHeader("Online now", count: 12, countSuffix: "members", topPadding: Spacing.lg)
        SectionHeader("Today", topPadding: Spacing.lg, bottomPadding: Spacing.sm)
    }
    .padding(Spacing.lg)
}
