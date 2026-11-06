//
//  Avatar.swift
//  BlissUI
//
//  A person's picture, or their initials on a color picked from their name.
//  The same name always gets the same color — on every launch and every Mac,
//  so it can't come from `hashValue`, which Swift seeds per process. Three
//  sizes, a circle or a rounded square, and an optional status dot cut into
//  the corner. `AvatarStack` overlaps several with a `+N` for the rest.
//
//  The gaps (around the status dot, between stacked avatars) are cut out of
//  the avatar's clip path rather than drawn as a ring of the surface color:
//  the content pane is translucent on macOS 26, and a ring painted in it
//  would let the avatar behind show through. A cut-out shows whatever the
//  avatar sits on, on any surface. It's a vector clip, not an alpha mask.
//

import SwiftUI

// MARK: - Options

/// How big an avatar is.
public enum AvatarSize: Hashable, Sendable, CaseIterable {
    /// 20pt — inline with a row's text, a stack in a table cell.
    case small
    /// 28pt — a list row, a comment.
    case medium
    /// 40pt — a profile header, a sheet.
    case large

    /// The avatar's width and height.
    public var diameter: CGFloat {
        switch self {
        case .small: 20
        case .medium: 28
        case .large: 40
        }
    }

    var initialsFont: Font {
        switch self {
        case .small: Typography.labelXTinySemibold
        case .medium: Typography.captionSmallSemibold
        case .large: Typography.bodyMediumSemibold
        }
    }

    /// The person glyph shown when a name has no letters to take initials from.
    var glyphFont: Font {
        switch self {
        case .small: Typography.labelXSmall
        case .medium: Typography.bodySmall
        case .large: Typography.headingMedium
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: Sizing.radiusSmall
        case .medium: Sizing.radiusDefault
        case .large: Sizing.radiusLarge
        }
    }

    var statusDiameter: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large: 10
        }
    }

    /// The gap cut around a status dot, and between stacked avatars.
    var gap: CGFloat {
        self == .small ? 1.5 : 2
    }

    /// How far each stacked avatar tucks under the one before it.
    var stackOverlap: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large: 12
        }
    }

    /// How much of a stacked avatar's leading side the one before it hides,
    /// gap included.
    var stackHiddenWidth: CGFloat { stackOverlap + gap }
}

/// An avatar's outline.
public enum AvatarShape: Hashable, Sendable {
    case circle
    /// A rounded square — for a team, a workspace or a bot rather than a person.
    case rounded
}

/// A presence dot in an avatar's corner. Each has its own shape as well as its
/// color, so they stay apart without color vision: online is solid, busy is
/// solid with a bar, away and offline are rings.
public enum AvatarStatus: Hashable, Sendable, CaseIterable {
    case online
    case away
    case busy
    case offline

    var color: Color {
        switch self {
        case .online: Success.success500
        case .away: Warning.warning500
        case .busy: Danger.danger500
        case .offline: Grey.grey500
        }
    }

    var label: Text {
        switch self {
        case .online: Text("Online", bundle: .module)
        case .away: Text("Away", bundle: .module)
        case .busy: Text("Busy", bundle: .module)
        case .offline: Text("Offline", bundle: .module)
        }
    }
}

// MARK: - Avatar

/// A person's picture, or their initials on a color derived from their name.
///
/// ```swift
/// Avatar(name: "Ada Lovelace")
/// Avatar(name: user.name, image: user.photo, size: .large, status: .online)
/// Avatar(name: "Design Team", shape: .rounded)
/// ```
///
/// VoiceOver reads the name (and the status). Beside a visible name, hide it
/// with `.accessibilityHidden(true)` so the name isn't read twice.
public struct Avatar: View {
    let name: String
    let image: Image?
    let size: AvatarSize
    let shape: AvatarShape
    let status: AvatarStatus?
    /// Set by `AvatarStack`: the distance to the avatar before this one, which
    /// overlaps this one's leading side and gets a gap cut around it.
    var leadingNeighborDistance: CGFloat?


    /// - Parameters:
    ///   - name: The person's name — the initials and the color come from it,
    ///     and VoiceOver reads it. Shown as-is, never looked up as a string key.
    ///   - image: Their picture, filling the shape; nil shows the initials.
    ///   - size: Small (20pt), medium (28pt) or large (40pt).
    ///   - shape: A circle, or a rounded square.
    ///   - status: A presence dot in the corner.
    public init(
        name: String,
        image: Image? = nil,
        size: AvatarSize = .medium,
        shape: AvatarShape = .circle,
        status: AvatarStatus? = nil
    ) {
        self.name = name
        self.image = image
        self.size = size
        self.shape = shape
        self.status = status
    }

    public var body: some View {
        let diameter = size.diameter
        face
            .frame(width: diameter, height: diameter)
            .clipShape(AvatarCutoutShape(shape: shape, cornerRadius: size.cornerRadius, holes: holes))
            .overlay {
                if let status {
                    AvatarStatusGlyph(status: status)
                        .fill(status.color)
                        .frame(width: size.statusDiameter, height: size.statusDiameter)
                        .position(statusCenter)
                }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: name))
            .accessibilityValue(status?.label ?? Text(verbatim: ""))
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var face: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
        } else {
            let initials = AvatarInitials.initials(for: name)
            ZStack {
                AvatarPalette.fill(for: name).color
                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .font(size.glyphFont)
                } else {
                    Text(verbatim: initials)
                        .font(size.initialsFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .offset(x: visibleCenterShift)
                }
            }
            .foregroundStyle(AvatarPalette.foreground.color)
        }
    }

    /// In a stack, the initials center in the part the avatar before this one
    /// leaves showing, so its letters aren't cut.
    private var visibleCenterShift: CGFloat {
        guard leadingNeighborDistance != nil else { return 0 }
        return size.stackHiddenWidth / 2
    }

    // MARK: Cut-outs
    //
    // Written left to right: in a right-to-left layout SwiftUI mirrors the
    // view's own coordinates — the clip path, `.position` and `.offset` with
    // it — so the dot and the cuts land on the trailing side by themselves
    // (checked with `.environment(\.layoutDirection, .rightToLeft)`).

    /// The status dot's center: on the circle's edge at 45° toward the bottom
    /// trailing corner, or tucked into a rounded square's corner.
    private var statusCenter: CGPoint {
        let diameter = size.diameter
        let radius = diameter / 2
        let inset: CGFloat = shape == .circle
            ? radius - radius * 0.7071
            : size.statusDiameter / 2 - size.gap
        return CGPoint(x: diameter - inset, y: diameter - inset)
    }

    private var holes: [AvatarCutoutShape.Hole] {
        var holes: [AvatarCutoutShape.Hole] = []
        let diameter = size.diameter
        if status != nil {
            let center = statusCenter
            let radius = size.statusDiameter / 2 + size.gap
            holes.append(AvatarCutoutShape.Hole(
                rect: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
                cornerRadius: nil
            ))
        }
        if let distance = leadingNeighborDistance {
            let neighbor = CGRect(x: -distance, y: 0, width: diameter, height: diameter)
                .insetBy(dx: -size.gap, dy: -size.gap)
            holes.append(AvatarCutoutShape.Hole(
                rect: neighbor,
                cornerRadius: shape == .circle ? nil : size.cornerRadius + size.gap
            ))
        }
        return holes
    }
}

// MARK: - Shapes

/// An avatar's outline with holes cut out of it (the status dot's gap, the
/// stacked neighbor's gap).
struct AvatarCutoutShape: Shape {
    struct Hole: Equatable {
        var rect: CGRect
        /// nil for a circle.
        var cornerRadius: CGFloat?
    }

    var shape: AvatarShape
    var cornerRadius: CGFloat
    var holes: [Hole]

    func path(in rect: CGRect) -> Path {
        var path = outline(in: rect, cornerRadius: shape == .circle ? nil : cornerRadius)
        for hole in holes {
            path = path.subtracting(outline(in: hole.rect, cornerRadius: hole.cornerRadius))
        }
        return path
    }

    private func outline(in rect: CGRect, cornerRadius: CGFloat?) -> Path {
        if let cornerRadius {
            return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        }
        return Path(ellipseIn: rect)
    }
}

/// The status dot: solid, solid with a bar (busy), or a ring (away, offline).
/// The bar and the ring's middle are holes, so the surface shows through them.
struct AvatarStatusGlyph: Shape {
    let status: AvatarStatus

    func path(in rect: CGRect) -> Path {
        let dot = Path(ellipseIn: rect)
        switch status {
        case .online:
            return dot
        case .busy:
            let barHeight = max(1.5, rect.height * 0.24)
            let bar = CGRect(
                x: rect.minX + rect.width * 0.24,
                y: rect.midY - barHeight / 2,
                width: rect.width * 0.52,
                height: barHeight
            )
            return dot.subtracting(Path(roundedRect: bar, cornerRadius: barHeight / 2))
        case .away, .offline:
            let ring = max(1.5, rect.width * 0.26)
            return dot.subtracting(Path(ellipseIn: rect.insetBy(dx: ring, dy: ring)))
        }
    }
}

// MARK: - Initials

enum AvatarInitials {
    /// Up to two initials: the first letter of the first and last words
    /// ("Ada Lovelace" → "AL", "Mary Jane Watson" → "MW"), one for a single word
    /// or an email ("grace@example.com" → "G"). Names written in ideographs,
    /// kana or Hangul take one character — two of them crowd a small circle,
    /// and the family name comes first. Words without a letter or digit (an
    /// emoji, a dash) are skipped; empty when nothing is left.
    nonisolated static func initials(for name: String) -> String {
        let words = name
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { word in word.first(where: { $0.isLetter || $0.isNumber }) }
        guard let first = words.first else { return "" }
        if isWide(first) || words.count == 1 {
            return String(first).uppercased()
        }
        let last = words[words.count - 1]
        if isWide(last) { return String(first).uppercased() }
        return (String(first) + String(last)).uppercased()
    }

    /// CJK ideographs, Japanese kana and Hangul: one fills an avatar.
    nonisolated static func isWide(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isIdeographic
                || (0x3040...0x30FF).contains(scalar.value)  // Hiragana, Katakana
                || (0x1100...0x11FF).contains(scalar.value)  // Hangul Jamo
                || (0xAC00...0xD7A3).contains(scalar.value)  // Hangul syllables
        }
    }
}

// MARK: - Colors

enum AvatarPalette {
    /// Ten hues around the wheel, at a moderate saturation so no one avatar
    /// shouts, spaced so neighbors stay apart once darkened. Each is darkened
    /// (keeping its hue) until the initials on it reach the theme's text
    /// contrast — which is why yellows and yellow-greens are left out:
    /// darkened that far they turn olive and brown.
    nonisolated static let hues: [Double] = [0, 22, 145, 175, 200, 225, 255, 285, 315, 340]

    /// A stable index into `hues`: FNV-1a over the name's UTF-8, trimmed and
    /// lowercased so "ada " and "Ada" match.
    nonisolated static func hueIndex(for name: String) -> Int {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var hash: UInt32 = 2_166_136_261
        for byte in normalized.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash % UInt32(hues.count))
    }

    /// The initials' color: the theme's light content surface (cream under Low
    /// Glare, so the initials don't glare), else white.
    static var foreground: ThemeRGB {
        BlissTheme.active.lightPalette?.contentBackground ?? ThemeRGB(0xFFFFFF)
    }

    /// The fill for `name`: its hue, deep enough for `foreground` to reach the
    /// theme's status contrast on it (4.5:1, or 7:1 under High Contrast). A
    /// name with no initials gets a neutral grey.
    static func fill(for name: String) -> ThemeRGB {
        let base: ThemeRGB
        if AvatarInitials.initials(for: name).isEmpty {
            base = ThemeRGB(red: 0.55, green: 0.56, blue: 0.58)
        } else {
            base = StatusToneMath.rgb(hue: hues[hueIndex(for: name)] / 360, saturation: 0.55, brightness: 0.8)
        }
        return StatusToneMath.legible(base, on: [foreground], ratio: BlissTheme.active.minimumStatusContrast)
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 420, height: 200)) {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
            Avatar(name: "Ada Lovelace", size: .small)
            Avatar(name: "Grace Hopper", status: .online)
            Avatar(name: "Alan Turing", size: .large, status: .busy)
            Avatar(name: "Katherine Johnson", size: .large, status: .away)
            Avatar(name: "山田太郎", size: .large, status: .offline)
            Avatar(name: "Design Team", size: .large, shape: .rounded, status: .online)
        }
        HStack(spacing: Spacing.md) {
            Avatar(name: "Анна Каренина")
            Avatar(name: "김민준")
            Avatar(name: "محمد علي")
            Avatar(name: "Élodie Durand")
            Avatar(name: "🦊")
        }
    }
    .padding(Spacing.xl)
}
