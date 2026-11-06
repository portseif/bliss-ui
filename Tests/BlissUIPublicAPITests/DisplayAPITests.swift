import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the display, section, row and
/// grid components, built the way an app would build them.
@MainActor
@Suite struct DisplayAPITests {
    @Test func badgesAreReachable() {
        _ = Badge("Live").badgeStyle(.success)
        _ = Badge("Beta", icon: "flask")
            .badgeStyle(.primary)
            .badgeSize(.small)
            .badgeShape(.roundedRect)
            .dot(.active)
        _ = Badge("Custom").dot(.blue).badgeStyle(.custom(text: .white, icon: .white, background: .black, border: nil))
        _ = Badge("Solid").badgeStyle(.solid(.red)).badgeSize(.large)
        _ = Badge("Gradient").badgeStyle(.gradient(.custom([.red, .orange])))
        _ = Badge(count: 5)
        _ = Badge.status("Healthy", color: Success.success500)
        _ = Badge.pro()
        _ = Badge.lifetime(size: .small)
        _ = Badge.step(2, size: .regular)
        #expect(BadgeStyle.GradientPreset.pro.colors.count == 2)
        _ = BadgeDot(preset: .warning).color
        _ = BadgeDot(color: .green)
    }

    @Test func emptyStatesAreReachable() {
        _ = EmptyState(icon: "tray", title: "Nothing here", subtitle: "Add something to get started.")
        _ = EmptyState(icon: "tray", title: "Nothing here") {
            Button("Add") {}
        }
        _ = EmptyState(icon: "clock", title: "No activity yet").contained()
        #expect(EmptyState<EmptyView>.minimumHeight > 0)
    }

    @Test func hintsAndKeysAreReachable() {
        _ = InfoButton(text: "Explains the setting.")
        _ = InfoButton(text: "A wider explanation.", maxWidth: 320)
        _ = InfoHint { Text("Details") }
        _ = InfoHint(xPosition: .leading, yPosition: .above) { Text("Details") }
        _ = ShortcutKey("⌘K")
        _ = ShortcutKey("⇧⌘P", floating: true, compact: true)
        _ = Button("New") {}.shortcutHint("⌘N")
        _ = RevealToggleIcon(isRevealed: true)
    }

    @Test func statusAndProgressAreReachable() {
        _ = StatusDotPill(label: "Running", color: Success.success500)
        _ = StatusDotPill(label: "Degraded", color: Warning.warning500, font: Typography.labelSmall, bordered: true)
        _ = ThinkingSpinner()
        _ = ThinkingSpinner(size: 24, lineWidth: 2.5, color: .accent)
        _ = SlidingNumber(value: 42)
        _ = SlidingNumber(value: 7, font: .title, color: .secondary, padToDigits: 2, tracking: 1)
        _ = TimeAgoLabel(date: Date())
        _ = TimeAgoLabel(date: Date(), withSuffix: false, font: Typography.codeTiny)
    }

    @Test func pathsAndTerminalAreReachable() {
        _ = PathHoverChip(path: "/tmp")
        _ = PathHoverChip(path: "", placeholder: "Choose a folder", monospaced: true, canReveal: false)
        _ = PathHoverChip.code("swift build", onRun: {})
        let line = TerminalOutputLine("error: failed", type: .stderr)
        #expect(line.text == "error: failed")
        #expect(line.type == .stderr)
        _ = line.id
        _ = line.timestamp
        _ = TerminalOutputView(lines: [line, TerminalOutputLine("ok")])
        _ = TerminalOutputView(lines: [], title: "Log", maxHeight: 120, isCollapsible: false, showTimestamps: true)
        _ = TerminalOutputView(output: ["one", "two"], title: "Output", maxHeight: 80)
    }

    @Test func sectionsAreReachable() {
        _ = RoundedSection("General") { Text("Row") }
        _ = RoundedSection("General", divided: true, borderTint: .green) { Text("A"); Text("B") }
        _ = RoundedSection { Text("Row") }
        _ = RoundedSection(divided: true) { Text("Row") } header: { Text("Custom") }
        _ = Text("Flat").environment(\.roundedSectionPlain, true)
        _ = SectionHeader("Recent")
        _ = SectionHeader("Members", count: 12, countSuffix: "online", caption: "Updated now", topPadding: 0, bottomPadding: 4, horizontalPadding: 8) {
            Button("Invite") {}
        }
        _ = TimelineHeaderLabel("Today")
    }

    @Test func detailRowsAreReachable() {
        _ = DetailRow(label: "Name", value: "Demo")
        _ = DetailRow(label: "Path", value: "/tmp", monospace: true, isLink: false, isPath: true, copyable: true)
        _ = CopyButton(value: "secret", showCopied: .constant(false))
        _ = CopyButton(value: "secret", showCopied: .constant(false), isSecret: true)
        let rows = [
            InfoRow.labeled("Branch", value: "main"),
            InfoRow.hint("No remote configured"),
            InfoRow.status("Connected", icon: "checkmark.circle.fill", style: .success),
            InfoRow.status("Idle", icon: "circle"),
            InfoRow.branch("feature/new-ui"),
            InfoRow.custom { Text("Custom") },
        ]
        #expect(Set(rows.map(\.id)).count == rows.count)
        _ = StatusStyle.warning.color
    }

    @Test func listsAndGridsAreReachable() {
        struct Item: Identifiable { let id: Int }
        let items = [Item(id: 1), Item(id: 2)]
        _ = DividedForEach([1, 2, 3], id: \.self) { Text("\($0)") }
        _ = DividedForEach([1, 2, 3], id: \.self) { Text("\($0)") } separator: { Divider().padding(.leading, 8) }
        _ = DividedForEach(items) { Text("\($0.id)") }
        _ = DividedForEach(items) { Text("\($0.id)") } separator: { Divider() }
        _ = Text("Row").rowHover()
        _ = Text("Row").rowHover(verticalPadding: 4, horizontalBleed: 0, isEnabled: false)
        _ = Text("Row").listRowHover(isHovering: true, scheme: .dark)
        _ = Text("Row").rowTapAction {}
        _ = Text("Card").rowTapAction(isSelected: true, focusCornerRadius: 12, focusBleed: 0) {}
        _ = Text("Row").keyboardTapTarget {}
        var layout = FlowLayout()
        layout.spacing = 6
        #expect(layout.spacing == 6)
        _ = FlowLayout(spacing: 4) { Text("a"); Text("b") }
    }
}
