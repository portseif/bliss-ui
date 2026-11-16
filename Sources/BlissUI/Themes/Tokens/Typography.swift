//
//  TypographySystem.swift
//  BlissUI
//
//  Typography system for consistent text styling with Dynamic Type support.
//  Respects user's system font size preferences for accessibility.
//
//  Refactoring UI principles:
//  - Don't rely solely on font size for hierarchy
//  - Use font WEIGHT and COLOR to communicate importance
//  - 2-3 colors: dark (primary), grey (secondary), lighter grey (tertiary)
//  - 2 font weights: normal (400-500), heavier (600-700)
//  - Avoid font weights under 400 for UI work

import SwiftUI

// MARK: - Font Size Tokens

/// Base font size tokens for consistent typography.
/// These sizes are relative and scale with Dynamic Type when using the semantic styles.
public enum FontSize {
    // MARK: - Core Scale

    /// 7px - Micro text (rare, badges)
    public static let micro: CGFloat = 7

    /// 8px - Mini text (small indicators)
    public static let mini: CGFloat = 8

    /// 9px - Extra tiny text (compact badges)
    public static let xtiny: CGFloat = 9

    /// 10px - Tiny text (legal, footnotes)
    public static let tiny: CGFloat = 10

    /// 11px - Caption text
    public static let caption2: CGFloat = 11

    /// 12px - Small caption text
    public static let caption: CGFloat = 12

    /// 13px - Footnote text
    public static let footnote: CGFloat = 13

    /// 14px - Subheadline text
    public static let subheadline: CGFloat = 14

    /// 15px - Callout text
    public static let callout: CGFloat = 15

    /// 16px - Body text (default)
    public static let body: CGFloat = 16

    /// 17px - Headline text
    public static let headline: CGFloat = 17

    /// 20px - Title 3
    public static let title3: CGFloat = 20

    /// 22px - Title 2
    public static let title2: CGFloat = 22

    /// 28px - Title 1
    public static let title: CGFloat = 28

    /// 34px - Large title
    public static let largeTitle: CGFloat = 34
}

// MARK: - Typography Styles

/// Semantic typography styles for consistent text styling.
///
/// Every style is drawn in the user's fonts (`BlissAppearance.font(_:for:)`)
/// and scaled from their base sizes (`BlissAppearance.uiFontSize` and
/// `.codeFontSize`); the sizes below are at the defaults, 13 and 12.
///
/// ## Naming Convention
/// - `display*` - Large hero/section headers (34-22px, bold/semibold)
/// - `heading*` - Section headings (20-15px, semibold)
/// - `body*` - Regular content text (16-13px, regular weight)
/// - `label*` - UI labels, buttons, form labels (15-7px, regular weight)
/// - `caption*` - Descriptions, metadata (12-10px, regular weight)
/// - `content*` - Text the app shows rather than labels it, in the content font (14-11px)
/// - `code*` - Monospace for code (14-12px)
///
/// ## Usage
/// ```swift
/// Text("Title").font(Typography.headingMedium)
/// Text("Button").font(Typography.labelLarge)
/// Text("Description").font(Typography.caption)
/// ```
public enum Typography {

    // MARK: - Display Styles (Large Headers)

    /// Hero display (48px light) - for large decorative numbers/text
    public static var displayHero: Font {
        FontResolver.font(.ui, size: 48, weight: .light)
    }

    /// Extra large display (40px light)
    public static var displayXLarge: Font {
        FontResolver.font(.ui, size: 40, weight: .light)
    }

    /// Large display title for hero sections (34px semibold)
    public static var displayLarge: Font {
        FontResolver.font(.ui, size: FontSize.largeTitle, weight: .regular)
    }

    /// Large display medium variant (32px regular)
    public static var displayLargeMedium: Font {
        FontResolver.font(.ui, size: 32, weight: .regular)
    }

    /// Large display light variant (32px light) — a hero glyph (`EmptyState`)
    public static var displayLargeLight: Font {
        FontResolver.font(.ui, size: 32, weight: .light)
    }

    /// Medium display for section headers (28px semibold)
    public static var displayMedium: Font {
        FontResolver.font(.ui, size: FontSize.title, weight: .regular)
    }

    /// Medium display light variant (28px light)
    public static var displayMediumLight: Font {
        FontResolver.font(.ui, size: FontSize.title, weight: .light)
    }

    /// Medium display medium variant (24px regular)
    public static var displayMediumMedium: Font {
        FontResolver.font(.ui, size: 24, weight: .regular)
    }

    /// Medium display light variant (24px light)
    public static var displaySmallLight: Font {
        FontResolver.font(.ui, size: 24, weight: .light)
    }

    /// Small display for subsection headers (22px medium)
    public static var displaySmall: Font {
        FontResolver.font(.ui, size: FontSize.title2, weight: .regular)
    }

    // MARK: - Heading Styles

    /// Primary heading (20px medium)
    public static var headingLarge: Font {
        FontResolver.font(.ui, size: FontSize.title3, weight: .regular)
    }

    /// Primary heading light variant (20px light) — large numeric readouts
    /// beside colored badges (e.g. the health panel score).
    public static var headingLargeLight: Font {
        FontResolver.font(.ui, size: FontSize.title3, weight: .light)
    }

    /// Primary heading medium weight (20px regular)
    public static var headingLargeMedium: Font {
        FontResolver.font(.ui, size: FontSize.title3, weight: .regular)
    }

    /// Secondary heading (17px medium)
    public static var headingMedium: Font {
        FontResolver.font(.ui, size: FontSize.headline, weight: .regular)
    }

    /// Heading 18px regular
    public static var heading18Medium: Font {
        FontResolver.font(.ui, size: 18, weight: .regular)
    }

    /// Tertiary heading (15px medium)
    public static var headingSmall: Font {
        FontResolver.font(.ui, size: FontSize.callout, weight: .regular)
    }

    // MARK: - Body Styles (Regular weight for reading)

    /// Large body text (16px regular)
    public static var bodyLarge: Font {
        FontResolver.font(.ui, size: FontSize.body, weight: .regular)
    }

    /// Default body text (14px regular)
    public static var bodyMedium: Font {
        FontResolver.font(.ui, size: FontSize.subheadline, weight: .regular)
    }

    /// Small body text (13px regular)
    public static var bodySmall: Font {
        FontResolver.font(.ui, size: FontSize.footnote, weight: .regular)
    }

    // MARK: - Label Styles (Regular weight for UI elements)

    /// Extra large label - prominent buttons (15px regular)
    public static var labelXLarge: Font {
        FontResolver.font(.ui, size: FontSize.callout, weight: .regular)
    }

    /// Large label - buttons, form labels (14px regular)
    public static var labelLarge: Font {
        FontResolver.font(.ui, size: FontSize.subheadline, weight: .regular)
    }

    /// Medium label - default UI text (13px regular)
    public static var labelMedium: Font {
        FontResolver.font(.ui, size: FontSize.footnote, weight: .regular)
    }

    /// Small label - tags, badges, secondary UI (12px regular)
    public static var labelSmall: Font {
        FontResolver.font(.ui, size: FontSize.caption, weight: .regular)
    }

    /// Extra small label - tiny badges, indicators (11px regular)
    public static var labelXSmall: Font {
        FontResolver.font(.ui, size: FontSize.caption2, weight: .regular)
    }

    /// Tiny label - minimal UI elements (10px regular)
    public static var labelTiny: Font {
        FontResolver.font(.ui, size: FontSize.tiny, weight: .regular)
    }

    /// Extra tiny label - compact badges (9px regular)
    public static var labelXTiny: Font {
        FontResolver.font(.ui, size: FontSize.xtiny, weight: .regular)
    }

    /// Mini label - small indicators (8px regular)
    public static var labelMini: Font {
        FontResolver.font(.ui, size: FontSize.mini, weight: .regular)
    }

    /// Micro label - rare, very small text (7px regular)
    public static var labelMicro: Font {
        FontResolver.font(.ui, size: FontSize.micro, weight: .regular)
    }

    // MARK: - Caption Styles (Regular weight for descriptions)

    /// Caption text for descriptions (12px regular)
    public static var caption: Font {
        FontResolver.font(.ui, size: FontSize.caption, weight: .regular)
    }

    /// Small caption for metadata (11px regular)
    public static var captionSmall: Font {
        FontResolver.font(.ui, size: FontSize.caption2, weight: .regular)
    }

    /// Tiny caption for fine print (10px regular)
    public static var captionTiny: Font {
        FontResolver.font(.ui, size: FontSize.tiny, weight: .regular)
    }

    // MARK: - Content Styles (text the app shows, in the content font)

    /// Content text for reading (14px regular), in the content font.
    public static var contentMedium: Font {
        FontResolver.font(.content, size: FontSize.subheadline, weight: .regular)
    }

    /// Smaller content text (13px regular), in the content font.
    public static var contentSmall: Font {
        FontResolver.font(.content, size: FontSize.footnote, weight: .regular)
    }

    /// Content in a caption or a one-line summary (11px regular), in the
    /// content font.
    public static var contentCaption: Font {
        FontResolver.font(.content, size: FontSize.caption2, weight: .regular)
    }

    // MARK: - Monospace Styles

    /// Large monospace for code blocks (14px)
    public static var codeLarge: Font {
        FontResolver.font(.code, size: FontSize.subheadline, weight: .regular)
    }

    /// Large monospace medium (14px regular)
    public static var codeLargeMedium: Font {
        FontResolver.font(.code, size: FontSize.subheadline, weight: .regular)
    }

    /// Monospace for code snippets (13px)
    public static var code: Font {
        FontResolver.font(.code, size: FontSize.footnote, weight: .regular)
    }

    /// Small monospace for inline code (12px)
    public static var codeSmall: Font {
        FontResolver.font(.code, size: FontSize.caption, weight: .regular)
    }

    /// Small monospace medium (12px regular)
    public static var codeSmallMedium: Font {
        FontResolver.font(.code, size: FontSize.caption, weight: .regular)
    }

    /// Tiny monospace for keyboard shortcuts (11px regular)
    public static var codeTiny: Font {
        FontResolver.font(.code, size: FontSize.caption2, weight: .regular)
    }

    /// Extra tiny monospace (10px regular)
    public static var codeXTiny: Font {
        FontResolver.font(.code, size: FontSize.tiny, weight: .regular)
    }

    // MARK: - Medium Variants (for emphasis)

    /// Large body with emphasis (16px medium)
    public static var bodyLargeSemibold: Font {
        FontResolver.font(.ui, size: FontSize.body, weight: .medium)
    }

    /// Body text with emphasis (14px medium)
    public static var bodyMediumSemibold: Font {
        FontResolver.font(.ui, size: FontSize.subheadline, weight: .medium)
    }

    /// Small body text with emphasis (13px medium)
    public static var bodySmallSemibold: Font {
        FontResolver.font(.ui, size: FontSize.footnote, weight: .medium)
    }

    /// Caption with emphasis (12px medium)
    public static var captionSemibold: Font {
        FontResolver.font(.ui, size: FontSize.caption, weight: .medium)
    }

    /// Small caption with emphasis (11px medium)
    public static var captionSmallSemibold: Font {
        FontResolver.font(.ui, size: FontSize.caption2, weight: .medium)
    }

    /// Tiny with emphasis (10px medium)
    public static var labelTinySemibold: Font {
        FontResolver.font(.ui, size: FontSize.tiny, weight: .medium)
    }

    /// Extra tiny with emphasis (9px medium)
    public static var labelXTinySemibold: Font {
        FontResolver.font(.ui, size: FontSize.xtiny, weight: .medium)
    }

    /// Mini with emphasis (8px medium)
    public static var labelMiniSemibold: Font {
        FontResolver.font(.ui, size: FontSize.mini, weight: .medium)
    }

    // MARK: - Semibold Variants (for strong emphasis)

    /// Extra tiny semibold (9px semibold)
    public static var labelXTinyBold: Font {
        FontResolver.font(.ui, size: FontSize.xtiny, weight: .semibold)
    }

    /// Tiny semibold (10px semibold)
    public static var labelTinyBold: Font {
        FontResolver.font(.ui, size: FontSize.tiny, weight: .semibold)
    }

    /// Label semibold (13px semibold) — a strong row title
    public static var labelMediumBold: Font {
        FontResolver.font(.ui, size: FontSize.footnote, weight: .semibold)
    }

    /// Small label semibold (12px semibold)
    public static var labelSmallBold: Font {
        FontResolver.font(.ui, size: FontSize.caption, weight: .semibold)
    }

    /// Small caption semibold (11px semibold) — the checkmark in a selection box
    public static var labelXSmallBold: Font {
        FontResolver.font(.ui, size: FontSize.caption2, weight: .semibold)
    }

    /// Caption bold (12px semibold) — a large gradient badge's label
    public static var captionBold: Font {
        FontResolver.font(.ui, size: FontSize.caption, weight: .semibold)
    }

    /// Small caption bold (11px semibold) — a regular gradient badge's label
    public static var captionSmallBold: Font {
        FontResolver.font(.ui, size: FontSize.caption2, weight: .semibold)
    }

    /// Mini semibold (8px semibold) — a ✓ / ✕ inside a small status dot
    public static var labelMiniBold: Font {
        FontResolver.font(.ui, size: FontSize.mini, weight: .semibold)
    }

    /// Micro semibold (7px semibold) — the smallest inline ✕
    public static var labelMicroBold: Font {
        FontResolver.font(.ui, size: FontSize.micro, weight: .semibold)
    }

    /// Heading semibold (20px semibold) — a status glyph in a large badge
    public static var headingLargeBold: Font {
        FontResolver.font(.ui, size: FontSize.title3, weight: .semibold)
    }

    /// Display semibold (22px semibold) — a status glyph in a large badge
    public static var displaySmallBold: Font {
        FontResolver.font(.ui, size: FontSize.title2, weight: .semibold)
    }
}

// MARK: - Previews

#Preview("Typography Scale") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Text("Typography System")
                .font(Typography.displayLarge)

            Divider()

            Group {
                Text("Display Styles")
                    .font(Typography.headingSmall)
                    .foregroundStyle(.secondary)

                Text("Display Large (34px)")
                    .font(Typography.displayLarge)
                Text("Display Medium (28px)")
                    .font(Typography.displayMedium)
                Text("Display Small (22px)")
                    .font(Typography.displaySmall)
            }

            Divider()

            Group {
                Text("Heading Styles")
                    .font(Typography.headingSmall)
                    .foregroundStyle(.secondary)

                Text("Heading Large (20px)")
                    .font(Typography.headingLarge)
                Text("Heading Medium (17px)")
                    .font(Typography.headingMedium)
                Text("Heading Small (15px)")
                    .font(Typography.headingSmall)
            }

            Divider()

            Group {
                Text("Body Styles")
                    .font(Typography.headingSmall)
                    .foregroundStyle(.secondary)

                Text("Body Large (16px) - For primary content and important text.")
                    .font(Typography.bodyLarge)
                Text("Body Medium (14px) - Default body text for most content.")
                    .font(Typography.bodyMedium)
                Text("Body Small (13px) - For secondary content and descriptions.")
                    .font(Typography.bodySmall)
            }

            Divider()

            Group {
                Text("Label & Caption Styles")
                    .font(Typography.headingSmall)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Text("Label Large")
                        .font(Typography.labelLarge)
                    Text("Label Medium")
                        .font(Typography.labelMedium)
                    Text("Label Small")
                        .font(Typography.labelSmall)
                }

                Text("Caption - For metadata and descriptions")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Text("Caption Small - For timestamps and fine print")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Group {
                Text("Code Styles")
                    .font(Typography.headingSmall)
                    .foregroundStyle(.secondary)

                Text("let message = \"Code Large\"")
                    .font(Typography.codeLarge)
                Text("let message = \"Code Medium\"")
                    .font(Typography.code)
                Text("let message = \"Code Small\"")
                    .font(Typography.codeSmall)
            }
        }
        .padding(24)
    }
    .frame(width: 500, height: 800)
}
