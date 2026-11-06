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

    /// - Parameters:
    ///   - items: The people, in order; the first sits on top.
    ///   - name: Each one's name (initials, color, tooltip and VoiceOver).
    ///   - image: Each one's picture; nil shows initials.
    ///   - limit: How many avatars show before the rest fold into `+N`.
    ///   - size: Small (20pt), medium (28pt) or large (40pt).
    ///   - shape: A circle, or a rounded square.
    public init(
        _ items: [Item],
        name: @escaping (Item) -> String,
        image: @escaping (Item) -> Image? = { _ in nil },
        limit: Int = 4,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle
    ) {
        self.items = items
        self.name = name
        self.image = image
        self.limit = max(1, limit)
        self.size = size
        self.shape = shape
    }

    /// Avatars with initials only, from a list of names.
    public init(
        names: [String],
        limit: Int = 4,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle
    ) where Item == String {
        self.init(names, name: { $0 }, limit: limit, size: size, shape: shape)
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
                AvatarOverflowChip(count: overflow, size: size, shape: shape, neighborDistance: step)
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

/// `+N`, in an avatar's shape on the neutral selection fill, cut by the
/// avatar before it like the others.
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
        Text(verbatim: "+\(count.formatted())")
            .font(size.initialsFont)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // Centered in the part the avatar before it leaves showing.
            .frame(width: diameter - size.stackHiddenWidth)
            .offset(x: size.stackHiddenWidth / 2)
            .frame(width: diameter, height: diameter)
            .background(RowTint.selected(colorScheme))
            .clipShape(AvatarCutoutShape(shape: shape, cornerRadius: size.cornerRadius, holes: [neighbor]))
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
