//
//  ShortcutRecorder.swift
//  BlissUI
//
//  A control that records a key combination: click it (or Space / Return
//  while it has the ring) and press the combo. It shows "Press a shortcut"
//  with the modifiers you're holding until a key lands, then the combo as a
//  `ShortcutKey`.
//
//  - Esc cancels, Delete / Backspace clears (also while it's focused and not
//    recording), Tab leaves it. A click anywhere else, or the window losing
//    key, cancels too.
//  - A combo needs ⌘, ⌥ or ⌃ — a bare key, or one with only ⇧, types text —
//    except a function key, which stands on its own. A refused combo beeps
//    and shows itself in `Danger` for a moment.
//  - Keys are caught by a local key monitor while recording, which sees them
//    before the menu bar does: ⌘Q records instead of quitting.
//

import AppKit
import SwiftUI

// MARK: - Keyboard Shortcut Value

/// A key combination: modifiers plus one key. `Codable`, to keep in settings;
/// `keyboardShortcut` hands it to SwiftUI's `.keyboardShortcut(_:)`.
///
/// ```swift
/// @AppStorage("toggleSidebarShortcut") var stored = Data()
/// let shortcut = try? JSONDecoder().decode(KeyboardShortcutValue.self, from: stored)
/// Button("Toggle Sidebar") { … }.keyboardShortcut(shortcut?.keyboardShortcut)
/// ```
public nonisolated struct KeyboardShortcutValue: Hashable, Sendable, Codable {
    /// The modifier keys of a combination.
    public struct Modifiers: OptionSet, Hashable, Sendable, Codable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)

        /// The modifiers held in `flags` (Caps Lock, Fn and the keypad flag aside).
        public init(flags: NSEvent.ModifierFlags) {
            var modifiers: Modifiers = []
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.command) { modifiers.insert(.command) }
            self = modifiers
        }

        /// The glyphs in the order macOS menus show them: ⌃⌥⇧⌘.
        public var symbols: String {
            var symbols = ""
            if contains(.control) { symbols += "⌃" }
            if contains(.option) { symbols += "⌥" }
            if contains(.shift) { symbols += "⇧" }
            if contains(.command) { symbols += "⌘" }
            return symbols
        }

        /// The same modifiers as SwiftUI's `EventModifiers`.
        public var eventModifiers: EventModifiers {
            var modifiers: EventModifiers = []
            if contains(.control) { modifiers.insert(.control) }
            if contains(.option) { modifiers.insert(.option) }
            if contains(.shift) { modifiers.insert(.shift) }
            if contains(.command) { modifiers.insert(.command) }
            return modifiers
        }
    }

    /// The key a combination ends in.
    public enum Key: Hashable, Sendable, Codable {
        /// A key that types a character, stored unshifted and lowercased: "k",
        /// "1", ",". It's the character of the current keyboard layout, so an
        /// AZERTY "A" records as "a".
        case character(String)
        case `return`, tab, space, delete, forwardDelete, escape
        case upArrow, downArrow, leftArrow, rightArrow
        case home, end, pageUp, pageDown, clear
        /// F1 through F20.
        case function(Int)

        /// How the key reads on a key cap: "K", "↩", "⌫", "F5", "Space".
        public var displayName: String {
            switch self {
            case .character(let character): character.uppercased()
            case .return: "↩"
            case .tab: "⇥"
            case .space: String(localized: "Space", bundle: .module)
            case .delete: "⌫"
            case .forwardDelete: "⌦"
            case .escape: "⎋"
            case .upArrow: "↑"
            case .downArrow: "↓"
            case .leftArrow: "←"
            case .rightArrow: "→"
            case .home: "↖"
            case .end: "↘"
            case .pageUp: "⇞"
            case .pageDown: "⇟"
            case .clear: "⌧"
            case .function(let number): "F\(number)"
            }
        }

        public var isFunctionKey: Bool {
            if case .function = self { return true }
            return false
        }

        /// SwiftUI's equivalent; nil for function keys, which `KeyEquivalent`
        /// has no name for.
        public var keyEquivalent: KeyEquivalent? {
            switch self {
            case .character(let character):
                guard character.count == 1, let first = character.first else { return nil }
                return KeyEquivalent(first)
            case .return: return .return
            case .tab: return .tab
            case .space: return .space
            case .delete: return .delete
            case .forwardDelete: return .deleteForward
            case .escape: return .escape
            case .upArrow: return .upArrow
            case .downArrow: return .downArrow
            case .leftArrow: return .leftArrow
            case .rightArrow: return .rightArrow
            case .home: return .home
            case .end: return .end
            case .pageUp: return .pageUp
            case .pageDown: return .pageDown
            case .clear: return .clear
            case .function: return nil
            }
        }
    }

    public var key: Key
    public var modifiers: Modifiers

    public init(_ key: Key, modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The combination a key-down event makes; nil for an event that isn't a
    /// key press (a bare modifier, a dead key).
    public init?(event: NSEvent) {
        guard event.type == .keyDown,
              let key = Self.key(keyCode: event.keyCode, characters: event.characters(byApplyingModifiers: []))
        else { return nil }
        self.init(key, modifiers: Modifiers(flags: event.modifierFlags))
    }

    /// "⇧⌘K": the modifiers in menu order, then the key.
    public var displayString: String {
        modifiers.symbols + key.displayName
    }

    /// For `.keyboardShortcut(_:)`; nil when SwiftUI can't express the key
    /// (function keys).
    public var keyboardShortcut: KeyboardShortcut? {
        key.keyEquivalent.map { KeyboardShortcut($0, modifiers: modifiers.eventModifiers) }
    }

    /// Whether the recorder takes it: ⌘, ⌥ or ⌃ is held, or it's a function
    /// key. A bare key — or one with only ⇧ — types text.
    var isRecordable: Bool {
        !modifiers.isDisjoint(with: [.command, .option, .control]) || key.isFunctionKey
    }

    // MARK: Key Codes

    /// The key for a hardware key code, or the character it types (with no
    /// modifiers applied) for every other key.
    static func key(keyCode: UInt16, characters: String?) -> Key? {
        if let special = specialKeys[keyCode] { return special }
        if let number = functionKeyNumbers[keyCode] { return .function(number) }
        guard let characters, characters.count == 1, let character = characters.first else { return nil }
        // Control characters and AppKit's private-use function-key characters
        // (U+F700–F8FF) aren't printable keys.
        let isPrintable = character.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
        guard isPrintable, !character.isWhitespace else { return nil }
        return .character(String(character).lowercased())
    }

    /// Virtual key codes (`kVK_*`), the same on every layout.
    private static let specialKeys: [UInt16: Key] = [
        36: .return, 76: .return, 48: .tab, 49: .space, 51: .delete, 117: .forwardDelete, 53: .escape,
        126: .upArrow, 125: .downArrow, 123: .leftArrow, 124: .rightArrow,
        115: .home, 119: .end, 116: .pageUp, 121: .pageDown, 71: .clear,
    ]

    private static let functionKeyNumbers: [UInt16: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10,
        103: 11, 111: 12, 105: 13, 107: 14, 113: 15, 106: 16, 64: 17, 79: 18, 80: 19, 90: 20,
    ]
}

// MARK: - Recording

/// What a key press does while recording. Pure, so it's unit-tested on its own.
nonisolated enum ShortcutRecording {
    enum Outcome: Equatable {
        /// Esc: stop, keep the old shortcut.
        case cancel
        /// Delete / Backspace: stop, no shortcut.
        case clear
        /// Tab / Shift-Tab: stop and let focus move on.
        case leave
        case record(KeyboardShortcutValue)
        /// A combo without ⌘ / ⌥ / ⌃ (and not a function key).
        case reject(KeyboardShortcutValue?)
    }

    static func outcome(keyCode: UInt16, modifiers: KeyboardShortcutValue.Modifiers, characters: String?) -> Outcome {
        switch keyCode {
        case 53 where modifiers.isEmpty: return .cancel
        case 51 where modifiers.isEmpty, 117 where modifiers.isEmpty: return .clear
        case 48 where modifiers.isSubset(of: .shift): return .leave
        default: break
        }
        guard let key = KeyboardShortcutValue.key(keyCode: keyCode, characters: characters) else { return .reject(nil) }
        let value = KeyboardShortcutValue(key, modifiers: modifiers)
        return value.isRecordable ? .record(value) : .reject(value)
    }
}

// MARK: - Shortcut Recorder

/// Records a key combination into a `KeyboardShortcutValue`.
///
/// ```swift
/// @State private var shortcut: KeyboardShortcutValue? = KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift])
///
/// ShortcutRecorder(shortcut: $shortcut)
/// ```
///
/// Click it (or Space) and press a combo with ⌘, ⌥ or ⌃ (function keys need
/// none). Esc cancels; Delete clears.
public struct ShortcutRecorder: View {
    @Binding private var shortcut: KeyboardShortcutValue?

    @State private var isRecording = false
    /// The modifiers held while recording, shown until a key lands.
    @State private var heldModifiers: KeyboardShortcutValue.Modifiers = []
    /// A refused combo, shown in `Danger` for a moment.
    @State private var rejectedCombo: String?
    @State private var rejectionGeneration = 0
    @FocusState private var isFocused: Bool

    /// - Parameter shortcut: The recorded combination; nil for none.
    public init(shortcut: Binding<KeyboardShortcutValue?>) {
        self._shortcut = shortcut
    }

    /// Room the label leaves for the trailing ✕ or esc pill.
    private let trailingReserve: CGFloat = Sizing.controlSmall

    private var showsClearButton: Bool { shortcut != nil && !isRecording }

    public var body: some View {
        Button(action: toggleRecording) {
            label
                .padding(.trailing, isRecording || showsClearButton ? trailingReserve : 0)
                .frame(minWidth: 132, alignment: .leading)
        }
        .buttonStyle(ShortcutRecorderButtonStyle(isRecording: isRecording, isFocused: $isFocused))
        .background {
            ShortcutCaptureMonitor(
                isRecording: isRecording,
                onKeyDown: handleRecordingKey,
                onModifiersChanged: { heldModifiers = KeyboardShortcutValue.Modifiers(flags: $0) },
                onCancel: stopRecording
            )
        }
        .overlay(alignment: .trailing) { trailingAccessory }
        // Delete clears while the recorder has the ring (recording, the
        // monitor has the keys first).
        .onKeyPress(keys: [.delete, .backspace, .deleteForward]) { _ in
            guard shortcut != nil else { return .ignored }
            shortcut = nil
            return .handled
        }
        .accessibilityLabel(Text("Record Shortcut", bundle: .module))
        .accessibilityValue(accessibilityValue)
    }

    /// One structure in every state, the states changing only the text and
    /// which layer shows: a focused button whose label swaps view types loses
    /// keyboard focus (it falls to the window's first text field).
    private var label: some View {
        ZStack(alignment: .leading) {
            Text(verbatim: labelText)
                .font(rejectedCombo == nil ? Typography.bodySmall : Typography.codeTiny)
                .foregroundStyle(rejectedCombo == nil ? Color.secondary : Danger.danger500)
                .opacity(keyCapText == nil ? 1 : 0)
            ShortcutKey(keyCapText ?? "")
                .opacity(keyCapText == nil ? 0 : 1)
        }
    }

    /// The prompt, or a refused combo.
    private var labelText: String {
        if isRecording {
            return rejectedCombo ?? String(localized: "Press a shortcut", bundle: .module)
        }
        return String(localized: "Record Shortcut", bundle: .module)
    }

    /// The key cap: the held modifiers while recording, else the shortcut.
    private var keyCapText: String? {
        if isRecording {
            return rejectedCombo == nil && !heldModifiers.isEmpty ? heldModifiers.symbols : nil
        }
        return shortcut?.displayString
    }

    /// While recording, the key that cancels; with a shortcut, the ✕ that
    /// clears it (a Tab stop of its own, with its tooltip as its label).
    @ViewBuilder
    private var trailingAccessory: some View {
        if isRecording {
            ShortcutKey("esc")
                .padding(.trailing, Spacing.xs)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else if shortcut != nil {
            HoverIconButton(
                systemImage: "xmark.circle.fill",
                help: String(localized: "Clear Shortcut", bundle: .module)
            ) {
                shortcut = nil
                // The ✕ leaves with the shortcut; keep the keys on the
                // recorder rather than letting focus fall through the window.
                isFocused = true
            }
            .padding(.trailing, Spacing.xxs)
        }
    }

    private var accessibilityValue: Text {
        if isRecording { return Text("Press a shortcut", bundle: .module) }
        return Text(verbatim: shortcut?.displayString ?? "")
    }

    // MARK: Recording

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            rejectedCombo = nil
            heldModifiers = []
            isRecording = true
        }
    }

    private func stopRecording() {
        isRecording = false
        heldModifiers = []
        rejectedCombo = nil
    }

    /// Every key press while recording lands here before the window or the
    /// menu bar sees it; nil swallows it.
    private func handleRecordingKey(_ event: NSEvent) -> NSEvent? {
        guard !event.isARepeat else { return nil }
        let outcome = ShortcutRecording.outcome(
            keyCode: event.keyCode,
            modifiers: KeyboardShortcutValue.Modifiers(flags: event.modifierFlags),
            characters: event.characters(byApplyingModifiers: [])
        )
        switch outcome {
        case .cancel:
            stopRecording()
        case .clear:
            shortcut = nil
            stopRecording()
        case .leave:
            stopRecording()
            return event
        case .record(let value):
            shortcut = value
            stopRecording()
        case .reject(let value):
            reject(value)
        }
        return nil
    }

    private func reject(_ value: KeyboardShortcutValue?) {
        NSSound.beep()
        guard let value else { return }
        rejectionGeneration += 1
        let generation = rejectionGeneration
        rejectedCombo = value.displayString
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard generation == rejectionGeneration else { return }
            withAnimation(Animations.hover) { rejectedCombo = nil }
        }
    }
}

// MARK: - Button Style

/// The recorder's box: the input box's resting fill and hairline, `RowTint`
/// hover, and the shared ring — after keyboard input while idle, always while
/// recording (it's taking keys, like a focused field).
private struct ShortcutRecorderButtonStyle: ButtonStyle {
    let isRecording: Bool
    let isFocused: FocusState<Bool>.Binding

    func makeBody(configuration: Configuration) -> some View {
        ShortcutRecorderChrome(configuration: configuration, isRecording: isRecording, isFocused: isFocused)
    }
}

private struct ShortcutRecorderChrome: View {
    let configuration: ButtonStyleConfiguration
    let isRecording: Bool
    let isFocused: FocusState<Bool>.Binding
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Sizing.radiusMedium, style: .continuous)
    }

    private var fill: Color {
        if isRecording { return Color.controlBackground }
        if configuration.isPressed { return RowTint.selected(colorScheme) }
        if isHovering { return RowTint.hover(colorScheme) }
        return Color.primary.opacity(0.04)
    }

    var body: some View {
        configuration.label
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: Sizing.controlDefault)
            .background { shape.fill(fill) }
            .overlay { shape.strokeBorder(Color.menuBorder, lineWidth: 1) }
            .focusRing(
                isFocused: isFocused.wrappedValue || isRecording,
                cornerRadius: Sizing.radiusMedium,
                showsOnPointerFocus: isRecording
            )
            .contentShape(shape)
            .focusable()
            .focused(isFocused)
            .focusEffectDisabled()
            .onHover { isHovering = isEnabled && $0 }
            .opacity(isEnabled ? 1 : 0.5)
            .animation(Animations.hover, value: isHovering)
            .animation(Animations.press, value: configuration.isPressed)
    }
}

// MARK: - Key Capture

/// The AppKit side of recording: while `isRecording`, a local key monitor
/// hands every key-down to `onKeyDown` (and modifier changes to
/// `onModifiersChanged`), and a click outside the recorder or the window
/// losing key calls `onCancel`. Sits behind the recorder, sized to it, so it
/// knows where "outside" is; `dismantleNSView` removes the monitors.
private struct ShortcutCaptureMonitor: NSViewRepresentable {
    let isRecording: Bool
    let onKeyDown: (NSEvent) -> NSEvent?
    let onModifiersChanged: (NSEvent.ModifierFlags) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        PassthroughView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onKeyDown = onKeyDown
        coordinator.onModifiersChanged = onModifiersChanged
        coordinator.onCancel = onCancel
        if isRecording {
            coordinator.start(over: view)
        } else {
            coordinator.stop()
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Never takes a click: the button above it does.
    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    final class Coordinator {
        var onKeyDown: ((NSEvent) -> NSEvent?)?
        var onModifiersChanged: ((NSEvent.ModifierFlags) -> Void)?
        var onCancel: (() -> Void)?

        private weak var anchor: NSView?
        private var keyMonitor: Any?
        private var mouseMonitor: Any?
        private var resignObserver: NSObjectProtocol?

        func start(over anchor: NSView) {
            guard keyMonitor == nil else { return }
            self.anchor = anchor
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self else { return event }
                if event.type == .flagsChanged {
                    self.onModifiersChanged?(event.modifierFlags)
                    return event
                }
                guard let onKeyDown = self.onKeyDown else { return event }
                return onKeyDown(event)
            }
            // A click elsewhere cancels and still lands where it was aimed.
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self, let anchor = self.anchor else { return event }
                let isOnRecorder = event.window === anchor.window
                    && anchor.convert(anchor.bounds, to: nil).contains(event.locationInWindow)
                if !isOnRecorder { self.onCancel?() }
                return event
            }
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: anchor.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onCancel?() }
            }
        }

        func stop() {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
            keyMonitor = nil
            mouseMonitor = nil
            resignObserver = nil
            anchor = nil
        }
    }
}

// MARK: - Preview

private struct ShortcutRecorderPreviewHost: View {
    @State private var shortcut: KeyboardShortcutValue? = KeyboardShortcutValue(.character("k"), modifiers: [.command, .shift])
    @State private var emptyShortcut: KeyboardShortcutValue?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ShortcutRecorder(shortcut: $shortcut)
            ShortcutRecorder(shortcut: $emptyShortcut)
        }
        .padding(Spacing.xl)
    }
}

#Preview(traits: .fixedLayout(width: 280, height: 140)) {
    ShortcutRecorderPreviewHost()
}
