//
//  LayoutPage.swift
//  BlissCatalog
//
//  The "Layout & People" page.
//

import BlissUI
import SwiftUI

struct LayoutPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            AvatarDemo()
            AvatarStackDemo()
            BreadcrumbsDemo()
            InspectorSplitDemo()
            CodeFieldDemo()
        }
    }
}

private enum LayoutSamples {
    static let people = [
        "Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson", "Edsger Dijkstra",
        "Barbara Liskov", "Donald Knuth", "山田太郎", "Анна Каренина", "김민준",
    ]
}

// MARK: - Avatar

private struct AvatarDemo: View {
    private enum StatusOption: String, CaseIterable {
        case none = "None", online = "Online", away = "Away", busy = "Busy", offline = "Offline"

        var status: AvatarStatus? {
            switch self {
            case .none: nil
            case .online: .online
            case .away: .away
            case .busy: .busy
            case .offline: .offline
            }
        }
    }

    @State private var name = "Ada Lovelace"
    @State private var size: AvatarSize = .large
    @State private var shape: AvatarShape = .circle
    @State private var status: StatusOption = .online

    var body: some View {
        DemoBlock(title: "Avatar") {
            HStack(alignment: .center, spacing: Spacing.xl) {
                Avatar(name: name, size: size, shape: shape, status: status.status)
                    .frame(width: AvatarSize.large.diameter, height: AvatarSize.large.diameter)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextField("Name", text: $name).textFieldStyle(.largePadded)
                    HStack(spacing: Spacing.sm) {
                        SegmentedPills(options: AvatarSize.allCases, selection: $size, style: .compact, title: { size in
                            switch size {
                            case .small: "Small"
                            case .medium: "Medium"
                            case .large: "Large"
                            }
                        })
                        SegmentedPills(options: [AvatarShape.circle, .rounded], selection: $shape, style: .compact, title: { $0 == .circle ? "Circle" : "Rounded" })
                    }
                    SegmentedPills(options: StatusOption.allCases, selection: $status, style: .compact, title: { $0.rawValue })
                }
                .frame(maxWidth: 420)
            }
            Text("Initials and color come from the name — type one in any script. The same name always gets the same color.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.sm) {
                ForEach(LayoutSamples.people, id: \.self) { person in
                    Avatar(name: person, size: size, shape: shape)
                }
            }
        }
    }
}

// MARK: - Avatar stack

private struct AvatarStackDemo: View {
    @State private var count = 7
    @State private var limit = 4

    var body: some View {
        DemoBlock(title: "Avatar stack") {
            HStack(spacing: Spacing.xl) {
                AvatarStack(names: Array(LayoutSamples.people.prefix(count)), limit: limit, size: .small)
                AvatarStack(names: Array(LayoutSamples.people.prefix(count)), limit: limit)
                AvatarStack(names: Array(LayoutSamples.people.prefix(count)), limit: limit, size: .large)
            }
            HStack(spacing: Spacing.sm) {
                Text("People").font(Typography.caption).foregroundStyle(.secondary)
                SegmentedPills(options: [1, 3, 5, 7, 10], selection: $count, style: .compact, title: { "\($0)" })
                Text("Show up to").font(Typography.caption).foregroundStyle(.secondary)
                SegmentedPills(options: [2, 3, 4, 6], selection: $limit, style: .compact, title: { "\($0)" })
            }
            Text("Hover a stack for everyone's names.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Breadcrumbs

private struct BreadcrumbsDemo: View {
    private static let fullPath = ["Projects", "BlissUI", "Sources", "BlissUI", "Components", "Layout", "Breadcrumbs.swift"]

    @State private var depth = fullPath.count
    @State private var isNarrow = true

    private var path: [String] { Array(Self.fullPath.prefix(depth)) }

    var body: some View {
        DemoBlock(title: "Breadcrumbs") {
            Breadcrumbs(path, title: { $0 }, systemImage: { $0.hasSuffix(".swift") ? "swift" : "folder" }) { segment in
                if let index = path.firstIndex(of: segment) { depth = index + 1 }
            }
            .frame(maxWidth: isNarrow ? 360 : .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xs)
            .animation(Animations.pane, value: isNarrow)
            HStack(spacing: Spacing.sm) {
                SegmentedPills(options: [true, false], selection: $isNarrow, style: .compact, title: { $0 ? "Narrow" : "Wide" })
                Button("Reset path") { depth = Self.fullPath.count }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    .disabled(depth == Self.fullPath.count)
            }
            Text("Click a segment to go back to it. Segments that don't fit fold into the … menu.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Inspector split

private struct InspectorSplitDemo: View {
    @State private var showsInspector = true
    @State private var pinsInspector = true

    var body: some View {
        DemoBlock(title: "Inspector split") {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.sm) {
                    Text("Q3 Planning")
                        .font(Typography.bodySmallSemibold)
                    Spacer()
                    Button { pinsInspector.toggle() } label: {
                        Image(systemName: pinsInspector ? "pin.fill" : "pin")
                    }
                    .buttonStyle(ToolbarIconButtonStyle(isActive: pinsInspector))
                    .accessibilityLabel(Text(pinsInspector ? "Unpin inspector" : "Pin inspector"))
                    .tooltip(pinsInspector ? "Unpin inspector" : "Pin inspector", position: .below)
                    Button { showsInspector.toggle() } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(ToolbarIconButtonStyle(isActive: showsInspector))
                    .accessibilityLabel(Text(showsInspector ? "Hide inspector" : "Show inspector"))
                    .tooltip(showsInspector ? "Hide inspector" : "Show inspector", position: .below)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                Divider()
                InspectorSplit(
                    isPresented: $showsInspector,
                    isPinned: $pinsInspector,
                    idealWidth: 260,
                    minWidth: 200,
                    maxWidth: 420,
                    widthStorageKey: "blissCatalog.inspectorWidth"
                ) {
                    InspectorDemoDocument()
                } inspector: {
                    InspectorDemoDetails()
                }
            }
            .frame(height: 320)
            .background(Color.contentAreaBackground)
            .clipShape(RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Sizing.radiusLarge, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
            Text("Drag the inspector's edge to resize it (the width is kept). Pinned, the document makes room; unpinned, the inspector is a drawer — click the dim or press Esc to close it.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InspectorDemoDocument: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Goals for the quarter")
                .font(Typography.headingSmall)
            Text("Ship the theme picker, finish the accessibility audit, and cut the 1.0 release. Each goal has an owner and a date in the inspector.")
                .font(Typography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(["Theme picker", "Accessibility audit", "1.0 release"], id: \.self) { goal in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                    Text(goal)
                        .font(Typography.bodySmall)
                    Spacer()
                }
                .rowHover()
            }
            Spacer()
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InspectorDemoDetails: View {
    @State private var notifies = true

    var body: some View {
        ScrollViewWithThinIndicator {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Details")
                    .font(Typography.bodySmallSemibold)
                HStack(spacing: Spacing.sm) {
                    Avatar(name: "Grace Hopper", size: .small, status: .online)
                        .accessibilityHidden(true)
                    Text(verbatim: "Grace Hopper")
                        .font(Typography.bodySmall)
                }
                DetailRow(label: "Due", value: "Sep 30")
                DetailRow(label: "Status", value: "On track")
                Toggle("Notify me", isOn: $notifies)
                    .toggleStyle(.flatSwitch(showsLabel: true))
                AvatarStack(names: Array(LayoutSamples.people.prefix(6)), size: .small)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Code field

private struct CodeFieldDemo: View {
    @State private var command = "cd {path} && composer install --no-dev"
    @State private var workflow = """
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
          - name: Test
            run: swift test --parallel
            continue-on-error: false
    """
    @State private var query = "SELECT name, email FROM users WHERE id = 42 -- the owner"

    var body: some View {
        DemoBlock(title: "Code field") {
            Text("Shell")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            CodeField(text: $command, highlighter: .shell, prompt: "composer create-project…")
                .onSubmit {
                    ToastService.shared.showInfo(title: "Run", message: command)
                }
            Text("YAML")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            CodeField(text: $workflow, highlighter: .yaml, prompt: "name: Workflow", layout: .editor(height: 200), font: Typography.codeSmall)
            Text("A rule-based highlighter (SQL) — apps add their own languages")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            CodeField(text: $query, highlighter: .catalogSQL)
            Text("Read-only")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            CodeField(code: "git clone \"https://github.com/user/repo\" {path}  # then open it", highlighter: .shell)
        }
    }
}

extension CodeHighlighter {
    /// A small SQL highlighter built from rules — what an app would add.
    static let catalogSQL = CodeHighlighter(rules: [
        CodeHighlightRule(#"--[^\n]*"#, kind: .comment),
        CodeHighlightRule(#"'[^']*'"#, kind: .string),
        CodeHighlightRule(#"(?i)\b(select|from|where|join|on|and|or|order by|group by|limit|insert|into|values|update|set|delete)\b"#, kind: .keyword),
        CodeHighlightRule(#"\b\d+(\.\d+)?\b"#, kind: .number),
        CodeHighlightRule(#"[=<>!]+|,"#, kind: .operator),
    ])
}
