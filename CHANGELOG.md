# Changelog

All notable changes to BlissUI. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
