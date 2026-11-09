# CLAUDE.md

Project guidance for Claude Code working on **BlissUI**, a SwiftUI component library for macOS. Beautiful by default. This file describes the library as it is now — when something changes, update the section in place instead of appending a "latest pass" note.

The components were extracted from StackMe, where every one of them was tuned in a shipping app. The comments in the sources explain *why* things are the way they are (timing, z-order, AppKit gotchas). Keep them; don't "simplify" a workaround without reading its comment first.

---

## Quick Reference

**Build:** `swift build` | **Test:** `swift test` | **Catalog:** `swift run BlissCatalog` (`-page table` opens on a page)
**Target:** macOS 15.0. 15 APIs (`.pointerStyle`, `.restorationBehavior`) need no `#available`; 26-only ones go through `isTahoeOrLater`.
**Swift settings** (`Package.swift`): Swift 5 language mode, `defaultIsolation(MainActor.self)`, approachable concurrency (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`), `MemberImportVisibility`. Everything is main-actor unless marked `nonisolated`.

- **The catalog is the integration check.** `Examples/BlissCatalog` uses only the public API; add a demo for every new component.
- **README screenshots:** `scripts/screenshots.sh` rebuilds every image in `docs/images` (needs `cwebp` and Screen Recording permission). A new component gets a `GalleryEntry` in `Examples/BlissCatalog/Gallery.swift` and a card in the README's Component index. The catalog flags it drives: `-gallery <folder>` (capture each `GalleryEntry`, quit), `-capture <file.png>` (capture the window once settled, quit), `-page <case>`, `-demo selection|sheet|toasts`, plus any `UserDefaults` key as `-bliss.theme low-glare` / `-bliss.colorScheme Dark`.
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
├── Window/          Traffic-light offset, shell backdrop, drag exclusion, frame persistence, borderless card, WindowTitleBar
├── Services/        Focus visibility, shortcut hints, popup menus, secret clipboard
├── Extensions/      Date formatting, LocalizedStringKey(verbatim:), Bundle.blissUI
├── Resources/       Localizable.xcstrings — the library's own strings, 10 languages
└── Components/
    ├── Actions/     ActionBar, HoverIconButton, quick-action menu rows
    ├── Calendar/    MonthCalendar, DatePickerField, DateRangePickerField, DateRangeCalendar
    ├── Data/        ProgressBar, ProgressRing, UsageBar, TickStrip, ChangeBlocks, Sparkline
    ├── Display/     Badge, EmptyState, ThinkingSpinner, InfoButton, PathHoverChip, SlidingNumber, StatusPill, KeyHintPill, …
    ├── Feedback/    Banner, DisclosureSection, ConfirmationSheet, skeleton loading
    ├── Filters/     FilterBar + FilterCondition matching, filter menu rows, FilterMenuButton
    ├── Forms/       SettingsRow family, settings table of contents, FormField, OptionCard, RadioGlyph, wizard rows
    ├── Inputs/      FloatingMenuPicker, SegmentedPills, color + icon pickers, checkbox, NumberField, BlissSlider, TextArea, SecretField, TokenField, ComboBox, ShortcutRecorder, DropZone
    ├── Layout/      Avatar, AvatarStack, Breadcrumbs, InspectorSplit, CodeField + highlighters
    ├── Navigation/  UnderlineTabBar, StepIndicator, CommandPalette, Sidebar, OutlineList, SlideoutPanel
    ├── Overlays/    FloatingMenu, context menu, Tooltip, ScrollViewWithThinIndicator, ProgressOverlay
    ├── Sections/    RoundedSection, SectionHeader, DetailRow, InfoList
    ├── Sheets/      AppSheet, SheetHeader, SheetCloseButton
    ├── Tables/      BlissTable, SelectionBar, ReorderableList, DividedForEach, list-row hover
    ├── Grids/       FlowLayout
    └── Toasts/      ToastData, ToastService, ToastNotification, .globalToast()
Examples/BlissCatalog/  Demo app of every component, public API only (Gallery.swift feeds the README index)
scripts/screenshots.sh  Regenerates docs/images
```

## Code Conventions

- **Reuse before you write:** grep for an existing component, helper or token first. If you roll something new, say why in one line. Hand-rolled chips and pills are how duplicate styles creep in.
- Descriptive names, no abbreviations; views organized by `// MARK: -`; services are `static let shared` singletons.
- **Public API:** a public struct needs an explicit `public init` (memberwise inits are internal), `public var body`, and public defaults may only reference public symbols. Keep plumbing (NSViewRepresentables, preference keys, panel controllers) internal. Add the construction test in `BlissUIPublicAPITests`.
- No per-struct `private let fooFont = .system(...)` constants; inline `Typography.*`.
- **Localization:** the library's own strings resolve in `Bundle.module`, never the app's catalog — `Text("Copy", bundle: .module)`, `String(localized: "Copy", bundle: .module)`, `Button(String(localized: …, bundle: .module))`, and `.verbatim(String(localized: …, bundle: .module))` into a `LocalizedStringKey` parameter. A public default argument can't see the internal `.module`, so it uses `.blissUI`. Add every new key to `Resources/Localizable.xcstrings` with its translations. Strings a caller passes in (`Badge`, `BlissTableColumn`, `SheetHeader` titles) stay in the app's bundle. To check a translation in a test use `LocalizedStringResource(_:locale:bundle:)` — `String(localized:bundle:locale:)` only formats with `locale`, it doesn't pick the language.
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

**Use the custom components, never native equivalents** (no `.bordered`/`.borderedProminent`/`.plain` for real buttons, no native `Picker`/`Menu`/`ColorPicker`/`.help()`/`.contextMenu` — `.blissContextMenu { … }` is the right-click menu).

### Buttons (`ButtonStyles.swift`)

Linear-inspired: `radiusMedium` corners, hairline borders, `RowTint` hover/press, no shadows, no accent hue. `PrimaryButtonStyle` (main actions, `compact:` for 28pt), `SecondaryButtonStyle` (Cancel/Back; `accent: true` for affirmative secondary), `OutlineButtonStyle`, `GhostButtonStyle` (`hugsLabel:` for a heading that's also a link), `DestructiveButtonStyle`, `SmallPillButtonStyle`, `ToolbarIconButtonStyle`, `InlineIconButtonStyle`, `SelectableCardButtonStyle` (a card picked by clicking it), and `AnimatedGradientBorderButtonStyle` (the signature "this starts something big" button).

**Keyboard focus:** every style is a Tab stop with the same ring, and **rings show only after keyboard input** (`FocusVisibilityService`, like the web's `:focus-visible`). Space presses; Return presses the control a ring is on. The ring appears without animation. A menu's trigger button must **toggle** its `isPresented` binding, not set it `true`.

**Busy buttons:** `.buttonLoading(isSaving)` on any text button puts a spinner where the label was (same size) and blocks presses while keeping the enabled look — a working button isn't a disabled one.

### Inputs

- `TextField(...).textFieldStyle(.largePadded)`. A hand-built input wraps its chrome in `.inputBox(isFocused:cornerRadius:)` — don't hand-roll the box.
- `FormField(title, hint:, error:, isRequired:) { control }` puts the title above and the hint or error below; while `error` is set it sets `\.formFieldIsInvalid`, which the text field styles and `.inputBox` draw as a red line (read it in your own input). The control keeps its own label for VoiceOver; the hint or error becomes its accessibility hint.
- `DropZone(title, hint:, allowedContentTypes:, …) { urls in … }` is the file drop target: a dashed card, accent while a drag hovers, and the whole card is one button that opens an `NSOpenPanel` with the same rules (the Browse text is drawn, not a nested button, so Tab stops once). Folders count only with `canChooseDirectories`.
- `SecretField` for keys, tokens and passwords: masked until revealed, copy through `SecretClipboard`. Both fields stay mounted (one hidden) so the reveal keeps focus — a `SecureField` ↔ `TextField` swap drops it. Revealing asks `SecretClipboard.authorize`, and the value re-masks when the app resigns active.
- Toggles are `.toggleStyle(.flatSwitch)`, never the native `.switch` (a Tab stop with the shared ring that Space flips, real switch semantics for VoiceOver).
- `FloatingMenuPicker` for dropdowns, `FloatingMenu` for action menus, `SegmentedPills` for segmented controls, `InfoButton(text:)` / `InfoHint { … }` instead of `.help()`.
- `ColorPickerButton` and the icon pickers stay native `.popover`s on purpose: a floating panel can't become key, so search fields and Return/Esc wouldn't work.
- `DatePickerField` / `DateRangePickerField` open native `.popover`s for the same reason: the calendar grid needs arrow keys, Return and Esc. `MonthCalendar` on its own is one Tab stop with a roving focused day (arrows, Page Up/Down for months, ⇧ for years, Space picks). Dates follow `Calendar.current` and the locale — never hardcode month or weekday names.
- `NumberField` (− / + steppers, ↑/↓ step, Shift ×10, typing applies live and reverts on commit) and `BlissSlider` (accent track, ←/→, Home/End, adjustable for VoiceOver). `TextArea` grows between a `lineLimit` range then scrolls with the thin indicator; its `title` is a `LocalizedStringResource` because the hosted `NSTextView` needs a resolved string for its accessibility label.
- `TokenField` (Return/comma/paste add, Backspace selects then removes, ←/→ move between tokens), `ComboBox` (free text or restricted to its options) and `ShortcutRecorder` (`KeyboardShortcutValue`) keep focus in the window's field and show suggestions in a floating panel driven by the field's own `onKeyPress`.
- `FilterBar` edits `Binding<[FilterCondition]>` over app-supplied `FilterField`s (chips read field │ operator ▾ │ values ▾ │ ×); evaluate rows with `conditions.matches { field in row.value(for: field) }`. Filter and Display menus use `FilterCheckRow` / `DisplayRadioRow` / `FilterMenuRow` and a `FilterMenuButton` trigger; menus that stay open return `.keepOpen` from `onActivate`.
- `FloatingMenuPicker(_, …, showsTitle: false)` where a row already shows the title (`SettingsRow`) — the title still labels the trigger for VoiceOver.

### Display

`Badge` (one badge, many styles: `.badgeStyle(.success)`, `Badge(count:)`, `.dot(_:)`), `EmptyState` (fills its container; `.contained()` for a section-level empty), `ThinkingSpinner` (the one indeterminate spinner — `ProgressView` can't be tinted on macOS), `TextLink` (URLs only), `TimeAgoLabel`, `DividedForEach`, `DetailRow`, `ShortcutKey`, `SectionHeader`, `UnderlineTabBar`, `FlowLayout`, `ShimmerTextOverlay`, `SlidingNumber`, `RoundedSection` (settings/form card).

- **Semantic badges** fill with a wash of their status tint in both schemes (`X.tint.opacity(0.1)` light / `0.2` dark, hairline `0.3` / `0.4`). The light ramp's `*50` / `*200` steps are near-full saturation; never fill a badge with them.
- **Data views** are shape-based and dependency-free: `ProgressBar` / `ProgressRing` (determinate; `nil` value is the indeterminate sweep, still under Reduce Motion — `ThinkingSpinner` stays the one indeterminate spinner), `UsageBar` (stacked segments in whole points, largest-remainder split, or a meter that turns amber past 75% and red past 90%), `TickStrip`, `ChangeBlocks`, `Sparkline` (gaps draw dashed, never interpolated). Strokes and text use the status marks; washes use `.statusTint`.
- **People & layout:** `Avatar` (initials on a name-hashed color held to the theme's contrast, optional status with a shape per state), `AvatarStack`, `Breadcrumbs` (middle segments fold into a "…" floating menu), `InspectorSplit` (pinned shrinks the content, unpinned is a drawer with a dim; drag grip, width clamped and optionally persisted), `CodeField` (clear editor under a colored overlay; `.shell` / `.yaml` / your own `CodeHighlighter`).

### Navigation

- `CommandPalette` / `.commandPalette(isPresented:commands:)` — app-supplied sections of `CommandPaletteCommand`s, ranked fuzzy matching, recents, ↑↓/Tab move, Return runs, Esc clears then closes. Modal like `AppSheet` (content disabled + hidden from VoiceOver, scoped blur on `Animations.paletteBackdrop`); the card itself appears at once — ⌘K is a keyboard action. The selected row rings only after a keyboard move.
- `Sidebar(selection:isCollapsed:)` with `SidebarSection`, `SidebarRow` (icon, count badge, ⌘-number hint while ⌘ is held) and `SidebarFilterRow` (dot or custom icon). Collapsed, rows keep their icon (title in a tooltip, count as a dot) and the caller sizes it to `Sizing.sidebarCollapsedWidth`; `SidebarToggleButton` flips it on `Animations.pane`. The title and accessory stay mounted at width 0, so a focused row keeps its focus.
- `OutlineList(items, children:, selection:, expanded:) { row }` — a tree with chevrons and one indent per level; expansion is the caller's `Set`. One Tab stop with a roving row: ↑↓ move, → opens or steps in, ← closes or steps out, Space / Return selects.
- `.slideoutPanel(isPresented:title:edge:width:)` — stays mounted, slides on `Animations.pane` in / `exit` out (fades under Reduce Motion), a click outside or Esc closes it. Not keyboard-modal.

### Forms & feedback

- `SettingsRow` / `SettingsToggleRow` / `SettingsActionRow` inside `RoundedSection(divided: true)`; `SettingsScrollView` adds the table-of-contents rail with scroll-spy (mark sections with `.settingsSection(id)`).
- `OptionCard` / `OptionCardGrid` for pick-one or pick-many cards; `RadioGlyph` pairs with `CheckboxGlyph`; `WizardRadioRow` and `WizardStepRow` (pending / current / running / done / failed).
- `Banner` (info / success / warning / danger: mark-colored icon, tint wash and edge), `DisclosureSection` (chevron on `Animations.accordion`, content only built while open), `.confirmationSheet(…)` (an `AppSheet` with `SheetHeader` + compact `ActionBar`; Return confirms, Esc cancels), and `.skeleton(isLoading:)` / `SkeletonBlock` (one window-aligned sweep, no mask, still under Reduce Motion).

### Tables

`BlissTable(rows, columns:, selection:, onOpen:) { row in cell; cell; cell }` — the `cells` closure returns one view per column and `BlissTableRowLayout` gives each its column width, so the header and rows always line up. Columns are `.fixed(_)` or `.flexible(minimum:)`; a column sorts when given a comparator or key path. Rows are an eager `VStack` by default — a `LazyVStack` shimmers by a sub-pixel during width animations. Bulk actions go in `.selectionBar(count:onClear:) { SelectionBarButton(…) }`, which lifts toasts above it.

`ReorderableList($items, gripPlacement:, divided:) { row }` — flat rows with a grip that drags them into a new order (the others slide as the dragged row's center crosses theirs); ⌥↑ / ⌥↓ move the focused grip's row, VoiceOver gets Move up / Move down. Only the grip drags, so the row's text stays selectable.

### Sheets

- **`AppSheet`** — the standard modal, not SwiftUI `.sheet` (macOS 26 draws a large Liquid Glass radius with no override). `.appSheet(isPresented:)` / `.appSheet(item:)`, hosted once by `.appSheetHost()` at the window root. Dismiss via `@Environment(\.appSheetDismiss)`, not `\.dismiss`. Sheets nest, and they're modal for the keyboard and VoiceOver too.
- **Auto-height:** the card hugs its content, capped to the window. `.frame(maxHeight:)` does NOT hug here. Use `AppSheetScaffold { header } content: { … } footer: { … }` for pinned header/footer with a scrolling middle.
- **Footer order:** side actions lead, then `Spacer()`, then Cancel directly left of the action. Sheets use the compact (28pt) buttons.

### Overlays

- **Tooltip:** `.tooltip("Settings", position: .below)` — never `.help()`. Grouped timing: the first waits 500ms, the next within 400ms shows instantly.
- **Toasts:** `ToastService.shared` rendered by `.globalToast()`. They stack (at most 5), fan out on hover, and a progress toast is the caller's to take down (`dismiss(id:)` from a `defer`). `success`/`info` auto-dismiss; `error`/`warning`/in-progress persist.
- **Right-click menus:** `.blissContextMenu { QuickActionMenuItem…; MenuDivider(); … }` — the popup (`PopupMenuService`) at the pointer, also opened by ⌃Return / ⇧F10 while the view has focus. A picked `QuickActionMenuItem` closes the popup on its own (inside a `floatingMenu` the trigger's binding closes it).
- **Floating menus:** content must be a `View` struct with `@Binding`s (it's hosted in an `NSHostingView` snapshotted at open). Menus are child windows at the parent's level, and the page doesn't scroll under an open one.
- **`ScrollViewWithThinIndicator`** — thin overlay indicator plus optional edge fades. The fade is an alpha MASK, and **never animate a mask**: an animated mask re-renders into a new texture every frame of a live resize (hundreds of MB of graphics memory).

### Window

For a `.windowStyle(.hiddenTitleBar)` window: `.blissWindowChrome()` (opaque shell behind the whole window + traffic lights at `TrafficLightOffset.defaultOffset`), `WindowTitleBar { leading } center: { title } trailing: { … }` (`Sizing.titleBarHeight` tall, `trafficLightClearance` before the leading controls — dropped in full screen — and the empty bar drags the window through `WindowDragGesture`; its controls are `.windowDragDisabled()` for you), `.persistsWindowFrame(key:)`, `.windowDragDisabled()` on other custom title-bar controls, `.borderlessCardWindow(isActive:size:)` for a first-run card.

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
| `onKeyPress(.delete)` never fires for Backspace | Backspace arrives as U+007F, SwiftUI's `.delete` is U+0008 — match the internal `KeyEquivalent.backspace` too |
| A focused Button loses focus to the first text field | Its label switched between view types (`if` / `else`); keep one structure and change its contents |
| `.accessibilityLabel` on a hosted `NSTextView` does nothing | Set the AppKit view's label from a resolved string (`TextArea` takes a `LocalizedStringResource`) |
| `ForEach(weekdaySymbols, id: \.self)` drops or duplicates days | Initials repeat ("S", "T"); identify by position |
| A dragged row's measured frame never settles | Its geometry includes its own `.offset`; measure row frames only while nothing is dragged (`ReorderableList`) |
| Translations fall back to English under Swift 6.3 (`LocalizationTests` fail, bundle has only `en`) | 6.3's default native build system copies `Localizable.xcstrings` uncompiled — build with `--build-system swiftbuild` (6.4's default; CI passes it) |
