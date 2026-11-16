//
//  DimmedOverlay.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/9/25.
//

import SwiftUI

/// The scrim and blur every modal backdrop shares (`AppSheet`, the command
/// palette, `.dimmedOverlay`, a drawer's dim).
public enum Scrim {
    /// How dark the scrim over the page is.
    public static let opacity: CGFloat = 0.32
    /// How far the page blurs under a sheet or the palette.
    public static let backdropBlur: CGFloat = 6
}

/// A view modifier that displays a dimmed overlay with custom content when a condition is true
struct DimmedOverlay<OverlayContent: View>: ViewModifier {
    let isPresented: Bool
    let dimOpacity: CGFloat
    let overlayContent: () -> OverlayContent

    init(
        isPresented: Bool,
        dimOpacity: CGFloat = Scrim.opacity,
        @ViewBuilder overlayContent: @escaping () -> OverlayContent
    ) {
        self.isPresented = isPresented
        self.dimOpacity = dimOpacity
        self.overlayContent = overlayContent
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        Color.black.opacity(dimOpacity)
                            .ignoresSafeArea()

                        overlayContent()
                    }
                    .transition(.motion(.opacity))
                }
            }
            .animation(Animations.sheet, value: isPresented)
    }
}

extension View {
    /// Displays a dimmed overlay with custom content when a condition is true
    /// - Parameters:
    ///   - isPresented: Whether the overlay should be displayed
    ///   - dimOpacity: The opacity of the dimmed background (default: `Scrim.opacity`)
    ///   - content: The content to display over the dimmed background
    public func dimmedOverlay<Content: View>(
        isPresented: Bool,
        dimOpacity: CGFloat = Scrim.opacity,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(DimmedOverlay(isPresented: isPresented, dimOpacity: dimOpacity, overlayContent: content))
    }
}

#Preview("Dimmed Overlay", traits: .fixedLayout(width: 320, height: 220)) {
    struct PreviewWrapper: View {
        @State private var isLoading = true

        var body: some View {
            VStack(spacing: Spacing.md) {
                Text("Main Content")
                    .font(Typography.headingMedium)

                Button("Toggle Overlay") {
                    isLoading.toggle()
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.contentAreaBackground)
            .dimmedOverlay(isPresented: isLoading) {
                VStack(spacing: Spacing.md) {
                    ThinkingSpinner(size: .large)
                    Text("Loading…")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.white)
                }
                .padding(Spacing.xl)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
            }
        }
    }

    return PreviewWrapper()
}
