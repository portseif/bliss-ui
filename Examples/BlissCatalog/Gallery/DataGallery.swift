//
//  DataGallery.swift
//  BlissCatalog
//
//  The "Data & Progress" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let data: [GalleryEntry] = [
        GalleryEntry("stat-card", width: 560, height: 150) {
            HStack(spacing: Spacing.md) {
                StatCard("Active users", value: "1,284", change: StatChange("12%", direction: .up), detail: "vs last week", systemImage: "person.2", sparkline: [12, 14, 13, 17, 19, 18, 23, 26])
                StatCard("Error rate", value: "0.4%", change: StatChange("0.1 pt", direction: .up, isPositive: false), detail: "vs last week", systemImage: "exclamationmark.triangle", sparkline: [3, 2, 2, 4, 3, 5, 4, 6])
            }
        },
        GalleryEntry("progress-bar", height: 160) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ProgressBar(value: 0.62, label: "Uploading", showsPercentage: true)
                ProgressBar(value: 0.88, tint: Success.success500, thickness: .thin)
                ProgressBar(value: 0.4, label: "Importing", readout: .text("4 of 10"), thickness: .thick)
                ProgressBar(value: nil, label: "Preparing…")
            }
        },
        GalleryEntry("progress-ring", width: 320, height: 120) {
            HStack(spacing: Spacing.lg) {
                ProgressRing(value: 0.25)
                ProgressRing(value: 0.62, center: .percentage, size: 44)
                ProgressRing(value: 3, total: 5, center: .text("3/5"), tint: Success.success500, size: 56, lineWidth: 4)
                ProgressRing(value: 0.9, center: .percentage, size: 72, lineWidth: 6)
            }
        },
        GalleryEntry("usage-bar", height: 132) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                UsageBar(
                    DataSamples.storage(),
                    capacity: 256,
                    title: "Storage",
                    showsTotal: true,
                    showsLegend: true,
                    valueFormat: DataSamples.gigabytes
                )
                UsageBar(value: 412, capacity: 500, title: "Log entries", showsTotal: true)
            }
        },
        GalleryEntry("tick-strip", width: 260, height: 96) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    TickStrip(DataSamples.health(seed: 0))
                    Text("Last 20 days")
                }
                HStack(spacing: Spacing.sm) {
                    TickStrip(DataSamples.health(seed: 2), tickWidth: 4, spacing: 2, height: 16)
                    Text("Wider ticks")
                }
            }
            .font(Typography.captionSmall)
            .foregroundStyle(.secondary)
        },
        GalleryEntry("change-blocks", width: 220, height: 134) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ChangeBlocks(additions: 529, deletions: 12)
                ChangeBlocks(additions: 40, deletions: 380)
                ChangeBlocks(additions: 12_400, deletions: 3_100)
                ChangeBlocks(additions: 0, deletions: 0)
            }
        },
        GalleryEntry("sparkline", width: 400, height: 76) {
            HStack(spacing: Spacing.lg) {
                Sparkline(DataSamples.latency(seed: 0))
                    .frame(width: 100, height: 28)
                Sparkline(DataSamples.latency(seed: 0), color: Success.success500, fillsArea: true)
                    .frame(width: 100, height: 28)
                Sparkline(DataSamples.withGaps(DataSamples.latency(seed: 0)), range: 0...120, color: Warning.warning500)
                    .frame(width: 100, height: 28)
            }
        },
        GalleryEntry("time-series-chart", width: 520, height: 260) {
            TimeSeriesChart(.area, samples: GalleryChartData.visits)
        },
        GalleryEntry("bar-chart", width: 520, height: 260) {
            BarChart(bars: GalleryChartData.downloads)
        },
        GalleryEntry("commit-graph", width: 600, height: 440) {
            CommitGraph(DataSamples.compactCommits)
        },
        GalleryEntry("status-pill", width: 340, height: 68) {
            HStack(spacing: Spacing.sm) {
                StatusPill("Running", isActive: true)
                StatusPill("Stopped", isActive: false)
                StatusPill("Connected", isActive: true, color: Info.info500, size: .regular, icon: "bolt.fill")
            }
        },
        GalleryEntry("key-hint-pill", width: 300, height: 64) {
            DataSamples.keyboardHints
        },
    ]
}

/// Two series of sample data for the chart pictures.
private enum GalleryChartData {
    static let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()

    static let visits: [ChartSample] = (0..<12).flatMap { day -> [ChartSample] in
        let date = Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
        return [
            ChartSample(date: date, value: 120 + Double((day * 37) % 80), series: "Web"),
            ChartSample(date: date, value: 60 + Double((day * 53) % 70), series: "App"),
        ]
    }

    static let downloads: [ChartBar] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].enumerated().flatMap { index, month in
        [
            ChartBar(category: month, value: Double(40 + (index * 23) % 50), series: "Mac"),
            ChartBar(category: month, value: Double(20 + (index * 31) % 40), series: "iPad"),
        ]
    }
}
