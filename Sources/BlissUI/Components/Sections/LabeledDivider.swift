//
//  LabeledDivider.swift
//  BlissUI
//
//  A hairline with a label set into it: "or" between two sign-in options, a
//  date between groups of messages, a section word in a long form. The label
//  sits in the middle by default, or at one end with the line running away
//  from it.
//

import SwiftUI

/// A hairline with a label set into it.
///
/// ```swift
/// LabeledDivider("or")
/// LabeledDivider(alignment: .leading) { TimeAgoLabel(date: message.date) }
/// LabeledDivider("Shipping", alignment: .leading, prominent: true)
/// ```
///
/// The label reads in `Typography.captionSmall` and `.secondary` — or
/// `bodySmallSemibold` and `.primary` when `prominent`, for a section word in
/// a long form; put your own font or color modifiers on the label view to
/// change that.
public struct LabeledDivider<Label: View>: View {
    private let alignment: HorizontalAlignment
    private let prominent: Bool
    private let verticalPadding: CGFloat
    private let label: Label

    /// - Parameters:
    ///   - alignment: Where the label sits along the line.
    ///   - prominent: A semibold primary label, for a section word.
    ///   - verticalPadding: Breathing room above and below, for a date in a message list.
    ///   - label: The text (or view) set into the line.
    public init(alignment: HorizontalAlignment = .center, prominent: Bool = false, verticalPadding: CGFloat = 0, @ViewBuilder label: () -> Label) {
        self.alignment = alignment
        self.prominent = prominent
        self.verticalPadding = verticalPadding
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            leadingLine
            label
                .font(prominent ? Typography.bodySmallSemibold : Typography.captionSmall)
                .foregroundStyle(prominent ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .fixedSize()
            trailingLine
        }
        .padding(.vertical, verticalPadding)
    }

    // MARK: Lines

    /// A label at an end starts or finishes the line, with nothing past it; a
    /// centered one has a line on each side.
    @ViewBuilder
    private var leadingLine: some View {
        if alignment != .leading {
            hairline
        }
    }

    @ViewBuilder
    private var trailingLine: some View {
        if alignment != .trailing {
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
    ///   - prominent: A semibold primary label, for a section word.
    ///   - verticalPadding: Breathing room above and below.
    public init(_ title: LocalizedStringKey, alignment: HorizontalAlignment = .center, prominent: Bool = false, verticalPadding: CGFloat = 0) {
        self.init(alignment: alignment, prominent: prominent, verticalPadding: verticalPadding) { Text(title) }
    }
}

// MARK: - Preview

#Preview("Labeled divider", traits: .fixedLayout(width: 420, height: 200)) {
    VStack(spacing: Spacing.lg) {
        LabeledDivider("or")
        LabeledDivider("Yesterday", alignment: .leading)
        LabeledDivider("Shipping", alignment: .leading, prominent: true, verticalPadding: Spacing.sm)
        LabeledDivider(alignment: .trailing) {
            Text("3 more")
                .font(Typography.captionSmallSemibold)
        }
    }
    .padding(Spacing.xl)
}
