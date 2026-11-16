import SwiftUI
import Testing
import BlissUI

/// Compiles only against BlissUI's public API: the variants the consistency
/// pass added to the tables, toasts, the flow layout, the appearance page and
/// the effects, built the way an app would build them.
@MainActor
@Suite struct TablesToastsVariantsAPITests {
    private struct Person: Identifiable {
        let id: Int
        let name: String
    }

    private let people = [Person(id: 1, name: "Ada"), Person(id: 2, name: "Grace")]
    private let columns = [BlissTableColumn<Person>("Name", sortedBy: \Person.name)]

    @Test func tableVariantsAreReachable() {
        _ = BlissTable(people, columns: columns, compact: true, striped: true, divided: false, showsHeader: false) { person in
            Text(verbatim: person.name)
        }
        _ = BlissTable(people, columns: columns, selection: .constant([]), emptyState: { EmptyState(icon: "tray", title: "No people") }) { person in
            Text(verbatim: person.name)
        }
        _ = BlissTable([Person](), columns: columns) {
            EmptyState(icon: "tray", title: "No people").contained()
        } cells: { person in
            Text(verbatim: person.name)
        }
        _ = BlissTableHeader(columns: columns, sortOrder: .constant(nil), compact: true)
    }

    @Test func rowHelpersAreReachable() {
        _ = Text("Row").rowHover(cornerRadius: Sizing.radiusLarge, isSelected: true)
        _ = Text("Row").rowHover(verticalPadding: 4, horizontalBleed: 0, isEnabled: false)
        _ = Text("Row").listRowHover(isHovering: false, scheme: .light, cornerRadius: Sizing.radiusDefault, isSelected: true)
        _ = DividedForEach([1, 2, 3], id: \.self, separatorInset: Spacing.xl, includesTrailingSeparator: true) { Text("\($0)") }
        _ = DividedForEach(people, separatorInset: Spacing.lg) { Text(verbatim: $0.name) } separator: { Divider() }
    }

    @Test func paginationVariantsAreReachable() {
        _ = Pagination(page: .constant(1), pageCount: 13, totalItems: 312)
        _ = Pagination(page: .constant(2), pageCount: 13, totalItems: 312, pageSize: .constant(25), pageSizeOptions: [25, 50], showsFirstLast: true)
    }

    @Test func reorderableListVariantsAreReachable() {
        _ = ReorderableList(.constant(people), compact: true, canMove: { $0.id != 1 }, onMove: { _, _ in }) { person in
            Text(verbatim: person.name)
        }
    }

    @Test func selectionBarVariantsAreReachable() {
        _ = SelectionBar(count: 3, total: 120, placement: .attached, onClear: {}, onSelectAll: {}) {
            SelectionBarButton("Delete", systemImage: "trash", isDestructive: true) {}
        }
        _ = Color.clear.selectionBar(count: 1, total: 9, placement: .floating, onClear: {}, onSelectAll: {}) {
            SelectionBarButton("Open", systemImage: "arrow.up.forward.app") {}
        }
        let placement: SelectionBarPlacement = .attached
        #expect(placement == .attached)
    }

    @Test func toastVariantsAreReachable() {
        let action = ToastAction(label: "Install", icon: "arrow.down", isProminent: true) {}
        #expect(action.isProminent)
        let stacked = ToastData(title: "Backup complete", message: "1.2 GB saved", style: .success, layout: .stacked)
        #expect(stacked.layout == .stacked)
        _ = ToastNotification(toast: stacked)
        _ = Color.clear.globalToast(position: .bottomTrailing)
        _ = Color.clear.toast(.constant(nil), autoDismissDelay: ToastService.defaultAutoDismissDelay)
        #expect(ToastService.defaultAutoDismissDelay == 3)
        // Referenced, not called: they'd put toasts on the shared stack.
        _ = ToastService.shared.showWarning(title:message:icon:fullMessage:failures:totalItems:actions:)
        _ = ToastService.shared.showInProgress(title:message:icon:startedAt:)
    }

    @Test func flowLayoutVariantsAreReachable() {
        let layout = FlowLayout(spacing: Spacing.xs, lineSpacing: Spacing.sm, alignment: .center)
        #expect(layout.lineSpacing == Spacing.sm)
        _ = FlowLayout(alignment: .trailing) { Text("a"); Text("b") }
    }

    @Test func appearancePageVariantsAreReachable() {
        _ = AppearanceSettings(options: [.fonts, .contrast], themes: BlissTheme.builtIn)
        _ = AppearanceSettings(options: .all) {
            RoundedSection { Text("Footer") }
        }
        _ = ThemeCard(theme: .system, isSelected: true, showsName: false, onSelect: {})
        _ = AppearanceModePicker(selection: .constant(.light), options: [.light, .dark], showsLabels: true)
        let options: AppearanceSettingsOptions = [.themeFiles, .separateModes]
        #expect(options.contains(.separateModes))
        #expect(!options.contains(.fonts))
    }

    @Test func effectsVariantsAreReachable() {
        _ = Color.clear.glassBorder(tint: Color.accent)
        _ = ShimmerTextOverlay(text: "Scanning", isActive: false)
        _ = ShimmerTextOverlay("Thinking…", font: Typography.bodyMedium)
        #expect(ShimmerTextOverlay.defaultDuration > 0)
        _ = Scrim.opacity
    }
}
