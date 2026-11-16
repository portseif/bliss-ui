//
//  TerminalOutputView.swift
//  BlissUI
//
//  A console: lines of command output in the code font under a header strip,
//  as a rounded box or docked flush along a pane's bottom.
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

// MARK: - Metrics

/// The console's geometry.
public enum TerminalMetrics {
    /// The body's height cap.
    public static let maxHeight: CGFloat = 200
    /// The timestamp column.
    public static let timestampWidth: CGFloat = 60
    /// Between lines.
    public static let lineSpacing: CGFloat = Spacing.hairline
}

// MARK: - Terminal Output View

/// A terminal-like view that displays command output with monospace font,
/// auto-scrolling, and error highlighting. A rounded box by default; `isDocked`
/// makes it a flush panel with a hairline on top, for a console docked along
/// the bottom of a pane (like Xcode's). Pass `isExpanded` to own the collapse
/// (a toolbar button that reopens a docked console); `wrapsLines: false`
/// scrolls sideways like a real console.
public struct TerminalOutputView<HeaderAccessory: View>: View {
    let lines: [TerminalOutputLine]
    var title: String = String(localized: "Output", bundle: .module)
    var maxHeight: CGFloat = TerminalMetrics.maxHeight
    var isCollapsible: Bool = true
    var showTimestamps: Bool = false
    var isDocked: Bool = false
    var contentInset: CGFloat = Spacing.md
    var wrapsLines: Bool = true
    let externalIsExpanded: Binding<Bool>?
    let headerAccessory: HeaderAccessory

    @State private var internalIsExpanded = true
    @Environment(\.colorScheme) private var colorScheme

    /// - Parameters:
    ///   - lines: The output.
    ///   - title: The header's title.
    ///   - maxHeight: The body's height cap; past it the output scrolls.
    ///   - isCollapsible: A chevron that folds the body under the header.
    ///   - showTimestamps: A time column before each line.
    ///   - isDocked: Flush along a pane's bottom, square, with a hairline on top.
    ///   - contentInset: The horizontal inset of the header and the lines.
    ///   - isExpanded: Whether the body shows; nil lets the view keep it.
    ///   - wrapsLines: Long lines wrap; false scrolls them sideways.
    ///   - headerAccessory: Clear, Copy all or Save in the header.
    public init(
        lines: [TerminalOutputLine],
        title: String = String(localized: "Output", bundle: .blissUI),
        maxHeight: CGFloat = TerminalMetrics.maxHeight,
        isCollapsible: Bool = true,
        showTimestamps: Bool = false,
        isDocked: Bool = false,
        contentInset: CGFloat = Spacing.md,
        isExpanded: Binding<Bool>? = nil,
        wrapsLines: Bool = true,
        @ViewBuilder headerAccessory: () -> HeaderAccessory
    ) {
        self.lines = lines
        self.title = title
        self.maxHeight = maxHeight
        self.isCollapsible = isCollapsible
        self.showTimestamps = showTimestamps
        self.isDocked = isDocked
        self.contentInset = contentInset
        self.externalIsExpanded = isExpanded
        self.wrapsLines = wrapsLines
        self.headerAccessory = headerAccessory()
    }

    private var isExpanded: Binding<Bool> { externalIsExpanded ?? $internalIsExpanded }

    /// Square when docked: it meets the pane's edges.
    private var cornerRadius: CGFloat { isDocked ? 0 : Sizing.textBoxCornerRadius }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with expand/collapse toggle
            headerView

            // Terminal content
            if isExpanded.wrappedValue {
                terminalContent
                    .frame(maxHeight: maxHeight)
                    .transition(.motion(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    )))
            }
        }
        // Docked, no fill: the pane it's docked in shows through, so the log
        // reads on the regular content background. As a box, the resting fill
        // every box has. A hairline around the box, or along the top edge
        // when docked.
        .background {
            if !isDocked {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.restingFill)
            }
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
        HStack(spacing: Spacing.sm) {
            // Terminal icon
            Image(systemName: "terminal")
                .font(Typography.labelXSmall)
                .foregroundStyle(.secondary)

            Text(title)
                .font(Typography.captionSmallSemibold)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            headerAccessory

            // Line count badge
            if !lines.isEmpty {
                Badge(.verbatim(String(localized: "\(lines.count) line\(lines.count == 1 ? "" : "s")", bundle: .module)))
                    .badgeStyle(.secondary)
                    .badgeSize(.small)
            }

            // Expand/collapse button
            if isCollapsible {
                HoverIconButton(
                    systemImage: isExpanded.wrappedValue ? "chevron.up" : "chevron.down",
                    help: isExpanded.wrappedValue
                        ? String(localized: "Collapse output", bundle: .module)
                        : String(localized: "Expand output", bundle: .module)
                ) {
                    withAnimation(Animations.accordion) {
                        isExpanded.wrappedValue.toggle()
                    }
                }
                .accessibilityValue(isExpanded.wrappedValue ? Text("Expanded", bundle: .module) : Text("Collapsed", bundle: .module))
            }
        }
        .padding(.horizontal, contentInset)
        .padding(.vertical, Spacing.sm)
        .background {
            // A step above the body: the shared band.
            RowTint.band(colorScheme)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: isExpanded.wrappedValue ? 0 : cornerRadius,
                bottomTrailingRadius: isExpanded.wrappedValue ? 0 : cornerRadius,
                topTrailingRadius: cornerRadius
            )
        )
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        ScrollViewReader { proxy in
            ScrollView(wrapsLines ? .vertical : [.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: TerminalMetrics.lineSpacing) {
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
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: lines.count) { _, newCount in
                // Auto-scroll to bottom when new lines are added
                guard newCount > 0 else { return }
                withAnimation(prefersReducedMotion ? nil : Animations.scrollIndicator) {
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
        HStack(alignment: .top, spacing: Spacing.sm) {
            if showTimestamps {
                Text(line.timestamp, format: .dateTime.hour().minute().second())
                    .font(Typography.codeSmall)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: TerminalMetrics.timestampWidth, alignment: .leading)
            }

            Text(line.text)
                .font(Typography.codeSmall)
                .foregroundStyle(colorForLineType(line.type))
                .textSelection(.enabled)
                .lineLimit(wrapsLines ? nil : 1)
                .fixedSize(horizontal: !wrapsLines, vertical: true)
                .frame(maxWidth: wrapsLines ? .infinity : nil, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack {
            Spacer()
            Text("Waiting for output...", bundle: .module)
                .font(Typography.codeSmall)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .padding(.vertical, Spacing.lg)
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

// MARK: - Convenience Initializers

extension TerminalOutputView where HeaderAccessory == EmptyView {
    /// A console with no header accessory.
    public init(
        lines: [TerminalOutputLine],
        title: String = String(localized: "Output", bundle: .blissUI),
        maxHeight: CGFloat = TerminalMetrics.maxHeight,
        isCollapsible: Bool = true,
        showTimestamps: Bool = false,
        isDocked: Bool = false,
        contentInset: CGFloat = Spacing.md,
        isExpanded: Binding<Bool>? = nil,
        wrapsLines: Bool = true
    ) {
        self.init(
            lines: lines,
            title: title,
            maxHeight: maxHeight,
            isCollapsible: isCollapsible,
            showTimestamps: showTimestamps,
            isDocked: isDocked,
            contentInset: contentInset,
            isExpanded: isExpanded,
            wrapsLines: wrapsLines,
            headerAccessory: { EmptyView() }
        )
    }

    /// Create a terminal view from an array of strings (all treated as stdout)
    public init(output: [String], title: String = String(localized: "Output", bundle: .blissUI), maxHeight: CGFloat = TerminalMetrics.maxHeight) {
        self.init(lines: output.map { TerminalOutputLine($0, type: .stdout) }, title: title, maxHeight: maxHeight)
    }
}

// MARK: - Previews

#Preview("Empty State", traits: .fixedLayout(width: 520, height: 140)) {
    TerminalOutputView(lines: [])
        .padding()
}

#Preview("With Output", traits: .fixedLayout(width: 520, height: 280)) {
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
    ) {
        HoverIconButton(systemImage: "trash", help: "Clear") {}
    }
    .padding()
}

#Preview("With Errors", traits: .fixedLayout(width: 520, height: 260)) {
    TerminalOutputView(
        lines: [
            TerminalOutputLine("$ swift build", type: .system),
            TerminalOutputLine("Fetching https://github.com/example/demo-kit.git"),
            TerminalOutputLine("error: Dependencies could not be resolved because no versions of 'demo-kit' match the requirement 2.0.0..<3.0.0.", type: .stderr),
            TerminalOutputLine("  'demo' depends on 'demo-kit' 2.0.0..<3.0.0", type: .stderr),
        ],
        title: "Build Output",
        wrapsLines: false
    )
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

#Preview("With Timestamps", traits: .fixedLayout(width: 600, height: 240)) {
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
    .padding()
}
