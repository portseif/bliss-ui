//
//  TerminalOutputView.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/17/25.
//

import SwiftUI

// MARK: - Terminal Output Line

/// Represents a single line of terminal output with its type
public nonisolated struct TerminalOutputLine: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let text: String
    public let type: OutputType
    public let timestamp: Date

    public nonisolated enum OutputType: Sendable {
        case stdout
        case stderr
        case system  // For system messages like "Process started"
    }

    public init(_ text: String, type: OutputType = .stdout) {
        self.text = text
        self.type = type
        self.timestamp = Date()
    }
}

// MARK: - Terminal Output View

/// A terminal-like view that displays command output with monospace font,
/// auto-scrolling, and error highlighting. A rounded card by default; `isDocked`
/// makes it a flush panel with a hairline on top, for a console docked along
/// the bottom of a pane (like Xcode's).
public struct TerminalOutputView: View {
    let lines: [TerminalOutputLine]
    var title: String = String(localized: "Output", bundle: .module)
    var maxHeight: CGFloat = 200
    var isCollapsible: Bool = true
    var showTimestamps: Bool = false
    var isDocked: Bool = false
    var contentInset: CGFloat = 12

    @State private var isExpanded = true
    @State private var scrollProxy: ScrollViewProxy?

    public init(
        lines: [TerminalOutputLine],
        title: String = String(localized: "Output", bundle: .blissUI),
        maxHeight: CGFloat = 200,
        isCollapsible: Bool = true,
        showTimestamps: Bool = false,
        isDocked: Bool = false,
        contentInset: CGFloat = 12
    ) {
        self.lines = lines
        self.title = title
        self.maxHeight = maxHeight
        self.isCollapsible = isCollapsible
        self.showTimestamps = showTimestamps
        self.isDocked = isDocked
        self.contentInset = contentInset
    }

    /// Square when docked: it meets the pane's edges.
    private var cornerRadius: CGFloat { isDocked ? 0 : 8 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse toggle
            headerView

            // Terminal content
            if isExpanded {
                terminalContent
                    .frame(maxHeight: maxHeight)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        // The theme's surfaces, like a read-only `CodeField`: a faint wash over
        // whatever it sits on, and the shared hairline — around the card, or
        // along the top edge when docked.
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
        .overlay {
            if isDocked {
                Rectangle()
                    .fill(Color.menuBorder)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.menuBorder, lineWidth: 1)
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 8) {
            // Terminal icon
            Image(systemName: "terminal")
                .font(Typography.labelXSmall)
                .foregroundStyle(.secondary)

            Text(title)
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(.secondary)

            Spacer()

            // Line count badge
            if !lines.isEmpty {
                Text("\(lines.count) line\(lines.count == 1 ? "" : "s")", bundle: .module)
                    .font(Typography.captionTiny)
                    .foregroundStyle(.tertiary)
            }

            // Expand/collapse button
            if isCollapsible {
                Button {
                    withAnimation(Animations.accordion) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(Typography.labelTinySemibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FocusablePlainButtonStyle(cornerRadius: Sizing.radiusSmall, outset: 2))
                .tooltip(configuration: .iconHint, position: .above) {
                    Text(isExpanded ? "Collapse output" : "Expand output", bundle: .module).font(Typography.labelSmall)
                }
                .accessibilityLabel(Text("Output", bundle: .module))
                .accessibilityValue(isExpanded ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))
            }
        }
        .padding(.horizontal, contentInset)
        .padding(.vertical, 8)
        .background {
            // A step above the body's wash.
            Color.primary.opacity(0.04)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: isExpanded ? 0 : cornerRadius,
                bottomTrailingRadius: isExpanded ? 0 : cornerRadius,
                topTrailingRadius: cornerRadius
            )
        )
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if lines.isEmpty {
                        emptyStateView
                    } else {
                        // Use stable index-based IDs so re-rendering (with fresh UUIDs)
                        // doesn't lose scroll position or break the scrollTo target.
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            lineView(for: line)
                                .id(index)
                        }
                    }
                }
                .padding(.horizontal, contentInset)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: lines.count) { _, newCount in
                // Auto-scroll to bottom when new lines are added
                guard newCount > 0 else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newCount - 1, anchor: .bottom)
                }
            }
            .onAppear {
                // Scroll to bottom on initial appear
                if !lines.isEmpty {
                    proxy.scrollTo(lines.count - 1, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Line View

    private func lineView(for line: TerminalOutputLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if showTimestamps {
                Text(line.timestamp, format: .dateTime.hour().minute().second())
                    .font(Typography.codeTiny)
                    .foregroundStyle(.quaternary)
                    .frame(width: 60, alignment: .leading)
            }

            Text(line.text)
                .font(Typography.codeTiny)
                .foregroundStyle(colorForLineType(line.type))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack {
            Spacer()
            Text("Waiting for output...", bundle: .module)
                .font(Typography.codeTiny)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private func colorForLineType(_ type: TerminalOutputLine.OutputType) -> Color {
        switch type {
        case .stdout:
            return .primary
        case .stderr:
            return Danger.danger500
        case .system:
            return .accent
        }
    }
}

// MARK: - Convenience Initializer

extension TerminalOutputView {
    /// Create a terminal view from an array of strings (all treated as stdout)
    public init(output: [String], title: String = String(localized: "Output", bundle: .blissUI), maxHeight: CGFloat = 200) {
        self.lines = output.map { TerminalOutputLine($0, type: .stdout) }
        self.title = title
        self.maxHeight = maxHeight
        self.isCollapsible = true
        self.showTimestamps = false
    }
}

// MARK: - Previews

#Preview("Empty State") {
    TerminalOutputView(lines: [])
        .frame(width: 500)
        .padding()
}

#Preview("With Output") {
    TerminalOutputView(
        lines: [
            TerminalOutputLine("$ git clone https://github.com/example/demo.git", type: .system),
            TerminalOutputLine("Cloning into 'demo'..."),
            TerminalOutputLine("remote: Enumerating objects: 128, done."),
            TerminalOutputLine("Receiving objects: 100% (128/128), 48.20 KiB | 1.2 MiB/s, done."),
            TerminalOutputLine("Resolving deltas: 100% (42/42), done."),
            TerminalOutputLine("$ swift build", type: .system),
            TerminalOutputLine("Building for debugging..."),
            TerminalOutputLine("Build complete! (4.21s)"),
        ],
        title: "Build Output"
    )
    .frame(width: 500)
    .padding()
}

#Preview("With Errors") {
    TerminalOutputView(
        lines: [
            TerminalOutputLine("$ swift build", type: .system),
            TerminalOutputLine("Fetching https://github.com/example/demo-kit.git"),
            TerminalOutputLine("Computing version for https://github.com/example/demo-kit.git"),
            TerminalOutputLine("error: Dependencies could not be resolved because no versions of 'demo-kit' match the requirement 2.0.0..<3.0.0.", type: .stderr),
            TerminalOutputLine("", type: .stderr),
            TerminalOutputLine("  'demo' depends on 'demo-kit' 2.0.0..<3.0.0", type: .stderr),
            TerminalOutputLine("    - The newest published version is 1.4.2, which does not satisfy that requirement.", type: .stderr),
        ],
        title: "Build Output"
    )
    .frame(width: 500)
    .padding()
}

#Preview("Docked", traits: .fixedLayout(width: 520, height: 260)) {
    VStack(spacing: 0) {
        Color.clear
        TerminalOutputView(
            lines: [
                TerminalOutputLine("Checking 6 skills for updates…", type: .system),
                TerminalOutputLine("Everything is up to date.", type: .system),
            ],
            title: "Activity",
            maxHeight: 120,
            isDocked: true,
            contentInset: Spacing.xl
        )
    }
}

#Preview("With Timestamps") {
    TerminalOutputView(
        lines: [
            TerminalOutputLine("Starting build process...", type: .system),
            TerminalOutputLine("$ npm install"),
            TerminalOutputLine("added 245 packages in 12s"),
            TerminalOutputLine("$ npm run build"),
            TerminalOutputLine("Build completed successfully."),
        ],
        title: "Build Log",
        showTimestamps: true
    )
    .frame(width: 600)
    .padding()
}

#Preview("Long Output") {
    TerminalOutputView(
        lines: (1...50).map { index in
            TerminalOutputLine("Line \(index): This is a sample output line that demonstrates scrolling behavior in the terminal view")
        },
        title: "Scrollable Output",
        maxHeight: 200
    )
    .frame(width: 500)
    .padding()
}

#Preview("Collapsed") {
    VStack(spacing: 20) {
        TerminalOutputView(
            lines: [
                TerminalOutputLine("Some output here"),
            ],
            title: "Collapsed Terminal",
            isCollapsible: true
        )

        Text("The terminal above can be collapsed")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .frame(width: 500)
    .padding()
}
