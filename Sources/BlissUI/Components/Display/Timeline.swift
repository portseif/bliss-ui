//
//  Timeline.swift
//  BlissUI
//
//  An activity feed: a column of marks joined by a connector line, with the
//  event beside each mark. `Timeline` lays the rows out and tells each one
//  where it sits, so the line stops at the first mark and the last; each row
//  is a `TimelineItem` with a dot, an icon or an avatar mark, an optional
//  time on the first line, and the caller's content.
//

import SwiftUI

// MARK: - Row position

/// Where a row sits in its timeline, so its connector knows which ends to draw.
enum TimelineRowPosition {
    case first, middle, last, only

    var connectsUp: Bool { self == .middle || self == .last }
    var connectsDown: Bool { self == .first || self == .middle }
}

private struct TimelineRowPositionKey: EnvironmentKey {
    static let defaultValue: TimelineRowPosition = .only
}

private struct TimelineCompactKey: EnvironmentKey {
    static let defaultValue = false
}

private struct TimelinePlacementKey: EnvironmentKey {
    static let defaultValue: TimelinePlacement = .trailing
}

extension EnvironmentValues {
    var timelineRowPosition: TimelineRowPosition {
        get { self[TimelineRowPositionKey.self] }
        set { self[TimelineRowPositionKey.self] = newValue }
    }

    var timelineIsCompact: Bool {
        get { self[TimelineCompactKey.self] }
        set { self[TimelineCompactKey.self] = newValue }
    }

    var timelinePlacement: TimelinePlacement {
        get { self[TimelinePlacementKey.self] }
        set { self[TimelinePlacementKey.self] = newValue }
    }
}

/// Where a `TimelineItem`'s time sits.
public enum TimelinePlacement: Hashable, Sendable {
    /// After the content, on its first line.
    case trailing
    /// In a column before the mark, like an activity log.
    case leading
}

// MARK: - Timeline

/// A vertical feed of events, each a `TimelineItem`.
///
/// ```swift
/// Timeline(events) { event in
///     TimelineItem(mark: .icon("checkmark", Success.success500), time: Text(event.date, style: .relative)) {
///         Text(verbatim: event.title)
///     }
/// }
/// ```
public struct Timeline<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let compact: Bool
    private let timePlacement: TimelinePlacement
    private let content: (Data.Element) -> Content

    /// - Parameters:
    ///   - data: The events, top to bottom.
    ///   - id: What identifies an event.
    ///   - compact: Tighter rows in caption type, for an inspector.
    ///   - timePlacement: The time after the content, or in a column before the marks.
    ///   - content: The row for an event — a `TimelineItem`.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        compact: Bool = false,
        timePlacement: TimelinePlacement = .trailing,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.id = id
        self.compact = compact
        self.timePlacement = timePlacement
        self.content = content
    }

    public var body: some View {
        let firstID = data.first.map { $0[keyPath: id] }
        let lastID = data.last.map { $0[keyPath: id] }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(data, id: id) { element in
                content(element)
                    .environment(\.timelineRowPosition, position(of: element[keyPath: id], first: firstID, last: lastID))
            }
        }
        .environment(\.timelineIsCompact, compact)
        .environment(\.timelinePlacement, timePlacement)
    }

    private func position(of elementID: ID, first: ID?, last: ID?) -> TimelineRowPosition {
        let isFirst = elementID == first
        let isLast = elementID == last
        if isFirst && isLast { return .only }
        if isFirst { return .first }
        if isLast { return .last }
        return .middle
    }
}

extension Timeline where Data.Element: Identifiable, ID == Data.Element.ID {
    /// A timeline of identifiable events.
    public init(
        _ data: Data,
        compact: Bool = false,
        timePlacement: TimelinePlacement = .trailing,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.init(data, id: \.id, compact: compact, timePlacement: timePlacement, content: content)
    }
}

// MARK: - Mark

/// What marks an event on the line: a small dot, an SF Symbol on a wash of
/// its color, or the actor's avatar. Callers pass the status marks
/// (`Success.success500`, …).
public nonisolated enum TimelineMark: Sendable {
    case dot(Color)
    case icon(String, Color)
    /// A small `Avatar` for `name`: who did it.
    case avatar(name: String)
}

// MARK: - Item

/// One event in a `Timeline`: its mark on the line, an optional time on the
/// first line, and the content beside it.
public struct TimelineItem<Content: View>: View {
    private let mark: TimelineMark
    private let time: Text?
    private let content: Content

    @Environment(\.timelineRowPosition) private var position
    @Environment(\.timelineIsCompact) private var isCompact
    @Environment(\.timelinePlacement) private var placement
    @Environment(\.colorScheme) private var colorScheme

    /// The mark column: wide enough for the icon's circle (or the avatar).
    private var columnWidth: CGFloat {
        if case .avatar = mark { return Sizing.iconMedium }
        return Sizing.iconDefault + Spacing.xxs
    }
    /// Half the row's vertical padding on each side, so rows sit `Spacing.md`
    /// apart (`Spacing.sm` when compact).
    private var rowInset: CGFloat { isCompact ? Spacing.xxs : Spacing.xs }
    /// The first line of the content; the mark centers on it.
    private var firstLineHeight: CGFloat { isCompact ? Sizing.iconSmall : Sizing.iconDefault }
    private var markCenterY: CGFloat { rowInset + firstLineHeight / 2 }
    /// The leading time column's width.
    private static var timeColumnWidth: CGFloat { Spacing.xxxxl }

    /// - Parameters:
    ///   - mark: The dot, icon or avatar on the line.
    ///   - time: When it happened (`Text(date, style: .relative)`).
    ///   - content: The event, in `Typography.bodySmall` unless it sets its own.
    public init(mark: TimelineMark = .dot(.secondary), time: Text? = nil, @ViewBuilder content: () -> Content) {
        self.mark = mark
        self.time = time
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            if placement == .leading {
                timeLabel
                    .frame(width: Self.timeColumnWidth, alignment: .trailing)
                    .padding(.vertical, rowInset)
            }

            markColumn
                .frame(width: columnWidth)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                content
                    .font(isCompact ? Typography.captionSmall : Typography.bodySmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if placement == .trailing {
                    timeLabel
                }
            }
            .padding(.vertical, rowInset)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var timeLabel: some View {
        if let time {
            time
                .font(isCompact ? Typography.captionTiny : Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// The connector through the column's center, with the mark on it. The
    /// segment above the mark is drawn for every row but the first, the one
    /// below for every row but the last.
    private var markColumn: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                connector
                    .frame(height: markCenterY)
                    .opacity(position.connectsUp ? 1 : 0)
                connector
                    .frame(maxHeight: .infinity)
                    .opacity(position.connectsDown ? 1 : 0)
            }
            markView
                .padding(.top, markCenterY - markHeight / 2)
        }
    }

    private var connector: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(width: 1)
    }

    private var markHeight: CGFloat {
        switch mark {
        case .dot: return Sizing.statusCircle + Spacing.hairline
        case .icon, .avatar: return columnWidth
        }
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .dot(let color):
            Circle()
                .fill(color)
                .frame(width: markHeight, height: markHeight)
        case .icon(let name, let color):
            Image(systemName: name)
                .font(Typography.captionSmall)
                .foregroundStyle(color)
                .frame(width: markHeight, height: markHeight)
                .background {
                    Circle().fill(StatusWash.fill(color, colorScheme))
                }
        case .avatar(let name):
            Avatar(name: name, size: .small)
        }
    }
}

// MARK: - Preview

private struct TimelinePreviewEvent: Identifiable {
    let id: Int
    let title: String
    let detail: String?
    let mark: TimelineMark
    let minutesAgo: Int
}

#Preview("Timeline", traits: .fixedLayout(width: 420, height: 300)) {
    let events = [
        TimelinePreviewEvent(id: 1, title: "Deploy finished", detail: "Build 412 is live on production.", mark: .icon("checkmark", Success.success500), minutesAgo: 4),
        TimelinePreviewEvent(id: 2, title: "Tests passed", detail: nil, mark: .dot(Success.success500), minutesAgo: 9),
        TimelinePreviewEvent(id: 3, title: "Build started", detail: "Triggered by a push to main.", mark: .dot(.secondary), minutesAgo: 12),
        TimelinePreviewEvent(id: 4, title: "Ada approved the change", detail: nil, mark: .avatar(name: "Ada Lovelace"), minutesAgo: 20),
        TimelinePreviewEvent(id: 5, title: "Migration warning", detail: "Two columns were dropped without a backup.", mark: .icon("exclamationmark.triangle", Warning.warning500), minutesAgo: 30),
    ]
    Timeline(events) { event in
        TimelineItem(mark: event.mark, time: Text(verbatim: "\(event.minutesAgo)m ago")) {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(verbatim: event.title)
                if let detail = event.detail {
                    Text(verbatim: detail)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    .padding(Spacing.xl)
}

#Preview("Compact, leading time", traits: .fixedLayout(width: 420, height: 200)) {
    let events = [
        TimelinePreviewEvent(id: 1, title: "Signed in", detail: nil, mark: .dot(.secondary), minutesAgo: 2),
        TimelinePreviewEvent(id: 2, title: "Changed the plan", detail: nil, mark: .dot(Info.info500), minutesAgo: 15),
        TimelinePreviewEvent(id: 3, title: "Exported a report", detail: nil, mark: .dot(.secondary), minutesAgo: 44),
    ]
    Timeline(events, compact: true, timePlacement: .leading) { event in
        TimelineItem(mark: event.mark, time: Text(verbatim: "\(event.minutesAgo)m")) {
            Text(verbatim: event.title)
        }
    }
    .padding(Spacing.xl)
}
