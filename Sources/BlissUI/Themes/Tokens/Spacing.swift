//
//  Spacing.swift
//  BlissUI
//
//  Spacing and sizing tokens.
//
//  Refactoring UI principles:
//  - No two values should be closer than ~25% apart
//  - Packed tighter at small end, progressively more spaced at large end
//  - Use a consistent base scale for predictability
//  - Semantic tokens map to base scale for clarity

import SwiftUI

// MARK: - Spacing Tokens

/// Spacing system following Refactoring UI principles.
/// Scale: 4, 6, 8, 12, 16, 24, 32, 48, 64, 96
/// Each step is at least 25% larger than the previous.
///
/// Usage:
/// ```swift
/// .padding(.horizontal, .md)
/// VStack(spacing: .sm) { ... }
/// HStack(spacing: .xs) { ... }
/// ```
public enum Spacing {
    // MARK: - Core Scale
    // Ratios: 4→6 (50%), 6→8 (33%), 8→12 (50%), 12→16 (33%), 16→24 (50%)
    // 24→32 (33%), 32→48 (50%), 48→64 (33%), 64→96 (50%)

    /// 0px - No spacing
    public static let none: CGFloat = 0

    /// 2px - Hairline spacing (use sparingly)
    public static let hairline: CGFloat = 2

    /// 3px - Inset spacing for toolbar buttons on Tahoe+; also a regular pill's
    /// vertical padding and a bare text button's ring outset
    public static let insetSpacing: CGFloat = 3

    /// 4px - Extra extra small
    public static let xxs: CGFloat = 4

    /// 6px - Extra small
    public static let xs: CGFloat = 6

    /// 8px - Small
    public static let sm: CGFloat = 8

    /// 12px - Medium
    public static let md: CGFloat = 12

    /// 16px - Large
    public static let lg: CGFloat = 16

    /// 24px - Extra large
    public static let xl: CGFloat = 24

    /// 32px - 2x large
    public static let xxl: CGFloat = 32

    /// 48px - 3x large
    public static let xxxl: CGFloat = 48

    /// 64px - 4x large
    public static let xxxxl: CGFloat = 64

    /// 96px - 5x large
    public static let xxxxxl: CGFloat = 96

    // MARK: - Semantic Spacing

    /// A compact button's inset (horizontal: 12px, vertical: 6px); regular
    /// buttons use `lg + 2` / `sm`. The heights come from `Sizing.controlDefault`
    /// / `controlMedium`, which the styles pin with `minHeight`.
    public static let buttonPaddingH: CGFloat = md
    public static let buttonPaddingV: CGFloat = xs

    /// 16px – Standard card padding
    public static let cardPadding: CGFloat = lg
    /// A list row's vertical padding, inside its hover fill: every list (Stacks,
    /// Ports, Tools, Agents, Activity, Backups, the project page's tabs, the
    /// notifications panel, the wizard's lists, a sheet's rows) uses it, so rows
    /// are spaced and hover the same everywhere. `rowHover` / `listRowHover`
    /// default to it.
    public static let listRowPadding: CGFloat = sm

    /// 24px – Standard section spacing
    public static let sectionSpacing: CGFloat = xl

    /// 6px – Standard inline element spacing (icons next to text)
    public static let inlineSpacing: CGFloat = xs

    /// Standard toolbar padding (horizontal: 12px, vertical: 8px)
    public static let toolbarPaddingH: CGFloat = md
    public static let toolbarPaddingV: CGFloat = sm

    /// 12px – Standard sidebar padding
    public static let sidebarPadding: CGFloat = md

    /// 16px – Standard content area padding
    public static let contentPadding: CGFloat = lg

    /// 24px – Standard modal/sheet padding
    public static let sheetPadding: CGFloat = xl

    /// A regular pill's inset (horizontal: 6px, vertical: 3px); `BadgeSize`
    /// derives the small and large pills from it
    public static let tagPaddingH: CGFloat = xs
    public static let tagPaddingV: CGFloat = insetSpacing

    /// 6px – Default menu padding
    public static let menuPadding: CGFloat = xs
    
    /// 2px – Vertical spacing between header and subheading
    public static let headingSpacing: CGFloat = hairline

    /// 10px / 5px – A menu row's inset (`FilterMenuRow`, `QuickActionMenuItem`,
    /// a picker's rows): a step tighter than a list row, with `Sizing.radiusDefault`
    /// corners and `hairline` between rows.
    public static let menuRowPaddingH: CGFloat = 10
    public static let menuRowPaddingV: CGFloat = 5

    /// 8px / 6px – A boxed single-line field's inset (`.inputBox` hosts and the
    /// `.compact` text field); the field is `Sizing.controlDefault` tall.
    public static let fieldPaddingH: CGFloat = sm
    public static let fieldPaddingV: CGFloat = xs

    /// 6px – A navigation row's vertical padding (sidebar, outline list, command
    /// palette): a 13pt title makes a `Sizing.controlDefault` row.
    public static let navRowPaddingV: CGFloat = xs

    /// 3px – How far a bare text button's focus ring sits outside its label.
    public static let ringOutset: CGFloat = insetSpacing
}

// MARK: - CGFloat Extension

extension CGFloat {
    /// 0px - No spacing
    public static let none: CGFloat = Spacing.none

    /// 2px - Hairline spacing
    public static let hairline: CGFloat = Spacing.hairline

    /// 4px - Extra extra small
    public static let xxs: CGFloat = Spacing.xxs

    /// 6px - Extra small
    public static let xs: CGFloat = Spacing.xs

    /// 8px - Small
    public static let sm: CGFloat = Spacing.sm

    /// 12px - Medium
    public static let md: CGFloat = Spacing.md

    /// 16px - Large
    public static let lg: CGFloat = Spacing.lg

    /// 24px - Extra large
    public static let xl: CGFloat = Spacing.xl

    /// 32px - 2x large
    public static let xxl: CGFloat = Spacing.xxl

    /// 48px - 3x large
    public static let xxxl: CGFloat = Spacing.xxxl

    /// 64px - 4x large
    public static let xxxxl: CGFloat = Spacing.xxxxl

    /// 96px - 5x large
    public static let xxxxxl: CGFloat = Spacing.xxxxxl
}

// MARK: - View Extensions

extension View {
    /// Applies standard content area padding
    public func contentPadding() -> some View {
        self.padding(Spacing.contentPadding)
    }
}

// MARK: - Sizing Tokens

/// Common size tokens for consistent UI element sizing
public enum Sizing {
    /// MARK: - Status Circle
    /// 6px - Statuc circle
    public static let statusCircle: CGFloat = 6
    // MARK: - Icon Sizes
    /// 12px - Tiny icon (inline with small text)
    public static let iconTiny: CGFloat = 12

    /// 14px - Small icon
    public static let iconSmall: CGFloat = 14

    /// 16px - Default icon size
    public static let iconDefault: CGFloat = 16

    /// 20px - Medium icon
    public static let iconMedium: CGFloat = 20

    /// 24px - Large icon
    public static let iconLarge: CGFloat = 24

    /// 32px - Extra large icon
    public static let iconXLarge: CGFloat = 32

    /// 48px - Huge icon (feature icons)
    public static let iconHuge: CGFloat = 48

    // MARK: - Control Heights
    /// 10px - Tiny control (dropdowns)
    public static let controlTiny: CGFloat = 10

    /// 24px - Small control height (compact buttons)
    public static let controlSmall: CGFloat = 24

    /// 28px - Default control height
    public static let controlDefault: CGFloat = 28

    /// 32px - Medium control height
    public static let controlMedium: CGFloat = 32

    /// 36px - Large control height
    public static let controlLarge: CGFloat = 36

    /// 40px - Extra large control (a one-time code cell, a large avatar)
    public static let controlXLarge: CGFloat = 40

    // MARK: - Border Radius

    /// 4px - Small radius
    public static let radiusSmall: CGFloat = 4

    /// 6px - Default radius
    public static let radiusDefault: CGFloat = 6

    /// 8px - Medium radius
    public static let radiusMedium: CGFloat = 8

    /// 10px - Large radius
    public static let radiusLarge: CGFloat = 10

    /// 16px - Extra large radius
    public static let radiusXLarge: CGFloat = 16

    /// 20px - Extra extra large radius
    public static let radiusXXLarge: CGFloat = 20

    /// Full corner radius (capsule shape)
    public static let radiusFull: CGFloat = .infinity

    /// A single-line text field's corners: a capsule on macOS 26, `radiusDefault`
    /// before it. `.inputBox` defaults to it; buttons keep `radiusMedium`.
    public static var fieldCornerRadius: CGFloat { isTahoeOrLater ? radiusFull : radiusDefault }

    /// A multi-line or composite input's corners (text area, editor, composer,
    /// token field, code box, one-time code cells) — a capsule can't wrap a box.
    public static let textBoxCornerRadius: CGFloat = radiusMedium

    // MARK: - Common Widths

    /// 200px - Minimum sidebar width
    public static let sidebarMinWidth: CGFloat = 200

    /// 280px - Default sidebar width
    public static let sidebarDefaultWidth: CGFloat = 280

    /// 320px - Maximum sidebar width
    public static let sidebarMaxWidth: CGFloat = 320

    /// 56px - A `Sidebar` collapsed to icons
    public static let sidebarCollapsedWidth: CGFloat = 56

    /// 44px - A custom title bar in a hidden-title-bar window (`WindowTitleBar`)
    public static let titleBarHeight: CGFloat = 44

    /// 300px - Default sheet width (small)
    public static let sheetWidthSmall: CGFloat = 300

    /// 400px - Default sheet width (medium)
    public static let sheetWidthMedium: CGFloat = 400

    /// 500px - Default sheet width (large)
    public static let sheetWidthLarge: CGFloat = 500

    /// 600px - Default sheet width (extra large)
    public static let sheetWidthXLarge: CGFloat = 600

    /// 480px - An `AppSheet` with no size preset
    public static let sheetWidthDefault: CGFloat = 480

    /// 180px - The narrowest a dropdown panel gets (`ComboBox`, `FloatingMenuPicker`, filter menus)
    public static let menuMinWidth: CGFloat = 180

    /// 18px - An inline icon button's chip (`HoverIconButton`, a field's clear or reveal button)
    public static let inlineIconButton: CGFloat = 18

    /// 340px - A `.slideoutPanel`
    public static let slideoutPanelWidth: CGFloat = 340

    /// 640px - The command palette card
    public static let commandPaletteWidth: CGFloat = 640

    /// 440px - A toast card
    public static let toastWidth: CGFloat = 440

    /// 100px - `DetailRow`'s label column
    public static let detailLabelWidth: CGFloat = 100

    /// 176px - `SettingsScrollView`'s table-of-contents rail
    public static let settingsRailWidth: CGFloat = 176

    /// 160px / 96px - A chart's plot floor, and the compact one
    public static let chartMinimumHeight: CGFloat = 160
    public static let chartCompactHeight: CGFloat = 96
}

// MARK: - Previews

#Preview("Spacing Scale") {
    VStack(alignment: .leading, spacing: 16) {
        Text("Spacing Scale")
            .font(.title2)
            .fontWeight(.semibold)

        Text("Each step is at least 25% larger than the previous")
            .font(.caption)
            .foregroundStyle(Grey.grey500)

        Group {
            SpacingPreviewRow(name: "hairline (2px)", value: .hairline, ratio: nil)
            SpacingPreviewRow(name: "xxs (4px)", value: .xxs, ratio: "100%")
            SpacingPreviewRow(name: "xs (6px)", value: .xs, ratio: "50%")
            SpacingPreviewRow(name: "sm (8px)", value: .sm, ratio: "33%")
            SpacingPreviewRow(name: "md (12px)", value: .md, ratio: "50%")
            SpacingPreviewRow(name: "lg (16px)", value: .lg, ratio: "33%")
            SpacingPreviewRow(name: "xl (24px)", value: .xl, ratio: "50%")
            SpacingPreviewRow(name: "xxl (32px)", value: .xxl, ratio: "33%")
            SpacingPreviewRow(name: "xxxl (48px)", value: .xxxl, ratio: "50%")
            SpacingPreviewRow(name: "xxxxl (64px)", value: .xxxxl, ratio: "33%")
        }
    }
    .padding(24)
    .frame(width: 450)
}

#Preview("Semantic Spacing") {
    VStack(alignment: .leading, spacing: 24) {
        Text("Semantic Spacing Examples")
            .font(.title2)
            .fontWeight(.semibold)

        VStack(alignment: .leading, spacing: 8) {
            Text("Button Padding")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Standard Button") {}
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, Spacing.buttonPaddingH)
                .padding(.vertical, Spacing.buttonPaddingV)
                .background(Color.gray.opacity(0.2))
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Tag Padding")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Tag")
                .font(.caption)
                .padding(.horizontal, Spacing.tagPaddingH)
                .padding(.vertical, Spacing.tagPaddingV)
                .background(.blue.opacity(0.2))
                .clipShape(Capsule())
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Card Padding")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack {
                Text("Card Content")
            }
            .padding(Spacing.cardPadding)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium))
        }
    }
    .padding(24)
    .frame(width: 400)
}

// MARK: - Preview Helpers

private struct SpacingPreviewRow: View {
    let name: String
    let value: CGFloat
    let ratio: String?

    init(name: String, value: CGFloat, ratio: String? = nil) {
        self.name = name
        self.value = value
        self.ratio = ratio
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.caption)
                .frame(width: 120, alignment: .leading)

            Rectangle()
                .fill(Primary.primary500)
                .frame(width: value, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            if let ratio = ratio {
                Text("+\(ratio)")
                    .font(.caption2)
                    .foregroundStyle(Grey.grey400)
                    .frame(width: 40, alignment: .leading)
            }

            Spacer()
        }
    }
}

// MARK: - Readable Content Width

extension Sizing {
    /// Readable cap for page content on wide windows.
    public static let readableContentMaxWidth: CGFloat = 1120
}

extension View {
    /// Caps + centers content at the readable width. Apply INSIDE
    /// scroll containers (and to the headers above them) — never to the scroll
    /// view itself — so the scroller spans the full content pane and its thin
    /// indicator sits flush with the app's edge instead of floating at the
    /// capped container's edge.
    public func readableContentWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: Sizing.readableContentMaxWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }
}
