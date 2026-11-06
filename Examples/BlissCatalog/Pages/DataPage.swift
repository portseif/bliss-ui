//
//  DataPage.swift
//  BlissCatalog
//
//  The "Data & Progress" page.
//

import BlissUI
import SwiftUI

struct DataPage: View {
    @State private var progress = 0.35
    @State private var isIndeterminate = false
    @State private var photos = 31.0
    @State private var logEntries = 412.0
    @State private var health = DataSamples.health(seed: 0)
    @State private var isRefreshing = false
    @State private var refreshCount = 0
    @State private var additions = 529
    @State private var deletions = 12
    @State private var latency = DataSamples.latency(seed: 0)
    @State private var isRunning = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            progressBlock
            ringBlock
            usageBlock
            tickStripBlock
            changeBlocksBlock
            sparklineBlock
            pillsBlock
        }
    }

    // MARK: - Progress

    private var progressBlock: some View {
        DemoBlock(title: "Progress bar") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ProgressBar(
                    value: isIndeterminate ? nil : progress,
                    label: isIndeterminate ? "Preparing…" : "Uploading",
                    showsPercentage: true
                )
                ProgressBar(value: progress, tint: Success.success500, height: 4)
            }
            .frame(maxWidth: 420)
            HStack(spacing: Spacing.sm) {
                Button("Advance") { advanceProgress() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Button("Reset") { progress = 0 }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Toggle("Indeterminate", isOn: $isIndeterminate)
                    .toggleStyle(.flatSwitch(showsLabel: true))
            }
        }
    }

    private func advanceProgress() {
        progress = progress >= 1 ? 0 : min(progress + 0.2, 1)
    }

    private var ringBlock: some View {
        DemoBlock(title: "Progress ring") {
            HStack(spacing: Spacing.lg) {
                ProgressRing(value: progress)
                ProgressRing(value: progress, center: .percentage, size: 44)
                ProgressRing(
                    value: (progress * 5).rounded(.down),
                    total: 5,
                    center: .text(.verbatim("\(Int((progress * 5).rounded(.down)))/5")),
                    tint: Success.success500,
                    size: 56,
                    lineWidth: 4
                )
                ProgressRing(value: progress, center: .percentage, size: 72, lineWidth: 6)
            }
            Text("Uses the progress above — Advance to animate it.")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Usage

    private var usageBlock: some View {
        DemoBlock(title: "Usage bar") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                UsageBar(
                    DataSamples.storage(photos: photos),
                    capacity: 256,
                    title: "Storage",
                    showsTotal: true,
                    showsLegend: true,
                    valueFormat: DataSamples.gigabytes
                )
                UsageBar(value: logEntries, capacity: 500, title: "Log entries", showsTotal: true)
            }
            .frame(maxWidth: 420)
            HStack(spacing: Spacing.sm) {
                Button("Add photos") { photos = min(photos + 24, 160) }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Button("Add log entries") { logEntries = logEntries >= 500 ? 120 : min(logEntries + 40, 500) }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Button("Reset") {
                    photos = 31
                    logEntries = 412
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }
        }
    }

    // MARK: - Tick strip

    private var tickStripBlock: some View {
        DemoBlock(title: "Tick strip") {
            HStack(spacing: Spacing.md) {
                TickStrip(health, isRefreshing: isRefreshing, accessibilityLabel: "Health, last 20 days")
                Text("Hover a tick for its day.")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            Button(isRefreshing ? "Refreshing…" : "Refresh") { refreshHealth() }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .disabled(isRefreshing)
        }
    }

    /// Dims the strip, then lands a fresh reading — the ticks ripple back in.
    private func refreshHealth() {
        isRefreshing = true
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            refreshCount += 1
            health = DataSamples.health(seed: refreshCount)
            isRefreshing = false
        }
    }

    // MARK: - Change blocks

    private var changeBlocksBlock: some View {
        DemoBlock(title: "Change blocks") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ChangeBlocks(additions: additions, deletions: deletions)
                ChangeBlocks(additions: 40, deletions: 380)
                ChangeBlocks(additions: 12_400, deletions: 3_100)
                ChangeBlocks(additions: 0, deletions: 0)
            }
            Button("Randomize") {
                additions = Int.random(in: 0...900)
                deletions = Int.random(in: 0...500)
            }
            .buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }

    // MARK: - Sparkline

    private var sparklineBlock: some View {
        DemoBlock(title: "Sparkline") {
            HStack(spacing: Spacing.xl) {
                Sparkline(latency, accessibilityLabel: "Latency", valueFormat: DataSamples.milliseconds)
                    .frame(width: 140, height: 28)
                Sparkline(latency, color: Success.success500, fillsArea: true, accessibilityLabel: "Latency", valueFormat: DataSamples.milliseconds)
                    .frame(width: 140, height: 28)
                Sparkline(DataSamples.withGaps(latency), range: 0...120, color: Warning.warning500, accessibilityLabel: "Latency", valueFormat: DataSamples.milliseconds)
                    .frame(width: 140, height: 28)
            }
            Button("New data") { latency = DataSamples.latency(seed: Int.random(in: 1...999)) }
                .buttonStyle(SecondaryButtonStyle(compact: true))
        }
    }

    // MARK: - Pills

    private var pillsBlock: some View {
        DemoBlock(title: "Status and key pills") {
            HStack(spacing: Spacing.md) {
                StatusPill(isRunning ? "Running" : "Stopped", isActive: isRunning)
                Toggle("Running", isOn: $isRunning)
                    .toggleStyle(.flatSwitch(showsLabel: true))
            }
            DataSamples.keyboardHints
        }
    }
}

// MARK: - Sample data

/// Generic sample data shared by the Data page and its gallery entries.
enum DataSamples {
    static func gigabytes(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) GB"
    }

    static func milliseconds(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) ms"
    }

    static func storage(photos: Double = 31) -> [UsageBar.Segment] {
        [
            UsageBar.Segment("Apps", value: 48, color: Color.accent),
            UsageBar.Segment("Photos", value: photos, color: Info.info500),
            UsageBar.Segment("Mail", value: 9, color: Warning.warning500),
            UsageBar.Segment("System", value: 18, color: Grey.grey400),
        ]
    }

    /// Twenty days of a health reading, newest last: mostly healthy, a few
    /// degraded or failing days, and days with no reading.
    static func health(seed: Int) -> [TickStrip.Tick] {
        let pattern: [Int?] = [0, 0, nil, 0, 1, 1, 0, 0, 0, nil, nil, 2, 1, 0, 0, 0, 0, 1, 0, 0]
        let today = Calendar.current.startOfDay(for: Date())
        return pattern.enumerated().map { offset, state in
            // A refresh re-scores today in place, like a real sampler.
            let state = offset == pattern.count - 1 ? [0, 1, 2, 0][seed % 4] : state
            let day = Calendar.current.date(byAdding: .day, value: offset - (pattern.count - 1), to: today) ?? today
            let date = day.formatted(.dateTime.month(.abbreviated).day())
            switch state {
            case 0: return TickStrip.Tick(color: Success.success500, label: "\(date) · Healthy")
            case 1: return TickStrip.Tick(color: Warning.warning500, label: "\(date) · Degraded")
            case 2: return TickStrip.Tick(color: Danger.danger500, label: "\(date) · Failing")
            default: return TickStrip.Tick(color: nil, label: "\(date) · No reading")
            }
        }
    }

    /// A noisy, slowly rising series.
    static func latency(seed: Int) -> [Double?] {
        (0..<16).map { index in
            let wave = sin(Double(index + seed) * 0.9) * 14
            let jitter = Double((index * 37 + seed * 11) % 13)
            return 48 + Double(index) * 2.4 + wave + jitter
        }
    }

    static func withGaps(_ series: [Double?]) -> [Double?] {
        series.enumerated().map { index, value in [5, 6, 11].contains(index) ? nil : value }
    }

    /// "esc to cancel · ⌘↩ to restore", the footer hint the key pill is for.
    static var keyboardHints: some View {
        HStack(spacing: Spacing.xs) {
            KeyHintPill("esc")
            Text("to cancel")
                .font(Typography.captionTiny)
                .foregroundStyle(.tertiary)
            Text(verbatim: "·")
                .font(Typography.captionTiny)
                .foregroundStyle(.quaternary)
            KeyHintPill("⌘↩")
            Text("to restore")
                .font(Typography.captionTiny)
                .foregroundStyle(.tertiary)
        }
    }
}
