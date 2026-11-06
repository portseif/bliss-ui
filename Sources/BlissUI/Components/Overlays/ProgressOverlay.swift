//
//  ProgressOverlay.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/6/25.
//
//  A floating card for a long-running scan or import: a header (icon, title,
//  subtitle) with running counters, the item being worked on under a spinner,
//  and up to three parallel sub-tasks with what each is on right now.
//

import SwiftUI

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

    /// - Parameters:
    ///   - title: What's running ("Importing Library").
    ///   - subtitle: What it's running on, middle-truncated (a folder name).
    ///   - systemImage: The header's SF Symbol.
    ///   - currentItem: The item being worked on, shown beside a spinner.
    ///   - counters: Running counts in the header's trailing column.
    ///   - activeItems: Parallel sub-tasks; the first three are listed.
    ///   - activeItemsTitle: The line above them ("Following 2 linked folders…");
    ///     nil lists them without one.
    ///   - activeItemsSystemImage: The SF Symbol leading that line.
    public init(
        title: LocalizedStringKey,
        subtitle: String,
        systemImage: String = "folder.fill",
        currentItem: String,
        counters: [Counter] = [],
        activeItems: [ActiveItem] = [],
        activeItemsTitle: LocalizedStringKey? = nil,
        activeItemsSystemImage: String = "link"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.currentItem = currentItem
        self.counters = counters
        self.activeItems = activeItems
        self.activeItemsTitle = activeItemsTitle
        self.activeItemsSystemImage = activeItemsSystemImage
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(Typography.displayMediumMedium)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
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
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(counters) { counter in
                            HStack(spacing: 4) {
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

            // Current item being worked on
            HStack(spacing: 8) {
                ThinkingSpinner(size: 14, lineWidth: 1.5)
                Text(currentItem)
                    .font(Typography.codeTiny)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            // Active sub-tasks (show up to 3)
            if !activeItems.isEmpty {
                Divider()

                VStack(spacing: 8) {
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

                    ForEach(activeItems.prefix(3)) { item in
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(Typography.codeTiny)
                                .foregroundStyle(Warning.warning500)
                                .lineLimit(1)
                                .frame(width: 80, alignment: .leading)

                            ThinkingSpinner(size: 10, lineWidth: 1)

                            Text(item.detail)
                                .font(Typography.codeTiny)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()
                        }
                    }

                    if activeItems.count > 3 {
                        Text("+ \(activeItems.count - 3) more...")
                            .font(Typography.captionTiny)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.separator.opacity(0.5), lineWidth: 1)
        }
    }
}

#Preview {
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
            activeItemsTitle: "Following 2 linked folders..."
        )
    }
}
