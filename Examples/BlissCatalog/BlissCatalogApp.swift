//
//  BlissCatalogApp.swift
//  BlissCatalog
//
//  Every BlissUI component on one window, built only on the public API —
//  if something here needs `@testable`, it isn't public enough.
//
//  Run it with `swift run BlissCatalog`.
//

import AppKit
import BlissUI
import SwiftUI

@main
struct BlissCatalogApp: App {
    init() {
        // `swift run` launches a bare executable; make it a regular app with a
        // Dock icon and a key window.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApplication.shared.activate() }
    }

    var body: some Scene {
        WindowGroup("BlissUI Catalog") {
            CatalogView()
                .frame(minWidth: 960, minHeight: 640)
                .appSheetHost(leadingInset: CatalogView.sidebarWidth)
                .globalToast()
                .blissTheme()
                .blissWindowChrome()
                .persistsWindowFrame(key: "blissCatalog.windowFrame")
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 780)

        Settings {
            AppearanceSettings()
                .frame(width: 480, height: 520)
                .blissTheme()
        }
    }
}
