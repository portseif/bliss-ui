//
//  LayoutGallery.swift
//  BlissCatalog
//
//  The "Layout & People" components in the README index. One `GalleryEntry` per
//  component (or per small group that reads as one picture).
//

import AppKit
import BlissUI
import SwiftUI

extension Gallery {
    static let layout: [GalleryEntry] = [
        GalleryEntry("avatars", width: 520, height: 140) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    Avatar(name: "Ada Lovelace", size: .small)
                    Avatar(name: "Grace Hopper", status: .online)
                    Avatar(name: "Alan Turing", size: .large, status: .busy)
                    Avatar(name: "Katherine Johnson", size: .large, status: .away)
                    Avatar(name: "Edsger Dijkstra", size: .large, status: .offline)
                    Avatar(name: "Design Team", size: .large, shape: .rounded, status: .online, tint: Purple.purple400, symbol: "paintpalette")
                }
                HStack(spacing: Spacing.md) {
                    Avatar(name: "山田太郎", size: .large)
                    Avatar(name: "Анна Каренина", size: .large)
                    Avatar(name: "김민준", size: .large)
                    Avatar(name: "Élodie Durand", size: .large)
                    Avatar(name: "محمد علي", size: .large)
                    Avatar(name: "Barbara Liskov", image: GallerySamples.photo, size: .large, status: .online)
                }
            }
        },
        GalleryEntry("avatar-stack", width: 420, height: 150) {
            VStack(spacing: Spacing.md) {
                AvatarStack(names: GallerySamples.people, size: .small)
                AvatarStack(names: GallerySamples.people)
                AvatarStack(names: ["Design", "Platform", "Growth"], size: .large, shape: .rounded)
            }
        },
        GalleryEntry("person-row", width: 420, height: 150) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                PersonRow(name: "Ada Lovelace", detail: "ada@example.com", status: .online) {
                    Badge("Owner").badgeStyle(.primary).badgeSize(.small)
                }
                PersonRow(name: "Grace Hopper", detail: "Reviewer", status: .away)
                PersonRow(name: "Alan Turing", detail: "Invited") {
                    Button("Resend") {}.buttonStyle(SecondaryButtonStyle(compact: true))
                }
            }
        },
        GalleryEntry("kanban-board", width: 800, height: 360) {
            KanbanBoard(columns: .constant(GalleryKanbanTask.board), columnWidth: 232) { task in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(verbatim: task.title)
                        .font(Typography.bodySmall)
                    HStack(spacing: Spacing.sm) {
                        Badge(.verbatim(task.tag)).badgeStyle(.secondary).badgeSize(.small)
                        Spacer(minLength: 0)
                        Avatar(name: task.assignee, size: .small)
                    }
                }
            }
        },
        GalleryEntry("resizable-split", width: 560, height: 260) {
            GalleryResizableSplit()
        },
        GalleryEntry("breadcrumbs", width: 560, height: 140) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Breadcrumbs(["Projects", "BlissUI", "Sources", "Layout"], title: { $0 }) { _ in }
                Breadcrumbs(GallerySamples.deepPath, title: { $0 }, systemImage: { $0.hasSuffix(".swift") ? "swift" : "folder" }) { _ in }
                    .frame(width: 340, alignment: .leading)
                Breadcrumbs(GallerySamples.deepPath, title: { $0 }, separator: .slash, maximumSegments: 3) { _ in }
            }
        },
        GalleryEntry("inspector-split", width: 640, height: 260) {
            HStack(spacing: Spacing.md) {
                GalleryInspectorSplit(isPinned: true)
                GalleryInspectorSplit(isPinned: false)
            }
        },
        GalleryEntry("code-block", width: 520, height: 180) {
            CodeBlock(CatalogMarkdown.shellSnippet, highlighter: .shell, showsLineNumbers: true)
        },
        GalleryEntry("code-field", width: 560, height: 350) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                CodeField(text: .constant("cd {path} && composer install --no-dev | tee \"install.log\""), highlighter: .shell)
                CodeField(text: .constant(GallerySamples.workflow), highlighter: .yaml, layout: .editor(height: 170), font: Typography.codeSmall)
                CodeField(code: "git clone \"https://github.com/user/repo\" {path} # read-only", highlighter: .shell)
            }
        },
    ]
}

private enum GallerySamples {
    /// A stand-in photo: a soft two-tone gradient, so the index shows a
    /// picture filling the shape without shipping one.
    static let photo = Image(nsImage: NSImage(size: NSSize(width: 80, height: 80), flipped: false) { rect in
        NSGradient(colors: [NSColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1), NSColor(srgbRed: 0.45, green: 0.36, blue: 0.78, alpha: 1)])?
            .draw(in: rect, angle: -45)
        NSColor.white.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 28, y: 40, width: 24, height: 24)).fill()
        NSBezierPath(ovalIn: NSRect(x: 14, y: -6, width: 52, height: 40)).fill()
        return true
    })
    static let people = ["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra", "Barbara Liskov", "Donald Knuth"]
    static let deepPath = ["Projects", "BlissUI", "Sources", "BlissUI", "Components", "Layout", "Breadcrumbs.swift"]
    static let workflow = """
    # Runs on every push to main
    name: CI
    on:
      push:
        branches: [main]
    jobs:
      build:
        runs-on: macos-15
        timeout-minutes: 30
        steps:
          - uses: actions/checkout@v4
          - run: swift test
            continue-on-error: false
    """
}

/// One inspector over a sample document, in a card so two fit side by side.
private struct GalleryInspectorSplit: View {
    let isPinned: Bool

    var body: some View {
        InspectorSplit(isPresented: .constant(true), isPinned: .constant(isPinned), idealWidth: 150, minWidth: 120) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(isPinned ? "Pinned" : "Drawer")
                    .font(Typography.headingSmall)
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: Sizing.radiusSmall, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 10)
                        .frame(maxWidth: index.isMultiple(of: 2) ? .infinity : 120, alignment: .leading)
                }
                Spacer()
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        } inspector: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Details")
                    .font(Typography.bodySmallSemibold)
                HStack(spacing: Spacing.xs) {
                    Avatar(name: "Ada Lovelace", size: .small)
                    Text(verbatim: "Ada Lovelace").font(Typography.caption)
                }
                Text("Updated today")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.contentAreaBackground)
        .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}

/// A task card for the board picture.
private struct GalleryKanbanTask: Identifiable {
    let id: Int
    let title: String
    let tag: String
    let assignee: String

    static var board: [KanbanColumn<GalleryKanbanTask>] {
        [
            KanbanColumn(id: "todo", title: "To do", cards: [
                GalleryKanbanTask(id: 1, title: "Write the release notes", tag: "Docs", assignee: "Ada Lovelace"),
                GalleryKanbanTask(id: 2, title: "Audit focus rings", tag: "A11y", assignee: "Grace Hopper"),
                GalleryKanbanTask(id: 3, title: "Tune the sheet spring", tag: "Motion", assignee: "Alan Turing"),
            ], color: Grey.grey500),
            KanbanColumn(id: "doing", title: "In progress", cards: [
                GalleryKanbanTask(id: 4, title: "Ship the Low Glare theme", tag: "Themes", assignee: "Katherine Johnson"),
            ], color: Warning.warning500),
            KanbanColumn(id: "done", title: "Done", cards: [
                GalleryKanbanTask(id: 5, title: "Polish the onboarding card", tag: "Design", assignee: "Ada Lovelace"),
                GalleryKanbanTask(id: 6, title: "Fix the table shimmer", tag: "Bug", assignee: "Grace Hopper"),
            ], color: Success.success500),
        ]
    }
}

/// A sidebar and content with the divider between them.
private struct GalleryResizableSplit: View {
    @State private var sidebarWidth: CGFloat = 200

    var body: some View {
        ResizableSplit(width: $sidebarWidth, in: 160...320) {
            Sidebar(selection: .constant(CatalogDestination.today)) {
                SidebarSection {
                    SidebarRow("Inbox", icon: "tray", value: CatalogDestination.inbox, count: 4)
                    SidebarRow("Today", icon: "sun.max", value: CatalogDestination.today)
                    SidebarRow("Projects", icon: "folder", value: CatalogDestination.projects)
                }
            }
            .background(Color.appShell)
        } trailing: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(verbatim: "Today").font(Typography.headingMedium)
                Text(verbatim: "Drag the divider, or Tab to it and use the arrow keys.")
                    .font(Typography.bodySmall)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.contentAreaBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                .strokeBorder(Color.menuBorder, lineWidth: 1)
        }
    }
}
