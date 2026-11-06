//
//  CatalogView.swift
//  BlissCatalog
//
//  The shell: a sidebar of pages on the theme's shell color, and the page on
//  the content surface beside it.
//

import AppKit
import BlissUI
import SwiftUI

enum CatalogPage: String, CaseIterable, Identifiable {
    case themes = "Themes"
    case buttons = "Buttons"
    case inputs = "Inputs"
    case display = "Display"
    case sections = "Sections"
    case table = "Table"
    case overlays = "Menus & Tooltips"
    case sheets = "Sheets & Toasts"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .themes: return "paintpalette"
        case .buttons: return "button.horizontal"
        case .inputs: return "slider.horizontal.3"
        case .display: return "tag"
        case .sections: return "rectangle.grid.1x2"
        case .table: return "tablecells"
        case .overlays: return "text.bubble"
        case .sheets: return "rectangle.stack"
        }
    }
}

struct CatalogView: View {
    static let sidebarWidth: CGFloat = 220

    /// `swift run BlissCatalog -page table` opens on a page (handy for screenshots).
    @State private var page: CatalogPage = CatalogPage.allCases.first {
        String(describing: $0) == UserDefaults.standard.string(forKey: "page")
    } ?? .themes

    @State private var window: NSWindow?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .background(Color.appShell)
        .onWindow { hostWindow in
            if window !== hostWindow { window = hostWindow }
        }
        .task { await captureIfRequested() }
    }

    /// `-capture <file>`: wait for the page (and any demo state) to settle,
    /// capture the window, quit.
    private func captureIfRequested() async {
        guard let file = WindowCapture.requestedFile else { return }
        try? await Task.sleep(for: .milliseconds(2_000))
        if let window { WindowCapture.capture(window, to: file) }
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BlissUI")
                .font(Typography.headingSmall)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, 44)
                .padding(.bottom, Spacing.md)
            ForEach(CatalogPage.allCases) { item in
                CatalogSidebarRow(page: item, isSelected: page == item) {
                    withAnimation(Animations.selection) { page = item }
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .frame(width: Self.sidebarWidth, alignment: .leading)
    }

    // MARK: - Content

    private var content: some View {
        ScrollViewWithThinIndicator(showFadeMask: true, fillsViewport: true) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text(LocalizedStringKey(page.rawValue))
                    .font(Typography.displaySmall)
                pageBody
            }
            .padding(Spacing.xl)
            .padding(.top, Spacing.lg)
            .readableContentWidth()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.contentAreaBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
        .padding(.top, 8)
        .id(page)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch page {
        case .themes: ThemesPage()
        case .buttons: ButtonsPage()
        case .inputs: InputsPage()
        case .display: DisplayPage()
        case .sections: SectionsPage()
        case .table: TablePage()
        case .overlays: OverlaysPage()
        case .sheets: SheetsPage()
        }
    }
}

/// A sidebar row: neutral gray selection and hover, a Tab stop with the shared ring.
private struct CatalogSidebarRow: View {
    let page: CatalogPage
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(LocalizedStringKey(page.rawValue), systemImage: page.systemImage)
                .font(Typography.bodySmall)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
                        .fill(isSelected ? RowTint.selected(scheme) : (isHovering ? RowTint.hover(scheme) : .clear))
                }
                .contentShape(RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous))
        }
        .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusMedium))
        .onHover { isHovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview(traits: .fixedLayout(width: 1000, height: 680)) {
    CatalogView()
        .appSheetHost()
        .globalToast()
        .blissTheme()
}
