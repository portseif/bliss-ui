//
//  InfoList.swift
//  BlissUI
//
//  Created by Chris Seifert on 12/8/25.
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

        case .hint(let text):
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)

        case .status(let text, let icon, let style):
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(style.color)
                Text(text)
                    .foregroundStyle(.secondary)
            }

        case .branch(let branch):
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
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

    public static func status(_ text: LocalizedStringKey, icon: String, style: StatusStyle = .secondary) -> InfoRow {
        InfoRow(rowContent: .status(text: text, icon: icon, style: style))
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
        case status(text: LocalizedStringKey, icon: String, style: StatusStyle)
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

public enum StatusStyle {
    case success
    case warning
    case error
    case secondary

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

#Preview {
    SettingsForm {
        RoundedSection("Repository Info") {
            Group {
                InfoRow.labeled("Branch", value: "main")
                InfoRow.hint("No remote origin configured")
            }
        }
        RoundedSection("Status Examples") {
            Group {
                InfoRow.status("Git repository detected", icon: "checkmark.circle.fill", style: .success)
                InfoRow.status("Warning message", icon: "exclamationmark.triangle.fill", style: .warning)
                InfoRow.status("No repository found", icon: "xmark.circle", style: .secondary)
            }
        }
        RoundedSection("Custom Content") {
            Group {
                InfoRow.custom {
                    LabeledContent("Custom") {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
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
