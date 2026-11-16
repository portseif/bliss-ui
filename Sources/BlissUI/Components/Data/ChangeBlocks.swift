//
//  ChangeBlocks.swift
//  BlissUI
//
//  A diff-size glance: five small blocks and `+added −removed`. How many
//  blocks light up scales with the change's size; lit blocks split green/red
//  by the add/remove ratio, the rest stay neutral. No changes: five dim blocks
//  and "No changes".
//

import SwiftUI

/// How `ChangeBlocks` writes its counts.
public nonisolated enum ChangeCountStyle: Hashable, Sendable {
    /// The locale's compact notation: 1.9K, 19K.
    case compact
    /// Every digit: 1,904.
    case exact
}

/// Additions/deletions blocks with their counts.
///
/// ```swift
/// ChangeBlocks(additions: 529, deletions: 12)
/// ChangeBlocks(additions: added, deletions: removed, showsCounts: false)
/// ChangeBlocks(additions: added, deletions: removed, showsBlocks: false, countStyle: .exact)
/// ```
///
/// Blocks are whole points (7pt, 2pt apart), so a column of them stays crisp.
public struct ChangeBlocks: View {
    private let additions: Int
    private let deletions: Int
    private let showsCounts: Bool
    private let showsBlocks: Bool
    private let countStyle: ChangeCountStyle
    private let blockCount: Int
    private let unitsPerBlock: Int
    private let accessibilityLabel: LocalizedStringKey?

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - additions: Lines (or items) added.
    ///   - deletions: Lines (or items) removed.
    ///   - showsCounts: Shows `+added −removed` (or "No changes") after the blocks.
    ///   - showsBlocks: Shows the blocks; off, the counts stand alone in a tight column.
    ///   - countStyle: Compact (1.9K) or exact (1,904) counts.
    ///   - blockCount: How many blocks the scale has.
    ///   - unitsPerBlock: The change one lit block stands for.
    ///   - accessibilityLabel: What VoiceOver calls it ("Changes" when nil).
    public init(
        additions: Int,
        deletions: Int,
        showsCounts: Bool = true,
        showsBlocks: Bool = true,
        countStyle: ChangeCountStyle = .compact,
        blockCount: Int = 5,
        unitsPerBlock: Int = 150,
        accessibilityLabel: LocalizedStringKey? = nil
    ) {
        self.additions = additions
        self.deletions = deletions
        self.showsCounts = showsCounts
        self.showsBlocks = showsBlocks
        self.countStyle = countStyle
        self.blockCount = blockCount
        self.unitsPerBlock = unitsPerBlock
        self.accessibilityLabel = accessibilityLabel
    }

    /// A block: a 7pt square, whole points so a column stays crisp.
    private static let blockSize: CGFloat = 7
    private static let blockSpacing: CGFloat = Spacing.hairline
    /// A hair rounder than square; drawing geometry on a 7pt block.
    private static let blockRadius: CGFloat = 1.5

    public var body: some View {
        let added = max(additions, 0)
        let removed = max(deletions, 0)
        HStack(spacing: Spacing.sm) {
            if showsBlocks { blocks(added: added, removed: removed) }
            if showsCounts { counts(added: added, removed: removed) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel.map { Text($0) } ?? Text("Changes", bundle: .module))
        .accessibilityValue(
            added + removed == 0
                ? Text("No changes", bundle: .module)
                : Text("\(added) additions, \(removed) deletions", bundle: .module)
        )
    }

    private func blocks(added: Int, removed: Int) -> some View {
        HStack(spacing: Self.blockSpacing) {
            ForEach(Array(Self.blockKinds(additions: added, deletions: removed, blockCount: blockCount, unitsPerBlock: unitsPerBlock).enumerated()), id: \.offset) { _, kind in
                RoundedRectangle(cornerRadius: Self.blockRadius, style: .continuous)
                    .fill(color(for: kind))
                    .frame(width: Self.blockSize, height: Self.blockSize)
            }
        }
    }

    @ViewBuilder
    private func counts(added: Int, removed: Int) -> some View {
        if added + removed == 0 {
            Text("No changes", bundle: .module)
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: Spacing.xxs) {
                if added > 0 {
                    Text(added, format: countFormat.sign(strategy: .always()))
                        .foregroundStyle(Success.success500)
                }
                if removed > 0 {
                    // A negative number, so the locale's own minus sign.
                    Text(-removed, format: countFormat)
                        .foregroundStyle(Danger.danger500)
                }
            }
            .font(Typography.captionSmall.monospacedDigit())
            .lineLimit(1)
        }
    }

    private var countFormat: IntegerFormatStyle<Int> {
        switch countStyle {
        case .compact: return .number.notation(.compactName)
        case .exact: return .number
        }
    }

    private func color(for kind: BlockKind) -> Color {
        switch kind {
        case .addition: return Success.success500
        case .deletion: return Danger.danger500
        case .neutral: return DataTrack.color(colorScheme)
        }
    }

    // MARK: - Block math

    nonisolated enum BlockKind: Equatable, Sendable {
        case addition, deletion, neutral
    }

    /// The color of each block, leading to trailing: additions, then
    /// deletions, then neutral. Lit blocks = the change's size in
    /// `unitsPerBlock` steps (at least one, at most `blockCount`); each side
    /// that has any change keeps at least one block.
    nonisolated static func blockKinds(additions: Int, deletions: Int, blockCount: Int, unitsPerBlock: Int) -> [BlockKind] {
        let blockCount = max(blockCount, 0)
        let added = max(additions, 0)
        let removed = max(deletions, 0)
        let total = added + removed
        guard total > 0, blockCount > 0 else { return Array(repeating: .neutral, count: blockCount) }
        let sidesPresent = (added > 0 ? 1 : 0) + (removed > 0 ? 1 : 0)
        let bySize = Int((Double(total) / Double(max(unitsPerBlock, 1))).rounded(.up))
        let lit = min(blockCount, max(bySize, sidesPresent))
        var addedBlocks = Int((Double(added) / Double(total) * Double(lit)).rounded())
        if added > 0 { addedBlocks = max(addedBlocks, 1) }
        if removed > 0 { addedBlocks = min(addedBlocks, lit - 1) }
        return Array(repeating: .addition, count: addedBlocks)
            + Array(repeating: .deletion, count: lit - addedBlocks)
            + Array(repeating: .neutral, count: blockCount - lit)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 240, height: 170)) {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ChangeBlocks(additions: 529, deletions: 12)
        ChangeBlocks(additions: 40, deletions: 380)
        ChangeBlocks(additions: 12_400, deletions: 3_100)
        ChangeBlocks(additions: 12_400, deletions: 3_100, showsBlocks: false, countStyle: .exact)
        ChangeBlocks(additions: 0, deletions: 0)
        ChangeBlocks(additions: 18, deletions: 6, showsCounts: false)
    }
    .padding(Spacing.xl)
}
