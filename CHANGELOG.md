# Changelog

All notable changes to BlissUI. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.3.0] — 2026-11-16

The five from the web-kit comparison: a split, a markdown view, a code block, a stat card and a rating.

### Added

- `ResizableSplit` — two panes with a divider you drag, nudge from the keyboard or double-click to reset; the width is clamped and can persist.
- `MarkdownView` — a document's blocks (headings, lists, quotes, links, fenced code) at the library's sizes.
- `CodeBlock` — a read-only snippet in `CodeField`'s colors with line numbers and a copy button.
- `StatCard` and `StatChange` — the metric tile with a change pill and a sparkline.
- `Rating` — stars or any symbol, clicked, hovered or arrowed through.

## [2.2.0] — 2026-11-16

The three large pieces from the web-kit comparison: a board, an editor and a carousel.

### Added

- `KanbanBoard` and `KanbanColumn` — columns of cards that drag within a column or into another, with keyboard moves.
- `RichTextEditor` — a formatting toolbar over a hosted text view, bound to `AttributedString`.
- `Carousel` and `PageControl` — paged content with hover arrows, dots, keyboard paging and optional autoplay.

## [2.1.0] — 2026-11-16

Nine components that close most of the gap to a web kit's component list: the inputs an app needs in its first week, plus charts.

### Added

- `MultiSelectPicker` — the pick-many picker: chips on the trigger and a check-row menu that stays open.
- `MessageComposer` and `ComposerAttachment` — a chat composer with attachment chips, a toolbar slot and a send button; Return sends, ⇧Return adds a line.
- `TimeSeriesChart`, `BarChart`, `ChartLegend`, `ChartPalette` and `.blissChartStyle()` — themed charts on Swift Charts with a hover cursor and value card.
- `InputField` — the boxed text field with a leading icon, a clear button, a keyboard hint, a loading spinner and a trailing slot.
- `OneTimeCodeField` — a verification code typed into a row of boxes over one hidden field.
- `Pagination` — page controls for a table or list, 1-based, with an ellipsis for skipped runs.
- `Timeline` and `TimelineItem` — an activity feed with dot or icon marks on one connector line.
- `PersonRow` — avatar, name and detail with a trailing slot.
- `LabeledDivider` — a hairline with a label set into it.

## [2.0.0] — 2026-11-15

A title bar, a collapsible sidebar, a commit graph and theme-aware everything. Two changes break source compatibility: `ToastService` is `@Observable` (drop `@ObservedObject`), and `\.appSheetDismiss` is an `AppSheetDismissAction` (where it was passed as a closure, write `{ dismiss() }`). Both are under Changed.

### Added

- `WindowTitleBar` — the custom title bar for a hidden-title-bar window: leading and trailing controls around a centered title, room for the traffic lights (dropped in full screen), and the empty bar drags the window.
- `Sidebar(isCollapsed:)` and `SidebarToggleButton` — the sidebar collapses to its icons (titles in tooltips, counts as dots) at `Sizing.sidebarCollapsedWidth`.
- `SidebarRow(_:image:value:)` — a row whose icon is an `Image` (a logo, or one your app draws), shown as a template in the row's text color like the symbol icons.
- `OutlineList` — a tree with disclosure chevrons and one indent per level; one Tab stop with a roving row.
- `ReorderableList` — rows with a grip handle that drag into a new order; ⌥↑ / ⌥↓ move the focused row.
- `DropZone` — a file drop target that doubles as a Browse button, with the same rules for both.
- `CommitGraph` — a git history as a graph: colored lanes, merge rings, rounded elbows where branches leave and rejoin, and ref pills, with an optional trailing accessory per row.
- `RoundedSection(insetsHeader:)` — `false` puts the section's title flush with the card's edge instead of in line with its content.
- `BlissTable(pinsHeader:)` — the header stays at the top of the enclosing scroll view while the rows scroll under it. Rows stay eager unless `isLazy`, so a width animation doesn't rebuild them off screen.
- `AvatarStack(overflowStyle: .plain)` — `+N` as plain text after the avatars instead of a filled chip.
- `BlissTable(autoSizeColumns:)` — flexible columns size to their widest cell or header label instead of splitting the room evenly. Badges and dates hug their content; when the table is too narrow, the widest columns give way first (never below their minimum) and text truncates, so no column collapses or overflows. `BlissTableRowLayout(contentWidths:)` is the layout side of it.
- `AppearanceModePicker` — Light / Dark / System as three window previews (System split down the middle), drawn with the active theme's palettes.
- `ColorPickerButton(label: .hexChip)` — the color as a capsule with a round swatch and its hex value.
- `BlissAppearance.reduceMotion` (`ReduceMotionOption`: System / On / Off) — force reduced motion on or off for the app; `prefersReducedMotion` honors it. `BlissAppearance.resetToDefaults()` returns every appearance choice to its default.
- `.sidebarResizeHandle(width:in:isEnabled:)` — a grip on a sidebar's trailing edge that drags it wider or narrower, like `InspectorSplit`'s, adjustable with VoiceOver.
- `LocalizedStringKey.verbatimWithCode(_:)` — like `.verbatim(_:)`, but `backticked` spans show as inline code (monospaced on a faint tint). Nothing else is parsed, so names with `_` or `*` still show as-is.
- Custom background and foreground per theme and mode — `BlissAppearance.surfaceColor(_:for:in:)` / `setSurfaceColor(_:_:for:in:)` (`ThemeSurfaceRole`). A new background rebuilds the content pane, raised surfaces and border around it (`ThemePalette.withBackground(_:)`), and text turns light or dark to suit it unless a foreground is set. System takes them too, on its built-in surfaces.
- `ThemePalette.foreground` — a theme's text color. `Color.textPrimary` uses it, `.textSecondary` and `.textTertiary` are mixed from it toward the background as far as 4.5:1 allows, and `.blissTheme()` sets it as the root foreground style. High Contrast, Color Blind Safe and Low Glare publish one.
- When a picked background makes a mode's surfaces light in dark mode (or dark in light mode), `.blissTheme()` gives the views that scheme, so system colors and control labels stay readable on it.
- Separate light and dark themes — `BlissAppearance.separateModes`, `theme(for:)` / `setTheme(_:for:)` and `BlissTheme.active(for:)`. `ThemeColors.palette(for:)` returns a mode's palette with the user's colors laid over.
- `AppearanceSettings` gains Background and Foreground hex chips (for the mode being edited) and, under Advanced, "Separate light and dark modes" with a Light / Dark switch for which mode the card edits.
- Fonts and font sizes — `BlissAppearance.font(_:for:)` / `setFont(_:_:for:)` pick a family and base face (`FontChoice`) for the UI, content and code (`FontRole`), and `uiFontSize` / `codeFontSize` set the base sizes (13 and 12 by default). Every `Typography` style is drawn in them and scaled from them, so a change re-sizes the whole app. The UI font is kept per mode while light and dark are separate.
- `Typography.contentMedium`, `.contentSmall` and `.contentCaption` — text the app shows rather than labels it (descriptions, documents), in the content font.
- `AppearanceSettings` gains a Font row in the theme card and, under Advanced, UI and code font sizes, UI font style, and content and code fonts (a monospaced family for code), like a modern editor's settings.
- `BlissAppearance.contrast` (0–100, 50 by default): above 50, hairlines (`Color.menuBorder`), hover and selection washes (`RowTint`) and muted text step toward the text color; below, they soften, with muted text held at 4.5:1.
- `BlissAppearance.translucentSidebar` and `Color.shellBackground`: the title bar and sidebar show the desktop blurred through a tint of the shell color. Fill the window's root with `Color.shellBackground` instead of `.appShell`.
- `BlissAppearance.usesPointerCursors`: every BlissUI button style, switch, picker and menu row shows the pointing hand on hover. Off by default, like the rest of macOS.
- Alternate Dock icons — `DockIconOption`, `BlissAppearance.dockIconID` and `applyDockIcon(from:)`. `AppearanceSettings(dockIcons:)` offers them.
- Custom themes — `BlissTheme` (and its palettes) are `Codable`, colors as `#RRGGBB`. `BlissTheme.duplicate(_:)` copies a theme as it looks (picked background, foreground and accent included), `importTheme(from:)` reads a theme file, and `deleteCustom(_:)` removes one. They're kept under `BlissAppearance.Keys.customThemes` and listed with the built-ins; `resetToDefaults()` leaves them alone. `ThemeColors.palette(of:for:)` gives any theme's palette with the user's colors over it.
- `AppearanceSettings` gains import, duplicate and delete buttons beside the theme, and Translucent sidebar, Contrast, Use pointer cursors and Dock icon under Advanced.

### Changed

- `ToastService` is `@Observable` instead of an `ObservableObject`: views that read its toasts update when they change, not on every `@Published` broadcast. Hold it as a plain property (`let toastService = ToastService.shared`); `@ObservedObject` no longer applies.
- `\.appSheetDismiss` is an `AppSheetDismissAction` (call it as `dismiss()`) instead of a closure, so the environment can tell it hasn't changed and a sheet's content isn't redrawn for it. Where it was passed as a closure, write `{ dismiss() }`.
- A `Sidebar`'s rows no longer all redraw whenever the sidebar does: its selection reaches them through a writer it keeps for its lifetime rather than a fresh closure in the environment.
- Environment values are declared with `@Entry`. `.accentColor(_:)`, which is deprecated, is no longer set by `.blissTheme()`; it sets `.tint`, and `Color.accent` follows the theme. The view-argument forms of `.background`, `.overlay` and `.mask`, `.coordinateSpace(name:)` and `.cornerRadius(_:)` gave way to their current forms.

- Text tooltips (`.tooltip("…")`) use the same tight 10/5 padding as every preset; `TooltipConfiguration`'s init defaults now match.
- `AvatarStack`'s `+N` chip is a pill sized for `+99` at a fixed, larger font, so stacks in a column line up whatever the counts.
- `ToolbarIconButtonStyle` buttons are square (28pt, 30pt before macOS 26, 24pt compact) whatever the glyph's shape.
- `BlissTable`'s header sits on a darker rounded band, as wide as the rows' hover fill, in place of the hairline under it, so it reads as its own strip.
- `CompactTextFieldStyle`, `SearchTextFieldStyle` and `ToolbarSearchTextFieldStyle` fill with the active color theme's raised surface and border instead of fixed greys (and `LargePaddedTextFieldStyle`'s underline takes the theme's border); System keeps the greys.
- `TerminalOutputView` takes the theme's colors instead of a fixed dark terminal — the read-only `CodeField` surface and hairline, primary text, accent system lines, the danger mark for stderr — so it reads right in light mode and under every color theme.

- `BlissTable`'s header band in light mode is the window's shell surface with a hairline (rows' hover and selection fills darken, so a darker band looked like a selected row); its labels are secondary instead of tertiary, readable on the band.
- `RowTint.hover` and `.selected` are a faint wash of the theme's accent when a color theme is active, so list, table, sidebar and menu highlights take the theme's color; System keeps the neutral grays.
- `Banner` puts its action under the message when it's narrower than 360pt, instead of squeezing the text into a column beside it.
- `TerminalOutputView(isDocked:contentInset:)` — docked, it's a flush panel with a hairline on top for a console along the bottom of a pane; `contentInset` lines its text up with the content above. Docked, it has no fill of its own (the pane shows through); its header and the card take the theme's `RowTint.hover`.

- Text meets WCAG AA. `Color.textSecondary`, `.textTertiary` and `.textPrimary` adapt to light and dark (they were fixed light-mode grays, about 3:1 in dark mode) and hold 4.5:1 on every built-in theme's surfaces, the accent-tinted selections included. The table header, sidebar rows and section titles, banner and sheet messages, detail labels, empty-state subtitles, `+N` counts, the terminal view's header and the secondary badge use them instead of SwiftUI's `.secondary` / `.tertiary`, which fall to about 3.9:1 and 1.9:1 on white.
- `AppearanceSettings` is laid out like a modern settings page: Mode as window previews, a card with the theme (a menu with each theme's swatch) and the accent (Theme / System or Custom, plus a hex chip), and an Advanced disclosure (reduce motion) beside Reset to default. The theme card grid is gone; `ThemeCard` remains public.
- Floating menus (dropdowns, kebab and context menus) cast a slightly stronger shadow (14% at an 18pt blur in light mode, 42% in dark) and draw a darker edge (the theme's border at full strength, or 12% black), so they don't blend into pale or tinted surfaces.
- Text on the accent (`AccentHue.contrastForeground`) is chosen by WCAG contrast, not a brightness cutoff, which put white on a lavender accent at 2.7:1.

- Tooltips, the action bar under a table and `AppSheet`'s dividers take the theme's surfaces and text instead of system materials and grays.
- Toasts sit on the theme's raised surface with its border (like menus), and their close button's hover takes the theme's wash.
- `SidebarToggleButton` answers ⌃⌘S, macOS's Toggle Sidebar shortcut, and its tooltip shows it.
- `AppearanceModePicker` names a hovered mode on the preview itself, blurring it behind a centered label, instead of a tooltip under it.
- `AppearanceSettings`' switches are the compact size (`.controlSize(.small)`), like `SettingsToggleRow`'s.

### Fixed

- Switching from Light or Dark back to System could leave a color theme's own colors on the forced mode (light cards in a dark window). The window went back to the Mac's appearance, but SwiftUI's `colorScheme` stayed on the forced one, so nothing re-rendered. `.blissTheme()` now re-renders after it syncs the appearance, and gives views the mode actually in effect when SwiftUI's lags behind.

- Switching the color scheme from Light or Dark back to System no longer leaves a window half in each: `preferredColorScheme(nil)` doesn't hand a macOS window back to the system, so `.blissTheme()` now also sets the app's appearance and clears what each window was forced to. A System window whose appearance flips with the Mac re-reads the theme's palette too.
- `ScrollViewWithThinIndicator` keeps the system scroller hidden after its content grows past the viewport (a sidebar whose rows load after it appears showed the wide legacy scroller).
- `ScrollViewWithThinIndicator` no longer rebuilds its content on every resize and scroll frame. It sat in a `GeometryReader` and kept the scroll offset in its own state, so a sidebar collapse or a scroll re-ran `content()` each frame — seconds of main-thread work for a 100-row table. The thumb, fades and viewport fill now read the scroll metrics themselves.

## [1.0.0] — 2026-11-09

The first tagged release — the StackMe component set, extracted into a package.

### Added

- 79 components for macOS 15+: buttons and text-field styles, inputs (dropdown, segmented pills, checkbox, switch, number field, slider, text area, secret field, token field, combo box, shortcut recorder, color and icon pickers, browse input), a calendar family (month, date and range pickers, time of day), filters, tables with a selection bar, forms (settings rows with a table-of-contents rail, form field, option cards, wizard rows), feedback (banner, disclosure, confirmation sheet, skeletons), data views (progress bar and ring, usage bar, tick strip, change blocks, sparkline), navigation (command palette, sidebar, slide-out panel, tab bar, step indicator, breadcrumbs), overlays (floating menus, right-click menu, tooltips, toasts, progress overlay, thin scroll indicator), sheets (`AppSheet`), avatars, inspector split and code field.
- Four built-in themes — System, High Contrast, Color Blind Safe and Low Glare — plus `BlissTheme.register(_:)` for your own, and the `AppearanceSettings` pane.
- Window chrome for `.hiddenTitleBar` windows: traffic-light offset, shell backdrop, drag exclusion, frame persistence and a borderless first-run card.
- Motion tokens with Reduce Motion fallbacks, and focus rings that show only after keyboard input.
- The library's own strings in 10 languages (de, en, es, fr, it, ja, ko, pt-BR, ru, zh-Hans).
- `BlissCatalog`, a demo app of every component built on the public API, and `scripts/screenshots.sh`, which regenerates the README images from it.

[Unreleased]: https://github.com/portseif/bliss-ui/compare/2.3.0...HEAD
[2.3.0]: https://github.com/portseif/bliss-ui/releases/tag/2.3.0
[2.2.0]: https://github.com/portseif/bliss-ui/releases/tag/2.2.0
[2.1.0]: https://github.com/portseif/bliss-ui/releases/tag/2.1.0
[2.0.0]: https://github.com/portseif/bliss-ui/releases/tag/2.0.0
[1.0.0]: https://github.com/portseif/bliss-ui/releases/tag/1.0.0
