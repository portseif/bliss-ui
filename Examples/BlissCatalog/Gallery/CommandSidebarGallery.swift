//
//  CommandSidebarGallery.swift
//  BlissCatalog
//
//  The "Command & Sidebar" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import BlissUI
import SwiftUI

extension Gallery {
    static let commandSidebar: [GalleryEntry] = [
        // The palette's card inline, with a query typed: the ranked matches in
        // their sections, the first one selected.
        GalleryEntry("command-palette", width: 640, height: 452) {
            CommandPalette(
                commands: CommandSidebarSamples.paletteSections { _ in },
                query: .constant("pro"),
                recentsKey: nil,
                focusesFieldOnAppear: false,
                onDismiss: {}
            )
            .frame(maxHeight: .infinity, alignment: .top)
        },
        GalleryEntry("sidebar", width: 268, height: 476) {
            GallerySidebar()
        },
        GalleryEntry("window-title-bar", width: 640, height: 60) {
            WindowTitleBar(insetsForTrafficLights: false, showsDivider: true) {
                SidebarToggleButton(isCollapsed: .constant(false))
            } center: {
                Text("Inbox")
            } trailing: {
                Button {} label: { Image(systemName: "magnifyingglass") }
                    .buttonStyle(ToolbarIconButtonStyle())
                    .accessibilityLabel(Text("Search"))
                Button("New") {}
                    .buttonStyle(OutlineButtonStyle(compact: true))
            }
            .background(Color.appShell)
        },
        GalleryEntry("sidebar-collapsed", width: 560, height: 300) {
            GalleryCollapsedWindow()
        },
        GalleryEntry("outline-list", width: 340, height: 300) {
            OutlineList(CatalogOutlineNode.tree, children: \.children, selection: .constant("readme"), expanded: .constant(["sources", "components"])) { node in
                Label {
                    Text(verbatim: node.name).font(Typography.bodySmall)
                } icon: {
                    Image(systemName: node.icon).foregroundStyle(.secondary)
                }
            }
        },
        GalleryEntry("slideout-panel", width: 640, height: 400) {
            GallerySlideout()
        },
    ]
}

/// The sidebar on the window's shell, one destination selected and a filter
/// saved with its own icon.
private struct GallerySidebar: View {
    var body: some View {
        Sidebar(selection: .constant(CatalogDestination.today)) {
            SidebarSection {
                SidebarRow("Inbox", icon: "tray", value: CatalogDestination.inbox, count: 4, shortcut: "⌘1")
                SidebarRow("Today", icon: "sun.max", value: CatalogDestination.today, shortcut: "⌘2")
                SidebarRow("Upcoming", icon: "calendar", value: CatalogDestination.upcoming, shortcut: "⌘3")
                SidebarRow("Projects", icon: "folder", value: CatalogDestination.projects, count: 12, shortcut: "⌘4")
            }
            SidebarDivider()
            SidebarSection("Filters") {
                SidebarFilterRow("Running", color: Success.success500, value: CatalogDestination.running)
                SidebarFilterRow("In review", color: Warning.warning500, value: CatalogDestination.inReview)
                ForEach(CommandSidebarSamples.savedFilters) { filter in
                    SidebarFilterRow(.verbatim(filter.name), icon: filter.icon, color: filter.color, value: CatalogDestination.savedFilter(filter.id))
                }
                SidebarRow("New filter", icon: "plus") {}
            }
        } footer: {
            SidebarRow("Settings", icon: "gearshape", value: CatalogDestination.settings, shortcut: "⌘,")
        }
        .background {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .fill(Color.appShell)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

/// A page with the notifications panel slid in over its trailing edge.
private struct GallerySlideout: View {
    var body: some View {
        SlideoutPageSample(isPresented: .constant(true))
            .slideoutPanel(isPresented: .constant(true), title: "Notifications", width: 320) {
                NotificationsSample()
            } actions: {
                Button("Mark all read") {}
                    .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 3))
                    .font(Typography.labelSmall)
                    .foregroundStyle(Color.accent)
            }
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
    }
}

/// A mock window with the title bar and the sidebar collapsed to its icons.
private struct GalleryCollapsedWindow: View {
    var body: some View {
        VStack(spacing: 0) {
            WindowTitleBar(insetsForTrafficLights: false) {
                SidebarToggleButton(isCollapsed: .constant(true))
            } center: {
                Text("Today")
            } trailing: {
                Button("New") {}
                    .buttonStyle(OutlineButtonStyle(compact: true))
            }
            HStack(spacing: 0) {
                CollapsibleSidebarSample(selection: .constant(.today), isCollapsed: true)
                    .frame(width: Sizing.sidebarCollapsedWidth)
                VStack(alignment: .leading, spacing: Spacing.md) {
                    DividedForEach(["Design review", "Write release notes", "Audit focus rings"], id: \.self) { title in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "circle")
                                .font(Typography.bodySmall)
                                .foregroundStyle(.secondary)
                            Text(verbatim: title)
                                .font(Typography.bodySmall)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.contentAreaBackground)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous))
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: Sizing.radiusLarge, style: .continuous)
                        .strokeBorder(Color.menuBorder, lineWidth: 1)
                }
            }
        }
        .background(Color.appShell)
        .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}
