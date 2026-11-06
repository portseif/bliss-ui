# CLAUDE.md

Project guidance for Claude Code working on **BlissUI**, a SwiftUI component library for macOS. Beautiful by default. This file describes the library as it is now — when something changes, update the section in place instead of appending a "latest pass" note.

The components were extracted from StackMe, where every one of them was tuned in a shipping app. The comments in the sources explain *why* things are the way they are (timing, z-order, AppKit gotchas). Keep them; don't "simplify" a workaround without reading its comment first.

---

## Quick Reference

**Build:** `swift build` | **Test:** `swift test` | **Catalog:** `swift run BlissCatalog` (`-page table` opens on a page)
**Target:** macOS 15.0. 15 APIs (`.pointerStyle`, `.restorationBehavior`) need no `#available`; 26-only ones go through `isTahoeOrLater`.
**Swift settings** (`Package.swift`): Swift 5 language mode, `defaultIsolation(MainActor.self)`, approachable concurrency (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`), `MemberImportVisibility`. Everything is main-actor unless marked `nonisolated`.

- **The catalog is the integration check.** `Examples/BlissCatalog` uses only the public API; add a demo for every new component.
- **Two test targets.** `BlissUITests` uses `@testable import` for internals. `BlissUIPublicAPITests` imports BlissUI *without* `@testable`, so it only compiles against the public API — every public component gets a construction test there. If an app can't reach it, that target fails to build.
- **Previews:** every component has a `#Preview(traits: .fixedLayout(…))`, one per component plus variants only for different data states; no dedicated dark-mode previews (the canvas has an appearance toggle). Generic sample data only.

## Layout

```
Sources/BlissUI/
├── Themes/          BlissTheme + presets, BlissAppearance (settings keys), .blissTheme(), AppearanceSettings
│   ├── Tokens/      Colors, Typography, Spacing + Sizing
│   ├── Palettes/    BlissTheme, StatusTones (contrast math)
│   └── Styles/      Button, form/toggle, text-field and link styles — global, theme-aware
├── Animations/      Motion tokens, Reduce Motion fallback, isTahoeOrLater
├── Effects/         Glass border, dimmed overlay, shimmer
├── Window/          Traffic-light offset, shell backdrop, drag exclusion, frame persistence, borderless card
├── Services/        Focus visibility, shortcut hints, popup menus, secret clipboard
├── Extensions/      Date formatting, LocalizedStringKey(verbatim:)
└── Components/
    ├── Actions/     ActionBar, HoverIconButton, quick-action menu rows
    ├── Display/     Badge, EmptyState, ThinkingSpinner, InfoButton, PathHoverChip, SlidingNumber, …
    ├── Inputs/      FloatingMenuPicker, SegmentedPills, color + icon pickers, checkbox, secondary click
    ├── Navigation/  UnderlineTabBar, StepIndicator
    ├── Overlays/    FloatingMenu, Tooltip, ScrollViewWithThinIndicator, ProgressOverlay
    ├── Sections/    RoundedSection, SectionHeader, DetailRow, InfoList
    ├── Sheets/      AppSheet, SheetHeader, SheetCloseButton
    ├── Tables/      BlissTable, SelectionBar, DividedForEach, list-row hover
    ├── Grids/       FlowLayout
    └── Toasts/      ToastData, ToastService, ToastNotification, .globalToast()
Examples/BlissCatalog/  Demo app of every component, public API only
```

## Code Conventions

- **Reuse before you write:** grep for an existing component, helper or token first. If you roll something new, say why in one line. Hand-rolled chips and pills are how duplicate styles creep in.
- Descriptive names, no abbreviations; views organized by `// MARK: -`; services are `static let shared` singletons.
- **Public API:** a public struct needs an explicit `public init` (memberwise inits are internal), `public var body`, and public defaults may only reference public symbols. Keep plumbing (NSViewRepresentables, preference keys, panel controllers) internal. Add the construction test in `BlissUIPublicAPITests`.
- No per-struct `private let fooFont = .system(...)` constants; inline `Typography.*`.
- **Accessibility:** an icon-only button gets `.accessibilityLabel(Text("…"))` (its tooltip text — `.tooltip` is a hover panel VoiceOver never sees). A `Toggle` gets its real title even with `.labelsHidden()`. Drawn-only selection gets `.accessibilityAddTraits(isSelected ? [.isSelected] : [])`. A row opened by a tap uses `.rowTapAction { … }`, not a bare `.onTapGesture`. **Every clickable control is a Tab stop with the one ring**: a bare `.plain` button outside a menu panel uses `FocusablePlainButtonStyle(cornerRadius:outset:bleed:)` instead. A hover-only control (opacity 0 + `allowsHitTesting`) is also `.disabled` while hidden, or Tab lands on it and Space fires it unseen.

---

## Design System

Always use tokens instead of hardcoded values.

### Themes (`BlissTheme`)

Four built-ins: **System** (no palettes — built-in tokens, macOS accent, byte-for-byte the default look), **High Contrast** (low vision; status marks held to 7:1), **Color Blind Safe** (Okabe & Ito: bluish green / orange / vermillion / blue for success / warning / danger / info, distinct with protan, deutan and tritan vision) and **Low Glare** (dim warm surfaces; cream, not white, in light mode). Apps add their own with `BlissTheme.register(_:)` — a theme is an `id`, a name, a light and a dark `ThemePalette` (shell, content, raised, border, accent, optional accent foreground, optional status colors) and a four-color swatch.

- `.blissTheme()` at the root of every window applies the theme, Light/Dark/System and accent. The surface tokens read `ThemeColors.activePalette` on access, so the modifier re-IDs the tree on any change. **Consequence:** a `@State` default captured at launch doesn't re-evaluate; restore session state in `.onAppear`.
- Settings live in `UserDefaults` under `BlissAppearance.Keys` (`bliss.*`), readable with `@AppStorage` and settable from code (`BlissAppearance.theme = .lowGlare`). `AppearanceSettings()` is the drop-in pane.
- With a theme active the accent is still a picker: the theme's accent is its default, and a pick is kept per theme (`id=#RRGGBB` pairs in one string so one `@AppStorage` observes all of them).
- **No status mark may equal the theme's accent** — `statusTint` / `legibleOnDark` recognize marks by color. That's why Color Blind Safe's info is Okabe blue, not its sky-blue accent.

### Colors (`Colors.swift`)

- Surfaces: `Color.windowBackground`, `controlBackground`, `contentAreaBackground`, `appShell`, `menuBorder`.
- Status: `Success.success500`, `Warning.warning500`, `Danger.danger500` (**`Danger`, not `Error`**), `Info.info500`, `Grey.*`.
- **Status colors are two tones on dark.** Each `*500` is the MARK tone — text, icons, dots, bars. Each palette's `tint` (`Success.tint`, …) is the deep base for fills, borders and washes, and for any solid fill behind white text. A lifted color at low opacity goes grey on dark, and the lifted tones are too light for white on top. `StatusTones` derives both from a theme's base colors, lightening the mark only until it clears `minimumStatusContrast` on the content and raised surfaces. `Success.success500` and friends are computed — never capture one in a `static let`.
- A raw `*500` label on the dark pane fails contrast; status chips use `Color.legibleOnDark(_:)`.
- `Color.tertiary` / `.quaternary` don't exist as `Color` statics (ShapeStyle-only).

### Accent

`Color.accent` is the live accent: the theme's (or the pick for it), the custom RGB, or `NSColor.controlAccentColor`. Text on an accent fill uses `AccentHue.contrastForeground` (luminance-aware). Accent is for focus rings, selection checkmarks, links on hover and small pills — **the text-button styles use no accent hue.**

### Surfaces, selection & menus

- **Neutral gray selection + hover** from `RowTint`: `hover(scheme)` and `selected(scheme)` (selected stays a step above hover); Increase Contrast raises both. Text stays full-strength `.primary`.
- **Flat list rows** share one hover fill and one spacing: `listRowHover(…)` / `rowHover()`, `Spacing.listRowPadding` top and bottom, a `RoundedRectangle(cornerRadius: Sizing.radiusMedium)` fill. Rows stack flush (`DividedForEach`). Dividers span the row's content, not its hover fill.
- **Menu surfaces** fill `Color.controlBackground` under a theme, else `.ultraThinMaterial`, with `Color.menuBorder`. Detached `NSPanel`s don't inherit the forced color scheme, so menus and tooltips stamp `panel.appearance`.

### Spacing, sizing, typography

- `Spacing.xs/sm/md/lg/xl/xxl…`, `Spacing.insetSpacing` (3). `Sizing.radiusSmall` 4 / `radiusDefault` 6 / `radiusMedium` 8 / `radiusLarge` 10 / `radiusXLarge` 16 / `radiusXXLarge` 20 / `radiusFull`. Nested corners follow the concentric rule (inner radius = outer radius − padding).
- **Always `Typography.*`**, never `.font(.system(size:))`, never `.weight()` on a token. Every token renders at regular weight; emphasis comes only from the explicit `*Semibold` / `*Bold` variants. macOS text styles map to the token of the SAME size, not the same name: `.body` 13 = `bodySmall`, `.headline` = `bodySmallSemibold`, `.title3` 15 = `headingSmall`, `.title2` 17 = `headingMedium`, `.title` 22 = `displaySmall`.
- **macOS 26:** `isTahoeOrLater` instead of `#available` in expressions. Text fields switch to `Sizing.radiusFull` there; buttons keep `radiusMedium`.

---

## Components

**Use the custom components, never native equivalents** (no `.bordered`/`.borderedProminent`/`.plain` for real buttons, no native `Picker`/`Menu`/`ColorPicker`/`.help()`/`.contextMenu`).

### Buttons (`ButtonStyles.swift`)

Linear-inspired: `radiusMedium` corners, hairline borders, `RowTint` hover/press, no shadows, no accent hue. `PrimaryButtonStyle` (main actions, `compact:` for 28pt), `SecondaryButtonStyle` (Cancel/Back; `accent: true` for affirmative secondary), `OutlineButtonStyle`, `GhostButtonStyle` (`hugsLabel:` for a heading that's also a link), `DestructiveButtonStyle`, `SmallPillButtonStyle`, `ToolbarIconButtonStyle`, `InlineIconButtonStyle`, `SelectableCardButtonStyle` (a card picked by clicking it), and `AnimatedGradientBorderButtonStyle` (the signature "this starts something big" button).

**Keyboard focus:** every style is a Tab stop with the same ring, and **rings show only after keyboard input** (`FocusVisibilityService`, like the web's `:focus-visible`). Space presses; Return presses the control a ring is on. The ring appears without animation. A menu's trigger button must **toggle** its `isPresented` binding, not set it `true`.

### Inputs

- `TextField(...).textFieldStyle(.largePadded)`. A hand-built input wraps its chrome in `.inputBox(isFocused:cornerRadius:)` — don't hand-roll the box.
- Toggles are `.toggleStyle(.flatSwitch)`, never the native `.switch` (a Tab stop with the shared ring that Space flips, real switch semantics for VoiceOver).
- `FloatingMenuPicker` for dropdowns, `FloatingMenu` for action menus, `SegmentedPills` for segmented controls, `InfoButton(text:)` / `InfoHint { … }` instead of `.help()`.
- `ColorPickerButton` and the icon pickers stay native `.popover`s on purpose: a floating panel can't become key, so search fields and Return/Esc wouldn't work.

### Display

`Badge` (one badge, many styles: `.badgeStyle(.success)`, `Badge(count:)`, `.dot(_:)`), `EmptyState` (fills its container; `.contained()` for a section-level empty), `ThinkingSpinner` (the one indeterminate spinner — `ProgressView` can't be tinted on macOS), `TextLink` (URLs only), `TimeAgoLabel`, `DividedForEach`, `DetailRow`, `ShortcutKey`, `SectionHeader`, `UnderlineTabBar`, `FlowLayout`, `ShimmerTextOverlay`, `SlidingNumber`, `RoundedSection` (settings/form card).

### Tables

`BlissTable(rows, columns:, selection:, onOpen:) { row in cell; cell; cell }` — the `cells` closure returns one view per column and `BlissTableRowLayout` gives each its column width, so the header and rows always line up. Columns are `.fixed(_)` or `.flexible(minimum:)`; a column sorts when given a comparator or key path. Rows are an eager `VStack` by default — a `LazyVStack` shimmers by a sub-pixel during width animations. Bulk actions go in `.selectionBar(count:onClear:) { SelectionBarButton(…) }`, which lifts toasts above it.

### Sheets

- **`AppSheet`** — the standard modal, not SwiftUI `.sheet` (macOS 26 draws a large Liquid Glass radius with no override). `.appSheet(isPresented:)` / `.appSheet(item:)`, hosted once by `.appSheetHost()` at the window root. Dismiss via `@Environment(\.appSheetDismiss)`, not `\.dismiss`. Sheets nest, and they're modal for the keyboard and VoiceOver too.
- **Auto-height:** the card hugs its content, capped to the window. `.frame(maxHeight:)` does NOT hug here. Use `AppSheetScaffold { header } content: { … } footer: { … }` for pinned header/footer with a scrolling middle.
- **Footer order:** side actions lead, then `Spacer()`, then Cancel directly left of the action. Sheets use the compact (28pt) buttons.

### Overlays

- **Tooltip:** `.tooltip("Settings", position: .below)` — never `.help()`. Grouped timing: the first waits 500ms, the next within 400ms shows instantly.
- **Toasts:** `ToastService.shared` rendered by `.globalToast()`. They stack (at most 5), fan out on hover, and a progress toast is the caller's to take down (`dismiss(id:)` from a `defer`). `success`/`info` auto-dismiss; `error`/`warning`/in-progress persist.
- **Floating menus:** content must be a `View` struct with `@Binding`s (it's hosted in an `NSHostingView` snapshotted at open). Menus are child windows at the parent's level, and the page doesn't scroll under an open one.
- **`ScrollViewWithThinIndicator`** — thin overlay indicator plus optional edge fades. The fade is an alpha MASK, and **never animate a mask**: an animated mask re-renders into a new texture every frame of a live resize (hundreds of MB of graphics memory).

### Window

For a `.windowStyle(.hiddenTitleBar)` window: `.blissWindowChrome()` (opaque shell behind the whole window + traffic lights at `TrafficLightOffset.defaultOffset`), `.persistsWindowFrame(key:)`, `.windowDragDisabled()` on custom title-bar controls, `.borderlessCardWindow(isActive:size:)` for a first-run card.

- **Traffic lights** are offset by replacing `NSThemeFrame`'s private `_closeButtonOrigin` — AppKit re-places the buttons on every title-bar layout (each live-resize step that grows the height), so moving their view afterwards is always undone. If a macOS release drops the method, the swap is skipped and the lights sit at the default spot.
- **The backdrop fills with its layer's `backgroundColor`, never `draw(_:)`** — a window-sized drawn view gets a window-sized backing store at every live-resize step.
- Don't insert `.titled` / `fullSizeContentView` / `titlebarAppearsTransparent` yourself; they fight `.hiddenTitleBar`. After changing a style mask, call `WindowChrome.applyShellBackdrop(to:)`.

---

## Motion (`Animations`)

Pick by intent; if no token fits, add a named one rather than an inline spring. Springs for organic motion, short easeOut for cursor-driven micro-interactions, linear only for indeterminate progress. `accordion`, `pane`, `detailOpen` / `detailClose`, `hover` / `press` / `selection`, `interactionReveal` / `feedback` / `droplet`, `toast` / `dropdown` / `menuOpen` / `menuClose`, `sheet` / `sheetClose` / `sheetMorph`, `disclosure`, `searchExpand`, `stream` / `reveal`, `scrollIndicator`, `exit`, `standard`.

**Reduce Motion:** anything that scales, slides or loops goes through `prefersReducedMotion` or `AnyTransition.motion(_:)` (the transition, or a plain fade).

A value-keyed `.animation(_:value:)` on a big subtree retimes everything that changes in the same transaction. Scope it with `.animation(_:body:)`.

## Gotchas

| Issue | Solution |
|-------|----------|
| `@AppStorage` toggle doesn't animate | It bypasses the transaction — use `@State` seeded from UserDefaults and persist in `.onChange` |
| Native `ColorPicker` with `@AppStorage` breaks on re-render | `ColorPickerButton` |
| Custom `ShapeStyle` / `AnyView` values snap instead of tweening | Pass data to concrete views, use `.animation(_, value:)` |
| A row of "identical" bars anti-aliases unevenly | Integer widths + gaps summing exactly to the container |
| A width-only `Color.clear.frame(width:)` is vertically greedy | Pin a height |
| `"".localizedCaseInsensitiveContains` is false | Guard `query.isEmpty \|\|` before filtering |
| `Text` in a vertical `ScrollView` expands horizontally | `.lineLimit(nil).fixedSize(horizontal: false, vertical: true)` |
| Singleton panel hide/show race | Clear stored window references synchronously at the start of `hide()`, animate a captured local |
| Never `hasShadow` with a SwiftUI `.shadow()` on a panel | Stippled double halo |
