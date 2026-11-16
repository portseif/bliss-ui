//
//  ProgressOverlay.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/6/25.
//
//  A floating card for a long-running scan or import: a header (icon, title,
//  subtitle) with running counters, an optional determinate bar, the item
//  being worked on under a spinner, up to `maximumActiveItems` parallel
//  sub-tasks with what each is on right now, and an optional Cancel.
//

import SwiftUI

/// The overlay's own numbers.
private enum ProgressOverlayMetrics {
    /// The sub-task name column.
    static let nameColumnWidth: CGFloat = 80
}

public struct ProgressOverlay: View {
    /// A running count in the header's trailing column (e.g. folders scanned).
    public struct Counter: Identifiable {
        public let id: UUID
        /// SF Symbol name.
        public var systemImage: String
        public var value: Int
        /// Turns the count green once it's above zero — for a "found something"
        /// tally, where any hit is good news.
        public var highlightsWhenNonzero: Bool

        public init(id: UUID = UUID(), systemImage: String, value: Int, highlightsWhenNonzero: Bool = false) {
            self.id = id
            self.systemImage = systemImage
            self.value = value
            self.highlightsWhenNonzero = highlightsWhenNonzero
        }
    }

    /// A sub-task running alongside the main one (e.g. a linked folder being
    /// followed), listed under the current item.
    public struct ActiveItem: Identifiable {
        public let id: UUID
        public var name: String
        /// What this sub-task is on right now.
        public var detail: String

        public init(id: UUID = UUID(), name: String, detail: String) {
            self.id = id
            self.name = name
            self.detail = detail
        }
    }

    let title: LocalizedStringKey
    let subtitle: String
    let systemImage: String
    let currentItem: String
    let counters: [Counter]
    let activeItems: [ActiveItem]
    let activeItemsTitle: LocalizedStringKey?
    let activeItemsSystemImage: String
    let progress: Double?
    let maximumActiveItems: Int
    let width: CGFloat
    let onCancel: (() -> Void)?

    /// - Parameters:
    ///   - title: What's running ("Importing Library").
    ///   - subtitle: What it's running on, middle-truncated (a folder name).
    ///   - systemImage: The header's SF Symbol.
    ///   - currentItem: The item being worked on, shown beside a spinner.
    ///   - counters: Running counts in the header's trailing column.
    ///   - activeItems: Parallel sub-tasks; the first `maximumActiveItems` are listed.
    ///   - activeItemsTitle: The line above them ("Following 2 linked folders…");
    ///     nil lists them without one.
    ///   - activeItemsSystemImage: The SF Symbol leading that line.
    ///   - progress: A determinate bar under the header (0…1) for work with a
    ///     known total; nil shows none.
    ///   - maximumActiveItems: How many sub-tasks are listed before "+N more".
    ///   - width: The card's width.
    ///   - onCancel: A Cancel button in a footer; nil shows none.
    public init(
        title: LocalizedStringKey,
        subtitle: String,
        systemImage: String = "folder.fill",
        currentItem: String,
        counters: [Counter] = [],
        activeItems: [ActiveItem] = [],
        activeItemsTitle: LocalizedStringKey? = nil,
        activeItemsSystemImage: String = "link",
        progress: Double? = nil,
        maximumActiveItems: Int = 3,
        width: CGFloat = Sizing.sheetWidthMedium,
        onCancel: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.currentItem = currentItem
        self.counters = counters
        self.activeItems = activeItems
        self.activeItemsTitle = activeItemsTitle
        self.activeItemsSystemImage = activeItemsSystemImage
        self.progress = progress
        self.maximumActiveItems = max(maximumActiveItems, 0)
        self.width = width
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(Typography.displayMediumMedium)
                    .foregroundStyle(Color.accent)

                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(title)
                        .font(Typography.bodyMediumSemibold)
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Stats
                if !counters.isEmpty {
                    VStack(alignment: .trailing, spacing: Spacing.headingSpacing) {
                        ForEach(counters) { counter in
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: counter.systemImage)
                                    .font(Typography.captionTiny)
                                Text("\(counter.value)")
                                    .font(Typography.labelXSmall)
                            }
                            .foregroundStyle(counter.highlightsWhenNonzero && counter.value > 0 ? Success.success500 : Color.secondary)
                        }
                    }
                }
            }

            // A known total: the bar.
            if let progress {
                ProgressBar(value: progress)
            }

            // Current item being worked on
            HStack(spacing: Spacing.sm) {
                ThinkingSpinner(size: Sizing.iconSmall, lineWidth: Spacing.hairline)
                Text(currentItem)
                    .font(Typography.codeTiny)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            // Active sub-tasks
            if !activeItems.isEmpty {
                Divider()

                VStack(spacing: Spacing.sm) {
                    if let activeItemsTitle {
                        HStack {
                            Image(systemName: activeItemsSystemImage)
                                .font(Typography.captionTiny)
                                .foregroundStyle(Warning.warning500)
                            Text(activeItemsTitle)
                                .font(Typography.labelTiny)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    ForEach(activeItems.prefix(maximumActiveItems)) { item in
                        HStack(spacing: Spacing.xs) {
                            Text(item.name)
                                .font(Typography.codeTiny)
                                .foregroundStyle(Warning.warning500)
                                .lineLimit(1)
                                .frame(width: ProgressOverlayMetrics.nameColumnWidth, alignment: .leading)

                            ThinkingSpinner(size: Sizing.controlTiny, lineWidth: 1)

                            Text(item.detail)
                                .font(Typography.codeTiny)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()
                        }
                    }

                    if activeItems.count > maximumActiveItems {
                        Text("+ \(activeItems.count - maximumActiveItems) more…", bundle: .module)
                            .font(Typography.captionTiny)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let onCancel {
                Divider()
                HStack {
                    Spacer()
                    Button(String(localized: "Cancel", bundle: .module), action: onCancel)
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(Spacing.cardPadding)
        .frame(width: width)
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.controlBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .elevation(.panel)
    }
}

#Preview(traits: .fixedLayout(width: 520, height: 320)) {
    ZStack {
        Color.windowBackground
            .ignoresSafeArea()

        ProgressOverlay(
            title: "Importing Library",
            subtitle: "Photos 2024",
            currentItem: "Vacation/Beach/IMG_0142.jpg",
            counters: [
                .init(systemImage: "folder", value: 142),
                .init(systemImage: "photo", value: 2, highlightsWhenNonzero: true)
            ],
            activeItems: [
                .init(name: "Shared", detail: "Family/Birthdays"),
                .init(name: "Archive", detail: "2019/Scans")
            ],
            activeItemsTitle: "Following 2 linked folders…",
            progress: 0.42,
            onCancel: {}
        )
    }
}
