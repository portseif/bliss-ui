//
//  ToastData.swift
//  BlissUI
//
//  The toast model: its style, inline segments, actions, per-item failures and
//  the rows of an expanded in-progress card.
//

import SwiftUI

/// The type/style of toast notification
public enum ToastStyle: Equatable {
    case success
    case error
    /// Completed-but-incomplete: the operation finished, but some items were skipped
    /// (e.g. an import that dropped malformed rows). Amber, non-auto-dismiss,
    /// expandable to the per-item failures — louder than success, calmer than error.
    case warning
    case info
    case inProgress
    case progress(Double)  // 0.0 to 1.0

    /// Still running (progress ticks update the toast in place).
    public var isOngoing: Bool {
        switch self {
        case .inProgress, .progress: return true
        default: return false
        }
    }

    /// The style's SF Symbol (filled), for UI outside the pill.
    public var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error, .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .inProgress, .progress: return "arrow.triangle.2.circlepath"
        }
    }

    /// Bare glyph (no `.fill` chrome) shown white inside the filled status circle.
    public var glyph: String {
        switch self {
        case .success: return "checkmark"
        case .error, .warning: return "exclamationmark"
        case .info: return "info"
        case .inProgress, .progress: return "arrow.triangle.2.circlepath"
        }
    }

    public var iconColor: Color {
        switch self {
        case .success: return Success.success500
        case .error: return Danger.danger500
        case .warning: return Warning.warning500
        case .info: return Info.info500
            case .inProgress, .progress: return Color.accent
        }
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        let opacity = colorScheme == .dark ? 0.4 : 0.25
        switch self {
        case .success: return Success.tint.opacity(opacity)
        case .error: return Danger.tint.opacity(opacity)
        case .warning: return Warning.tint.opacity(opacity)
        case .info, .inProgress, .progress: return Color.accent.opacity(opacity)
        }
    }

    public var isInProgress: Bool {
        switch self {
        case .inProgress, .progress: return true
        default: return false
        }
    }

    /// The fraction done (0…1) of a `.progress` toast; nil for every other style.
    public var progressValue: Double? {
        if case .progress(let value) = self {
            return value
        }
        return nil
    }

    public static func == (lhs: ToastStyle, rhs: ToastStyle) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success), (.error, .error), (.warning, .warning), (.info, .info), (.inProgress, .inProgress):
            return true
        case (.progress(let a), .progress(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Action button for toast notifications
public struct ToastAction: Equatable, Identifiable {
    public let id: UUID
    public let label: String
    /// SF Symbol name.
    public let icon: String?
    public let action: () -> Void

    public init(id: UUID = UUID(), label: String, icon: String? = nil, action: @escaping () -> Void) {
        self.id = id
        self.label = label
        self.icon = icon
        self.action = action
    }

    public static func == (lhs: ToastAction, rhs: ToastAction) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.icon == rhs.icon
    }
}

/// One inline detail segment rendered after the title as `· text`. `isProminent`
/// renders it bright (e.g. a result count) vs. dim (timestamps, context).
public struct ToastSegment: Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public var isProminent: Bool

    public init(id: UUID = UUID(), _ text: String, isProminent: Bool = false) {
        self.id = id
        self.text = text
        self.isProminent = isProminent
    }
}

/// A single failed item shown as a row in the details popover.
public struct ToastFailure: Equatable, Identifiable {
    public let id: UUID
    /// File path or item identifier (e.g. `storage/uploads/2024/q4-report-final.pdf`).
    public let path: String
    /// Short error code (e.g. `EACCES`, `ETIMEDOUT`).
    public let code: String
    /// Human-readable failure reason.
    public let message: String

    public init(id: UUID = UUID(), path: String, code: String, message: String) {
        self.id = id
        self.path = path
        self.code = code
        self.message = message
    }
}

/// One structured row in an in-progress toast's expanded card (e.g. a batch job's
/// per-item status). The current (`working`) item shimmers; `done` items render
/// their result text in a mono message card.
public struct ToastDetailItem: Equatable, Identifiable {
    public enum ItemState: Equatable {
        case pending
        case working
        case done
        case failed
    }

    public let id: String
    public let name: String
    public let state: ItemState
    /// Working: the current phase ("writing summary"); done: the full result
    /// text (e.g. a generated summary); failed: an optional reason.
    public var text: String? = nil

    public init(id: String, name: String, state: ItemState, text: String? = nil) {
        self.id = id
        self.name = name
        self.state = state
        self.text = text
    }
}

/// Data model for a toast notification
public struct ToastData: Equatable, Identifiable {
    public let id: UUID
    public var title: String
    public var message: String
    public var style: ToastStyle
    /// SF Symbol shown in place of the style's glyph.
    public var customIcon: String?
    /// Full error message for viewing details (optional - used when message is truncated)
    public var fullMessage: String?
    /// Action buttons to display on the toast
    public var actions: [ToastAction]
    /// When set on an in-progress toast, the toast shows a live elapsed timer ticking
    /// from this instant. Lets a slow step read as "still working" rather than "frozen".
    public var startedAt: Date?
    /// Inline detail segments rendered after the title (`· seg · seg`). When empty, the
    /// pill falls back to showing `message` as a single dim segment.
    public var segments: [ToastSegment]
    /// Structured per-item failures shown in the details popover (errors only).
    public var failures: [ToastFailure]
    /// Total item count, for the popover's "N / M OK" summary (paired with `failures`).
    public var totalItems: Int?
    /// When the failure happened, for the popover's live "Failed m:ss ago" line.
    public var failedAt: Date?
    /// Structured per-item rows for the expanded in-progress card (replaces the
    /// plain `fullMessage` text when present).
    public var detailItems: [ToastDetailItem]
    /// Tap-anywhere handler. When set, clicking the pill runs this INSTEAD of
    /// the expand accordion (e.g. a minimized task's toast reopening its
    /// sheet). Excluded from equality.
    public var primaryAction: (() -> Void)?

    public static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.message == rhs.message
            && lhs.style == rhs.style
            && lhs.customIcon == rhs.customIcon
            && lhs.fullMessage == rhs.fullMessage
            && lhs.actions == rhs.actions
            && lhs.startedAt == rhs.startedAt
            && lhs.segments == rhs.segments
            && lhs.failures == rhs.failures
            && lhs.totalItems == rhs.totalItems
            && lhs.failedAt == rhs.failedAt
            && lhs.detailItems == rhs.detailItems
    }

    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        style: ToastStyle,
        customIcon: String? = nil,
        fullMessage: String? = nil,
        actions: [ToastAction] = [],
        startedAt: Date? = nil,
        segments: [ToastSegment] = [],
        failures: [ToastFailure] = [],
        totalItems: Int? = nil,
        failedAt: Date? = nil,
        detailItems: [ToastDetailItem] = [],
        primaryAction: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.style = style
        self.customIcon = customIcon
        self.fullMessage = fullMessage
        self.actions = actions
        self.startedAt = startedAt
        self.segments = segments
        self.failures = failures
        self.totalItems = totalItems
        self.failedAt = failedAt
        self.detailItems = detailItems
        self.primaryAction = primaryAction
    }

    /// Whether there are additional details worth a "Details" disclosure + popover.
    public var hasDetails: Bool {
        if !failures.isEmpty { return true }
        guard let fullMessage = fullMessage else { return false }
        return fullMessage.count > 60 || fullMessage.contains("\n")
    }

    public static func success(title: String, message: String, icon: String? = nil, segments: [ToastSegment] = [], actions: [ToastAction] = []) -> ToastData {
        ToastData(title: title, message: message, style: .success, customIcon: icon, actions: actions, segments: segments)
    }

    public static func error(title: String, message: String, icon: String? = nil, fullMessage: String? = nil, segments: [ToastSegment] = [], failures: [ToastFailure] = [], totalItems: Int? = nil, failedAt: Date? = nil, actions: [ToastAction] = []) -> ToastData {
        ToastData(title: title, message: message, style: .error, customIcon: icon, fullMessage: fullMessage ?? message, actions: actions, segments: segments, failures: failures, totalItems: totalItems, failedAt: failedAt)
    }

    /// Completed-with-skips toast (amber). Same expandable body as `.error` — per-item
    /// `failures` render as rows, `segments` label the pill (e.g. "contacts · 3 rows skipped").
    public static func warning(title: String, message: String, icon: String? = nil, fullMessage: String? = nil, segments: [ToastSegment] = [], failures: [ToastFailure] = [], totalItems: Int? = nil, actions: [ToastAction] = []) -> ToastData {
        ToastData(title: title, message: message, style: .warning, customIcon: icon, fullMessage: fullMessage ?? message, actions: actions, segments: segments, failures: failures, totalItems: totalItems)
    }

    public static func info(title: String, message: String, icon: String? = nil, segments: [ToastSegment] = [], actions: [ToastAction] = []) -> ToastData {
        ToastData(title: title, message: message, style: .info, customIcon: icon, actions: actions, segments: segments)
    }

    public static func inProgress(title: String, message: String, icon: String? = nil) -> ToastData {
        ToastData(title: title, message: message, style: .inProgress, customIcon: icon)
    }

    public static func progress(title: String, message: String, progress: Double, icon: String? = nil) -> ToastData {
        ToastData(title: title, message: message, style: .progress(progress), customIcon: icon)
    }
}
