//
//  AvatarStack.swift
//  BlissUI
//
//  Overlapping avatars — who's on a project, who's viewing a document — with a
//  `+N` for the ones that don't fit and a tooltip listing everyone. The first
//  avatar sits on top, and each one tucks under the one before it with a gap
//  cut around the edge (see `Avatar` for why it's a cut, not a ring).
//

import SwiftUI

/// How `AvatarStack` shows the avatars past its limit.
public enum AvatarStackOverflowStyle: Hashable, Sendable {
    /// `+N` in a pill on the selection fill, tucked under the last avatar.
    case chip
    /// `+N` as plain secondary text after the last avatar, for dense rows
    /// where a filled chip is one shape too many.
    case plain
}

/// Overlapping avatars with a `+N` overflow and a tooltip of names.
///
/// ```swift
/// AvatarStack(members, name: \.name, image: \.photo)
/// AvatarStack(names: ["Ada Lovelace", "Grace Hopper", "Alan Turing"], size: .small)
/// ```
///
/// VoiceOver reads it as one element: every name, as a list.
public struct AvatarStack<Item>: View {
    private let items: [Item]
    private let name: (Item) -> String
    private let image: (Item) -> Image?
    private let limit: Int
    private let size: AvatarSize
    private let shape: AvatarShape
    private let overflowStyle: AvatarStackOverflowStyle

    /// - Parameters:
    ///   - items: The people, in order; the first sits on top.
    ///   - name: Each one's name (initials, color, tooltip and VoiceOver).
    ///   - image: Each one's picture; nil shows initials.
    ///   - limit: How many avatars show before the rest fold into `+N`.
    ///   - size: Small (20pt), medium (28pt) or large (40pt).
    ///   - shape: A circle, or a rounded square.
    ///   - overflowStyle: `+N` in a filled chip, or as plain text.
    public init(
        _ items: [Item],
        name: @escaping (Item) -> String,
        image: @escaping (Item) -> Image? = { _ in nil },
        limit: Int = 4,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle,
        overflowStyle: AvatarStackOverflowStyle = .chip
    ) {
        self.items = items
        self.name = name
        self.image = image
        self.limit = max(1, limit)
        self.size = size
        self.shape = shape
        self.overflowStyle = overflowStyle
    }

    /// Avatars with initials only, from a list of names.
    public init(
        names: [String],
        limit: Int = 4,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle,
        overflowStyle: AvatarStackOverflowStyle = .chip
    ) where Item == String {
        self.init(names, name: { $0 }, limit: limit, size: size, shape: shape, overflowStyle: overflowStyle)
    }

    /// How many avatars show, and how many fold into the `+N` chip. A chip
    /// for one would take the room of the avatar it hides, so a list one over
    /// the limit shows everyone.
    nonisolated static func split(count: Int, limit: Int) -> (visible: Int, overflow: Int) {
        guard count > limit + 1 else { return (count, 0) }
        return (limit, count - limit)
    }

    public var body: some View {
        let (visibleCount, overflow) = Self.split(count: items.count, limit: limit)
        let everyone = items.map(name).formatted(.list(type: .and))
        // How far apart neighboring avatars' leading edges are.
        let step = size.diameter - size.stackOverlap
        HStack(spacing: -size.stackOverlap) {
            ForEach(0..<visibleCount, id: \.self) { index in
                let item = items[index]
                Avatar(name: name(item), image: image(item), size: size, shape: shape)
                    .cut(byLeadingNeighborAt: index > 0 ? step : nil)
                    .zIndex(Double(visibleCount - index))
            }
            if overflow > 0 {
                switch overflowStyle {
                case .chip:
                    AvatarOverflowChip(count: overflow, size: size, shape: shape, neighborDistance: step)
                case .plain:
                    AvatarOverflowLabel(count: overflow, size: size)
                }
            }
        }
        .tooltip(configuration: .default, position: .above) {
            Text(verbatim: everyone)
                .font(Typography.labelSmall)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: everyone))
    }
}

// MARK: - Overflow chip

/// `+N` in a pill on the neutral selection fill, cut by the avatar before it
/// like the others. Every chip is sized for the widest label (`+99`) at one
/// fixed font, so a column of stacks lines up whatever the counts; past 99 it
/// reads `99+`.
private struct AvatarOverflowChip: View {
    let count: Int
    let size: AvatarSize
    let shape: AvatarShape
    let neighborDistance: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let diameter = size.diameter
        // Left to right; SwiftUI mirrors it in a right-to-left layout (see `Avatar`).
        let neighbor = AvatarCutoutShape.Hole(
            rect: CGRect(x: -neighborDistance, y: 0, width: diameter, height: diameter)
                .insetBy(dx: -size.gap, dy: -size.gap),
            cornerRadius: shape == .circle ? nil : size.cornerRadius + size.gap
        )
        AvatarOverflowCount(count: count, size: size, alignment: .center)
            .foregroundStyle(Color.textSecondary)
        // The leading part sits under the avatar before it.
        .padding(.leading, size.stackHiddenWidth + size.overflowPadding)
        .padding(.trailing, size.overflowPadding)
        .frame(minWidth: diameter, minHeight: diameter, maxHeight: diameter)
        .background(RowTint.selected(colorScheme))
        // A circle stack gets a capsule: a wider-than-tall ellipse would read as a blob.
        .clipShape(AvatarCutoutShape(shape: .rounded, cornerRadius: shape == .circle ? diameter / 2 : size.cornerRadius, holes: [neighbor]))
    }
}

/// `+N` as plain text after the last avatar, at the chip's fixed width.
private struct AvatarOverflowLabel: View {
    let count: Int
    let size: AvatarSize

    var body: some View {
        AvatarOverflowCount(count: count, size: size, alignment: .leading)
            .foregroundStyle(Color.textSecondary)
            // Undo the stack's overlap, then the usual gap between neighbors.
            .padding(.leading, size.stackOverlap + size.gap + size.gap)
            .frame(height: size.diameter)
    }
}

/// The `+N` label at a fixed width, sized for `+99`; past 99 it reads `99+`.
private struct AvatarOverflowCount: View {
    let count: Int
    let size: AvatarSize
    /// Where a shorter label sits in the `+99` width: centered in a chip,
    /// leading after the avatars when plain.
    let alignment: Alignment

    var body: some View {
        ZStack(alignment: alignment) {
            Text(verbatim: "+99").hidden()
            Text(verbatim: count > 99 ? "99+" : "+\(count)")
        }
        .font(size.overflowFont)
        .lineLimit(1)
        .fixedSize()
    }
}

extension AvatarSize {
    /// The `+N` chip's label: a step up from the initials, so the count reads
    /// at a glance.
    var overflowFont: Font {
        switch self {
        case .small: Typography.captionSmallSemibold
        case .medium: Typography.bodySmallSemibold
        case .large: Typography.bodyMediumSemibold
        }
    }

    /// Space on each side of the `+N` label inside its pill.
    var overflowPadding: CGFloat {
        switch self {
        case .small: Spacing.xs
        case .medium: Spacing.sm
        case .large: Spacing.sm
        }
    }
}

extension Avatar {
    /// This avatar with a gap cut where the one before it overlaps (the
    /// distance between their leading edges); nil cuts nothing.
    func cut(byLeadingNeighborAt distance: CGFloat?) -> Avatar {
        var avatar = self
        avatar.leadingNeighborDistance = distance
        return avatar
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 360, height: 160)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        AvatarStack(names: ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra", "Barbara Liskov"], size: .small)
        AvatarStack(names: ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra", "Barbara Liskov"])
        AvatarStack(names: ["Design", "Platform", "Growth"], size: .large, shape: .rounded)
    }
    .padding(Spacing.xl)
}
