//
//  StatCard.swift
//  BlissUI
//
//  The dashboard tile: a title, a big value, a change pill that says whether
//  the move was good, and a sparkline of the recent readings. The card is a
//  `RoundedSection`, so it sits beside the settings cards without a seam.
//

import SwiftUI

// MARK: - Change

/// How a stat moved since the last period, already formatted by the app.
public struct StatChange: Hashable, Sendable {
    public enum Direction: Hashable, Sendable {
        case up, down, flat
    }

    /// The change as text ("12%", "+3"), shown as-is.
    public var text: String
    public var direction: Direction
    /// Whether `up` is good news — a cost going up is not.
    public var isPositive: Bool

    /// - Parameters:
    ///   - text: The change, formatted ("12%", "+3").
    ///   - direction: Which way it moved.
    ///   - isPositive: Whether an upward move is good; the pill is green when
    ///     the move is good and red when it is bad, whichever way it went.
    public init(_ text: String, direction: Direction, isPositive: Bool = true) {
        self.text = text
        self.direction = direction
        self.isPositive = isPositive
    }

    /// Up is good when `isPositive`, down is good when it isn't.
    var isGood: Bool {
        switch direction {
        case .up: return isPositive
        case .down: return !isPositive
        case .flat: return true
        }
    }

    var systemImage: String {
        switch direction {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }

    var badgeStyle: BadgeStyle {
        switch direction {
        case .flat: return .secondary
        case .up, .down: return isGood ? .success : .error
        }
    }
}

// MARK: - Stat Card

/// A metric tile: title, value, change and an optional sparkline.
///
/// ```swift
/// StatCard("Active users", value: "1,284", change: StatChange("12%", direction: .up), detail: "vs last week", sparkline: dailyUsers)
/// StatCard("Builds", value: "48", compact: true)
/// StatCard("Revenue", value: "$4,120", onOpen: { showRevenue() })
/// ```
///
/// The sparkline trails the value on the same row, so a 240pt card holds it
/// without growing. With `onOpen` the card is a button with the hover wash;
/// otherwise it has no hover — put it in a grid of its siblings.
public struct StatCard: View {
    private let title: LocalizedStringKey
    private let value: String
    private let change: StatChange?
    private let detail: LocalizedStringKey?
    private let systemImage: String?
    private let sparkline: [Double]?
    private let sparklineColor: Color?
    private let compact: Bool
    private let isLoading: Bool
    private let onOpen: (() -> Void)?

    /// - Parameters:
    ///   - title: What the number is ("Active users"), looked up in your app's strings.
    ///   - value: The number, formatted ("1,284").
    ///   - change: The move since the last period, as a pill.
    ///   - detail: A line after the pill ("vs last week").
    ///   - systemImage: An SF Symbol before the title.
    ///   - sparkline: Recent readings, oldest first, drawn beside the value.
    ///   - sparklineColor: The sparkline's mark; nil is the accent.
    ///   - compact: A smaller value and no sparkline, for a four-up strip or a sidebar.
    ///   - isLoading: Redacts the value row to a skeleton while the number loads.
    ///   - onOpen: Makes the card a button (a drill-down) with the hover wash.
    public init(
        _ title: LocalizedStringKey,
        value: String,
        change: StatChange? = nil,
        detail: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        sparkline: [Double]? = nil,
        sparklineColor: Color? = nil,
        compact: Bool = false,
        isLoading: Bool = false,
        onOpen: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.detail = detail
        self.systemImage = systemImage
        self.sparkline = sparkline
        self.sparklineColor = sparklineColor
        self.compact = compact
        self.isLoading = isLoading
        self.onOpen = onOpen
    }

    public var body: some View {
        if let onOpen {
            Button(action: onOpen) {
                card
            }
            .buttonStyle(SelectableCardButtonStyle(cornerRadius: Sizing.radiusLarge))
            .accessibilityElement(children: .combine)
        } else {
            card
                .accessibilityElement(children: .combine)
        }
    }

    private var card: some View {
        RoundedSection {
            VStack(alignment: .leading, spacing: compact ? Spacing.xs : Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    if let systemImage {
                        BlissSymbol(systemImage)
                            .font(Typography.labelSmall)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .lastTextBaseline, spacing: Spacing.md) {
                    Text(verbatim: value)
                        .font((compact ? Typography.headingLarge : Typography.displaySmall).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(DataMetrics.minimumScaleFactor)
                    Spacer(minLength: 0)
                    if !compact, let sparkline, !sparkline.isEmpty {
                        Sparkline(sparkline, color: sparklineColor ?? Color.accent)
                            .frame(width: StatCardMetrics.sparklineSize.width, height: StatCardMetrics.sparklineSize.height)
                    }
                }
                .skeleton(isLoading: isLoading)

                if change != nil || detail != nil {
                    HStack(spacing: Spacing.xs) {
                        if let change {
                            Badge(.verbatim(change.text), icon: change.systemImage)
                                .badgeStyle(change.badgeStyle)
                                .badgeSize(.small)
                        }
                        if let detail {
                            Text(detail)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

/// The tile's drawing constants.
enum StatCardMetrics {
    /// The sparkline beside the value: wide enough to read a trend, no taller
    /// than the value's line.
    static let sparklineSize = CGSize(width: Sizing.iconHuge, height: Sizing.iconMedium)
}

// MARK: - Preview

#Preview("Stat cards", traits: .fixedLayout(width: 760, height: 280)) {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.md) {
            StatCard("Active users", value: "1,284", change: StatChange("12%", direction: .up), detail: "vs last week", systemImage: "person.2", sparkline: [12, 14, 13, 17, 19, 18, 23, 26])
            StatCard("Error rate", value: "0.4%", change: StatChange("0.1 pt", direction: .up, isPositive: false), detail: "vs last week", systemImage: "exclamationmark.triangle", sparkline: [3, 2, 2, 4, 3, 5, 4, 6], sparklineColor: Danger.danger500)
            StatCard("Builds today", value: "48", change: StatChange("0", direction: .flat), detail: "same as yesterday", systemImage: "hammer", onOpen: {})
        }
        HStack(spacing: Spacing.md) {
            StatCard("Open issues", value: "17", compact: true)
            StatCard("Deploys", value: "3", change: StatChange("1", direction: .up), compact: true)
            StatCard("Latency", value: "142 ms", compact: true, isLoading: true)
        }
    }
    .padding(Spacing.xl)
}
