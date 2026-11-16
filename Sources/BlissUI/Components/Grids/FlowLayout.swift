//
//  FlowLayout.swift
//  BlissUI
//

import SwiftUI

/// Lays children out left to right, wrapping to a new line when the next one
/// would overflow the proposed width. Used for chip rows (tag chips, a filter's
/// condition chips).
public struct FlowLayout: Layout {
    /// The gap between items on a line, and between lines unless `lineSpacing` says otherwise.
    public var spacing: CGFloat = Spacing.xs
    /// The gap between lines; nil uses `spacing`.
    public var lineSpacing: CGFloat?
    /// Where a short line sits in the width: a tag cloud under a centered
    /// `EmptyState` wants `.center`.
    public var alignment: HorizontalAlignment = .leading

    public init(spacing: CGFloat = Spacing.xs, lineSpacing: CGFloat? = nil, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        let lineGap = lineSpacing ?? spacing
        var frames: [CGRect] = []
        /// The frames on the line being filled, so the whole line can shift
        /// once its width is known.
        var lineRange = 0..<0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        func closeLine() {
            let lineWidth = currentX - spacing
            widestLine = max(widestLine, lineWidth)
            // Unspecified width: nothing to align within.
            guard maxWidth.isFinite, alignment != .leading else { return }
            let shift = alignment == .center ? (maxWidth - lineWidth) / 2 : maxWidth - lineWidth
            for index in lineRange {
                frames[index].origin.x += shift.rounded(.down)
            }
        }

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                closeLine()
                lineRange = frames.count..<frames.count
                currentX = 0
                currentY += lineHeight + lineGap
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineRange = lineRange.lowerBound..<frames.count
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }
        if !frames.isEmpty { closeLine() }

        // An unspecified proposal reports the widest line, not infinity, so a
        // `fixedSize()` chip row hugs its content.
        let width = maxWidth.isFinite ? maxWidth : widestLine
        return (CGSize(width: width, height: totalHeight), frames)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 260, height: 220)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(["Design", "Engineering", "Marketing", "Sales", "Support", "Operations", "Finance"], id: \.self) { tag in
                Badge(LocalizedStringKey(tag)).badgeSize(.large)
            }
        }
        FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.sm, alignment: .center) {
            ForEach(["Design", "Engineering", "Marketing", "Sales", "Support"], id: \.self) { tag in
                Badge(LocalizedStringKey(tag)).badgeSize(.large)
            }
        }
    }
    .padding(Spacing.lg)
}
