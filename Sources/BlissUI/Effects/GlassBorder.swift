//
//  GlassBorder.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/9/25.
//

import SwiftUI

/// A view modifier that adds a glass-like border effect with a gradient stroke
struct GlassBorder: ViewModifier {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat
    var opacity: CGFloat
    /// The stroke's color; nil picks white on a dark surface and black on a light one.
    var tint: Color?

    @Environment(\.colorScheme) private var colorScheme

    init(cornerRadius: CGFloat = Sizing.radiusLarge, lineWidth: CGFloat = 1, opacity: CGFloat = 1.0, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.tint = tint
    }

    /// A white gradient vanishes on a light surface, so the default follows the scheme.
    private var strokeColor: Color {
        tint ?? (colorScheme == .dark ? .white : .black)
    }

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                strokeColor.opacity(GlassBorderMetrics.topOpacity * opacity),
                                strokeColor.opacity(GlassBorderMetrics.middleOpacity * opacity),
                                strokeColor.opacity(GlassBorderMetrics.bottomOpacity * opacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            }
    }
}

/// The gradient's stops: bright at the lit top-leading corner, fading away.
enum GlassBorderMetrics {
    static let topOpacity: CGFloat = 0.5
    static let middleOpacity: CGFloat = 0.25
    static let bottomOpacity: CGFloat = 0.1
}

extension View {
    /// Applies a glass-like border effect with a gradient stroke
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the border (default: `Sizing.radiusLarge`)
    ///   - lineWidth: The width of the stroke (default: 1)
    ///   - opacity: The overall opacity multiplier for the gradient (default: 1.0)
    ///   - tint: The stroke's color; nil is white in dark mode and black in light.
    public func glassBorder(
        cornerRadius: CGFloat = Sizing.radiusLarge,
        lineWidth: CGFloat = 1,
        opacity: CGFloat = 1.0,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassBorder(cornerRadius: cornerRadius, lineWidth: lineWidth, opacity: opacity, tint: tint))
    }
}

#Preview("Glass Border", traits: .fixedLayout(width: 260, height: 300)) {
    VStack(spacing: Spacing.lg) {
        Text("Default")
            .frame(width: 200, height: 56)
            .background(.ultraThinMaterial)
            .glassBorder()

        Text("Larger radius")
            .frame(width: 200, height: 56)
            .background(.ultraThinMaterial)
            .glassBorder(cornerRadius: Sizing.radiusXXLarge)

        Text("Lower opacity, accent")
            .frame(width: 200, height: 56)
            .background(.ultraThinMaterial)
            .glassBorder(opacity: 0.5, tint: Color.accent)
    }
    .padding(Spacing.lg)
}
