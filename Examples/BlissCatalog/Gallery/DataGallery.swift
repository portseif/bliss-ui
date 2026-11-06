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
        GalleryEntry("progress-bar", height: 132) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ProgressBar(value: 0.62, label: "Uploading", showsPercentage: true)
                ProgressBar(value: 0.88, tint: Success.success500, height: 4)
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
        GalleryEntry("status-pill", width: 340, height: 68) {
            HStack(spacing: Spacing.sm) {
                StatusPill("Running", isActive: true)
                StatusPill("Stopped", isActive: false)
                StatusPill("Connected", isActive: true, color: Info.info500)
            }
        },
        GalleryEntry("key-hint-pill", width: 300, height: 64) {
            DataSamples.keyboardHints
        },
    ]
}
