# Changelog

All notable changes to BlissUI. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `WindowTitleBar` — the custom title bar for a hidden-title-bar window: leading and trailing controls around a centered title, room for the traffic lights (dropped in full screen), and the empty bar drags the window.
- `Sidebar(isCollapsed:)` and `SidebarToggleButton` — the sidebar collapses to its icons (titles in tooltips, counts as dots) at `Sizing.sidebarCollapsedWidth`.
- `OutlineList` — a tree with disclosure chevrons and one indent per level; one Tab stop with a roving row.
- `ReorderableList` — rows with a grip handle that drag into a new order; ⌥↑ / ⌥↓ move the focused row.
- `DropZone` — a file drop target that doubles as a Browse button, with the same rules for both.
- `CommitGraph` — a git history as a graph: colored lanes, merge rings, rounded elbows where branches leave and rejoin, and ref pills, with an optional trailing accessory per row.
- `RoundedSection(insetsHeader:)` — `false` puts the section's title flush with the card's edge instead of in line with its content.
- `BlissTable(pinsHeader:)` — the header stays at the top of the enclosing scroll view while the rows scroll under it. Rows stay eager unless `isLazy`, so a width animation doesn't rebuild them off screen.
- `AvatarStack(overflowStyle: .plain)` — `+N` as plain text after the avatars instead of a filled chip.
- `BlissTable(autoSizeColumns:)` — flexible columns size to their widest cell or header label instead of splitting the room evenly. Badges and dates hug their content; when the table is too narrow, the widest columns give way first (never below their minimum) and text truncates, so no column collapses or overflows. `BlissTableRowLayout(contentWidths:)` is the layout side of it.
- `.sidebarResizeHandle(width:in:isEnabled:)` — a grip on a sidebar's trailing edge that drags it wider or narrower, like `InspectorSplit`'s, adjustable with VoiceOver.
- `LocalizedStringKey.verbatimWithCode(_:)` — like `.verbatim(_:)`, but `backticked` spans show as inline code (monospaced on a faint tint). Nothing else is parsed, so names with `_` or `*` still show as-is.

### Changed

- Text tooltips (`.tooltip("…")`) use the same tight 10/5 padding as every preset; `TooltipConfiguration`'s init defaults now match.
- `AvatarStack`'s `+N` chip is a pill sized for `+99` at a fixed, larger font, so stacks in a column line up whatever the counts.
- `ToolbarIconButtonStyle` buttons are square (28pt, 30pt before macOS 26, 24pt compact) whatever the glyph's shape.
- `BlissTable`'s header sits on a darker rounded band, as wide as the rows' hover fill, in place of the hairline under it, so it reads as its own strip.
- `CompactTextFieldStyle`, `SearchTextFieldStyle` and `ToolbarSearchTextFieldStyle` fill with the active color theme's raised surface and border instead of fixed greys (and `LargePaddedTextFieldStyle`'s underline takes the theme's border); System keeps the greys.
- `TerminalOutputView` takes the theme's colors instead of a fixed dark terminal — the read-only `CodeField` surface and hairline, primary text, accent system lines, the danger mark for stderr — so it reads right in light mode and under every color theme.

- `BlissTable`'s header band in light mode is the window's shell surface with a hairline (rows' hover and selection fills darken, so a darker band looked like a selected row); its labels are secondary instead of tertiary, readable on the band.
- `RowTint.hover` and `.selected` are a faint wash of the theme's accent when a color theme is active, so list, table, sidebar and menu highlights take the theme's color; System keeps the neutral grays.
- `Banner` puts its action under the message when it's narrower than 360pt, instead of squeezing the text into a column beside it.
- `TerminalOutputView(isDocked:contentInset:)` — docked, it's a flush panel with a hairline on top for a console along the bottom of a pane; `contentInset` lines its text up with the content above.

### Fixed

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

[Unreleased]: https://github.com/portseif/bliss-ui/compare/1.0.0...HEAD
[1.0.0]: https://github.com/portseif/bliss-ui/releases/tag/1.0.0
