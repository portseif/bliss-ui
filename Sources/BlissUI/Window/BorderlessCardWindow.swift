//
//  BorderlessCardWindow.swift
//  BlissUI
//
//  Turns a window into a borderless, content-sized card (a first-run or
//  onboarding flow) and back into the window SwiftUI built.
//

import AppKit
import SwiftUI

/// While `isActive`, strips the window down to a centered, borderless,
/// draggable card of `size`; afterwards it restores the ORIGINAL style mask.
///
/// The mask is captured once, before the strip, and restored verbatim.
/// Restoring a hand-picked subset (`.resizable`, `.miniaturizable`) left a
/// borderless window — square corners, no traffic lights, and since a
/// borderless window can't become key, no control could take focus. The
/// capture doubles as a configure-once guard, so a re-render doesn't re-strip
/// and re-center a card the user dragged.
private struct BorderlessCardWindowView: NSViewRepresentable {
    let isActive: Bool
    let size: CGSize

    func makeNSView(context: Context) -> CardWindowConfigurator {
        let view = CardWindowConfigurator()
        view.isActive = isActive
        view.size = size
        return view
    }

    func updateNSView(_ nsView: CardWindowConfigurator, context: Context) {
        nsView.size = size
        nsView.isActive = isActive
    }

    final class CardWindowConfigurator: NSView {
        var size: CGSize = .zero
        var isActive = false {
            didSet { if oldValue != isActive { configure() } }
        }
        /// The window's mask as SwiftUI built it, captured before the strip.
        private var capturedStyleMask: NSWindow.StyleMask?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configure()
        }

        private func configure() {
            guard let window else { return }
            if isActive {
                guard capturedStyleMask == nil else { return }
                capturedStyleMask = window.styleMask
                window.styleMask.remove(.titled)
                window.styleMask.remove(.resizable)
                window.styleMask.remove(.miniaturizable)
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = true
                window.toolbar?.isVisible = false
                window.setContentSize(size)
                window.center()
            } else if let capturedStyleMask {
                // Back to exactly what SwiftUI built — `.titled` included, so
                // rounded corners, traffic lights and key-window eligibility
                // return without hand-picking flags that fight `.hiddenTitleBar`.
                window.styleMask = capturedStyleMask
                self.capturedStyleMask = nil
                window.isMovableByWindowBackground = false
                window.titlebarSeparatorStyle = .none
                // A style-mask change rebuilds the theme frame in AppKit's own
                // order; put the shell backdrop back underneath.
                ShellBackdropView.apply(to: window)
            }
        }
    }
}

extension View {
    /// While `isActive`, shows this window as a borderless card of `size`,
    /// centered and draggable by its background; when it turns false the
    /// window gets its original chrome back. Draw the card's own rounded
    /// background in the content.
    public func borderlessCardWindow(isActive: Bool, size: CGSize = CGSize(width: 760, height: 600)) -> some View {
        background(BorderlessCardWindowView(isActive: isActive, size: size))
    }
}
