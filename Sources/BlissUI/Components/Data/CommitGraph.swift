//
//  CommitGraph.swift
//  BlissUI
//
//  A git history as a graph: one colored lane per line of development, a dot
//  per commit (a ring for merges), and rounded elbows where a branch leaves
//  or rejoins. Each row shows the commit's refs, title, short hash, author
//  and age; text starts right after the lanes active in that row, so a deep
//  branch indents only its own rows.
//
//  The lanes are laid out once from the parent links (`CommitGraphLayout`)
//  and each row draws only its own slice in a Canvas, so rows stack flush and
//  their lines meet. Colors come from the status marks plus purple, so they
//  follow the theme and keep their contrast on both schemes.
//

import SwiftUI

// MARK: - Model

/// One commit in a `CommitGraph`.
public struct CommitGraphCommit: Identifiable, Hashable, Sendable {
    /// The full commit hash.
    public let id: String
    /// Parent hashes, first parent first. Parents not in the list continue as
    /// a lane off the bottom.
    public let parentIDs: [String]
    public let title: String
    public let shortHash: String
    public let authorName: String
    public let date: Date
    /// Branches, tags or your own labels ("Installed"), shown before the title.
    public let refs: [CommitGraphRef]

    /// - Parameters:
    ///   - id: The full commit hash.
    ///   - parentIDs: Parent hashes, first parent first.
    ///   - title: The commit's subject line.
    ///   - shortHash: Shown in the hash chip; the first 7 characters of `id` by default.
    ///   - authorName: Drawn as an `Avatar` and a name.
    ///   - date: Shown as a relative time.
    ///   - refs: Labels before the title.
    public init(
        id: String,
        parentIDs: [String],
        title: String,
        shortHash: String? = nil,
        authorName: String,
        date: Date,
        refs: [CommitGraphRef] = []
    ) {
        self.id = id
        self.parentIDs = parentIDs
        self.title = title
        self.shortHash = shortHash ?? String(id.prefix(7))
        self.authorName = authorName
        self.date = date
        self.refs = refs
    }

    var isMerge: Bool { parentIDs.count > 1 }
}

/// A label on a commit: a branch, a tag, or one of your own.
public struct CommitGraphRef: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A local branch (amber).
        case branch
        /// A remote-tracking branch (purple).
        case remoteBranch
        /// A tag (green).
        case tag
        /// Your own label in the accent color ("Installed", "HEAD").
        case highlight
        /// Your own label in a neutral grey.
        case neutral
    }

    public let name: String
    public let kind: Kind

    public var id: String { "\(kind)-\(name)" }

    public init(_ name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }

    var badgeStyle: BadgeStyle {
        switch kind {
        case .branch: .warning
        case .remoteBranch: .status(Purple.purple500)
        case .tag: .success
        case .highlight: .primary
        case .neutral: .secondary
        }
    }
}

// MARK: - Graph

/// A git history drawn as a graph, one row per commit, newest first.
///
/// ```swift
/// ScrollViewWithThinIndicator {
///     CommitGraph(commits, onOpen: { show($0) }) { commit, isHovered in
///         Button("Check Out") { checkOut(commit) }
///             .buttonStyle(SecondaryButtonStyle(compact: true))
///             .opacity(isHovered ? 1 : 0)
///             .disabled(!isHovered)
///     }
/// }
/// ```
///
/// Pass commits in topological order (`git log --topo-order`), newest first,
/// with parents rewritten to the commits you show (`--parents` with a path).
/// It doesn't scroll on its own.
public struct CommitGraph<Accessory: View>: View {
    private let commits: [CommitGraphCommit]
    private let laneWidth: CGFloat
    private let onOpen: ((CommitGraphCommit) -> Void)?
    private let accessory: (CommitGraphCommit, Bool) -> Accessory

    /// - Parameters:
    ///   - commits: Newest first, in topological order.
    ///   - laneWidth: Horizontal space per lane.
    ///   - onOpen: A click on a row; nil leaves rows inert.
    ///   - accessory: Trailing content per row, given whether the row is
    ///     hovered (a hover-only control should also be `.disabled` while hidden).
    public init(
        _ commits: [CommitGraphCommit],
        laneWidth: CGFloat = 18,
        onOpen: ((CommitGraphCommit) -> Void)? = nil,
        @ViewBuilder accessory: @escaping (CommitGraphCommit, Bool) -> Accessory
    ) {
        self.commits = commits
        self.laneWidth = laneWidth
        self.onOpen = onOpen
        self.accessory = accessory
    }

    public var body: some View {
        let rows = CommitGraphLayout.rows(for: commits)
        let graphWidth = CGFloat((rows.map(\.maxColumn).max() ?? 0) + 1) * laneWidth

        VStack(spacing: 0) {
            ForEach(Array(zip(commits, rows)), id: \.0.id) { commit, row in
                CommitGraphRowView(
                    commit: commit,
                    row: row,
                    laneWidth: laneWidth,
                    graphWidth: graphWidth,
                    onOpen: onOpen,
                    accessory: accessory
                )
            }
        }
    }
}

extension CommitGraph where Accessory == EmptyView {
    /// A graph with no trailing content per row.
    public init(_ commits: [CommitGraphCommit], laneWidth: CGFloat = 18, onOpen: ((CommitGraphCommit) -> Void)? = nil) {
        self.init(commits, laneWidth: laneWidth, onOpen: onOpen) { _, _ in EmptyView() }
    }
}

// MARK: - Row

private struct CommitGraphRowView<Accessory: View>: View {
    let commit: CommitGraphCommit
    let row: CommitGraphRow
    let laneWidth: CGFloat
    let graphWidth: CGFloat
    let onOpen: ((CommitGraphCommit) -> Void)?
    let accessory: (CommitGraphCommit, Bool) -> Accessory

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            details
                .modifier(CommitGraphRowTap(commit: commit, onOpen: onOpen))
            // Outside the combined element, so VoiceOver and Tab reach its controls.
            accessory(commit, isHovering)
        }
        .listRowHover(isHovering: isHovering, scheme: scheme, verticalPadding: Spacing.sm, horizontalBleed: 0)
        // Outside the padding, so each row's lanes span its full height and meet the next row's.
        .background(alignment: .leading) {
            CommitGraphLanes(row: row, laneWidth: laneWidth, isMerge: commit.isMerge)
                .frame(width: graphWidth)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Animations.hover) { isHovering = hovering }
        }
        .accessibilityElement(children: .contain)
    }

    /// Everything but the accessory: one element for VoiceOver (a button when
    /// the graph has `onOpen`), read as refs, title, hash, author and age.
    private var details: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            // Text starts after the lanes this row uses, not the widest row's.
            Color.clear
                .frame(width: CGFloat(row.maxColumn + 1) * laneWidth, height: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    ForEach(commit.refs) { ref in
                        Badge(.verbatim(ref.name))
                            .badgeStyle(ref.badgeStyle)
                            .badgeSize(.small)
                    }
                    Text(verbatim: commit.title)
                        .font(Typography.bodySmall)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack(spacing: Spacing.xs) {
                    CommitHashChip(shortHash: commit.shortHash)
                    // The name follows, so VoiceOver shouldn't read it twice.
                    Avatar(name: commit.authorName, size: .small)
                        .accessibilityHidden(true)
                    Text(verbatim: commit.authorName)
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            TimeAgoLabel(date: commit.date)
                .foregroundStyle(Color.textTertiary)
                .layoutPriority(1)
        }
        .contentShape(Rectangle())
    }
}

/// `rowTapAction` (one VoiceOver button, a Tab stop) only when the graph has
/// an `onOpen`; otherwise the row is one combined element and no Tab stop.
private struct CommitGraphRowTap: ViewModifier {
    let commit: CommitGraphCommit
    let onOpen: ((CommitGraphCommit) -> Void)?

    func body(content: Content) -> some View {
        if let onOpen {
            content.rowTapAction { onOpen(commit) }
        } else {
            content.accessibilityElement(children: .combine)
        }
    }
}

/// The short hash in the code font on a hairline outline. Not `KeyHintPill`:
/// that's a key cap, and VoiceOver should read this as text.
private struct CommitHashChip: View {
    let shortHash: String

    var body: some View {
        Text(verbatim: shortHash)
            .font(Typography.codeTiny)
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 1)
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
    }
}

// MARK: - Lanes

/// One row's slice of the graph.
private struct CommitGraphLanes: View {
    let row: CommitGraphRow
    let laneWidth: CGFloat
    let isMerge: Bool

    @Environment(\.colorScheme) private var scheme

    private static let lineWidth: CGFloat = 2
    private static let dotRadius: CGFloat = 4
    private static let mergeRingRadius: CGFloat = 5.5

    var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            let cornerRadius = min(laneWidth / 2, 6)
            func x(_ column: Int) -> CGFloat { CGFloat(column) * laneWidth + laneWidth / 2 }
            func stroke(_ path: Path, colorIndex: Int) {
                context.stroke(path, with: .color(CommitGraphPalette.color(colorIndex, scheme: scheme)), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round))
            }

            for lane in row.passThrough {
                stroke(Path { path in
                    path.move(to: CGPoint(x: x(lane.column), y: 0))
                    path.addLine(to: CGPoint(x: x(lane.column), y: size.height))
                }, colorIndex: lane.color)
            }

            if row.hasLineAbove {
                stroke(Path { path in
                    path.move(to: CGPoint(x: x(row.column), y: 0))
                    path.addLine(to: CGPoint(x: x(row.column), y: middle))
                }, colorIndex: row.color)
            }

            // A lane from above that ends here: down, round the corner, across into the dot.
            for lane in row.incoming {
                let direction: CGFloat = lane.column > row.column ? -1 : 1
                stroke(Path { path in
                    path.move(to: CGPoint(x: x(lane.column), y: 0))
                    path.addLine(to: CGPoint(x: x(lane.column), y: middle - cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: x(lane.column) + direction * cornerRadius, y: middle), control: CGPoint(x: x(lane.column), y: middle))
                    path.addLine(to: CGPoint(x: x(row.column), y: middle))
                }, colorIndex: lane.color)
            }

            // To each parent: straight down, or across, round the corner, and down its lane.
            for lane in row.parents {
                stroke(Path { path in
                    path.move(to: CGPoint(x: x(row.column), y: middle))
                    if lane.column != row.column {
                        let direction: CGFloat = lane.column > row.column ? 1 : -1
                        path.addLine(to: CGPoint(x: x(lane.column) - direction * cornerRadius, y: middle))
                        path.addQuadCurve(to: CGPoint(x: x(lane.column), y: middle + cornerRadius), control: CGPoint(x: x(lane.column), y: middle))
                    }
                    path.addLine(to: CGPoint(x: x(lane.column), y: size.height))
                }, colorIndex: lane.color)
            }

            let center = CGPoint(x: x(row.column), y: middle)
            let color = CommitGraphPalette.color(row.color, scheme: scheme)
            if isMerge {
                let ring = Path(ellipseIn: CGRect(x: center.x - Self.mergeRingRadius, y: center.y - Self.mergeRingRadius, width: Self.mergeRingRadius * 2, height: Self.mergeRingRadius * 2))
                context.fill(ring, with: .color(Color.contentAreaBackground))
                context.stroke(ring, with: .color(color), lineWidth: 1.5)
                let innerRadius: CGFloat = 2
                context.fill(Path(ellipseIn: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)), with: .color(color))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: center.x - Self.dotRadius, y: center.y - Self.dotRadius, width: Self.dotRadius * 2, height: Self.dotRadius * 2)), with: .color(color))
            }
        }
    }
}

/// Lane colors: the status marks plus purple, lifted on dark like any mark.
/// Computed each time — the marks follow the active theme.
enum CommitGraphPalette {
    static func color(_ index: Int, scheme: ColorScheme) -> Color {
        let marks = [Danger.danger500, Success.success500, Warning.warning500, Purple.purple500, Info.info500]
        return marks[index % marks.count].legibleOnDark(scheme)
    }
}

// MARK: - Layout

/// A lane segment: which column it's in and which color it carries.
struct CommitGraphLane: Hashable, Sendable {
    let column: Int
    let color: Int
}

/// What one row draws.
struct CommitGraphRow: Hashable, Sendable {
    /// The commit's lane.
    let column: Int
    let color: Int
    /// A lane continued into this commit from the row above.
    let hasLineAbove: Bool
    /// Other lanes that end at this commit (the branches it merges, or that branched from it).
    let incoming: [CommitGraphLane]
    /// Lanes that pass by untouched.
    let passThrough: [CommitGraphLane]
    /// Where each parent's line leaves this row.
    let parents: [CommitGraphLane]

    var maxColumn: Int {
        ([column] + incoming.map(\.column) + passThrough.map(\.column) + parents.map(\.column)).max() ?? 0
    }
}

/// Assigns lanes the way most git clients do: a commit takes the lane that
/// was waiting for it (the leftmost if several were, and the others end into
/// it), its first parent continues that lane, and every other parent joins a
/// lane already waiting for it or takes a free one. A lane's color stays with
/// it from the commit that opened it until it ends.
enum CommitGraphLayout {
    static func rows(for commits: [CommitGraphCommit]) -> [CommitGraphRow] {
        var lanes: [(commitID: String, color: Int)?] = []
        var nextColor = 0
        var rows: [CommitGraphRow] = []
        rows.reserveCapacity(commits.count)

        func freeColumn() -> Int {
            if let index = lanes.firstIndex(where: { $0 == nil }) { return index }
            lanes.append(nil)
            return lanes.count - 1
        }

        for commit in commits {
            let waiting = lanes.indices.filter { lanes[$0]?.commitID == commit.id }
            let column: Int
            let color: Int
            if let first = waiting.first, let lane = lanes[first] {
                column = first
                color = lane.color
            } else {
                column = freeColumn()
                color = nextColor
                nextColor += 1
            }
            let incoming = waiting.dropFirst().compactMap { index in lanes[index].map { CommitGraphLane(column: index, color: $0.color) } }
            for index in waiting { lanes[index] = nil }

            let passThrough = lanes.indices.compactMap { index in
                lanes[index].map { CommitGraphLane(column: index, color: $0.color) }
            }

            var parents: [CommitGraphLane] = []
            for (parentIndex, parentID) in commit.parentIDs.enumerated() {
                if parentIndex == 0 {
                    // The first parent always continues this lane. If another lane
                    // waits for it too, the two meet at the parent's row.
                    lanes[column] = (parentID, color)
                    parents.append(CommitGraphLane(column: column, color: color))
                } else if let existing = lanes.firstIndex(where: { $0?.commitID == parentID }) {
                    // A merged parent that a lane already waits for joins that lane.
                    parents.append(CommitGraphLane(column: existing, color: color))
                } else {
                    let newColumn = freeColumn()
                    lanes[newColumn] = (parentID, nextColor)
                    parents.append(CommitGraphLane(column: newColumn, color: nextColor))
                    nextColor += 1
                }
            }

            while let last = lanes.last, last == nil { lanes.removeLast() }

            rows.append(CommitGraphRow(
                column: column,
                color: color,
                hasLineAbove: !waiting.isEmpty,
                incoming: incoming,
                passThrough: passThrough,
                parents: parents
            ))
        }
        return rows
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 640, height: 560)) {
    let day: TimeInterval = 86_400
    let now = Date()
    ScrollViewWithThinIndicator {
        CommitGraph([
            CommitGraphCommit(id: "9a4a6a4", parentIDs: ["adc4847"], title: "Show sunrise and sunset", authorName: "Mara Lindqvist", date: now - 21 * day),
            CommitGraphCommit(id: "da952d4", parentIDs: ["7c22f2f"], title: "Refresh the widget every hour", authorName: "Priya Raman", date: now - 28 * day, refs: [CommitGraphRef("origin/feature/widgets", kind: .remoteBranch), CommitGraphRef("feature/widgets", kind: .branch)]),
            CommitGraphCommit(id: "7c22f2f", parentIDs: ["adc4847"], title: "Add a small Today widget", authorName: "Priya Raman", date: now - 30 * day),
            CommitGraphCommit(id: "adc4847", parentIDs: ["2fd6dc2", "55697e4"], title: "Merge branch 'feature/offline'", authorName: "Mara Lindqvist", date: now - 32 * day, refs: [CommitGraphRef("v1.0.0", kind: .tag)]),
            CommitGraphCommit(id: "55697e4", parentIDs: ["184d442"], title: "Serve the cached forecast when offline", authorName: "Theo Brandt", date: now - 33 * day),
            CommitGraphCommit(id: "184d442", parentIDs: ["20eb5ba"], title: "Expire cached forecasts after six hours", authorName: "Theo Brandt", date: now - 34 * day),
            CommitGraphCommit(id: "20eb5ba", parentIDs: ["71c90cc"], title: "Cache forecasts on disk", authorName: "Theo Brandt", date: now - 35 * day),
            CommitGraphCommit(id: "2fd6dc2", parentIDs: ["a6dfa29"], title: "Localize condition names", authorName: "Priya Raman", date: now - 36 * day),
            CommitGraphCommit(id: "a6dfa29", parentIDs: ["71c90cc", "f33ac3e"], title: "Merge branch 'fix/units'", authorName: "Mara Lindqvist", date: now - 37 * day),
            CommitGraphCommit(id: "f33ac3e", parentIDs: ["71c90cc"], title: "Respect the system's temperature unit", authorName: "Jonas Weber", date: now - 38 * day),
            CommitGraphCommit(id: "71c90cc", parentIDs: ["c41d2e9", "6856bfd"], title: "Merge branch 'feature/hourly'", authorName: "Mara Lindqvist", date: now - 39 * day),
            CommitGraphCommit(id: "6856bfd", parentIDs: ["5a27a62"], title: "Animate temperature changes", authorName: "Priya Raman", date: now - 40 * day),
            CommitGraphCommit(id: "5a27a62", parentIDs: ["c41d2e9"], title: "Add an hourly strip", authorName: "Priya Raman", date: now - 41 * day),
            CommitGraphCommit(id: "c41d2e9", parentIDs: ["8e3f1a0"], title: "Retry failed requests with backoff", authorName: "Theo Brandt", date: now - 42 * day, refs: [CommitGraphRef("Installed", kind: .highlight)]),
            CommitGraphCommit(id: "8e3f1a0", parentIDs: [], title: "Fetch the forecast", authorName: "Mara Lindqvist", date: now - 45 * day),
        ])
        .padding(Spacing.lg)
    }
    .background(Color.contentAreaBackground)
    .blissTheme()
}
