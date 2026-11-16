//
//  RichTextEditorHost.swift
//  BlissUI
//
//  The AppKit half of `RichTextEditor`: the hosted `NSTextView` (the same
//  TextKit 1 stack as `TextArea`), the controller the toolbar talks to, and
//  the formatting operations on the text storage.
//
//  Lists are what `NSTextView`'s own list panel makes: each item starts with
//  "\t<marker>\t" as literal text, with the `NSTextList` on the paragraph
//  style and tab stops that right-align the marker. The style alone draws no
//  marker in either TextKit (checked in a throwaway view), so the text view
//  writes the next marker itself on Return and takes it away again on Return
//  in an empty item. Items are numbered when the list is made or continued;
//  deleting one in the middle doesn't renumber the rest.
//
//  Formatting is read off the selection (or the caret's typing attributes)
//  after every change, so the toolbar's buttons light up for the text under
//  the caret. Styles are recognized by their attributes alone — a heading by
//  its size, code by its monospaced font, a list by its text list, a quote by
//  its indent — so an `AttributedString` built elsewhere formats the same way.
//

import AppKit
import SwiftUI

// MARK: - Formatting

/// The paragraph styles a rich text can be set in.
enum RichTextHeading: CaseIterable, Hashable {
    case body, heading1, heading2, heading3

    /// Point sizes: `bodySmall`, `headingSmall`, `headingMedium`, `displaySmall`.
    var pointSize: CGFloat {
        switch self {
        case .body: return FontSize.footnote
        case .heading3: return FontSize.callout
        case .heading2: return FontSize.headline
        case .heading1: return FontSize.title2
        }
    }

    var isHeading: Bool { self != .body }

    /// The largest heading whose size the font reaches.
    static func matching(_ font: NSFont) -> RichTextHeading {
        let size = font.pointSize
        if size >= RichTextHeading.heading1.pointSize { return .heading1 }
        if size >= RichTextHeading.heading2.pointSize { return .heading2 }
        if size >= RichTextHeading.heading3.pointSize { return .heading3 }
        return .body
    }
}

enum RichTextListKind: Hashable {
    case bulleted, numbered

    var markerFormat: NSTextList.MarkerFormat {
        switch self {
        case .bulleted: return .disc
        case .numbered: return NSTextList.MarkerFormat("{decimal}.")
        }
    }

    init(_ list: NSTextList) {
        self = list.markerFormat.rawValue.contains("decimal") ? .numbered : .bulleted
    }

    func makeList() -> NSTextList {
        NSTextList(markerFormat: markerFormat, options: 0)
    }
}

/// What the selection (or the caret's typing attributes) carries.
struct RichTextFormatting: Equatable {
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    var isStruck = false
    var isCode = false
    var isLink = false
    var isQuote = false
    var heading: RichTextHeading = .body
    var list: RichTextListKind?
}

/// The fonts and measures the editor sets text in. System fonts at the
/// `Typography` sizes, like `TextArea`'s.
enum RichTextStyle {
    static let textInset = NSSize(width: Spacing.sm, height: Spacing.xs)
    static let quoteIndent: CGFloat = Spacing.lg
    static let codeBackgroundAlpha: CGFloat = 0.08
    /// Where a list item's text starts, and the stop its marker right-aligns on.
    static let listHeadIndent: CGFloat = 28
    static let listMarkerStop: CGFloat = 18

    /// A list item's paragraph: the marker on a right-aligned stop, the text
    /// (and its wrapped lines) at `listHeadIndent`.
    static func listParagraphStyle(_ list: NSTextList, from existing: NSParagraphStyle?) -> NSParagraphStyle {
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.textLists = [list]
        style.firstLineHeadIndent = 0
        style.headIndent = listHeadIndent
        style.tabStops = [
            NSTextTab(textAlignment: .right, location: listMarkerStop),
            NSTextTab(textAlignment: .left, location: listHeadIndent),
        ]
        return style
    }

    /// The marker text at the start of a list item.
    static func marker(for list: NSTextList, itemNumber: Int) -> String {
        "\t\(list.marker(forItemNumber: itemNumber))\t"
    }

    static var bodyFont: NSFont { .systemFont(ofSize: RichTextHeading.body.pointSize) }
    static var codeFont: NSFont { .monospacedSystemFont(ofSize: FontSize.caption, weight: .regular) }

    /// A heading in the semibold face; body in the regular one, bold when asked.
    static func font(for heading: RichTextHeading, bold: Bool, italic: Bool) -> NSFont {
        let weight: NSFont.Weight = heading.isHeading ? .semibold : (bold ? .bold : .regular)
        var font = NSFont.systemFont(ofSize: heading.pointSize, weight: weight)
        if italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }

    static func isMonospaced(_ font: NSFont) -> Bool {
        font.fontDescriptor.symbolicTraits.contains(.monoSpace)
    }

    static var codeBackground: NSColor { NSColor.labelColor.withAlphaComponent(codeBackgroundAlpha) }
}

// MARK: - Controller

/// What the toolbar sees of the text view: the formatting under the caret and
/// the operations. Held in the editor's state and handed to the host.
@MainActor
@Observable
final class RichTextController {
    private(set) var formatting = RichTextFormatting()
    @ObservationIgnored weak var textView: RichTextView?
    /// ⌘K in the text view: the editor opens its link popover.
    @ObservationIgnored var onLinkShortcut: (() -> Void)?

    func noteFormatting(_ formatting: RichTextFormatting) {
        if self.formatting != formatting { self.formatting = formatting }
    }

    func toggleBold() { textView?.toggleTrait(.boldFontMask, isOn: formatting.isBold) }
    func toggleItalic() { textView?.toggleTrait(.italicFontMask, isOn: formatting.isItalic) }
    func toggleUnderline() { textView?.toggleLine(.underlineStyle, isOn: formatting.isUnderlined) }
    func toggleStrikethrough() { textView?.toggleLine(.strikethroughStyle, isOn: formatting.isStruck) }
    func toggleCode() { textView?.toggleCode(isOn: formatting.isCode) }
    func toggleQuote() { textView?.toggleQuote(isOn: formatting.isQuote) }
    func setHeading(_ heading: RichTextHeading) { textView?.setHeading(heading) }

    func toggleList(_ kind: RichTextListKind) {
        textView?.setList(formatting.list == kind ? nil : kind)
    }

    /// The link under the caret, to edit.
    var currentLink: URL? { textView?.currentLink }

    func setLink(_ url: URL) { textView?.setLink(url) }
    func removeLink() { textView?.removeLink() }
}

// MARK: - Host

/// The text view in a scroller-less `NSScrollView`, as tall as its text and
/// at least `minimumHeight`. The height goes round through state
/// (`onContentHeightChange`): TextKit 2 has no off-screen measurer as cheap
/// as TextKit 1's, and a rich text's height changes with its styles anyway.
struct RichTextEditorHost: NSViewRepresentable {
    @Binding var text: AttributedString
    var accessibilityLabel: String
    var isEnabled: Bool
    var minimumHeight: CGFloat
    var contentHeight: CGFloat
    var focusRequest: Int
    var controller: RichTextController
    var onFocusChange: (Bool) -> Void
    var onContentHeightChange: (CGFloat) -> Void

    /// A width-less proposal (`fixedSize`) gets a typical field width.
    static let idealWidth: CGFloat = 320

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator

        // TextKit 1, explicitly, like `TextArea`: the one whose list handling
        // this file mirrors.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let textView = RichTextView(frame: .zero, textContainer: container)
        textView.delegate = coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = RichTextStyle.textInset
        textView.font = RichTextStyle.bodyFont
        textView.textColor = .labelColor
        textView.typingAttributes = [.font: RichTextStyle.bodyFont, .foregroundColor: NSColor.labelColor]
        textView.textStorage?.setAttributedString(NSAttributedString(text))
        textView.onFocusChange = { [weak coordinator] focused in
            // First-responder changes can land inside a SwiftUI update.
            DispatchQueue.main.async { coordinator?.parent.onFocusChange(focused) }
        }
        textView.onFormattingChange = { [weak coordinator] formatting in
            DispatchQueue.main.async { coordinator?.parent.controller.noteFormatting(formatting) }
        }
        textView.onLinkShortcut = { [weak coordinator] in
            coordinator?.parent.controller.onLinkShortcut?()
        }
        controller.textView = textView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // The view grows with its text; nothing scrolls, so no scroller.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = textView
        textView.postsFrameChangedNotifications = true

        coordinator.textView = textView
        coordinator.lastFocusRequest = focusRequest
        NotificationCenter.default.addObserver(
            coordinator, selector: #selector(Coordinator.textViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification, object: textView
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView, let storage = textView.textStorage else { return }
        controller.textView = textView

        // Set from outside (a reset, a loaded draft). Never mid-composition:
        // that would drop the marked text an input method is building.
        let incoming = NSAttributedString(text)
        if !storage.isEqual(to: incoming), !textView.hasMarkedText() {
            let length = incoming.length
            let selection = textView.selectedRanges.map { value -> NSValue in
                let range = value.rangeValue
                let location = min(range.location, length)
                return NSValue(range: NSRange(location: location, length: min(range.length, length - location)))
            }
            storage.setAttributedString(incoming)
            textView.selectedRanges = selection
        }
        if textView.accessibilityLabel() != accessibilityLabel { textView.setAccessibilityLabel(accessibilityLabel) }
        if textView.isEditable != isEnabled { textView.isEditable = isEnabled }
        // Links in the live accent, which follows the theme.
        textView.linkTextAttributes = [
            .foregroundColor: NSColor(Color.accent),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
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
        return CGSize(width: width, height: max(contentHeight, minimumHeight))
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditorHost
        weak var textView: RichTextView?
        var lastFocusRequest = 0
        private var lastReportedHeight: CGFloat = 0

        init(parent: RichTextEditorHost) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, let storage = textView.textStorage else { return }
            parent.text = AttributedString(storage)
            textView.reportFormatting()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            textView?.reportFormatting()
        }

        @objc func textViewFrameDidChange(_ notification: Notification) {
            guard let textView else { return }
            let height = textView.frame.height.rounded(.up)
            guard abs(height - lastReportedHeight) > 0.5 else { return }
            lastReportedHeight = height
            // Frame changes arrive during layout, which can be inside a SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                self?.parent.onContentHeightChange(height)
            }
        }
    }
}

// MARK: - Text view

/// Reports focus and formatting, takes ⌘B / ⌘I / ⌘U / ⌘K, and carries the
/// formatting operations. Tab moves focus like a form field.
final class RichTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var onFormattingChange: ((RichTextFormatting) -> Void)?
    var onLinkShortcut: (() -> Void)?

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

    /// The formatting shortcuts, taken here because an app without a Format
    /// menu gives `NSTextView` nowhere to route them (the font panel is off).
    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "b": toggleTrait(.boldFontMask, isOn: currentFormatting().isBold); return
            case "i": toggleTrait(.italicFontMask, isOn: currentFormatting().isItalic); return
            case "u": toggleLine(.underlineStyle, isOn: currentFormatting().isUnderlined); return
            case "k": onLinkShortcut?(); return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    // MARK: Reading

    /// The attributes the next typed character gets: the caret's typing
    /// attributes, or the first character of the selection.
    private var selectionAttributes: [NSAttributedString.Key: Any] {
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage, range.location < storage.length else { return typingAttributes }
        return storage.attributes(at: range.location, effectiveRange: nil)
    }

    func currentFormatting() -> RichTextFormatting {
        let attributes = selectionAttributes
        let font = attributes[.font] as? NSFont ?? RichTextStyle.bodyFont
        let traits = font.fontDescriptor.symbolicTraits
        let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle ?? .default
        var formatting = RichTextFormatting()
        formatting.isCode = RichTextStyle.isMonospaced(font)
        formatting.isBold = traits.contains(.bold)
        formatting.isItalic = traits.contains(.italic)
        formatting.isUnderlined = (attributes[.underlineStyle] as? Int ?? 0) != 0 && attributes[.link] == nil
        formatting.isStruck = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
        formatting.isLink = attributes[.link] != nil
        formatting.heading = formatting.isCode ? .body : RichTextHeading.matching(font)
        if let list = paragraph.textLists.first {
            formatting.list = RichTextListKind(list)
        }
        formatting.isQuote = paragraph.textLists.isEmpty && paragraph.headIndent >= RichTextStyle.quoteIndent
        return formatting
    }

    func reportFormatting() {
        onFormattingChange?(currentFormatting())
    }

    var currentLink: URL? {
        let value = selectionAttributes[.link]
        if let url = value as? URL { return url }
        if let string = value as? String { return URL(string: string) }
        return nil
    }

    // MARK: Writing

    /// Changes attributes over the selection with undo, or the typing
    /// attributes when the selection is empty (so the next character gets them).
    private func change(
        _ transform: (NSTextStorage, NSRange) -> Void,
        typing: (inout [NSAttributedString.Key: Any]) -> Void
    ) {
        let range = selectedRange()
        if range.length == 0 {
            var attributes = typingAttributes
            typing(&attributes)
            typingAttributes = attributes
            reportFormatting()
            return
        }
        guard let storage = textStorage, shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        transform(storage, range)
        storage.endEditing()
        didChangeText()
        reportFormatting()
    }

    /// Changes attributes over the whole paragraphs the selection touches.
    private func changeParagraphs(_ transform: (NSTextStorage, NSRange) -> Void) {
        guard let storage = textStorage else { return }
        let range = (string as NSString).paragraphRange(for: selectedRange())
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        transform(storage, range)
        storage.endEditing()
        didChangeText()
        // The caret's attributes follow its paragraph.
        if storage.length > 0 {
            typingAttributes = storage.attributes(at: min(selectedRange().location, storage.length - 1), effectiveRange: nil)
        }
        reportFormatting()
    }

    private func replacingFonts(in storage: NSTextStorage, range: NSRange, _ replace: (NSFont) -> NSFont) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? RichTextStyle.bodyFont
            storage.addAttribute(.font, value: replace(font), range: subrange)
        }
    }

    func toggleTrait(_ trait: NSFontTraitMask, isOn: Bool) {
        let manager = NSFontManager.shared
        func toggled(_ font: NSFont) -> NSFont {
            isOn ? manager.convert(font, toNotHaveTrait: trait) : manager.convert(font, toHaveTrait: trait)
        }
        change({ storage, range in
            replacingFonts(in: storage, range: range, toggled)
        }, typing: { attributes in
            attributes[.font] = toggled(attributes[.font] as? NSFont ?? RichTextStyle.bodyFont)
        })
    }

    func toggleLine(_ key: NSAttributedString.Key, isOn: Bool) {
        let value = NSUnderlineStyle.single.rawValue
        change({ storage, range in
            if isOn { storage.removeAttribute(key, range: range) } else { storage.addAttribute(key, value: value, range: range) }
        }, typing: { attributes in
            if isOn { attributes[key] = nil } else { attributes[key] = value }
        })
    }

    func toggleCode(isOn: Bool) {
        change({ storage, range in
            if isOn {
                storage.addAttribute(.font, value: RichTextStyle.bodyFont, range: range)
                storage.removeAttribute(.backgroundColor, range: range)
            } else {
                storage.addAttribute(.font, value: RichTextStyle.codeFont, range: range)
                storage.addAttribute(.backgroundColor, value: RichTextStyle.codeBackground, range: range)
            }
        }, typing: { attributes in
            attributes[.font] = isOn ? RichTextStyle.bodyFont : RichTextStyle.codeFont
            attributes[.backgroundColor] = isOn ? nil : RichTextStyle.codeBackground
        })
    }

    /// Sets the paragraphs' size and weight, keeping bold (in body) and italic.
    func setHeading(_ heading: RichTextHeading) {
        changeParagraphs { storage, range in
            replacingFonts(in: storage, range: range) { font in
                if RichTextStyle.isMonospaced(font) { return font }
                let traits = font.fontDescriptor.symbolicTraits
                return RichTextStyle.font(for: heading, bold: traits.contains(.bold), italic: traits.contains(.italic))
            }
        }
    }

    // MARK: Lists

    /// Puts the paragraphs the selection touches in a list, or takes them out
    /// of one (nil): the marker text goes in or out and the paragraph style
    /// with it, as one undoable replacement.
    func setList(_ kind: RichTextListKind?) {
        let range = (string as NSString).paragraphRange(for: selectedRange())
        _ = rebuildParagraphs(in: range, list: kind, quote: nil)
    }

    /// Indents the paragraphs and dims their text; the indent is what marks
    /// a quote when the text is read back. A list item leaves its list first.
    func toggleQuote(isOn: Bool) {
        let range = (string as NSString).paragraphRange(for: selectedRange())
        _ = rebuildParagraphs(in: range, list: nil, quote: !isOn)
    }

    /// Rewrites the paragraphs in `range` with the list and quote asked for
    /// and returns the range they occupy afterwards. The caret lands at the end
    /// of the last paragraph's text.
    @discardableResult
    private func rebuildParagraphs(in range: NSRange, list kind: RichTextListKind?, quote: Bool?) -> NSRange {
        guard let storage = textStorage, range.length > 0 || kind != nil || quote == true else { return range }
        let list = kind?.makeList()
        let rebuilt = NSMutableAttributedString()
        var itemNumber = kind == .numbered ? listItemNumber(before: range.location) : 1
        let content = storage.attributedSubstring(from: range)
        for paragraph in Self.paragraphs(of: content) {
            let stripped = Self.strippingMarker(from: paragraph)
            let attributes = stripped.length > 0 ? stripped.attributes(at: 0, effectiveRange: nil) : typingAttributes
            let existingStyle = attributes[.paragraphStyle] as? NSParagraphStyle
            let item = NSMutableAttributedString(attributedString: stripped)
            if let list {
                var markerAttributes = attributes
                markerAttributes[.link] = nil
                markerAttributes[.backgroundColor] = nil
                item.insert(NSAttributedString(string: RichTextStyle.marker(for: list, itemNumber: itemNumber), attributes: markerAttributes), at: 0)
                itemNumber += 1
            }
            let style = Self.paragraphStyle(list: list, quote: quote ?? (existingStyle.map { Self.isQuote($0) } ?? false), from: existingStyle)
            let whole = NSRange(location: 0, length: item.length)
            item.addAttribute(.paragraphStyle, value: style, range: whole)
            if let quote {
                if quote {
                    item.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: whole)
                } else {
                    item.addAttribute(.foregroundColor, value: NSColor.labelColor, range: whole)
                }
            } else if list != nil {
                item.addAttribute(.foregroundColor, value: NSColor.labelColor, range: whole)
            }
            rebuilt.append(item)
        }
        // An empty paragraph (a bare caret) still gets its marker.
        if rebuilt.length == 0, let list {
            var markerAttributes = typingAttributes
            markerAttributes[.paragraphStyle] = Self.paragraphStyle(list: list, quote: false, from: nil)
            rebuilt.append(NSAttributedString(string: RichTextStyle.marker(for: list, itemNumber: itemNumber), attributes: markerAttributes))
        }
        guard shouldChangeText(in: range, replacementString: rebuilt.string) else { return range }
        storage.replaceCharacters(in: range, with: rebuilt)
        didChangeText()
        let newRange = NSRange(location: range.location, length: rebuilt.length)
        let endsWithNewline = rebuilt.string.hasSuffix("\n")
        setSelectedRange(NSRange(location: newRange.location + newRange.length - (endsWithNewline ? 1 : 0), length: 0))
        if storage.length > 0 {
            typingAttributes = storage.attributes(at: min(selectedRange().location, storage.length - 1), effectiveRange: nil)
        }
        reportFormatting()
        return newRange
    }

    /// Return inside a list item starts the next item with its marker; Return
    /// in an item that holds only its marker ends the list instead.
    override func insertNewline(_ sender: Any?) {
        guard let storage = textStorage else { super.insertNewline(sender); return }
        let selection = selectedRange()
        let paragraphRange = (string as NSString).paragraphRange(for: selection)
        let paragraph = storage.attributedSubstring(from: paragraphRange)
        guard let style = paragraph.length > 0 ? paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle : typingAttributes[.paragraphStyle] as? NSParagraphStyle,
              let list = style.textLists.first else {
            super.insertNewline(sender)
            return
        }
        let text = paragraph.string.hasSuffix("\n") ? String(paragraph.string.dropLast()) : paragraph.string
        if Self.strippingMarker(from: NSAttributedString(string: text)).length == 0 {
            // An empty item: Return leaves the list.
            rebuildParagraphs(in: paragraphRange, list: nil, quote: false)
            return
        }
        let kind = RichTextListKind(list)
        let nextNumber = kind == .numbered ? listItemNumber(before: paragraphRange.location) + Self.listItemCount(in: storage, range: paragraphRange) : 1
        var markerAttributes = typingAttributes
        markerAttributes[.link] = nil
        markerAttributes[.backgroundColor] = nil
        markerAttributes[.paragraphStyle] = style
        let marker = NSAttributedString(string: "\n" + RichTextStyle.marker(for: list, itemNumber: nextNumber), attributes: markerAttributes)
        guard shouldChangeText(in: selection, replacementString: marker.string) else { return }
        storage.replaceCharacters(in: selection, with: marker)
        didChangeText()
        setSelectedRange(NSRange(location: selection.location + marker.length, length: 0))
        typingAttributes = markerAttributes
        reportFormatting()
    }

    /// How many numbered items sit right above `location`, so a new one takes
    /// the next number.
    private func listItemNumber(before location: Int) -> Int {
        guard let storage = textStorage else { return 1 }
        var count = 0
        var cursor = location
        let text = string as NSString
        while cursor > 0 {
            let previous = text.paragraphRange(for: NSRange(location: cursor - 1, length: 0))
            guard previous.location < storage.length,
                  let style = storage.attribute(.paragraphStyle, at: previous.location, effectiveRange: nil) as? NSParagraphStyle,
                  let list = style.textLists.first, RichTextListKind(list) == .numbered else { break }
            count += 1
            cursor = previous.location
        }
        return count + 1
    }

    private static func listItemCount(in storage: NSTextStorage, range: NSRange) -> Int {
        paragraphs(of: storage.attributedSubstring(from: range)).count
    }

    /// The paragraphs of a text, each with its trailing newline.
    private static func paragraphs(of text: NSAttributedString) -> [NSAttributedString] {
        let string = text.string as NSString
        var result: [NSAttributedString] = []
        var cursor = 0
        while cursor < string.length {
            let range = string.paragraphRange(for: NSRange(location: cursor, length: 0))
            result.append(text.attributedSubstring(from: range))
            cursor = range.location + range.length
        }
        return result
    }

    /// A paragraph without its "\t<marker>\t" prefix, if it has one.
    private static func strippingMarker(from paragraph: NSAttributedString) -> NSAttributedString {
        let string = paragraph.string as NSString
        guard string.length > 1, string.character(at: 0) == 9 else { return paragraph }
        let searchRange = NSRange(location: 1, length: min(string.length - 1, 8))
        let secondTab = string.range(of: "\t", options: [], range: searchRange)
        guard secondTab.location != NSNotFound else { return paragraph }
        let markerLength = secondTab.location + 1
        return paragraph.attributedSubstring(from: NSRange(location: markerLength, length: paragraph.length - markerLength))
    }

    private static func isQuote(_ style: NSParagraphStyle) -> Bool {
        style.textLists.isEmpty && style.headIndent >= RichTextStyle.quoteIndent
    }

    private static func paragraphStyle(list: NSTextList?, quote: Bool, from existing: NSParagraphStyle?) -> NSParagraphStyle {
        if let list { return RichTextStyle.listParagraphStyle(list, from: existing) }
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.textLists = []
        style.tabStops = NSParagraphStyle.default.tabStops
        style.headIndent = quote ? RichTextStyle.quoteIndent : 0
        style.firstLineHeadIndent = quote ? RichTextStyle.quoteIndent : 0
        return style
    }

    /// Links the selection; with nothing selected, inserts the URL as the text.
    func setLink(_ url: URL) {
        var range = selectedRange()
        if range.length == 0 {
            let text = url.absoluteString
            guard shouldChangeText(in: range, replacementString: text) else { return }
            insertText(text, replacementRange: range)
            range = NSRange(location: range.location, length: (text as NSString).length)
        }
        guard let storage = textStorage, shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.addAttribute(.link, value: url, range: range)
        storage.endEditing()
        didChangeText()
        setSelectedRange(NSRange(location: range.location + range.length, length: 0))
        // The caret after a link types plain text.
        typingAttributes[.link] = nil
        reportFormatting()
    }

    /// Removes the link under the caret, or across the selection.
    func removeLink() {
        guard let storage = textStorage else { return }
        var range = selectedRange()
        if range.length == 0, range.location < storage.length, storage.attribute(.link, at: range.location, effectiveRange: &range) == nil {
            return
        }
        guard range.length > 0, shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.removeAttribute(.link, range: range)
        storage.endEditing()
        didChangeText()
        typingAttributes[.link] = nil
        reportFormatting()
    }
}
