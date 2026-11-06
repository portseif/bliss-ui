//
//  TextArea.swift
//  BlissUI
//
//  Multi-line text input in the shared input box:
//  - Grows with its text between a minimum and maximum number of lines, then
//    scrolls with the thin overlay indicator instead of a native scroller
//  - A placeholder, and an optional character limit with a count
//  - Tab moves to the next control like any form field; ⌥Tab types a tab
//
//  Built on an `NSTextView` rather than `TextEditor`: `TextEditor` exposes
//  neither its content height (so it can't hug its text exactly) nor its
//  scroll position (so it can't draw the thin indicator), and its scroll view
//  shows the wide legacy scroller under "Show scroll bars: Always".
//

import AppKit
import SwiftUI

/// A multi-line text field that grows with its text.
///
/// ```swift
/// TextArea("Notes", text: $notes, prompt: Text("Add a note…"))
/// TextArea("Bio", text: $bio, lineLimit: 2...5, characterLimit: 160)
/// TextArea("Ignore file", text: $template, prompt: Text("/node_modules"), monospaced: true)
/// ```
///
/// `title` is what VoiceOver reads; it isn't drawn. It's a
/// `LocalizedStringResource` (a string literal, looked up in your app's
/// strings) rather than a `LocalizedStringKey` because the text view is
/// AppKit's and needs its label as a resolved string — a SwiftUI
/// `.accessibilityLabel` doesn't reach a hosted `NSTextView`.
///
/// The field fills the width it's given and is as tall as its text, between
/// `lineLimit.lowerBound` and `lineLimit.upperBound` lines; past that it
/// scrolls. With a `characterLimit`, typing and pasting stop at the limit (a
/// paste keeps what fits) and a count shows under the text.
public struct TextArea: View {
    private let title: LocalizedStringResource
    @Binding private var text: String
    private let prompt: Text?
    private let lineLimit: ClosedRange<Int>
    private let characterLimit: Int?
    private let showsCharacterCount: Bool
    private let fontStyle: TextAreaFontStyle

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFocused = false
    /// Bumped to put the caret in the text view (a click on the box's padding).
    @State private var focusRequest = 0
    @State private var scrollMetrics = TextAreaScrollMetrics()
    @State private var isHovering = false
    @State private var isScrolling = false
    @State private var scrollEndTask: Task<Void, Never>?

    /// - Parameters:
    ///   - title: What VoiceOver reads for the field.
    ///   - text: The text.
    ///   - prompt: Shown while the text is empty.
    ///   - lineLimit: How many lines tall it is when empty, and how many it
    ///     grows to before it scrolls.
    ///   - characterLimit: The most characters it takes; nil for no limit.
    ///   - showsCharacterCount: Shows the count without a limit too (it always
    ///     shows with one).
    ///   - monospaced: Sets the text in the monospaced code font.
    public init(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        prompt: Text? = nil,
        lineLimit: ClosedRange<Int> = 3...8,
        characterLimit: Int? = nil,
        showsCharacterCount: Bool = false,
        monospaced: Bool = false
    ) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.lineLimit = max(lineLimit.lowerBound, 1)...max(lineLimit.upperBound, lineLimit.lowerBound, 1)
        self.characterLimit = characterLimit.flatMap { $0 > 0 ? $0 : nil }
        self.showsCharacterCount = showsCharacterCount
        self.fontStyle = monospaced ? .code : .body
    }

    private var showsCount: Bool { characterLimit != nil || showsCharacterCount }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextAreaEditor(
                text: $text,
                accessibilityLabel: String(localized: title),
                fontStyle: fontStyle,
                lineLimit: lineLimit,
                characterLimit: characterLimit,
                isEnabled: isEnabled,
                focusRequest: focusRequest,
                onFocusChange: { focused in isFocused = focused },
                onScroll: handleScroll
            )
            .overlay(alignment: .topLeading) { placeholder }
            .overlay(alignment: .topTrailing) { scrollIndicator }

            if showsCount {
                characterCount
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A click on the box around the text (the count row) still edits.
        .contentShape(Rectangle())
        .onTapGesture { focusRequest += 1 }
        .inputBox(isFocused: isFocused, cornerRadius: Sizing.radiusDefault)
        .onHover { hovering in isHovering = hovering }
        .onDisappear { scrollEndTask?.cancel() }
    }

    // MARK: Placeholder

    @ViewBuilder
    private var placeholder: some View {
        if text.isEmpty, let prompt {
            prompt
                .font(fontStyle.font)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, TextAreaEditor.textInset.width)
                .padding(.vertical, TextAreaEditor.textInset.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: Character count

    private var characterCount: some View {
        let count = text.count
        let isAtLimit = characterLimit.map { count >= $0 } ?? false
        return HStack {
            Spacer(minLength: 0)
            countText(count: count)
                .font(Typography.captionSmall.monospacedDigit())
                .foregroundStyle(isAtLimit ? AnyShapeStyle(Danger.danger500.legibleOnDark(colorScheme)) : AnyShapeStyle(.tertiary))
                .accessibilityLabel(countDescription(count: count))
        }
        .padding(.horizontal, TextAreaEditor.textInset.width)
        .padding(.bottom, TextAreaEditor.textInset.height)
    }

    private func countText(count: Int) -> Text {
        guard let characterLimit else { return Text("\(count) characters", bundle: .module) }
        return Text(verbatim: "\(count.formatted())/\(characterLimit.formatted())")
    }

    private func countDescription(count: Int) -> Text {
        guard let characterLimit else { return Text("\(count) characters", bundle: .module) }
        return Text("\(count) of \(characterLimit) characters", bundle: .module)
    }

    // MARK: Scroll indicator

    /// The thin thumb `ScrollViewWithThinIndicator` draws, for the text view's
    /// own scroll: shown while hovering or scrolling, only when the text
    /// overflows, and never hit-testable.
    @ViewBuilder
    private var scrollIndicator: some View {
        let metrics = scrollMetrics
        if metrics.overflows {
            let track = metrics.viewportHeight - 2 * ThinIndicatorMetrics.verticalPadding
            let thumbHeight = min(max(ThinIndicatorMetrics.minimumHeight, track * metrics.viewportHeight / metrics.contentHeight), track)
            let progress = min(max(metrics.offset / (metrics.contentHeight - metrics.viewportHeight), 0), 1)
            RoundedRectangle(cornerRadius: ThinIndicatorMetrics.width / 2)
                .fill(Color.primary.opacity(0.35))
                .frame(width: ThinIndicatorMetrics.width, height: thumbHeight)
                .padding(.top, ThinIndicatorMetrics.verticalPadding + progress * (track - thumbHeight))
                .padding(.trailing, ThinIndicatorMetrics.trailingPadding)
                .opacity(isHovering || isScrolling ? 1 : 0)
                .animation(Animations.scrollIndicator, value: isHovering || isScrolling)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func handleScroll(_ metrics: TextAreaScrollMetrics, didScroll: Bool) {
        scrollMetrics = metrics
        guard didScroll else { return }
        isScrolling = true
        scrollEndTask?.cancel()
        scrollEndTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            withAnimation(Animations.scrollIndicator) { isScrolling = false }
        }
    }
}

// MARK: - Metrics

/// The thin indicator's proportions, matching `ScrollViewWithThinIndicator`.
private enum ThinIndicatorMetrics {
    static let width: CGFloat = Spacing.xs
    static let minimumHeight: CGFloat = 30
    static let trailingPadding: CGFloat = Spacing.hairline
    static let verticalPadding: CGFloat = Spacing.xxs
}

/// The text view's scroll position, reported to draw the thin indicator.
struct TextAreaScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0

    var overflows: Bool { viewportHeight > 0 && contentHeight > viewportHeight + 1 }
}

/// The two faces a text area sets its text in, as an AppKit font for the text
/// view and the matching token for the placeholder.
enum TextAreaFontStyle {
    case body
    case code

    /// `Typography.bodySmall` / `Typography.codeSmall`.
    var nsFont: NSFont {
        switch self {
        case .body: return .systemFont(ofSize: FontSize.footnote)
        case .code: return .monospacedSystemFont(ofSize: FontSize.caption, weight: .regular)
        }
    }

    var font: Font {
        switch self {
        case .body: return Typography.bodySmall
        case .code: return Typography.codeSmall
        }
    }
}

// MARK: - Text view host

/// An `NSTextView` in a scroller-less `NSScrollView`, sized by SwiftUI to its
/// text: `sizeThatFits` lays the text out at the proposed width and clamps the
/// height to the line limit, so no size round-trips through state.
struct TextAreaEditor: NSViewRepresentable {
    @Binding var text: String
    var accessibilityLabel: String
    var fontStyle: TextAreaFontStyle
    var lineLimit: ClosedRange<Int>
    var characterLimit: Int?
    var isEnabled: Bool
    var focusRequest: Int
    var onFocusChange: (Bool) -> Void
    var onScroll: (TextAreaScrollMetrics, _ didScroll: Bool) -> Void

    /// Padding between the box and the text, inside the scroll view so the
    /// text scrolls to the box's edge and the thin indicator sits in the gutter.
    static let textInset = NSSize(width: Spacing.sm, height: Spacing.xs)
    /// A width-less proposal (`fixedSize`) gets a typical field width.
    static let idealWidth: CGFloat = 240

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        // TextKit 1, explicitly: its `usedRect` measures the height exactly,
        // and asking a TextKit 2 view for its layout manager would silently
        // switch it back anyway.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let textView = TextAreaTextView(frame: .zero, textContainer: container)
        textView.delegate = coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = Self.textInset
        textView.font = fontStyle.nsFont
        textView.textColor = .labelColor
        textView.string = text
        if fontStyle == .code {
            // Code and file templates: no smart quotes, dashes or corrections.
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isContinuousSpellCheckingEnabled = false
        }
        textView.onFocusChange = { [weak coordinator] focused in
            // First-responder changes can land inside a SwiftUI update.
            DispatchQueue.main.async { coordinator?.parent.onFocusChange(focused) }
        }

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // No scroller at all (the thin indicator is drawn in SwiftUI), so
        // "Show scroll bars: Always" can't bring back the wide one.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        textView.postsFrameChangedNotifications = true

        coordinator.textView = textView
        coordinator.scrollView = scrollView
        coordinator.lastFocusRequest = focusRequest
        NotificationCenter.default.addObserver(
            coordinator, selector: #selector(Coordinator.scrollGeometryDidChange(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            coordinator, selector: #selector(Coordinator.scrollGeometryDidChange(_:)),
            name: NSView.frameDidChangeNotification, object: textView
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }

        // Set from outside (a reset, a loaded draft). Never mid-composition:
        // that would drop the marked text an input method is building.
        if textView.string != text, !textView.hasMarkedText() {
            let length = (text as NSString).length
            let selection = textView.selectedRanges.map { value -> NSValue in
                let range = value.rangeValue
                let location = min(range.location, length)
                return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
            }
            textView.string = text
            textView.selectedRanges = selection
        }
        if textView.accessibilityLabel() != accessibilityLabel { textView.setAccessibilityLabel(accessibilityLabel) }
        let font = fontStyle.nsFont
        if textView.font != font { textView.font = font }
        if textView.isEditable != isEnabled { textView.isEditable = isEnabled }
        let textColor: NSColor = isEnabled ? .labelColor : .secondaryLabelColor
        if textView.textColor != textColor { textView.textColor = textColor }
        // Fills the box when the text is shorter than the minimum, so a click
        // anywhere in it lands in the text view.
        let minimumHeight = coordinator.height(lines: lineLimit.lowerBound, font: font)
        if textView.minSize.height != minimumHeight { textView.minSize = NSSize(width: 0, height: minimumHeight) }

        if focusRequest != coordinator.lastFocusRequest {
            coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak textView] in
                guard let textView, textView.isEditable else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? Self.idealWidth
        let font = fontStyle.nsFont
        let coordinator = context.coordinator
        let contentHeight = coordinator.contentHeight(of: text, width: width, font: font)
        let minimumHeight = coordinator.height(lines: lineLimit.lowerBound, font: font)
        let maximumHeight = coordinator.height(lines: lineLimit.upperBound, font: font)
        return CGSize(width: width, height: min(max(contentHeight, minimumHeight), maximumHeight))
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextAreaEditor
        weak var textView: TextAreaTextView?
        weak var scrollView: NSScrollView?
        var lastFocusRequest = 0
        private var lastReportedOffset: CGFloat = 0

        /// An off-screen TextKit 1 stack that lays text out at a proposed width,
        /// configured like the text view's so the two always agree.
        private let measuringStorage = NSTextStorage()
        private let measuringLayoutManager = NSLayoutManager()
        private let measuringContainer = NSTextContainer()
        private var cachedMeasurement: (text: String, width: CGFloat, font: NSFont, height: CGFloat)?

        init(parent: TextAreaEditor) {
            self.parent = parent
            super.init()
            measuringStorage.addLayoutManager(measuringLayoutManager)
            measuringContainer.lineFragmentPadding = 0
            measuringLayoutManager.addTextContainer(measuringContainer)
        }

        // MARK: Measuring

        /// The height of `lines` lines, insets included.
        func height(lines: Int, font: NSFont) -> CGFloat {
            (measuringLayoutManager.defaultLineHeight(for: font) * CGFloat(lines)).rounded(.up) + 2 * TextAreaEditor.textInset.height
        }

        /// The height `text` lays out to at `width`, insets included. An empty
        /// text (or a trailing newline) counts its empty last line.
        func contentHeight(of text: String, width: CGFloat, font: NSFont) -> CGFloat {
            if let cached = cachedMeasurement, cached.text == text, cached.width == width, cached.font == font {
                return cached.height
            }
            measuringContainer.size = NSSize(width: max(width - 2 * TextAreaEditor.textInset.width, 1), height: CGFloat.greatestFiniteMagnitude)
            // An empty last line (no text, or a trailing newline) is laid out
            // as the extra line fragment, in the default font here — there are
            // no typing attributes without a text view. A zero-width space
            // puts a character in our font on that line instead.
            let endsOnEmptyLine = text.isEmpty || text.last?.isNewline == true
            measuringStorage.setAttributedString(NSAttributedString(string: endsOnEmptyLine ? text + "\u{200B}" : text, attributes: [.font: font]))
            measuringLayoutManager.ensureLayout(for: measuringContainer)
            let height = measuringLayoutManager.usedRect(for: measuringContainer).height.rounded(.up) + 2 * TextAreaEditor.textInset.height
            cachedMeasurement = (text, width, font, height)
            return height
        }

        // MARK: Editing

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
        }

        /// Holds the text to the character limit. A paste past it keeps what
        /// fits; a keystroke at it beeps, like a full native field.
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let limit = parent.characterLimit, let replacement = replacementString else { return true }
            // An input method's marked text isn't final; the limit applies
            // when it's committed.
            guard !textView.hasMarkedText() else { return true }
            let current = textView.string as NSString
            let resulting = current.replacingCharacters(in: affectedCharRange, with: replacement)
            guard resulting.count > limit else { return true }
            let replacedCount = current.substring(with: affectedCharRange).count
            let room = limit - (textView.string.count - replacedCount)
            guard room > 0, !replacement.isEmpty else {
                NSSound.beep()
                return false
            }
            textView.insertText(String(replacement.prefix(room)), replacementRange: affectedCharRange)
            return false
        }

        // MARK: Scrolling

        @objc func scrollGeometryDidChange(_ notification: Notification) {
            guard let scrollView, let textView else { return }
            let clipBounds = scrollView.contentView.bounds
            let metrics = TextAreaScrollMetrics(
                offset: clipBounds.origin.y,
                contentHeight: textView.frame.height,
                viewportHeight: clipBounds.height
            )
            let didScroll = abs(clipBounds.origin.y - lastReportedOffset) > 0.5
            lastReportedOffset = clipBounds.origin.y
            // Rubber-band only when there's something to scroll, like
            // `ScrollViewWithThinIndicator`'s `.basedOnSize`.
            let elasticity: NSScrollView.Elasticity = metrics.overflows ? .allowed : .none
            if scrollView.verticalScrollElasticity != elasticity { scrollView.verticalScrollElasticity = elasticity }
            // Bounds and frame changes arrive during layout, which can be
            // inside a SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                self?.parent.onScroll(metrics, didScroll)
            }
        }
    }
}

// MARK: - Text view

/// Reports first-responder changes (the box draws the focus ring) and makes
/// Tab move focus like a form field instead of typing a tab.
final class TextAreaTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    override func insertTab(_ sender: Any?) {
        window?.selectNextKeyView(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        window?.selectPreviousKeyView(sender)
    }

    /// ⌥Tab still types a tab.
    override func insertTabIgnoringFieldEditor(_ sender: Any?) {
        insertText("\t", replacementRange: selectedRange())
    }
}

// MARK: - Previews

#Preview("Text area", traits: .fixedLayout(width: 360, height: 320)) {
    @Previewable @State var notes = ""
    @Previewable @State var bio = "Designer and tinkerer. Builds tools for people who make things."

    VStack(alignment: .leading, spacing: Spacing.lg) {
        TextArea("Notes", text: $notes, prompt: Text("Add a note…"))
        TextArea("Bio", text: $bio, lineLimit: 2...5, characterLimit: 160)
        TextArea("Ignore file", text: .constant("/node_modules\n/dist\n.env"), lineLimit: 2...4, monospaced: true)
    }
    .padding(Spacing.lg)
}
