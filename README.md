# BlissUI

**Beautiful by default.**

A SwiftUI component library for macOS — premium components, fluid motion, careful effects, and themes that cover accessibility out of the box. Every piece was built and tuned inside a shipping app before it landed here, so the details are already sweated: focus rings that only show for the keyboard, sheets that hug their content, toasts that stack, traffic lights that stay put through a live resize.

- **Themes** — System, High Contrast, Color Blind Safe and Low Glare built in, plus your own. Light, Dark or System on top of any of them, and a per-theme accent.
- **Tokens** — colors, typography, spacing, sizing and motion, so nothing is hardcoded.
- **Components** — buttons, inputs, pickers, menus, tooltips, toasts, sheets, tables, sections, badges, empty states and more.
- **Window chrome** — a hidden-title-bar shell with an opaque backdrop, offset traffic lights, drag exclusion for title-bar controls, frame persistence.
- **Accessible** — every control is a Tab stop with one shared ring, VoiceOver labels on icon buttons, Reduce Motion fallbacks, Increase Contrast support.

## Requirements

- macOS 15 or later
- Xcode 26 or later (Swift 6.2 tools)

## Installation

Add the package in Xcode (**File → Add Package Dependencies…**) or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/portseif/bliss-ui.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "BlissUI", package: "bliss-ui")]),
]
```

## Quick start

```swift
import SwiftUI
import BlissUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .appSheetHost()     // hosts every .appSheet in the window
                .globalToast()      // renders ToastService toasts
                .blissTheme()       // theme, light/dark, accent
                .blissWindowChrome() // opaque shell + traffic lights
                .persistsWindowFrame()
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            AppearanceSettings()
                .blissTheme()
        }
    }
}
```

```swift
struct ContentView: View {
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
```

## Themes

```swift
BlissAppearance.theme = .colorBlindSafe   // or .system, .highContrast, .lowGlare
BlissAppearance.colorScheme = .dark       // .light, .dark, .system
```

| Theme | For |
|---|---|
| **System** | Follows macOS: the built-in palette and your system accent. |
| **High Contrast** | Low vision. Full-strength borders, status colors held to 7:1. |
| **Color Blind Safe** | Okabe & Ito's palette — success, warning, danger and info stay distinct with protan, deutan and tritan vision. |
| **Low Glare** | Light sensitivity and visual stress. Dim, warm surfaces; cream instead of white in light mode. |

Add your own:

```swift
BlissTheme.register(BlissTheme(
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
))
```

Give a palette `status:` colors and BlissUI derives the rest: a mark that clears 4.5:1 (or the theme's `minimumStatusContrast`) on every surface, and a deeper fill that white text reads on.

## Components

| Area | Components |
|---|---|
| **Buttons & styles** | `PrimaryButtonStyle`, `SecondaryButtonStyle`, `OutlineButtonStyle`, `GhostButtonStyle`, `DestructiveButtonStyle`, `SmallPillButtonStyle`, `ToolbarIconButtonStyle`, `InlineIconButtonStyle`, `SelectableCardButtonStyle`, `AnimatedGradientBorderButtonStyle`, `FocusablePlainButtonStyle`, `.textFieldStyle(.largePadded)`, `.toggleStyle(.flatSwitch)`, `.inputBox(isFocused:)`, `TextLink` |
| **Inputs** | `FloatingMenuPicker`, `SegmentedPills`, `ColorPickerButton`, `IconPickerButton`, `BrowseInput`, `CheckboxGlyph`, `.onSecondaryClick` |
| **Actions** | `ActionBar`, `HoverIconButton`, quick-action menu rows |
| **Display** | `Badge`, `EmptyState`, `ThinkingSpinner`, `InfoButton`, `InfoHint`, `PathHoverChip`, `SlidingNumber`, `StatusDotPill`, `TimeAgoLabel`, `ShortcutKey`, `RevealToggleIcon` |
| **Sections** | `RoundedSection`, `SectionHeader`, `DetailRow`, `InfoList`, `SettingsForm` |
| **Tables & grids** | `BlissTable`, `SelectionBar`, `DividedForEach`, `.listRowHover`, `.rowTapAction`, `FlowLayout` |
| **Navigation** | `UnderlineTabBar`, `StepIndicator` |
| **Overlays** | `.floatingMenu`, `.tooltip`, `ScrollViewWithThinIndicator`, `AutoHeightScroll`, `ProgressOverlay`, `PopupMenuService` |
| **Sheets** | `.appSheet`, `AppSheetScaffold`, `SheetHeader`, `SheetCloseButton` |
| **Toasts** | `ToastService`, `.globalToast()`, `.toastsRestAbove()` |
| **Effects** | glass border, dimmed overlay, shimmer |
| **Window** | `.blissWindowChrome()`, `.trafficLightOffset(_:)`, `.windowDragDisabled()`, `.persistsWindowFrame(key:)`, `.borderlessCardWindow(isActive:size:)` |

Run the catalog to see them all (`-page table` opens on a page):

```bash
swift run BlissCatalog
```

## Using this repo as a template

BlissUI is set up as a GitHub template repository. **Use this template → Create a new repository** gives you the package, the test targets (including `BlissUIPublicAPITests`, which compiles only against the public API), CI, and the issue and PR templates. [CLAUDE.md](CLAUDE.md) holds the design-system rules the components follow.

## License

MIT — see [LICENSE](LICENSE).
