//
//  SectionHeader.swift
//  BlissUI
//
//  The shared in-content section header for a page's sections: a
//  `headingMedium` title (`headingSmall` at `.small`), with an optional count
//  (with an optional unit suffix) as a small neutral `Badge` and/or a
//  `caption` + tertiary caption, and a trailing `Spacer` that pushes the title
//  group to the leading edge. Use it instead of per-view `sectionHeader` /
//  `sectionLabel` helpers. `hugsContent: true` drops the spacer, for a header
//  inside an HStack or over a column (`TimelineHeaderLabel` is that).
//
//  NOT this component (deliberately separate):
//   - A wizard step or settings section heading — a VERTICAL title+subtitle.
//   - `RoundedSection`'s card title — a `bodySmall` secondary tier.
//

import SwiftUI

/// A section header's title size.
public enum SectionHeaderSize: Hashable, Sendable {
    /// `headingMedium` (17pt) — a page's sections.
    case regular
    /// `headingSmall` (15pt) — a nested group.
    case small

    var font: Font {
        switch self {
        case .regular: Typography.headingMedium
        case .small: Typography.headingSmall
        }
    }
}

public struct SectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var count: Int?
    var countSuffix: LocalizedStringKey?
    var caption: LocalizedStringKey?
    var size: SectionHeaderSize
    var hugsContent: Bool
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var horizontalPadding: CGFloat
    /// Optional accessory pinned to the trailing edge (defaults to nothing), so a
    /// header can carry an inline control space-between with its title.
    @ViewBuilder var trailing: () -> Trailing

    /// - Parameters:
    ///   - title: The section's name. Looked up in your app's strings.
    ///   - count: A count beside the title, as a small neutral badge.
    ///   - countSuffix: A unit after the count ("members").
    ///   - caption: A tertiary note beside the title.
    ///   - size: `.regular` (17pt) or `.small` (15pt, a nested group).
    ///   - hugsContent: No trailing spacer: the header sizes to its text.
    ///   - topPadding: Space above; `Spacing.md` by default.
    ///   - bottomPadding: Space below.
    ///   - horizontalPadding: Inset on both sides.
    ///   - trailing: An accessory on the trailing edge.
    public init(
        _ title: LocalizedStringKey,
        count: Int? = nil,
        countSuffix: LocalizedStringKey? = nil,
        caption: LocalizedStringKey? = nil,
        size: SectionHeaderSize = .regular,
        hugsContent: Bool = false,
        topPadding: CGFloat = Spacing.md,
        bottomPadding: CGFloat = 0,
        horizontalPadding: CGFloat = 0,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.count = count
        self.countSuffix = countSuffix
        self.caption = caption
        self.size = size
        self.hugsContent = hugsContent
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.horizontalPadding = horizontalPadding
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(size.font)
                .foregroundStyle(.primary)

            if let count {
                countBadge(count)
            }

            if let caption {
                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Color.textTertiary)
            }

            if !hugsContent {
                Spacer(minLength: 0)
            }

            trailing()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    /// The count as the library's neutral chip; with a suffix, "12 members".
    @ViewBuilder
    private func countBadge(_ count: Int) -> some View {
        if let countSuffix {
            Badge("\(count) \(Text(countSuffix))")
                .badgeStyle(.secondary)
                .badgeSize(.small)
        } else {
            Badge(.verbatim("\(count)"))
                .badgeStyle(.secondary)
                .badgeSize(.small)
        }
    }
}

#Preview(traits: .fixedLayout(width: 360, height: 260)) {
    VStack(alignment: .leading, spacing: 0) {
        SectionHeader("Popular")
        SectionHeader("All Items", topPadding: Spacing.xxl)
        SectionHeader("Drafts", count: 5, caption: "Not yet shared", topPadding: Spacing.lg)
        SectionHeader("Online now", count: 12, countSuffix: "members", topPadding: Spacing.lg)
        SectionHeader("Today", topPadding: Spacing.lg, bottomPadding: Spacing.sm)
        SectionHeader("Nested group", size: .small, topPadding: Spacing.lg)
        HStack(spacing: Spacing.md) {
            SectionHeader("Yesterday", hugsContent: true, topPadding: 0)
            Text(verbatim: "3 events").font(Typography.caption).foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.lg)
    }
    .padding(Spacing.lg)
}
