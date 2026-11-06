//
//  TimelineHeaderLabel.swift
//  BlissUI
//
//  A content-sized `headingMedium` + `.primary` header label used above timeline
//  day-groups ("Today" / "Yesterday" / "MMM d") and detail-page stat/column
//  headers. Unlike `SectionHeader` it has no trailing Spacer, so it sizes to its
//  text and works inside HStacks / multi-column rows. Its only padding is a
//  bottom `md`.
//

import SwiftUI

public struct TimelineHeaderLabel: View {
    let label: LocalizedStringKey

    public init(_ label: LocalizedStringKey) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(Typography.headingMedium)
            .foregroundStyle(.primary)
            .padding(.bottom, Spacing.md)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 240, height: 100)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        TimelineHeaderLabel("Today")
        TimelineHeaderLabel("Yesterday")
        TimelineHeaderLabel("Jun 9")
    }
    .padding()
}
