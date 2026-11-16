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
/// ```
///
/// The sparkline trails the value on the same row, so a 240pt card holds it
/// without growing. The card has no hover; put it in a grid of its siblings.
public struct StatCard: View {
    private let title: LocalizedStringKey
    private let value: String
    private let change: StatChange?
    private let detail: LocalizedStringKey?
    private let systemImage: String?
    private let sparkline: [Double]?

    /// - Parameters:
    ///   - title: What the number is ("Active users"), looked up in your app's strings.
    ///   - value: The number, formatted ("1,284").
    ///   - change: The move since the last period, as a pill.
    ///   - detail: A line after the pill ("vs last week").
    ///   - systemImage: An SF Symbol before the title.
    ///   - sparkline: Recent readings, oldest first, drawn beside the value.
    public init(
        _ title: LocalizedStringKey,
        value: String,
        change: StatChange? = nil,
        detail: LocalizedStringKey? = nil,
        systemImage: String? = nil,
        sparkline: [Double]? = nil
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.detail = detail
        self.systemImage = systemImage
        self.sparkline = sparkline
    }

    public var body: some View {
        RoundedSection {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(Typography.labelMedium)
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
                        .font(Typography.displaySmall.monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    if let sparkline, !sparkline.isEmpty {
                        Sparkline(sparkline, color: Color.accent)
                            .frame(width: 48, height: 20)
                    }
                }

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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("Stat cards", traits: .fixedLayout(width: 760, height: 160)) {
    HStack(spacing: Spacing.md) {
        StatCard("Active users", value: "1,284", change: StatChange("12%", direction: .up), detail: "vs last week", systemImage: "person.2", sparkline: [12, 14, 13, 17, 19, 18, 23, 26])
        StatCard("Error rate", value: "0.4%", change: StatChange("0.1 pt", direction: .up, isPositive: false), detail: "vs last week", systemImage: "exclamationmark.triangle", sparkline: [3, 2, 2, 4, 3, 5, 4, 6])
        StatCard("Builds today", value: "48", change: StatChange("0", direction: .flat), detail: "same as yesterday", systemImage: "hammer")
    }
    .padding(Spacing.xl)
}
