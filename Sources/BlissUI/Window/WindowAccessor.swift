//
//  WindowAccessor.swift
//  BlissUI
//
//  Reaches the hosting NSWindow from SwiftUI to configure it.
//

import AppKit
import SwiftUI

/// A view that provides access to the underlying NSWindow for configuration
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window)
            }
        }
    }
}

extension View {
    /// Runs `configure` with the hosting window once it's attached, and again
    /// on updates. Keep it idempotent.
    public func onWindow(_ configure: @escaping (NSWindow) -> Void) -> some View {
        background(WindowAccessor(configure: configure))
    }
}
