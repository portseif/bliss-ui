//
//  DimmedOverlay.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/9/25.
//

import SwiftUI

/// A view modifier that displays a dimmed overlay with custom content when a condition is true
struct DimmedOverlay<OverlayContent: View>: ViewModifier {
    let isPresented: Bool
    let dimOpacity: CGFloat
    let overlayContent: () -> OverlayContent

    init(
        isPresented: Bool,
        dimOpacity: CGFloat = 0.3,
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
                }
            }
    }
}

extension View {
    /// Displays a dimmed overlay with custom content when a condition is true
    /// - Parameters:
    ///   - isPresented: Whether the overlay should be displayed
    ///   - dimOpacity: The opacity of the dimmed background (default: 0.3)
    ///   - content: The content to display over the dimmed background
    public func dimmedOverlay<Content: View>(
        isPresented: Bool,
        dimOpacity: CGFloat = 0.3,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(DimmedOverlay(isPresented: isPresented, dimOpacity: dimOpacity, overlayContent: content))
    }
}

#Preview("Dimmed Overlay") {
    struct PreviewWrapper: View {
        @State private var isLoading = true

        var body: some View {
            VStack {
                Text("Main Content")
                    .font(.largeTitle)

                Button("Toggle Overlay") {
                    isLoading.toggle()
                }
                .padding()
            }
            .frame(width: 300, height: 200)
            .background(Color.gray.opacity(0.2))
            .dimmedOverlay(isPresented: isLoading) {
                VStack(spacing: 12) {
                    ThinkingSpinner(size: 32, lineWidth: 3)
                    Text("Loading...")
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    return PreviewWrapper()
}
