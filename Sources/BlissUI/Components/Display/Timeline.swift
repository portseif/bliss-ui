//
//  Timeline.swift
//  BlissUI
//
//  An activity feed: a column of marks joined by a connector line, with the
//  event beside each mark. `Timeline` lays the rows out and tells each one
//  where it sits, so the line stops at the first mark and the last; each row
//  is a `TimelineItem` with a dot or an icon mark, an optional time on the
//  first line, and the caller's content.
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

extension EnvironmentValues {
    var timelineRowPosition: TimelineRowPosition {
        get { self[TimelineRowPositionKey.self] }
        set { self[TimelineRowPositionKey.self] = newValue }
    }
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
    private let content: (Data.Element) -> Content

    /// - Parameters:
    ///   - data: The events, top to bottom.
    ///   - id: What identifies an event.
    ///   - content: The row for an event — a `TimelineItem`.
    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.id = id
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
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.init(data, id: \.id, content: content)
    }
}

// MARK: - Mark

/// What marks an event on the line: a small dot, or an SF Symbol on a wash of
/// its color. Callers pass the status marks (`Success.success500`, …).
public nonisolated enum TimelineMark: Sendable {
    case dot(Color)
    case icon(String, Color)
}

// MARK: - Item

/// One event in a `Timeline`: its mark on the line, an optional time on the
/// first line, and the content beside it.
public struct TimelineItem<Content: View>: View {
    private let mark: TimelineMark
    private let time: Text?
    private let content: Content

    @Environment(\.timelineRowPosition) private var position

    /// The mark column: wide enough for the icon's circle.
    private static var columnWidth: CGFloat { Sizing.iconDefault + Spacing.xxs }
    /// Half the row's vertical padding on each side, so rows sit `Spacing.md` apart.
    private static var rowInset: CGFloat { Spacing.xs }
    /// The first line of `Typography.bodySmall` content; the mark centers on it.
    private static var firstLineHeight: CGFloat { Sizing.iconDefault }
    private static var markCenterY: CGFloat { rowInset + firstLineHeight / 2 }

    /// - Parameters:
    ///   - mark: The dot or icon on the line.
    ///   - time: When it happened, trailing on the first line (`Text(date, style: .relative)`).
    ///   - content: The event, in `Typography.bodySmall` unless it sets its own.
    public init(mark: TimelineMark = .dot(.secondary), time: Text? = nil, @ViewBuilder content: () -> Content) {
        self.mark = mark
        self.time = time
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            markColumn
                .frame(width: Self.columnWidth)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                content
                    .font(Typography.bodySmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let time {
                    time
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, Self.rowInset)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// The connector through the column's center, with the mark on it. The
    /// segment above the mark is drawn for every row but the first, the one
    /// below for every row but the last.
    private var markColumn: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                connector
                    .frame(height: Self.markCenterY)
                    .opacity(position.connectsUp ? 1 : 0)
                connector
                    .frame(maxHeight: .infinity)
                    .opacity(position.connectsDown ? 1 : 0)
            }
            markView
                .padding(.top, Self.markCenterY - markHeight / 2)
        }
    }

    private var connector: some View {
        Rectangle()
            .fill(Color.menuBorder)
            .frame(width: 1)
    }

    private var markHeight: CGFloat {
        switch mark {
        case .dot: return Sizing.statusCircle + 2
        case .icon: return Self.columnWidth
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
                    Circle().fill(color.opacity(0.15))
                }
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

#Preview("Timeline", traits: .fixedLayout(width: 420, height: 260)) {
    let events = [
        TimelinePreviewEvent(id: 1, title: "Deploy finished", detail: "Build 412 is live on production.", mark: .icon("checkmark", Success.success500), minutesAgo: 4),
        TimelinePreviewEvent(id: 2, title: "Tests passed", detail: nil, mark: .dot(Success.success500), minutesAgo: 9),
        TimelinePreviewEvent(id: 3, title: "Build started", detail: "Triggered by a push to main.", mark: .dot(.secondary), minutesAgo: 12),
        TimelinePreviewEvent(id: 4, title: "Migration warning", detail: "Two columns were dropped without a backup.", mark: .icon("exclamationmark.triangle", Warning.warning500), minutesAgo: 30),
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
