//
//  FlowLayout.swift
//  BlissUI
//

import SwiftUI

/// Lays children out left to right, wrapping to a new line when the next one
/// would overflow the proposed width. Used for chip rows (tag chips, a filter's
/// condition chips).
public struct FlowLayout: Layout {
    public var spacing: CGFloat = Spacing.xs

    public init(spacing: CGFloat = Spacing.xs) {
        self.spacing = spacing
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
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 260, height: 140)) {
    FlowLayout(spacing: Spacing.xs) {
        ForEach(["Design", "Engineering", "Marketing", "Sales", "Support", "Operations", "Finance"], id: \.self) { tag in
            Badge(LocalizedStringKey(tag)).badgeSize(.large)
        }
    }
    .padding(Spacing.lg)
}
