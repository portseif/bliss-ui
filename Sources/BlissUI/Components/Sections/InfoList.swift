//
//  InfoList.swift
//  BlissUI
//
//  Rows for a `RoundedSection` of facts: a labeled value, a hint, a status
//  line with an icon, a branch name, or any view.
//

import SwiftUI

/// A single row in an info list
public struct InfoRow: View, Identifiable {
    public let id = UUID()
    private let rowContent: InfoRowContent

    public var body: some View {
        switch rowContent {
        case .labeled(let label, let value):
            LabeledContent(label, value: value)
                .font(Typography.bodySmall)

        case .hint(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

        case .status(let text, let icon, let style, let detail):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                BlissSymbol(icon)
                    .font(Typography.caption)
                    .foregroundStyle(style.color)
                VStack(alignment: .leading, spacing: Spacing.headingSpacing) {
                    Text(text)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    if let detail {
                        Text(detail)
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

        case .branch(let branch):
            HStack {
                Spacer()
                HStack(spacing: Spacing.xxs) {
                    BlissSymbol("arrow.triangle.branch")
                        .font(Typography.captionTiny)
                    Text(branch)
                        .font(Typography.codeTiny)
                }
                .foregroundStyle(.secondary)
            }

        case .custom(let view):
            view
        }
    }

    // Factory methods
    public static func labeled(_ label: LocalizedStringKey, value: String) -> InfoRow {
        InfoRow(rowContent: .labeled(label: label, value: value))
    }

    public static func hint(_ text: LocalizedStringKey) -> InfoRow {
        InfoRow(rowContent: .hint(text: text))
    }

    /// A status line: an icon in the status color, the text, and an optional
    /// tertiary detail under it ("Last checked 2m ago").
    public static func status(_ text: LocalizedStringKey, icon: String, style: StatusStyle = .secondary, detail: LocalizedStringKey? = nil) -> InfoRow {
        InfoRow(rowContent: .status(text: text, icon: icon, style: style, detail: detail))
    }

    public static func branch(_ branch: String) -> InfoRow {
        InfoRow(rowContent: .branch(branch: branch))
    }

    public static func custom<Content: View>(@ViewBuilder content: () -> Content) -> InfoRow {
        InfoRow(customContent: content())
    }

    // Private storage
    private enum InfoRowContent {
        case labeled(label: LocalizedStringKey, value: String)
        case hint(text: LocalizedStringKey)
        case status(text: LocalizedStringKey, icon: String, style: StatusStyle, detail: LocalizedStringKey?)
        case branch(branch: String)
        case custom(view: CustomViewWrapper)
    }

    // Type-erased wrapper that avoids AnyView in hot paths
    private struct CustomViewWrapper: View {
        private let _body: () -> AnyView

        init<Content: View>(_ content: Content) {
            self._body = { AnyView(content) }
        }

        var body: some View {
            _body()
        }
    }

    private init(rowContent: InfoRowContent) {
        self.rowContent = rowContent
    }

    // Allow custom view wrapper initialization
    private init<Content: View>(customContent: Content) {
        self.rowContent = .custom(view: CustomViewWrapper(customContent))
    }
}

// MARK: - Supporting Types

/// A status row's color: one of the status marks, or the secondary tone.
public enum StatusStyle {
    case success
    case warning
    case error
    case secondary

    /// The row style for a `StatusKind`; info takes the secondary tone.
    public init(_ kind: StatusKind) {
        switch kind {
        case .success: self = .success
        case .warning: self = .warning
        case .danger: self = .error
        case .info: self = .secondary
        }
    }

    /// The `StatusKind` this maps to; nil for `.secondary`.
    public var kind: StatusKind? {
        switch self {
        case .success: .success
        case .warning: .warning
        case .error: .danger
        case .secondary: nil
        }
    }

    public var color: Color {
        switch self {
        case .success: return Success.success500
        case .warning: return Warning.warning500
        case .error: return Danger.danger500
        case .secondary: return .secondary
        }
    }
}

// MARK: - Preview

#Preview(traits: .fixedLayout(width: 420, height: 420)) {
    SettingsForm {
        RoundedSection("Repository Info") {
            Group {
                InfoRow.labeled("Branch", value: "main")
                InfoRow.hint("No remote origin configured")
            }
        }
        RoundedSection("Status Examples") {
            Group {
                InfoRow.status("Git repository detected", icon: "checkmark.circle.fill", style: .success, detail: "Last checked 2 minutes ago")
                InfoRow.status("Warning message", icon: "exclamationmark.triangle.fill", style: .warning)
                InfoRow.status("No repository found", icon: "xmark.circle", style: .secondary)
            }
        }
        RoundedSection("Custom Content") {
            Group {
                InfoRow.custom {
                    LabeledContent("Custom") {
                        HStack(spacing: Spacing.xxs) {
                            BlissSymbol("arrow.triangle.branch")
                                .font(Typography.caption)
                            Text("feature/new-ui")
                                .font(Typography.codeSmall)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    .frame(width: 400)
}
