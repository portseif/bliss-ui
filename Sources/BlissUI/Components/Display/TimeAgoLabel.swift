//
//  TimeAgoLabel.swift
//  BlissUI
//
//  A relative age with a clock glyph in front of it.
//
//  Metadata rows line up several dim, same-sized fragments — a domain, a pid, an
//  author, an age — and a bare "6h ago" beside "example.com" reads as one more
//  unlabelled string. The glyph says "this one is a time" without spending a
//  word on it.
//
//  Use it wherever a relative age stands on its own. A time already introduced by
//  a word ("edited 3d ago", "up 4:21", "Expires in 9d") is differentiated
//  already — adding the glyph there just doubles up.
//

import SwiftUI

public struct TimeAgoLabel: View {
    let date: Date
    /// "3d ago" rather than a bare "3d". Off where the surrounding copy already
    /// makes the direction obvious.
    var withSuffix: Bool = true
    var font: Font = Typography.captionSmall

    public init(date: Date, withSuffix: Bool = true, font: Font = Typography.captionSmall) {
        self.date = date
        self.withSuffix = withSuffix
        self.font = font
    }

    /// Colour is inherited, so a caller's `.foregroundStyle(.tertiary)` still
    /// governs the glyph and the text together.
    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
            Text(DateFormatting.formatRelativeCompact(date, withSuffix: withSuffix))
        }
        .font(font)
    }
}

// MARK: - Previews

#Preview("Time ago", traits: .fixedLayout(width: 360, height: 220)) {
    VStack(alignment: .leading, spacing: Spacing.md) {
        // The row that prompted this: a domain and an age, side by side.
        HStack(spacing: Spacing.sm) {
            Text("Acme Site").font(Typography.labelLarge)
            Text(verbatim: "example.com")
                .font(Typography.codeSmall)
                .foregroundStyle(.tertiary)
            TimeAgoLabel(date: Date().addingTimeInterval(-6 * 3600))
                .foregroundStyle(.tertiary)
        }

        Divider()

        TimeAgoLabel(date: Date().addingTimeInterval(-90))
        TimeAgoLabel(date: Date().addingTimeInterval(-3 * 86400))
        TimeAgoLabel(date: Date().addingTimeInterval(-3 * 86400), withSuffix: false)
        TimeAgoLabel(date: Date().addingTimeInterval(-40 * 86400), font: Typography.codeTiny)
            .foregroundStyle(.tertiary)
    }
    .padding(Spacing.xl)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.contentAreaBackground)
}
