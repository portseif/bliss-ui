//
//  BlissSlider.swift
//  BlissUI
//
//  The color picker's track-and-thumb slider, tinted with the accent:
//  - A thin rounded track filled with the accent up to the thumb
//  - A white-ringed accent thumb; a soft accent halo on hover, a slight grow
//    while dragged (no grow under Reduce Motion)
//  - Optional step with tick marks, and an optional value readout
//  - ← / → (and ↑ / ↓) step it, Shift ten steps, Home / End jump to the ends
//
//  Used instead of the native `Slider`, which can't take the theme's accent on
//  macOS and shows the system focus ring.
//

import SwiftUI

/// A slider over a closed range, with an optional step, tick marks and value label.
///
/// ```swift
/// BlissSlider("Volume", value: $volume)
/// BlissSlider("Columns", value: $columns, in: 1...6, showsTicks: true) { Text($0, format: .number) }
/// ```
///
/// `title` is what VoiceOver reads; it isn't drawn. The slider fills the width
/// it's given. A Tab stop with the shared ring on its thumb.
public struct BlissSlider<Value>: View {
    private let title: LocalizedStringKey
    @Binding private var value: Value
    private let stepping: SteppedRange
    private let showsTicks: Bool
    private let valueLabel: ((Value) -> Text)?
    private let onEditingChanged: (Bool) -> Void
    private let toDouble: (Value) -> Double
    private let fromDouble: (Double) -> Value

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @State private var isDragging = false

    private init(
        title: LocalizedStringKey,
        value: Binding<Value>,
        stepping: SteppedRange,
        showsTicks: Bool,
        valueLabel: ((Value) -> Text)?,
        onEditingChanged: @escaping (Bool) -> Void,
        toDouble: @escaping (Value) -> Double,
        fromDouble: @escaping (Double) -> Value
    ) {
        self.title = title
        self._value = value
        self.stepping = stepping
        self.showsTicks = showsTicks
        self.valueLabel = valueLabel
        self.onEditingChanged = onEditingChanged
        self.toDouble = toDouble
        self.fromDouble = fromDouble
    }

    // MARK: Body

    public var body: some View {
        let current = toDouble(value)
        HStack(alignment: .top, spacing: Spacing.sm) {
            track(fraction: stepping.fraction(of: current))
            if let valueLabel {
                readout(valueLabel)
            }
        }
        // Faded as one layer, so the filled track doesn't show through the thumb.
        .compositingGroup()
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Rectangle())
        .onHover { hovering in isHovering = isEnabled && hovering }
        .focusable(isEnabled)
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .home, .end]) { press in
            handle(press)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(valueText(for: value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1, animated: false)
            case .decrement: step(by: -1, animated: false)
            @unknown default: break
            }
        }
    }

    // MARK: Track

    private func track(fraction: Double) -> some View {
        VStack(spacing: Spacing.xxs) {
            GeometryReader { geometry in
                let travel = max(geometry.size.width - SliderMetrics.thumbSize, 0)
                let thumbOffset = fraction * travel
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        // The surfaces' hairline: faint by default, the
                        // theme's own border under High Contrast and friends.
                        .overlay { Capsule().strokeBorder(Color.menuBorder, lineWidth: 1) }
                        .frame(height: SliderMetrics.trackHeight)
                    Capsule()
                        .fill(Color.accent)
                        .frame(width: thumbOffset + SliderMetrics.thumbSize / 2, height: SliderMetrics.trackHeight)
                    thumb
                        .offset(x: thumbOffset)
                }
                .frame(height: SliderMetrics.thumbSize)
                .contentShape(Rectangle())
                .gesture(dragGesture(travel: travel))
            }
            .frame(height: SliderMetrics.thumbSize)

            if showsTicks {
                let fractions = stepping.tickFractions(limit: SliderMetrics.maximumTickCount)
                if !fractions.isEmpty {
                    BlissSliderTickMarks(fractions: fractions, inset: SliderMetrics.thumbSize / 2, tickWidth: SliderMetrics.tickWidth)
                        .fill(tickColor)
                        .frame(height: SliderMetrics.tickHeight)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var thumb: some View {
        ZStack {
            // A soft accent halo while the pointer is over the slider or
            // dragging it — an opacity change, so Reduce Motion keeps it.
            Circle()
                .fill(Color.accent.opacity(isDragging ? 0.3 : 0.2))
                .padding(-SliderMetrics.haloInset)
                .opacity(isHovering || isDragging ? 1 : 0)
                .animation(Animations.hover, value: isHovering || isDragging)

            Circle()
                .fill(Color.accent)
                .overlay {
                    Circle().strokeBorder(.white, lineWidth: SliderMetrics.thumbBorderWidth)
                }
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .scaleEffect(isDragging && !prefersReducedMotion ? SliderMetrics.draggingScale : 1)
                .animation(Animations.press, value: isDragging)
                .focusRingCapsule(isFocused: isFocused, padding: -Spacing.hairline)
        }
        .frame(width: SliderMetrics.thumbSize, height: SliderMetrics.thumbSize)
    }

    /// The readout, as wide as the widest of its two ends so the track never
    /// changes length as the number does.
    private func readout(_ label: (Value) -> Text) -> some View {
        let lowerBound = fromDouble(stepping.range.lowerBound)
        let upperBound = fromDouble(stepping.range.upperBound)
        return ZStack(alignment: .trailing) {
            label(lowerBound).hidden()
            label(upperBound).hidden()
            label(value)
        }
        .font(Typography.labelSmall.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(height: SliderMetrics.thumbSize)
        .accessibilityHidden(true)
    }

    private var trackColor: Color {
        Color.primary.opacity(prefersIncreasedContrast ? 0.25 : 0.1)
    }

    private var tickColor: Color {
        Color.primary.opacity(prefersIncreasedContrast ? 0.55 : 0.3)
    }

    // MARK: Interaction

    private func dragGesture(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard isEnabled else { return }
                if !isDragging {
                    isDragging = true
                    onEditingChanged(true)
                }
                // The thumb's center follows the pointer.
                let fraction = travel > 0 ? (drag.location.x - SliderMetrics.thumbSize / 2) / travel : 0
                set(stepping.snapped(stepping.value(atFraction: fraction)))
            }
            .onEnded { _ in
                guard isDragging else { return }
                isDragging = false
                onEditingChanged(false)
            }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        switch press.key {
        case .home:
            set(stepping.normalized(stepping.range.lowerBound), animated: true)
        case .end:
            set(stepping.normalized(stepping.range.upperBound), animated: true)
        default:
            let direction = press.key == .rightArrow || press.key == .upArrow ? 1 : -1
            step(by: SteppedRange.steps(direction: direction, isLarge: press.modifiers.contains(.shift)), animated: true)
        }
        return .handled
    }

    private func step(by steps: Int, animated: Bool) {
        guard isEnabled else { return }
        set(stepping.stepped(toDouble(value), by: steps), animated: animated)
    }

    /// Keyboard steps glide the thumb; a drag tracks the pointer exactly, and
    /// under Reduce Motion nothing slides.
    private func set(_ number: Double, animated: Bool = false) {
        guard stepping.rounded(toDouble(value)) != number else { return }
        if animated, !prefersReducedMotion {
            withAnimation(Animations.selection) { value = fromDouble(number) }
        } else {
            value = fromDouble(number)
        }
    }

    // MARK: Text

    private func valueText(for value: Value) -> Text {
        if let valueLabel { return valueLabel(value) }
        return Text(verbatim: NumberFieldText.format(toDouble(value), fractionDigits: stepping.fractionDigits, locale: locale))
    }
}

// MARK: - Metrics

/// The color picker sliders' proportions: a 14pt thumb with a 2pt white
/// ring on a 6pt track.
private enum SliderMetrics {
    static let thumbSize: CGFloat = Sizing.iconSmall
    static let trackHeight: CGFloat = Spacing.xs
    static let thumbBorderWidth: CGFloat = Spacing.hairline
    /// The hover halo's reach past the thumb on each side.
    static let haloInset: CGFloat = Spacing.xxs
    static let tickHeight: CGFloat = Spacing.xxs
    static let tickWidth: CGFloat = 1
    /// More grid points than this draw no ticks — they'd read as a bar.
    static let maximumTickCount = 60
    static let draggingScale: CGFloat = 1.15
}

// MARK: - Initializers

extension BlissSlider where Value: BinaryFloatingPoint, Value.Stride: BinaryFloatingPoint {
    /// A slider over a decimal value.
    /// - Parameters:
    ///   - title: What VoiceOver reads for the slider.
    ///   - value: The value, kept inside `range`.
    ///   - range: The ends of the track.
    ///   - step: Snaps the value to steps from the lower bound; nil slides freely
    ///     (the arrow keys then move 1% of the range).
    ///   - showsTicks: Draws a tick at each step, when there's a step and at
    ///     most 60 of them.
    ///   - valueLabel: A readout after the track, e.g. `{ Text($0, format: .percent) }`;
    ///     VoiceOver reads it as the value too.
    ///   - onEditingChanged: True when a drag starts, false when it ends.
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Value>,
        in range: ClosedRange<Value> = 0...1,
        step: Value.Stride? = nil,
        showsTicks: Bool = false,
        valueLabel: ((Value) -> Text)? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        let stepSize = step.map { Double($0) } ?? 0
        self.init(
            title: title,
            value: value,
            stepping: SteppedRange(
                range: Double(range.lowerBound)...Double(range.upperBound),
                step: stepSize,
                // A free slider still reads out a sensible precision.
                fractionDigits: stepSize > 0 ? nil : 2
            ),
            showsTicks: showsTicks,
            valueLabel: valueLabel,
            onEditingChanged: onEditingChanged,
            toDouble: { Double($0) },
            fromDouble: { Value($0) }
        )
    }
}

extension BlissSlider where Value: BinaryInteger {
    /// A slider over a whole number, snapping to `step`.
    /// - Parameters:
    ///   - title: What VoiceOver reads for the slider.
    ///   - value: The value, kept inside `range`.
    ///   - range: The ends of the track.
    ///   - step: The snap, from the lower bound.
    ///   - showsTicks: Draws a tick at each step (at most 60).
    ///   - valueLabel: A readout after the track; VoiceOver reads it as the value too.
    ///   - onEditingChanged: True when a drag starts, false when it ends.
    public init(
        _ title: LocalizedStringKey,
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value = 1,
        showsTicks: Bool = false,
        valueLabel: ((Value) -> Text)? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        let lowerBound = range.lowerBound
        let upperBound = range.upperBound
        self.init(
            title: title,
            value: value,
            stepping: SteppedRange(range: Double(lowerBound)...Double(upperBound), step: Double(step), fractionDigits: 0),
            showsTicks: showsTicks,
            valueLabel: valueLabel,
            onEditingChanged: onEditingChanged,
            toDouble: { Double($0) },
            fromDouble: { number in
                Value(exactly: number.rounded()) ?? (number <= Double(lowerBound) ? lowerBound : upperBound)
            }
        )
    }
}

// MARK: - Tick marks

/// Thin vertical ticks at `fractions` (0…1) of the width, inset so the end
/// ticks sit under the thumb's center at either end.
struct BlissSliderTickMarks: Shape {
    var fractions: [Double]
    var inset: CGFloat
    var tickWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let travel = max(rect.width - 2 * inset, 0)
        for fraction in fractions {
            // Whole points, so every tick renders equally crisp.
            let centerX = (rect.minX + inset + fraction * travel).rounded()
            path.addRect(CGRect(x: centerX - tickWidth / 2, y: rect.minY, width: tickWidth, height: rect.height))
        }
        return path
    }
}

// MARK: - Previews

#Preview("Slider", traits: .fixedLayout(width: 360, height: 180)) {
    @Previewable @State var volume = 0.6
    @Previewable @State var columns = 3
    @Previewable @State var opacity = 0.4

    VStack(alignment: .leading, spacing: Spacing.lg) {
        BlissSlider("Volume", value: $volume)
        BlissSlider("Columns", value: $columns, in: 1...6, showsTicks: true) { Text($0, format: .number) }
        BlissSlider("Opacity", value: $opacity, step: 0.1, valueLabel: { Text($0, format: .percent.precision(.fractionLength(0))) })
        BlissSlider("Disabled", value: .constant(0.3))
            .disabled(true)
    }
    .padding(Spacing.lg)
}
