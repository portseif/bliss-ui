import SwiftUI
import Testing
import BlissUI

/// The README's code, compiled — if the README drifts from the API, this fails.
@MainActor
@Suite struct ReadmeSnippetTests {
    private struct DetailsSheet: View {
        var body: some View { Text("Details") }
    }

    private struct ContentView: View {
        @State private var showingSheet = false

        var body: some View {
            VStack(spacing: Spacing.lg) {
                Text("Hello, Bliss")
                    .font(Typography.displaySmall)

                HStack(spacing: Spacing.sm) {
                    Button("Save") { ToastService.shared.showSuccess(title: "Saved", message: "Your changes are in.") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Details") { showingSheet = true }
                        .buttonStyle(SecondaryButtonStyle())
                }

                Badge("Live").badgeStyle(.success)
            }
            .padding(Spacing.xl)
            .appSheet(isPresented: $showingSheet) {
                DetailsSheet()
            }
        }
    }

    @Test func quickStartCompiles() {
        _ = ContentView()
            .appSheetHost()
            .globalToast()
            .blissTheme()
            .blissWindowChrome()
            .persistsWindowFrame()
        _ = AppearanceSettings().blissTheme()
    }

    @Test func customThemeRegisters() {
        let harbor = BlissTheme(
            id: "harbor",
            name: "Harbor",
            light: ThemePalette(
                windowBackground: ThemeRGB(0xEEF2F5), contentBackground: ThemeRGB(0xFFFFFF),
                elevatedBackground: ThemeRGB(0xFFFFFF), border: ThemeRGB(0xD5DDE3), accent: ThemeRGB(0x1F6F8B)
            ),
            dark: ThemePalette(
                windowBackground: ThemeRGB(0x111A20), contentBackground: ThemeRGB(0x16222A),
                elevatedBackground: ThemeRGB(0x1E2D36), border: ThemeRGB(0x2B3D48), accent: ThemeRGB(0x5FB3CE)
            ),
            swatch: [ThemeRGB(0x111A20), ThemeRGB(0x1F6F8B), ThemeRGB(0x5FB3CE), ThemeRGB(0xEEF2F5)]
        )
        BlissTheme.register(harbor)
        #expect(BlissTheme.all.contains(harbor))
        #expect(BlissTheme.all.prefix(4).map(\.id) == BlissTheme.builtIn.map(\.id))
    }

    @Test func appearanceIsSettableFromCode() {
        let defaults = UserDefaults.standard
        let savedTheme = defaults.object(forKey: BlissAppearance.Keys.theme)
        let savedScheme = defaults.object(forKey: BlissAppearance.Keys.colorScheme)
        defer {
            defaults.set(savedTheme, forKey: BlissAppearance.Keys.theme)
            defaults.set(savedScheme, forKey: BlissAppearance.Keys.colorScheme)
        }
        BlissAppearance.theme = .colorBlindSafe
        BlissAppearance.colorScheme = .dark
        #expect(BlissAppearance.theme == .colorBlindSafe)
        #expect(BlissAppearance.colorScheme == .dark)
    }

    @Test func tableAndSelectionBarCompile() {
        struct Person: Identifiable { let id = UUID(); let name: String; let joined: Date }
        let people = [Person(name: "Ada", joined: .now)]
        _ = BlissTable(people, columns: [
            BlissTableColumn("Name", sortedBy: \Person.name),
            BlissTableColumn("Joined", width: .fixed(110), alignment: .trailing, sortedBy: \Person.joined),
        ], selection: .constant([]), onOpen: { _ in }) { person in
            Text(person.name)
            TimeAgoLabel(date: person.joined)
        }
        .selectionBar(count: 1, onClear: {}) {
            SelectionBarButton("Archive", systemImage: "archivebox") {}
        }
        let layout = BlissTableRowLayout(columns: [.fixed(40), .flexible(), .flexible(minimum: 80)])
        _ = layout
    }
}
