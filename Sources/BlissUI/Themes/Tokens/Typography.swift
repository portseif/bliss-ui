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
/// ## Naming Convention
/// - `display*` - Large hero/section headers (34-22px, bold/semibold)
/// - `heading*` - Section headings (20-15px, semibold)
/// - `body*` - Regular content text (16-13px, regular weight)
/// - `label*` - UI labels, buttons, form labels (15-7px, regular weight)
/// - `caption*` - Descriptions, metadata (12-10px, regular weight)
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
        .system(size: 48, weight: .light, design: .default)
    }

    /// Extra large display (40px light)
    public static var displayXLarge: Font {
        .system(size: 40, weight: .light, design: .default)
    }

    /// Large display title for hero sections (34px semibold)
    public static var displayLarge: Font {
        .system(size: FontSize.largeTitle, weight: .regular, design: .default)
    }

    /// Large display medium variant (32px regular)
    public static var displayLargeMedium: Font {
        .system(size: 32, weight: .regular, design: .default)
    }

    /// Medium display for section headers (28px semibold)
    public static var displayMedium: Font {
        .system(size: FontSize.title, weight: .regular, design: .default)
    }

    /// Medium display light variant (28px light)
    public static var displayMediumLight: Font {
        .system(size: FontSize.title, weight: .light, design: .default)
    }

    /// Medium display medium variant (24px regular)
    public static var displayMediumMedium: Font {
        .system(size: 24, weight: .regular, design: .default)
    }

    /// Medium display light variant (24px light)
    public static var displaySmallLight: Font {
        .system(size: 24, weight: .light, design: .default)
    }

    /// Small display for subsection headers (22px medium)
    public static var displaySmall: Font {
        .system(size: FontSize.title2, weight: .regular, design: .default)
    }

    // MARK: - Heading Styles

    /// Primary heading (20px medium)
    public static var headingLarge: Font {
        .system(size: FontSize.title3, weight: .regular, design: .default)
    }

    /// Primary heading light variant (20px light) — large numeric readouts
    /// beside colored badges (e.g. the health panel score).
    public static var headingLargeLight: Font {
        .system(size: FontSize.title3, weight: .light, design: .default)
    }

    /// Primary heading medium weight (20px regular)
    public static var headingLargeMedium: Font {
        .system(size: FontSize.title3, weight: .regular, design: .default)
    }

    /// Secondary heading (17px medium)
    public static var headingMedium: Font {
        .system(size: FontSize.headline, weight: .regular, design: .default)
    }

    /// Heading 18px regular
    public static var heading18Medium: Font {
        .system(size: 18, weight: .regular, design: .default)
    }

    /// Tertiary heading (15px medium)
    public static var headingSmall: Font {
        .system(size: FontSize.callout, weight: .regular, design: .default)
    }

    // MARK: - Body Styles (Regular weight for reading)

    /// Large body text (16px regular)
    public static var bodyLarge: Font {
        .system(size: FontSize.body, weight: .regular, design: .default)
    }

    /// Default body text (14px regular)
    public static var bodyMedium: Font {
        .system(size: FontSize.subheadline, weight: .regular, design: .default)
    }

    /// Small body text (13px regular)
    public static var bodySmall: Font {
        .system(size: FontSize.footnote, weight: .regular, design: .default)
    }

    // MARK: - Label Styles (Regular weight for UI elements)

    /// Extra large label - prominent buttons (15px regular)
    public static var labelXLarge: Font {
        .system(size: FontSize.callout, weight: .regular, design: .default)
    }

    /// Large label - buttons, form labels (14px regular)
    public static var labelLarge: Font {
        .system(size: FontSize.subheadline, weight: .regular, design: .default)
    }

    /// Medium label - default UI text (13px regular)
    public static var labelMedium: Font {
        .system(size: FontSize.footnote, weight: .regular, design: .default)
    }

    /// Small label - tags, badges, secondary UI (12px regular)
    public static var labelSmall: Font {
        .system(size: FontSize.caption, weight: .regular, design: .default)
    }

    /// Extra small label - tiny badges, indicators (11px regular)
    public static var labelXSmall: Font {
        .system(size: FontSize.caption2, weight: .regular, design: .default)
    }

    /// Tiny label - minimal UI elements (10px regular)
    public static var labelTiny: Font {
        .system(size: FontSize.tiny, weight: .regular, design: .default)
    }

    /// Extra tiny label - compact badges (9px regular)
    public static var labelXTiny: Font {
        .system(size: FontSize.xtiny, weight: .regular, design: .default)
    }

    /// Mini label - small indicators (8px regular)
    public static var labelMini: Font {
        .system(size: FontSize.mini, weight: .regular, design: .default)
    }

    /// Micro label - rare, very small text (7px regular)
    public static var labelMicro: Font {
        .system(size: FontSize.micro, weight: .regular, design: .default)
    }

    // MARK: - Caption Styles (Regular weight for descriptions)

    /// Caption text for descriptions (12px regular)
    public static var caption: Font {
        .system(size: FontSize.caption, weight: .regular, design: .default)
    }

    /// Small caption for metadata (11px regular)
    public static var captionSmall: Font {
        .system(size: FontSize.caption2, weight: .regular, design: .default)
    }

    /// Tiny caption for fine print (10px regular)
    public static var captionTiny: Font {
        .system(size: FontSize.tiny, weight: .regular, design: .default)
    }

    // MARK: - Monospace Styles

    /// Large monospace for code blocks (14px)
    public static var codeLarge: Font {
        .system(size: FontSize.subheadline, weight: .regular, design: .monospaced)
    }

    /// Large monospace medium (14px regular)
    public static var codeLargeMedium: Font {
        .system(size: FontSize.subheadline, weight: .regular, design: .monospaced)
    }

    /// Monospace for code snippets (13px)
    public static var code: Font {
        .system(size: FontSize.footnote, weight: .regular, design: .monospaced)
    }

    /// Small monospace for inline code (12px)
    public static var codeSmall: Font {
        .system(size: FontSize.caption, weight: .regular, design: .monospaced)
    }

    /// Small monospace medium (12px regular)
    public static var codeSmallMedium: Font {
        .system(size: FontSize.caption, weight: .regular, design: .monospaced)
    }

    /// Tiny monospace for keyboard shortcuts (11px regular)
    public static var codeTiny: Font {
        .system(size: FontSize.caption2, weight: .regular, design: .monospaced)
    }

    /// Extra tiny monospace (10px regular)
    public static var codeXTiny: Font {
        .system(size: FontSize.tiny, weight: .regular, design: .monospaced)
    }

    // MARK: - Medium Variants (for emphasis)

    /// Large body with emphasis (16px medium)
    public static var bodyLargeSemibold: Font {
        .system(size: FontSize.body, weight: .medium, design: .default)
    }

    /// Body text with emphasis (14px medium)
    public static var bodyMediumSemibold: Font {
        .system(size: FontSize.subheadline, weight: .medium, design: .default)
    }

    /// Small body text with emphasis (13px medium)
    public static var bodySmallSemibold: Font {
        .system(size: FontSize.footnote, weight: .medium, design: .default)
    }

    /// Caption with emphasis (12px medium)
    public static var captionSemibold: Font {
        .system(size: FontSize.caption, weight: .medium, design: .default)
    }

    /// Small caption with emphasis (11px medium)
    public static var captionSmallSemibold: Font {
        .system(size: FontSize.caption2, weight: .medium, design: .default)
    }

    /// Tiny with emphasis (10px medium)
    public static var labelTinySemibold: Font {
        .system(size: FontSize.tiny, weight: .medium, design: .default)
    }

    /// Extra tiny with emphasis (9px medium)
    public static var labelXTinySemibold: Font {
        .system(size: FontSize.xtiny, weight: .medium, design: .default)
    }

    /// Mini with emphasis (8px medium)
    public static var labelMiniSemibold: Font {
        .system(size: FontSize.mini, weight: .medium, design: .default)
    }

    // MARK: - Semibold Variants (for strong emphasis)

    /// Extra tiny semibold (9px semibold)
    public static var labelXTinyBold: Font {
        .system(size: FontSize.xtiny, weight: .semibold, design: .default)
    }

    /// Tiny semibold (10px semibold)
    public static var labelTinyBold: Font {
        .system(size: FontSize.tiny, weight: .semibold, design: .default)
    }

    /// Label semibold (13px semibold) — a strong row title
    public static var labelMediumBold: Font {
        .system(size: FontSize.footnote, weight: .semibold, design: .default)
    }

    /// Small label semibold (12px semibold)
    public static var labelSmallBold: Font {
        .system(size: FontSize.caption, weight: .semibold, design: .default)
    }

    /// Small caption semibold (11px semibold) — the checkmark in a selection box
    public static var labelXSmallBold: Font {
        .system(size: FontSize.caption2, weight: .semibold, design: .default)
    }

    /// Mini semibold (8px semibold) — a ✓ / ✕ inside a small status dot
    public static var labelMiniBold: Font {
        .system(size: FontSize.mini, weight: .semibold, design: .default)
    }

    /// Micro semibold (7px semibold) — the smallest inline ✕
    public static var labelMicroBold: Font {
        .system(size: FontSize.micro, weight: .semibold, design: .default)
    }

    /// Heading semibold (20px semibold) — a status glyph in a large badge
    public static var headingLargeBold: Font {
        .system(size: FontSize.title3, weight: .semibold, design: .default)
    }

    /// Display semibold (22px semibold) — a status glyph in a large badge
    public static var displaySmallBold: Font {
        .system(size: FontSize.title2, weight: .semibold, design: .default)
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
