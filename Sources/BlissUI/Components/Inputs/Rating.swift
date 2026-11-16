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

/// A row of symbols that rate something from 0 to `maximum`.
///
/// ```swift
/// Rating("Quality", value: $stars)
/// Rating("Priority", value: $priority, maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
/// ```
///
/// A `.constant` binding makes it read-only; `.disabled` dims it and ignores
/// input.
public struct Rating: View {
    private let title: LocalizedStringKey
    @Binding private var value: Int
    private let maximum: Int
    private let systemImage: String
    private let color: Color?
    private let allowsClear: Bool

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
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Int>,
        maximum: Int = 5,
        systemImage: String = "star",
        color: Color? = nil,
        allowsClear: Bool = true
    ) {
        self.title = title
        self._value = value
        self.maximum = max(maximum, 1)
        self.systemImage = systemImage
        self.color = color
        self.allowsClear = allowsClear
    }

    private var fillColor: Color { color ?? Warning.warning500 }

    /// The fill shown: the hovered symbol's run while the pointer is over
    /// one, else the value.
    private var shownValue: Int { hoveredIndex ?? value }

    public var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(1...maximum, id: \.self) { index in
                symbol(at: index)
            }
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, Spacing.hairline)
        .contentShape(Capsule())
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .focusRingCapsule(isFocused: isFocused)
        .onHover { hovering in
            if !hovering { hoveredIndex = nil }
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .downArrow, .home, .end], phases: [.down, .repeat]) { press in
            guard isEnabled else { return .ignored }
            return adjust(for: press.key) ? .handled : .ignored
        }
        .animation(Animations.hover, value: hoveredIndex)
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value) of \(maximum)", bundle: .module))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(min(value + 1, maximum))
            case .decrement: set(max(value - 1, 0))
            @unknown default: break
            }
        }
    }

    private func symbol(at index: Int) -> some View {
        let isFilled = index <= shownValue
        return Image(systemName: isFilled ? "\(systemImage).fill" : systemImage)
            .font(Typography.labelMedium)
            .foregroundStyle(isFilled ? fillColor : Color.primary.opacity(0.25))
            .frame(width: Sizing.iconDefault + Spacing.xxs, height: Sizing.iconDefault + Spacing.xxs)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { hoveredIndex = index }
            }
            .onTapGesture { pick(index) }
    }

    // MARK: Changes

    /// A click on the current value clears it (when allowed); any other sets it.
    private func pick(_ index: Int) {
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

// MARK: - Preview

#Preview("Rating", traits: .fixedLayout(width: 360, height: 140)) {
    @Previewable @State var stars = 3
    @Previewable @State var priority = 2
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Rating("Quality", value: $stars)
        Rating("Priority", value: $priority, maximum: 3, systemImage: "flame", color: Danger.danger500, allowsClear: false)
        Rating("Average", value: .constant(4))
    }
    .padding(Spacing.xl)
}
