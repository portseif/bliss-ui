import AppKit
import SwiftUI
import Testing
import UniformTypeIdentifiers
import BlissUI

/// Compiles only against BlissUI's public API: the inputs, actions, navigation
/// and sheet components, built the way an app would build them.
@MainActor
@Suite struct InputsAPITests {
    private enum Period: String, CaseIterable, Hashable {
        case hourly, daily, weekly
    }

    private struct SheetItem: Identifiable {
        let id = UUID()
    }

    /// The pure data types build off the main actor, like BlissTheme's.
    nonisolated private static func makeOffMainActorData() -> (IconCategory, PickerOptionDetail, UnderlineTabItem<Int>) {
        (
            IconCategory(title: "Brands", icon: "tag", icons: [.asset("icon-acme"), IconItem.statusDot]),
            PickerOptionDetail(title: "Detail", bars: [PickerStatBar(label: "Load", value: 0.5, color: .orange)]),
            UnderlineTabItem(value: 1, title: "One")
        )
    }

    @Test func dataTypesBuildOffTheMainActor() {
        let (category, detail, tab) = Self.makeOffMainActorData()
        #expect(category.icons.count == 2)
        #expect(detail.bars.first?.id == "Load")
        #expect(tab.id == 1)
    }

    @Test func inputsAreReachable() {
        _ = BrowseInput(path: "/tmp", onBrowse: {})
        _ = BrowseInput(path: "", placeholder: "Pick a file", icon: "doc", onBrowse: {})
        _ = BrowseInput(path: .constant(""))
        _ = BrowseInput(path: .constant(""), canChooseFiles: true, canChooseDirectories: false, allowedContentTypes: [.json])

        _ = CheckboxGlyph(isOn: true)
        _ = CheckboxGlyph(isOn: false, size: 12)

        _ = Color.clear.onSecondaryClick { _ in }
    }

    @Test func segmentedPillsWorkOverAnEnum() {
        _ = SegmentedPills(
            options: Period.allCases,
            selection: .constant(.daily),
            title: { $0.rawValue.capitalized }
        )
        _ = SegmentedPills(
            options: Period.allCases,
            selection: .constant(.hourly),
            style: .compact,
            isEnabled: false,
            animation: .default,
            title: { $0.rawValue },
            icon: { _ in "clock" },
            isOptionEnabled: { $0 != .weekly }
        )
        let styles: [SegmentedPillsStyle] = [.regular, .compact]
        #expect(styles.count == 2)
    }

    @Test func colorPickerIsReachable() {
        _ = ColorPickerButton(red: .constant(0.2), green: .constant(0.4), blue: .constant(0.6))
        _ = ColorPickerButton(
            red: .constant(0), green: .constant(0), blue: .constant(1),
            isUsingDefault: .constant(true),
            defaultOption: .accent(of: .highContrast, in: .dark),
            onColorApplied: {}
        )
        _ = ColorPickerPopover(
            red: .constant(1), green: .constant(0), blue: .constant(0),
            defaultOption: .systemAccent,
            onApply: {}, onUseDefault: {}, onCancel: {}
        )

        // `.system` has no palette, so its default is the macOS accent.
        #expect(ColorPickerDefault.accent(of: .system, in: .light).symbol == ColorPickerDefault.systemAccent.symbol)
        // A palette theme offers its own accent for the scheme.
        let lowGlareDark = ColorPickerDefault.accent(of: .lowGlare, in: .dark)
        #expect(lowGlareDark.symbol == ColorPickerDefault.themeAccent(.black).symbol)
        #expect(lowGlareDark.color == BlissTheme.lowGlare.darkPalette?.accent.nsColor)
        _ = ColorPickerDefault(color: .systemPink, symbol: "star.fill", label: "Use pink")
    }

    @Test func floatingMenuPickerIsReachable() {
        _ = FloatingMenuPicker(
            "Period",
            selection: .constant("Daily"),
            options: ["Hourly", "Daily", "Weekly"],
            optionTitle: { $0 },
            optionIcon: { _ in "clock" },
            optionColor: { _ in nil },
            optionDetail: { option in
                PickerOptionDetail(
                    title: option,
                    subtitle: "Usage",
                    bars: [PickerStatBar(label: "CPU", value: 0.4, color: .blue)]
                )
            },
            compactLabel: "Every",
            horizontalPadding: 6
        )
        _ = FloatingMenuPicker(
            "",
            selection: .constant("Light"),
            options: ["Light", "Dark"],
            optionTitle: { $0 },
            optionIconView: { _, size in Image(systemName: "circle").frame(width: size) }
        )
    }

    @Test func iconPickerIsReachable() {
        _ = IconGlyph(name: "folder")
        _ = IconGlyph(name: IconItem.statusDotName, color: .red, size: 12)
        _ = IconPickerButton(selectedIcon: .constant("star"))
        _ = IconPickerButton(selectedIcon: .constant("star"), red: .constant(1), green: .constant(0), blue: .constant(0))
        _ = GroupIconPicker(selectedIcon: .constant("star"))

        let custom = IconCategory(title: "Brands", icon: "tag", icons: [.asset("icon-acme"), .sfSymbol("bolt")])
        #expect(custom.id == "Brands")
        _ = GroupIconPicker(selectedIcon: .constant("bolt"), includeStatusDot: true, categories: [custom] + IconCategory.defaults)
        #expect(IconCategory.defaults.map(\.id) == [IconCategory.general.id, IconCategory.tools.id])
        #expect(IconItem.statusDot.isStatusDot)
        #expect(IconItem.asset("icon-acme").isAsset)
        #expect(!IconItem.sfSymbol("bolt").isAsset)
    }

    @Test func actionsAreReachable() {
        _ = ActionBar(onConfirm: {})
        _ = ActionBar(
            cancelTitle: "Back",
            confirmTitle: "Delete",
            isConfirmDisabled: true,
            isDestructive: true,
            material: .regularMaterial,
            useKeyboardShortcuts: true,
            cancelUsesEscape: false,
            showBackground: false,
            leadingContent: AnyView(Text("Hint")),
            onCancel: {},
            onConfirm: {}
        )
        _ = ActionBar.cancelConfirm(onCancel: {}, onConfirm: {})

        _ = HoverIconButton(systemImage: "doc.on.doc") {}
        _ = HoverIconButton(systemImage: "checkmark", size: 10, chipPadding: 2, tint: .green, help: "Copied") {}

        _ = QuickActionMenuItem(title: "Rename", icon: "pencil") {}
        _ = QuickActionMenuItem(title: "Delete", icon: "trash", isDestructive: true, showProBadge: true, isFocused: true) {}
        _ = QuickActionMenuItem(title: "Custom", iconView: AnyView(Circle().frame(width: 8, height: 8))) {}
        _ = QuickActionFlyoutRow(title: "Open in", icon: "arrow.up.forward.app", isPresented: .constant(false), onHoverEnter: {}) {
            QuickActionMenuItem(title: "Finder", icon: "folder") {}
        }
    }

    @Test func navigationIsReachable() {
        _ = UnderlineTabBar(
            items: [
                UnderlineTabItem(value: Period.hourly, title: "Hourly"),
                UnderlineTabItem(value: Period.daily, title: "Daily", icon: "sun.max", count: 3),
                UnderlineTabItem(value: Period.weekly, title: "weekly.log", isMono: true, alignTrailing: true),
            ],
            selection: .constant(Period.daily)
        )
        _ = UnderlineTabBar(
            items: [UnderlineTabItem(value: 0, title: "One")],
            selection: .constant(0),
            spacing: 8,
            showsBorder: false,
            horizontalInset: 12
        )
        _ = StepIndicator(stepCount: 4, currentIndex: 1)
        _ = StepIndicator(stepCount: 4, currentIndex: 3, color: .white)
    }

    @Test func sheetsAreReachable() {
        _ = Color.clear
            .appSheetHost()
            .appSheetHost(leadingInset: 220)
            .appSheet(isPresented: .constant(false)) { Text("Sheet") }
            .appSheet(isPresented: .constant(false), contentSized: true, scrollsItsOwnContent: true) { Text("Wizard") }
            .appSheet(item: .constant(SheetItem?.none)) { _ in Text("Item") }
            .appSheet(item: .constant(SheetItem?.none), contentSized: true, scrollsItsOwnContent: false) { _ in Text("Item") }

        _ = AppSheetScaffold {
            SheetHeader(title: "New Item", subtitle: "Give it a name", onDismiss: {})
        } content: {
            Text("Form")
        } footer: {
            ActionBar(onCancel: {}, onConfirm: {})
        }

        _ = SheetHeader(title: "Title")
        _ = SheetHeader(title: "Title", subtitle: "Subtitle", icon: "star", iconColor: .yellow, onDismiss: {})
        _ = SheetHeader.destructive(title: "Delete", subtitle: "Can't be undone")
        _ = SheetHeader.success(title: "Done", subtitle: "Saved")
        _ = SheetHeader.warning(title: "Careful", subtitle: "Check this")
        _ = SheetCloseButton {}
        _ = SheetCloseButton(action: {}, verticalOffset: 0)

        var environment = EnvironmentValues()
        var dismissed = false
        environment.appSheetDismiss = { dismissed = true }
        environment.appSheetDismiss()
        #expect(dismissed)
        environment.appSheetMaxHeight = 480
        #expect(environment.appSheetMaxHeight == 480)
    }

    @Test func secretFieldIsReachable() {
        _ = SecretField("API key", text: .constant("sk-live"))
        _ = SecretField("Password", text: .constant(""), prompt: Text("Required"), isCopyable: false)
        _ = RevealToggleIcon(isRevealed: true)
    }
}
