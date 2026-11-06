# BlissUI

**Beautiful by default.**

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/pages/hero-dark.webp">
    <img src="docs/images/pages/hero-light.webp" alt="The BlissUI catalog: a sortable table with two rows selected and the selection bar floating below" width="880">
  </picture>
</p>

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

<table>
  <tr>
    <td align="center"><img src="docs/images/pages/theme-system.webp" alt="System theme, dark" width="420"><br><sub>System (dark)</sub></td>
    <td align="center"><img src="docs/images/pages/theme-high-contrast.webp" alt="High Contrast theme, light" width="420"><br><sub>High Contrast (light)</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/pages/theme-color-blind-safe.webp" alt="Color Blind Safe theme, dark" width="420"><br><sub>Color Blind Safe (dark)</sub></td>
    <td align="center"><img src="docs/images/pages/theme-low-glare.webp" alt="Low Glare theme, light" width="420"><br><sub>Low Glare (light)</sub></td>
  </tr>
</table>

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

## Component index

Every component, light or dark to match your GitHub theme. Run `swift run BlissCatalog` to try them, and `scripts/screenshots.sh` regenerates these images.

Not pictured, because they're separate panels rather than part of the window: `.tooltip`, the floating menu panel itself, and `InfoHint`'s popover.

<details open>
<summary><b>Buttons & styles</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/buttons-dark.webp"><img src="docs/images/components/buttons-light.webp" alt="Buttons" width="420"></picture><br><b>Buttons</b><br><code>PrimaryButtonStyle</code> · <code>SecondaryButtonStyle</code> · <code>OutlineButtonStyle</code> · <code>GhostButtonStyle</code> · <code>DestructiveButtonStyle</code><br><sub>Linear-style text buttons: hairline borders, neutral hover and press, no accent hue.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/compact-buttons-dark.webp"><img src="docs/images/components/compact-buttons-light.webp" alt="Compact buttons" width="420"></picture><br><b>Compact buttons</b><br><code>compact: true</code> on any button style<br><sub>The 28pt sizes every sheet footer uses.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/gradient-button-dark.webp"><img src="docs/images/components/gradient-button-light.webp" alt="Gradient and pill buttons" width="420"></picture><br><b>Gradient and pill buttons</b><br><code>AnimatedGradientBorderButtonStyle</code> · <code>SmallPillButtonStyle</code><br><sub>The animated border marks the action that kicks off something big.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/icon-buttons-dark.webp"><img src="docs/images/components/icon-buttons-light.webp" alt="Icon buttons" width="420"></picture><br><b>Icon buttons</b><br><code>ToolbarIconButtonStyle</code> · <code>HoverIconButton</code> · <code>InlineIconButtonStyle</code><br><sub>Title-bar icons, hover chips and small inline glyphs.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/text-link-dark.webp"><img src="docs/images/components/text-link-light.webp" alt="Text link" width="420"></picture><br><b>Text link</b><br><code>TextLink</code><br><sub>A dotted-underline URL that turns accent on hover.</sub></td>
    <td width="50%"></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Inputs</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/text-fields-dark.webp"><img src="docs/images/components/text-fields-light.webp" alt="Text fields" width="420"></picture><br><b>Text fields</b><br><code>.largePadded</code> · <code>.search</code> · <code>.inputBox(isFocused:)</code><br><sub>An underline that turns accent on focus; the search field gets the shared ring.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/flat-switch-dark.webp"><img src="docs/images/components/flat-switch-light.webp" alt="Switch" width="420"></picture><br><b>Switch</b><br><code>.toggleStyle(.flatSwitch)</code><br><sub>A Tab stop that Space flips, with real switch semantics for VoiceOver.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/checkbox-dark.webp"><img src="docs/images/components/checkbox-light.webp" alt="Checkbox" width="420"></picture><br><b>Checkbox</b><br><code>CheckboxGlyph</code><br><sub>The glyph the table and multi-select lists draw.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/segmented-pills-dark.webp"><img src="docs/images/components/segmented-pills-light.webp" alt="Segmented pills" width="420"></picture><br><b>Segmented pills</b><br><code>SegmentedPills</code><br><sub>A sliding pill; <code>.regular</code> fills its width, <code>.compact</code> hugs its labels.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/floating-menu-picker-dark.webp"><img src="docs/images/components/floating-menu-picker-light.webp" alt="Dropdown" width="420"></picture><br><b>Dropdown</b><br><code>FloatingMenuPicker</code><br><sub>Opens a floating menu with type-to-filter and keyboard navigation.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/pickers-dark.webp"><img src="docs/images/components/pickers-light.webp" alt="Color and icon pickers" width="420"></picture><br><b>Color and icon pickers</b><br><code>ColorPickerButton</code> · <code>IconPickerButton</code><br><sub>Swatches plus a custom color; SF Symbols by category, with search.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/browse-input-dark.webp"><img src="docs/images/components/browse-input-light.webp" alt="Browse input" width="420"></picture><br><b>Browse input</b><br><code>BrowseInput</code><br><sub>A path field with a Browse button that runs an open panel.</sub></td>
    <td width="50%"></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Display</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/badges-dark.webp"><img src="docs/images/components/badges-light.webp" alt="Badges" width="420"></picture><br><b>Badges</b><br><code>Badge</code> · <code>.badgeStyle(_:)</code> · <code>Badge(count:)</code> · <code>Badge.status</code><br><sub>One badge with semantic, count, status, solid and gradient styles.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/status-dot-pill-dark.webp"><img src="docs/images/components/status-dot-pill-light.webp" alt="Status pill" width="420"></picture><br><b>Status pill</b><br><code>StatusDotPill</code><br><sub>A dot and a label, lifted for contrast on dark.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/spinner-shimmer-dark.webp"><img src="docs/images/components/spinner-shimmer-light.webp" alt="Spinner and shimmer" width="420"></picture><br><b>Spinner and shimmer</b><br><code>ThinkingSpinner</code> · <code>ShimmerTextOverlay</code><br><sub>A tintable indeterminate spinner, and a shimmer for "working" text.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/numbers-keys-time-dark.webp"><img src="docs/images/components/numbers-keys-time-light.webp" alt="Numbers, keys and time" width="420"></picture><br><b>Numbers, keys and time</b><br><code>SlidingNumber</code> · <code>ShortcutKey</code> · <code>TimeAgoLabel</code> · <code>InfoButton</code><br><sub>Rolling digits, key caps, relative ages and a click-to-read hint.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/path-hover-chip-dark.webp"><img src="docs/images/components/path-hover-chip-light.webp" alt="Path chip" width="420"></picture><br><b>Path chip</b><br><code>PathHoverChip</code> · <code>PathHoverChip.code</code><br><sub>Morphs into a frosted chip with Copy and Reveal (or Run) on hover.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/terminal-output-dark.webp"><img src="docs/images/components/terminal-output-light.webp" alt="Terminal output" width="420"></picture><br><b>Terminal output</b><br><code>TerminalOutputView</code><br><sub>Collapsible stdout / stderr / system lines.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/empty-state-dark.webp"><img src="docs/images/components/empty-state-light.webp" alt="Empty state" width="420"></picture><br><b>Empty state</b><br><code>EmptyState</code> · <code>.contained()</code><br><sub>One empty state everywhere; <code>.contained()</code> for a section inside a page.</sub></td>
    <td width="50%"></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Sections</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/rounded-section-dark.webp"><img src="docs/images/components/rounded-section-light.webp" alt="Rounded section" width="420"></picture><br><b>Rounded section</b><br><code>RoundedSection</code> · <code>SettingsForm</code> · <code>DetailRow</code><br><sub>The settings and form card, with copyable and path rows.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/section-header-dark.webp"><img src="docs/images/components/section-header-light.webp" alt="Section header" width="420"></picture><br><b>Section header</b><br><code>SectionHeader</code><br><sub>A heading with a count capsule, a caption and a trailing action.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/info-rows-dark.webp"><img src="docs/images/components/info-rows-light.webp" alt="Info rows" width="420"></picture><br><b>Info rows</b><br><code>InfoRow.labeled</code> · <code>.status</code> · <code>.branch</code> · <code>.hint</code><br><sub>Prebuilt rows for status cards; a passing check tints the border, never fills it.</sub></td>
    <td width="50%"></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Navigation</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/underline-tab-bar-dark.webp"><img src="docs/images/components/underline-tab-bar-light.webp" alt="Underline tabs" width="420"></picture><br><b>Underline tabs</b><br><code>UnderlineTabBar</code><br><sub>A sliding underline with optional count chips and icons.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/step-indicator-dark.webp"><img src="docs/images/components/step-indicator-light.webp" alt="Step indicator" width="420"></picture><br><b>Step indicator</b><br><code>StepIndicator</code><br><sub>Dots for a wizard.</sub></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Tables & lists</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/bliss-table-dark.webp"><img src="docs/images/components/bliss-table-light.webp" alt="Table" width="480"></picture><br><b>Table</b><br><code>BlissTable</code> · <code>BlissTableColumn</code><br><sub>Sortable columns, checkbox selection with shift-click ranges, row taps.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/selection-bar-dark.webp"><img src="docs/images/components/selection-bar-light.webp" alt="Selection bar" width="390"></picture><br><b>Selection bar</b><br><code>.selectionBar(count:onClear:)</code> · <code>SelectionBarButton</code><br><sub>The floating bulk-action island; toasts lift to rest above it.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/divided-list-dark.webp"><img src="docs/images/components/divided-list-light.webp" alt="Divided list" width="420"></picture><br><b>Divided list</b><br><code>DividedForEach</code> · <code>.rowHover()</code> · <code>.rowTapAction</code><br><sub>Flat rows with a divider between each pair and one shared hover fill.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/flow-layout-dark.webp"><img src="docs/images/components/flow-layout-light.webp" alt="Flow layout" width="420"></picture><br><b>Flow layout</b><br><code>FlowLayout</code><br><sub>Wraps chips and tags onto as many lines as they need.</sub></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Sheets & actions</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/sheet-dark.webp"><img src="docs/images/components/sheet-light.webp" alt="App sheet" width="360"></picture><br><b>App sheet</b><br><code>.appSheet</code> · <code>AppSheetScaffold</code> · <code>SheetHeader</code><br><sub>Hugs its content, scales from the click point, nests, and is modal for the keyboard too.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/action-bar-dark.webp"><img src="docs/images/components/action-bar-light.webp" alt="Action bar" width="360"></picture><br><b>Action bar</b><br><code>ActionBar</code><br><sub>The footer: side actions lead, Cancel sits directly left of the action.</sub></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Menus, toasts & overlays</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/menu-rows-dark.webp"><img src="docs/images/components/menu-rows-light.webp" alt="Menu rows" width="240"></picture><br><b>Menu rows</b><br><code>.floatingMenu</code> · <code>PopupMenuService</code> · <code>QuickActionMenuItem</code> · <code>.onSecondaryClick</code><br><sub>Menus open from the trigger's corner and run from the keyboard. (Drawn inline here; the real one is a panel.)</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/toasts-dark.webp"><img src="docs/images/components/toasts-light.webp" alt="Toasts" width="420"></picture><br><b>Toasts</b><br><code>ToastService</code> · <code>.globalToast()</code><br><sub>Pills that stack into a deck, fan out on hover, and expand errors into a card.</sub></td>
  </tr>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/progress-overlay-dark.webp"><img src="docs/images/components/progress-overlay-light.webp" alt="Progress overlay" width="345"></picture><br><b>Progress overlay</b><br><code>ProgressOverlay</code><br><sub>A card for long imports and scans.</sub></td>
    <td width="50%"></td>
  </tr>
</table>

</details>

<details open>
<summary><b>Themes</b></summary>

<table>
  <tr>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/theme-cards-dark.webp"><img src="docs/images/components/theme-cards-light.webp" alt="Theme cards" width="390"></picture><br><b>Theme cards</b><br><code>ThemeCard</code><br><sub>A swatch per theme, built-in or registered.</sub></td>
    <td width="50%" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/components/appearance-settings-dark.webp"><img src="docs/images/components/appearance-settings-light.webp" alt="Appearance settings" width="390"></picture><br><b>Appearance settings</b><br><code>AppearanceSettings</code><br><sub>The drop-in pane: Light / Dark / System, accent, theme.</sub></td>
  </tr>
</table>

</details>

Run the catalog to see them all (`-page table` opens on a page):

```bash
swift run BlissCatalog
```

## Using this repo as a template

BlissUI is set up as a GitHub template repository. **Use this template → Create a new repository** gives you the package, the test targets (including `BlissUIPublicAPITests`, which compiles only against the public API), CI, and the issue and PR templates. [CLAUDE.md](CLAUDE.md) holds the design-system rules the components follow.

## License

MIT — see [LICENSE](LICENSE).
