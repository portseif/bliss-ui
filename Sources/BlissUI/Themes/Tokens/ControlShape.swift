//
//  ControlShape.swift
//  BlissUI
//
//  One corner style for every control below a view: square, rounded (the
//  default) or round. Buttons, text and search fields, hand-built input boxes,
//  pickers and segmented controls read it, so a whole window can switch at once.
//

import SwiftUI

/// How a control's corners are drawn: square, rounded, or round.
public nonisolated enum ControlShape: Hashable, Sendable, CaseIterable {
    /// Sharp corners.
    case square
    /// Each control's own rounded corners. The default.
    case rounded
    /// Capsule ends on single-line controls; a box that holds more than one
    /// line keeps a generous radius, since a capsule can't wrap a box.
    case round

    /// A single-line control's corners, given the radius it has when rounded.
    func radius(rounded: CGFloat) -> CGFloat {
        switch self {
        case .square: 0
        case .rounded: rounded
        case .round: Sizing.radiusFull
        }
    }

    /// A multi-line box's corners (a text area, a composer), given the radius
    /// it has when rounded.
    func boxRadius(rounded: CGFloat) -> CGFloat {
        switch self {
        case .square: 0
        case .rounded: rounded
        case .round: Sizing.radiusXLarge
        }
    }
}

extension RoundedCornerStyle {
    /// Continuous corners, except at `Sizing.radiusFull`: continuous corners
    /// that large bulge into a squircle, so a capsule takes circular ends.
    static func matching(_ radius: CGFloat) -> RoundedCornerStyle {
        radius.isInfinite ? .circular : .continuous
    }
}

extension EnvironmentValues {
    /// The corner style every control below reads; `.controlShape(_:)` sets it.
    @Entry public var controlShape: ControlShape = .rounded
}

extension View {
    /// Draws every control below — buttons, text and search fields, input
    /// boxes, pickers and segmented controls — with `shape` corners. A button
    /// given a `cornerRadiusOverride` keeps it.
    public func controlShape(_ shape: ControlShape) -> some View {
        environment(\.controlShape, shape)
    }
}

// MARK: - Preview

#Preview("Control Shapes") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ForEach(ControlShape.allCases, id: \.self) { shape in
            HStack(spacing: Spacing.sm) {
                Button("Save") {}.buttonStyle(PrimaryButtonStyle())
                Button("Cancel") {}.buttonStyle(SecondaryButtonStyle())
                TextField("", text: .constant(""), prompt: Text(verbatim: "Name"))
                    .textFieldStyle(.largePadded)
                    .frame(width: 160)
            }
            .controlShape(shape)
        }
    }
    .padding(Spacing.xl)
}
