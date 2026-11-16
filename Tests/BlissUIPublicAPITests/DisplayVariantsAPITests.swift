import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the variant parameters the
/// consistency pass added to the display, feedback, section and action
/// components, built the way an app would build them.
@MainActor
@Suite struct DisplayVariantsAPITests {
    @Test func pillsShareTheBadgeSizes() {
        _ = StatusPill("Running", isActive: true, size: .regular, icon: "bolt.fill", bordered: false)
        _ = StatusDotPill(label: "Healthy", color: Success.success500, size: .large, icon: "heart.fill", isActive: false, bordered: true)
        _ = StatusDotPill(label: "Legacy", color: Info.info500, font: Typography.labelSmall, bordered: true)
        _ = ShortcutKey("esc", outlined: true)
        _ = ShortcutKey("⌘K", floating: true, compact: true, tint: .white)
        _ = KeyHintPill("⌘↩")
        _ = Badge("v6.2").badgeStyle(.outline)
        _ = Badge(count: 1_204, maximum: 999)
        _ = Badge.status("Done", color: Success.success500, size: .small)
        #expect(BadgeSize.small.minHeight < BadgeSize.regular.minHeight)
        #expect(BadgeSize.regular.minHeight < BadgeSize.large.minHeight)
        #expect(BadgeSize.regular.horizontalPadding == Spacing.tagPaddingH)
        #expect(BadgeSize.regular.cornerRadius == Sizing.radiusDefault)
    }

    @Test func inlineIconButtonsAreReachable() {
        _ = HoverIconButton(systemImage: "pin", size: .regular, isActive: true, help: "Pinned") {}
        _ = HoverIconButton(systemImage: "xmark", size: Sizing.iconTiny, chipPadding: Spacing.xxs) {}
        _ = CopyButton(value: "sk-live", showCopied: .constant(false), isSecret: true)
        #expect(CopyButton.confirmationDuration > 0)
        _ = InfoButton(text: "Why", title: "Beta", maxWidth: 200, size: .regular, systemImage: "questionmark.circle", xPosition: .center, yPosition: .below)
        _ = InfoHint(size: .regular, systemImage: "exclamationmark.circle") { Text("Hint") }
    }

    @Test func displayVariantsAreReachable() {
        _ = EmptyState(icon: "tray", title: "No results", subtitle: "Try another search.", compact: true, iconColor: Danger.danger500, minHeight: 100)
        _ = EmptyState(icon: "doc", title: "Empty", compact: true) { Button("Add") {} }
        #expect(EmptyState<EmptyView>.compactMinimumHeight < EmptyState<EmptyView>.minimumHeight)
        _ = SlidingNumber(value: 42, size: .large, color: .primary, padToDigits: 3, tracking: 1, prefix: "$", suffix: ".00")
        _ = SlidingNumber(value: 7, font: Typography.codeLarge, prefix: nil, suffix: "%")
        _ = ThinkingSpinner(size: .small)
        _ = ThinkingSpinner(size: .large, color: .accent, label: Text("Syncing"))
        _ = ThinkingSpinner(size: 20, lineWidth: 2, label: nil)
        _ = TimeAgoLabel(date: Date(), showsIcon: false, style: .full)
        _ = MarkdownView("# Notes", size: .regular, compact: true)
        _ = PathHoverChip(path: "/tmp", compact: true, showsCopy: false, onOpen: {})
        _ = TerminalOutputView(lines: [], isExpanded: .constant(true), wrapsLines: false) {
            HoverIconButton(systemImage: "trash", help: "Clear") {}
        }
        _ = TerminalOutputView(lines: [TerminalOutputLine("hi")], wrapsLines: false)
        _ = TerminalOutputView(output: ["hi"], maxHeight: 120)
    }

    @Test func carouselAndTimelineVariantsAreReachable() {
        struct Page: Identifiable { let id: Int }
        _ = Carousel([Page(id: 1), Page(id: 2)], cornerRadius: 0, loops: true, pageSpacing: Spacing.md) { _ in Color.clear }
        struct Event: Identifiable { let id: Int }
        _ = Timeline([Event(id: 1)], compact: true, timePlacement: .leading) { _ in
            TimelineItem(mark: .avatar(name: "Ada Lovelace"), time: Text(verbatim: "2m")) { Text("Signed in") }
        }
        _ = Timeline([Event(id: 1)], id: \.id, compact: false, timePlacement: .trailing) { _ in TimelineItem { Text("Event") } }
    }

    @Test func feedbackVariantsAreReachable() {
        _ = Banner("Saved", style: .success, showsIcon: false, compact: true, cornerRadius: 0)
        _ = Banner("Offline", message: "Changes stay here.", style: .warning) {
            Button("Retry") {}
            Button("Work offline") {}
        }
        _ = ConfirmationSheet(title: "Discard?", message: "Unsaved changes are lost.", confirmTitle: "Discard", cancelTitle: "Keep", isDestructive: true, style: .warning, width: Sizing.sheetWidthLarge) {}
        _ = Color.clear.confirmationSheet(isPresented: .constant(false), title: "Delete?", confirmTitle: "Delete", cancelTitle: "Keep", style: .danger) {}
        _ = DisclosureSection("Advanced", chevronPlacement: .trailing, indentsContent: false) { Text("Body") } trailing: { Badge(count: 2) }
        _ = DisclosureSection(initiallyExpanded: true) { Text("Body") } label: { Text("Custom") } trailing: { Text("3") }
        _ = SkeletonBlock.paragraph(lines: 4, lastLineFraction: 0.4)
        _ = SkeletonBlock.control(width: 80, compact: false)
        #expect(SkeletonBlock.lineHeight > 0)
    }

    @Test func sectionVariantsAreReachable() {
        _ = DetailRow(label: "Key", value: "abc", monospace: true, copyable: true, labelWidth: 140, isSecret: true, lineLimit: nil)
        _ = InfoRow.status("Connected", icon: "checkmark.circle.fill", style: .success, detail: "Last checked 2m ago")
        #expect(StatusStyle(.danger) == .error)
        #expect(StatusStyle.warning.kind == .warning)
        #expect(StatusStyle.secondary.kind == nil)
        _ = LabeledDivider("Shipping", alignment: .leading, prominent: true, verticalPadding: Spacing.sm)
        _ = LabeledDivider(prominent: true) { Text("Billing") }
        _ = RoundedSection("Members", divided: true, padding: 0) { Text("Row") }
        _ = RoundedSection("General") { Text("Row") } footer: { Text("Changes apply on relaunch.") }
        _ = RoundedSection("General") { Text("Row") }.headerTrailing { Button("Reset") {} }
        _ = RoundedSection(padding: Spacing.md) { Text("Row") } header: { Text("Custom") } footer: { Text("Note") }
        _ = SectionHeader("Nested", count: 3, countSuffix: "open", size: .small, hugsContent: true)
        _ = TimelineHeaderLabel("Today")
    }

    @Test func actionVariantsAreReachable() {
        _ = ActionBar(confirmTitle: "Save", isConfirmLoading: true, compact: false, secondaryTitle: "Don't Save", onSecondary: {}, onCancel: {}, onConfirm: {})
        _ = QuickActionMenuItem(title: "Refresh", icon: "arrow.clockwise", shortcut: "⌘R", isEnabled: false, isChecked: true, detail: "Reloads") {}
        _ = QuickActionMenuItem(title: "Custom", iconView: AnyView(Circle()), shortcut: nil, isEnabled: true, isChecked: nil, detail: nil) {}
    }
}
