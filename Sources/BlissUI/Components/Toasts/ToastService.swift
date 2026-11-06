//
//  ToastService.swift
//  BlissUI
//
//  The app-wide toast stack. Show, update, dismiss and cancel toasts here;
//  `.globalToast()` at the window root draws them.
//

import Combine
import SwiftUI

// MARK: - Global Toast Service

/// Centralized service for showing toast notifications at the app window level.
/// Toasts STACK: each new one goes on top of the deck (index 0 is the front
/// card), and showing a toast with an id that's already up updates it in place
/// — that's how a progress toast ticks. An operation that shows progress
/// dismisses its own toast when it ends (`dismiss(id:)`), usually from a
/// `defer`, since its result arrives as a separate toast.
@MainActor
public class ToastService: ObservableObject {
    public static let shared = ToastService()

    /// Newest first: index 0 is the front card of the stack.
    @Published public private(set) var toasts: [ToastData] = []
    /// Toasts whose underlying operation can be cancelled from their ×.
    @Published private(set) var cancellableToastIDs: Set<UUID> = []

    /// The most toasts kept at once. Past it the oldest finished one goes; a
    /// running operation's toast only goes when every toast is one.
    public static let maxToasts = 5

    private var autoDismissTasks: [UUID: Task<Void, Never>] = [:]
    /// Actions that cancel the operation feeding a toast (e.g. an in-flight upload).
    private var cancelHandlers: [UUID: () -> Void] = [:]
    /// While the pointer is over the stack, toasts that run out of time wait
    /// here instead of leaving from under it.
    private var isPaused = false
    private var expiredWhilePaused: Set<UUID> = []

    private init() {}

    /// Puts `toast` on top of the stack, or updates it in place when a toast with
    /// its id is already up. Success and info toasts leave after
    /// `autoDismissDelay`; pass `autoDismiss` to force that on or off.
    public func show(_ toast: ToastData, autoDismissDelay: TimeInterval = 3.0, autoDismiss: Bool? = nil) {
        if let index = toasts.firstIndex(where: { $0.id == toast.id }) {
            // A progress tick updates in place; announce only when it turns into a result.
            if toasts[index].style.isOngoing && !toast.style.isOngoing { announce(toast) }
            toasts[index] = toast
        } else {
            toasts.insert(toast, at: 0)
            trimToLimit()
            announce(toast)
        }

        autoDismissTasks.removeValue(forKey: toast.id)?.cancel()
        expiredWhilePaused.remove(toast.id)

        // Auto-dismiss success/info toasts by default; callers can force it on/off
        // (e.g. a persistent "Update ready · Review" toast passes `false`).
        let shouldAutoDismiss = autoDismiss ?? (toast.style == .success || toast.style == .info)
        guard shouldAutoDismiss else { return }
        let id = toast.id
        autoDismissTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if self.isPaused {
                self.expiredWhilePaused.insert(id)
            } else {
                self.dismiss(id: id)
            }
        }
    }

    /// VoiceOver reads the toast out: it's the only place a background
    /// operation's result lands, and nothing moves focus to it.
    private func announce(_ toast: ToastData) {
        let text = [toast.title, toast.message].filter { !$0.isEmpty }.joined(separator: ". ")
        guard !text.isEmpty, let window = NSApp.mainWindow ?? NSApp.keyWindow else { return }
        let priority: NSAccessibilityPriorityLevel = (toast.style == .error || toast.style == .warning) ? .high : .medium
        NSAccessibility.post(
            element: window,
            notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: priority.rawValue]
        )
    }

    public func showSuccess(title: String, message: String, icon: String? = nil, actions: [ToastAction] = []) {
        show(.success(title: title, message: message, icon: icon, actions: actions))
    }

    public func showError(title: String, message: String, icon: String? = nil, fullMessage: String? = nil, actions: [ToastAction] = []) {
        show(.error(title: title, message: message, icon: icon, fullMessage: fullMessage, actions: actions))
    }

    public func showInfo(title: String, message: String, icon: String? = nil, actions: [ToastAction] = []) {
        show(.info(title: title, message: message, icon: icon, actions: actions))
    }

    public func showProgress(title: String, message: String, progress: Double, icon: String? = nil) {
        show(.progress(title: title, message: message, progress: progress, icon: icon))
    }

    /// Takes one toast off the stack (no-op if it's already gone).
    public func dismiss(id: UUID) {
        autoDismissTasks.removeValue(forKey: id)?.cancel()
        cancelHandlers[id] = nil
        cancellableToastIDs.remove(id)
        expiredWhilePaused.remove(id)
        toasts.removeAll { $0.id == id }
        // The last toast closed under the pointer: the stack goes away without a
        // hover exit, so nothing would lift the pause for the toasts that follow.
        if toasts.isEmpty {
            isPaused = false
            expiredWhilePaused.removeAll()
        }
    }

    /// Holds expiring toasts while the pointer is over the stack; letting go
    /// dismisses the ones whose time ran out meanwhile.
    func setPaused(_ paused: Bool) {
        isPaused = paused
        guard !paused else { return }
        for id in expiredWhilePaused {
            dismiss(id: id)
        }
    }

    private func trimToLimit() {
        while toasts.count > Self.maxToasts, let oldest = toasts.last(where: { !$0.style.isInProgress }) ?? toasts.last {
            dismiss(id: oldest.id)
        }
    }

    // MARK: - Cancellable operations

    /// Register a cancel action for the operation feeding `toastId`. While set, the
    /// toast shows an × that runs `handler` (after a confirmation).
    public func registerCancel(for toastId: UUID, handler: @escaping () -> Void) {
        cancelHandlers[toastId] = handler
        cancellableToastIDs.insert(toastId)
    }

    /// Clear the cancel action for `toastId`.
    public func clearCancel(for toastId: UUID) {
        cancelHandlers[toastId] = nil
        cancellableToastIDs.remove(toastId)
    }

    public func isCancellable(_ toastId: UUID) -> Bool {
        cancellableToastIDs.contains(toastId)
    }

    /// Run the registered cancel action for `toastId`, if any.
    public func cancel(_ toastId: UUID) {
        let handler = cancelHandlers[toastId]
        clearCancel(for: toastId)
        handler?()
    }
}
