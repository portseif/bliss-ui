//
//  LabeledDivider.swift
//  BlissUI
//
//  A hairline with a label set into it: "or" between two sign-in options, a
//  date between groups of messages, a section word in a long form. The label
//  sits in the middle by default, or near one end.
//

import SwiftUI

/// A hairline with a label set into it.
///
/// ```swift
/// LabeledDivider("or")
/// LabeledDivider(alignment: .leading) { TimeAgoLabel(date: message.date) }
/// ```
///
/// The label reads in `Typography.captionSmall` and `.secondary`; put your own
/// font or color modifiers on the label view to change that.
public struct LabeledDivider<Label: View>: View {
    private let alignment: HorizontalAlignment
    private let label: Label

    /// - Parameters:
    ///   - alignment: Where the label sits along the line.
    ///   - label: The text (or view) set into the line.
    public init(alignment: HorizontalAlignment = .center, @ViewBuilder label: () -> Label) {
        self.alignment = alignment
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            leadingLine
            label
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            trailingLine
        }
    }

    // MARK: Lines

    /// A short fixed line keeps the label near an end; a flexible one pushes it
    /// toward the middle.
    @ViewBuilder
    private var leadingLine: some View {
        if alignment == .leading {
            hairline.frame(width: Spacing.md)
        } else {
            hairline
        }
    }

    @ViewBuilder
    private var trailingLine: some View {
        if alignment == .trailing {
            hairline.frame(width: Spacing.md)
        } else {
            hairline
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

extension LabeledDivider where Label == Text {
    /// A divider labeled with a string from your app's catalog.
    ///
    /// - Parameters:
    ///   - title: The label, looked up in your app's strings like `Text("…")`.
    ///   - alignment: Where the label sits along the line.
    public init(_ title: LocalizedStringKey, alignment: HorizontalAlignment = .center) {
        self.init(alignment: alignment) { Text(title) }
    }
}

// MARK: - Preview

#Preview("Labeled divider", traits: .fixedLayout(width: 420, height: 160)) {
    VStack(spacing: Spacing.lg) {
        LabeledDivider("or")
        LabeledDivider("Yesterday", alignment: .leading)
        LabeledDivider(alignment: .trailing) {
            Text("3 more")
                .font(Typography.captionSmallSemibold)
        }
    }
    .padding(Spacing.xl)
}
