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

    init(cornerRadius: CGFloat = 10, lineWidth: CGFloat = 1, opacity: CGFloat = 1.0) {
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5 * opacity),
                                Color.white.opacity(0.25 * opacity),
                                Color.white.opacity(0.1 * opacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            }
    }
}

extension View {
    /// Applies a glass-like border effect with a gradient stroke
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the border (default: 10)
    ///   - lineWidth: The width of the stroke (default: 1)
    ///   - opacity: The overall opacity multiplier for the gradient (default: 1.0)
    public func glassBorder(
        cornerRadius: CGFloat = 10,
        lineWidth: CGFloat = 1,
        opacity: CGFloat = 1.0
    ) -> some View {
        modifier(GlassBorder(cornerRadius: cornerRadius, lineWidth: lineWidth, opacity: opacity))
    }
}

#Preview("Glass Border") {
    VStack(spacing: 20) {
        Text("Default")
            .frame(width: 200, height: 100)
            .background(.ultraThinMaterial)
            .glassBorder()

        Text("Custom Radius")
            .frame(width: 200, height: 100)
            .background(.ultraThinMaterial)
            .glassBorder(cornerRadius: 20)

        Text("Thicker Line")
            .frame(width: 200, height: 100)
            .background(.ultraThinMaterial)
            .glassBorder(lineWidth: 2)

        Text("Lower Opacity")
            .frame(width: 200, height: 100)
            .background(.ultraThinMaterial)
            .glassBorder(opacity: 0.5)
    }
    .padding()
    .background(Color.black)
}
