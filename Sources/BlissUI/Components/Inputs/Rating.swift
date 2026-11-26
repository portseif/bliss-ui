//
//  Rating.swift
//  BlissUI
//
//  Stars (or any symbol) you click or arrow through. Hovering previews the
//  fill up to the pointer, a click sets it, and clicking the current value
//  clears it. The row is one Tab stop: ←/→ step, Home/End jump, and VoiceOver
//  adjusts it like a slider.
//

import SwiftUI

/// How big a `Rating`'s symbols are.
public enum RatingSize: Sendable {
    /// 12pt symbols in 16pt cells — a table cell or a caption line.
    case small
    /// 13pt symbols in 20pt cells; the row is a field's height.
    case regular
    /// 20pt symbols in 28pt cells — a review header.
    case large

    var font: Font {
        switch self {
        case .small: Typography.labelSmall
        case .regular: Typography.labelMedium
        case .large: Typography.headingLarge
        }
    }

    var cellSize: CGFloat {
        switch self {
        case .small: Sizing.iconDefault
        case .regular: Sizing.iconDefault + Spacing.xxs
        case .large: Sizing.controlDefault
        }
    }
}

/// A row of symbols that rate something from 0 to `maximum`.
///
/// ```swift
/// Rating("Quality", value: $stars)
/// Rating("Priority", value: $priority, maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
/// Rating("Average", value: .constant(4), isReadOnly: true, valueLabel: Text("4.2"))
/// ```
///
/// `isReadOnly` shows the value without hover previews or input (an average
/// rating); `.disabled` dims it and ignores input.
public struct Rating: View {
    private let title: LocalizedStringKey
    @Binding private var value: Int
    private let maximum: Int
    private let systemImage: String
    private let color: Color?
    private let allowsClear: Bool
    private let size: RatingSize
    private let isReadOnly: Bool
    private let valueLabel: Text?

    @State private var hoveredIndex: Int?
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    /// - Parameters:
    ///   - title: What VoiceOver reads for the control.
    ///   - value: How many symbols are filled, 0 to `maximum`.
    ///   - maximum: How many symbols there are.
    ///   - systemImage: The outline symbol; its `.fill` variant draws a filled one.
    ///   - color: The filled symbols' color; the warning mark by default.
    ///   - allowsClear: Clicking the current value (or ↓) clears it to 0.
    ///   - size: The symbols' size; `.regular` sits level with a field.
    ///   - isReadOnly: Shows the value and nothing else: no hover preview, no
    ///     clicks or keys, not a Tab stop, and not dimmed.
    ///   - valueLabel: A readout after the symbols ("4.2"), in the secondary tone.
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        maximum: Int = 5,
        systemImage: String = "star",
        color: Color? = nil,
        allowsClear: Bool = true,
        size: RatingSize = .regular,
        isReadOnly: Bool = false,
        valueLabel: Text? = nil
    ) {
        self.title = title
        self._value = value
        self.maximum = max(maximum, 1)
        self.systemImage = systemImage
        self.color = color
        self.allowsClear = allowsClear
        self.size = size
        self.isReadOnly = isReadOnly
        self.valueLabel = valueLabel
    }

    private var fillColor: Color { color ?? Warning.warning500 }

    private var isInteractive: Bool { isEnabled && !isReadOnly }

    /// The fill shown: the hovered symbol's run while the pointer is over
    /// one, else the value.
    private var shownValue: Int { hoveredIndex ?? value }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xxs) {
                ForEach(1...maximum, id: \.self) { index in
                    symbol(at: index)
                }
            }
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxs)
            .contentShape(Capsule())
            .focusable(isInteractive)
            .focused($isFocused)
            .focusEffectDisabled()
            .focusRingCapsule(isFocused: isFocused)
            .onHover { hovering in
                if !hovering { hoveredIndex = nil }
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .downArrow, .home, .end], phases: [.down, .repeat]) { press in
                guard isInteractive else { return .ignored }
                return adjust(for: press.key) ? .handled : .ignored
            }
            .animation(Animations.hover, value: hoveredIndex)
            .allowsHitTesting(isInteractive)

            if let valueLabel {
                valueLabel
                    .font(Typography.labelSmall.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(isEnabled ? 1 : Animations.disabledOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value) of \(maximum)", bundle: .module))
        .accessibilityAdjustableAction { direction in
            guard isInteractive else { return }
            switch direction {
            case .increment: set(min(value + 1, maximum))
            case .decrement: set(max(value - 1, 0))
            @unknown default: break
            }
        }
    }

    private func symbol(at index: Int) -> some View {
        let isFilled = index <= shownValue
        return BlissSymbol(isFilled ? "\(systemImage).fill" : systemImage)
            .font(size.font)
            .foregroundStyle(isFilled ? fillColor : Color.primary.opacity(RatingMetrics.emptyOpacity))
            .frame(width: size.cellSize, height: size.cellSize)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering, isInteractive { hoveredIndex = index }
            }
            .onTapGesture { pick(index) }
    }

    // MARK: Changes

    /// A click on the current value clears it (when allowed); any other sets it.
    private func pick(_ index: Int) {
        guard isInteractive else { return }
        if index == value, allowsClear {
            set(0)
        } else {
            set(index)
        }
    }

    private func set(_ newValue: Int) {
        guard newValue != value else { return }
        value = newValue
    }

    /// ←/→ step, ↓ clears, Home/End jump; false for a key with nothing to do.
    private func adjust(for key: KeyEquivalent) -> Bool {
        switch key {
        case .leftArrow: set(max(value - 1, 0))
        case .rightArrow: set(min(value + 1, maximum))
        case .downArrow:
            guard allowsClear else { return false }
            set(0)
        case .home: set(0)
        case .end: set(maximum)
        default: return false
        }
        return true
    }
}

private enum RatingMetrics {
    /// An empty symbol: faint, so the filled run reads at a glance.
    static let emptyOpacity: Double = 0.25
}

// MARK: - Preview

#Preview("Rating", traits: .fixedLayout(width: 360, height: 200)) {
    @Previewable @State var stars = 3
    @Previewable @State var priority = 2
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Rating("Quality", value: $stars)
        Rating("Priority", value: $priority, maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
        Rating("Average", value: .constant(4), isReadOnly: true, valueLabel: Text(verbatim: "4.2"))
        Rating("Small", value: .constant(2), size: .small)
        Rating("Large", value: .constant(5), size: .large)
    }
    .padding(Spacing.xl)
}
