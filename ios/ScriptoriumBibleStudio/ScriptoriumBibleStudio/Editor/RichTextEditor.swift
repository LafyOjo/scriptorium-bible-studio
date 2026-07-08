import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var selectedText: String

    let context: RichTextContext
    let settings: SBAppSettings?
    let onTextChange: (NSAttributedString) -> Void

    func makeUIView(context coordinatorContext: Context) -> UITextView {
        let textView = ScriptoriumTextView()
        textView.delegate = coordinatorContext.coordinator
        textView.backgroundColor = .clear
        textView.textColor = SBTheme.uiInk
        textView.tintColor = SBTheme.uiPrimary
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.allowsEditingTextAttributes = true
        textView.adjustsFontForContentSizeCategory = true
        textView.attributedText = text
        textView.typingAttributes = AttributedContent.baseAttributes(settings: settings)
        textView.linkTextAttributes = [
            .foregroundColor: SBTheme.uiPrimary,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        textView.commandContext = context
        coordinatorContext.coordinator.install(textView: textView, commandContext: context)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context coordinatorContext: Context) {
        coordinatorContext.coordinator.onTextChange = onTextChange
        coordinatorContext.coordinator.selectedText = $selectedText
        coordinatorContext.coordinator.commandContext = self.context
        coordinatorContext.coordinator.commandContext?.textView = uiView
        if let textView = uiView as? ScriptoriumTextView {
            textView.commandContext = self.context
        }

        if !uiView.attributedText.isEqual(to: text) {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = text
            uiView.selectedRange = clamped(selectedRange, length: uiView.attributedText.length)
        }

        uiView.typingAttributes = mergedTypingAttributes(for: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedText: $selectedText, onTextChange: onTextChange)
    }

    private func mergedTypingAttributes(for textView: UITextView) -> [NSAttributedString.Key: Any] {
        var attributes = AttributedContent.baseAttributes(settings: settings)
        textView.typingAttributes.forEach { attributes[$0.key] = $0.value }
        return attributes
    }

    private func clamped(_ range: NSRange, length: Int) -> NSRange {
        guard range.location <= length else {
            return NSRange(location: length, length: 0)
        }
        return NSRange(location: range.location, length: min(range.length, length - range.location))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: NSAttributedString
        var selectedText: Binding<String>
        var onTextChange: (NSAttributedString) -> Void
        weak var commandContext: RichTextContext?

        init(
            text: Binding<NSAttributedString>,
            selectedText: Binding<String>,
            onTextChange: @escaping (NSAttributedString) -> Void
        ) {
            _text = text
            self.selectedText = selectedText
            self.onTextChange = onTextChange
        }

        func install(textView: UITextView, commandContext: RichTextContext) {
            self.commandContext = commandContext
            commandContext.textView = textView
            commandContext.onMutation = { [weak self] attributed in
                self?.text = attributed
                self?.onTextChange(attributed)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            let updated = textView.attributedText ?? NSAttributedString()
            text = updated
            onTextChange(updated)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            guard range.length > 0, range.location + range.length <= textView.attributedText.length else {
                selectedText.wrappedValue = ""
                return
            }
            selectedText.wrappedValue = textView.attributedText.attributedSubstring(from: range).string
        }
    }
}

final class RichTextContext: ObservableObject {
    weak var textView: UITextView?
    var onMutation: ((NSAttributedString) -> Void)?

    func toggleBold() {
        toggleTrait(.traitBold)
    }

    func toggleItalic() {
        toggleTrait(.traitItalic)
    }

    func toggleUnderline() {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            let current = textView.typingAttributes[.underlineStyle] as? Int
            if current == NSUnderlineStyle.single.rawValue {
                textView.typingAttributes.removeValue(forKey: .underlineStyle)
            } else {
                textView.typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            return
        }

        let text = mutableText()
        let existing = text.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int
        if existing == NSUnderlineStyle.single.rawValue {
            text.removeAttribute(.underlineStyle, range: range)
        } else {
            text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        apply(text)
    }

    func toggleStrikethrough() {
        toggleIntegerAttribute(.strikethroughStyle, activeValue: NSUnderlineStyle.single.rawValue)
    }

    func toggleSuperscript() {
        toggleBaseline(offset: 7, sizeDelta: -3)
    }

    func toggleSubscript() {
        toggleBaseline(offset: -3, sizeDelta: -3)
    }

    func applyHeading() {
        applyHeading(level: 1)
    }

    func applyHeading(level: Int) {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        let text = mutableText()
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = level == 1 ? 18 : 14
        paragraph.paragraphSpacingBefore = level == 1 ? 14 : 10
        paragraph.lineHeightMultiple = 1.18
        let size: CGFloat
        switch level {
        case 1: size = 34
        case 2: size = 26
        default: size = 21
        }
        text.addAttributes([
            .font: level == 1 ? SBTheme.bodyUIFont(size: size, weight: .semibold) : AttributedContent.displayFont(size: size, weight: .semibold),
            .foregroundColor: SBTheme.uiPrimary,
            .paragraphStyle: paragraph,
        ], range: range)
        apply(text, selectedRange: range)
    }

    func applyParagraph() {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        let text = mutableText()
        text.addAttributes(AttributedContent.baseAttributes(settings: nil), range: range)
        apply(text, selectedRange: range)
    }

    func applyQuote() {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        let text = mutableText()
        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 18
        paragraph.headIndent = 18
        paragraph.paragraphSpacing = 12
        paragraph.lineSpacing = 7
        text.addAttribute(.paragraphStyle, value: paragraph, range: range)
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            text.addAttribute(.font, value: font.addingTrait(.traitItalic), range: subrange)
        }
        text.addAttribute(.foregroundColor, value: SBTheme.uiPrimary, range: range)
        apply(text, selectedRange: range)
    }

    func applyPreformatted() {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        let text = mutableText()
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 12
        paragraph.lineSpacing = 4
        text.addAttributes([
            .font: UIFont(name: SBTheme.FontName.monospace, size: 15) ?? UIFont.monospacedSystemFont(ofSize: 15, weight: .regular),
            .foregroundColor: SBTheme.uiInk,
            .backgroundColor: SBTheme.uiParchment.withAlphaComponent(0.72),
            .paragraphStyle: paragraph,
        ], range: range)
        apply(text, selectedRange: range)
    }

    func applyAlignment(_ alignment: NSTextAlignment) {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        if range.length == 0 {
            let style = (textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            style.alignment = alignment
            textView.typingAttributes[.paragraphStyle] = style
            return
        }

        let text = mutableText()
        text.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            style.alignment = alignment
            text.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
        apply(text, selectedRange: range)
    }

    func toggleList(ordered: Bool) {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        guard range.location + range.length <= textView.attributedText.length else { return }

        let text = mutableText()
        let selected = text.attributedSubstring(from: range)
        let baseAttributes = selected.length > 0 ? selected.attributes(at: 0, effectiveRange: nil) : AttributedContent.baseAttributes(settings: nil)
        var itemNumber = 1
        let replacement = selected.string
            .components(separatedBy: .newlines)
            .map { line -> String in
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return line }
                let stripped = line.replacingOccurrences(
                    of: #"^\s*(?:[-•]|\d+\.)\s+"#,
                    with: "",
                    options: .regularExpression
                )
                if ordered {
                    defer { itemNumber += 1 }
                    return "\(itemNumber). \(stripped)"
                }
                return "\u{2022} \(stripped)"
            }
            .joined(separator: "\n")

        let attributed = NSAttributedString(string: replacement, attributes: baseAttributes)
        text.replaceCharacters(in: range, with: attributed)
        apply(text, selectedRange: NSRange(location: range.location, length: attributed.length))
    }

    func adjustIndent(by amount: CGFloat) {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        guard range.length > 0 else {
            let style = (textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            let nextIndent = max(0, style.headIndent + amount)
            style.headIndent = nextIndent
            style.firstLineHeadIndent = max(0, style.firstLineHeadIndent + amount)
            textView.typingAttributes[.paragraphStyle] = style
            return
        }

        let text = mutableText()
        text.enumerateAttribute(.paragraphStyle, in: range) { value, subrange, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            let nextIndent = max(0, style.headIndent + amount)
            style.headIndent = nextIndent
            style.firstLineHeadIndent = max(0, style.firstLineHeadIndent + amount)
            text.addAttribute(.paragraphStyle, value: style, range: subrange)
        }
        apply(text, selectedRange: range)
    }

    func applySmallCaps() {
        guard let textView else { return }
        let range = textView.selectedRange
        guard range.length > 0 else { return }
        let text = mutableText()
        let replacement = text.attributedSubstring(from: range).string.uppercased()
        let attributes = text.attributes(at: range.location, effectiveRange: nil)
        let smallCaps = NSMutableAttributedString(string: replacement, attributes: attributes)
        smallCaps.addAttributes([.kern: 0.9], range: NSRange(location: 0, length: smallCaps.length))
        text.replaceCharacters(in: range, with: smallCaps)
        apply(text, selectedRange: NSRange(location: range.location, length: smallCaps.length))
    }

    func uppercaseSelection() {
        guard let textView else { return }
        let range = textView.selectedRange
        guard range.length > 0 else { return }
        let text = mutableText()
        let attributes = text.attributes(at: range.location, effectiveRange: nil)
        let replacement = NSAttributedString(
            string: text.attributedSubstring(from: range).string.uppercased(),
            attributes: attributes
        )
        text.replaceCharacters(in: range, with: replacement)
        apply(text, selectedRange: NSRange(location: range.location, length: replacement.length))
    }

    func applyHighlight(_ theme: HighlightTheme) {
        applyAttributes([
            .backgroundColor: theme.uiColor,
            .scriptoriumHighlightTheme: theme.rawValue,
        ])
    }

    func applyForegroundColor(_ color: UIColor) {
        applyAttributes([.foregroundColor: color])
    }

    func insertLinkPlaceholder() {
        guard let textView else { return }
        let pasteboardURL = UIPasteboard.general.string.flatMap { URL(string: $0) }
        let url = pasteboardURL ?? URL(string: "https://example.com")!
        let range = textView.selectedRange
        if range.length == 0 {
            replaceSelection(with: NSAttributedString(
                string: url.absoluteString,
                attributes: [
                    .font: SBTheme.bodyUIFont(size: 19),
                    .foregroundColor: SBTheme.uiPrimary,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: url,
                ]
            ))
            return
        }
        applyAttributes([
            .link: url,
            .foregroundColor: SBTheme.uiPrimary,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
    }

    func applyFont(name: String, size: CGFloat? = nil) {
        guard let textView else { return }
        let range = effectiveSelection(in: textView)
        let text = mutableText()
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let current = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            let font = AttributedContent.editorFont(
                name: name,
                size: size ?? current.pointSize,
                bold: current.fontDescriptor.symbolicTraits.contains(.traitBold),
                italic: current.fontDescriptor.symbolicTraits.contains(.traitItalic)
            )
            text.addAttribute(.font, value: font, range: subrange)
        }
        apply(text, selectedRange: range)
    }

    func applyFontSize(_ size: CGFloat) {
        guard let textView else { return }
        let range = effectiveSelection(in: textView)
        let text = mutableText()
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let current = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            text.addAttribute(.font, value: current.withSize(size), range: subrange)
        }
        apply(text, selectedRange: range)
    }

    func insertVerseNumber(_ number: Int) {
        replaceSelection(with: AttributedContent.verseNumber(number))
    }

    func insertFootnoteMarker() {
        replaceSelection(with: NSAttributedString(
            string: "*",
            attributes: [
                .font: AttributedContent.displayFont(size: 12, weight: .bold),
                .foregroundColor: SBTheme.uiCrimson,
                .baselineOffset: 7,
            ]
        ))
    }

    func insertSectionTitle(_ title: String = "Section Title") {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 12
        replaceSelection(with: NSAttributedString(
            string: "\n\(title.uppercased())\n\n",
            attributes: [
                .font: AttributedContent.displayFont(size: 18, weight: .semibold),
                .foregroundColor: SBTheme.uiCrimson,
                .kern: 1.2,
                .paragraphStyle: paragraph,
            ]
        ))
    }

    func clearFormatting() {
        guard let textView else { return }
        let range = effectiveSelection(in: textView)
        let text = mutableText()
        let plain = text.attributedSubstring(from: range).string
        text.replaceCharacters(in: range, with: NSAttributedString(string: plain, attributes: AttributedContent.baseAttributes(settings: nil)))
        apply(text, selectedRange: NSRange(location: range.location, length: plain.utf16.count))
    }

    func undo() {
        textView?.undoManager?.undo()
        if let attributed = textView?.attributedText {
            onMutation?(attributed)
        }
    }

    func redo() {
        textView?.undoManager?.redo()
        if let attributed = textView?.attributedText {
            onMutation?(attributed)
        }
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            let current = (textView.typingAttributes[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            textView.typingAttributes[.font] = current.togglingTrait(trait)
            return
        }

        let text = mutableText()
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            text.addAttribute(.font, value: font.togglingTrait(trait), range: subrange)
        }
        apply(text, selectedRange: range)
    }

    private func applyAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            attributes.forEach { textView.typingAttributes[$0.key] = $0.value }
            return
        }
        let text = mutableText()
        text.addAttributes(attributes, range: range)
        apply(text, selectedRange: range)
    }

    private func toggleIntegerAttribute(_ key: NSAttributedString.Key, activeValue: Int) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            let current = textView.typingAttributes[key] as? Int
            if current == activeValue {
                textView.typingAttributes.removeValue(forKey: key)
            } else {
                textView.typingAttributes[key] = activeValue
            }
            return
        }

        let text = mutableText()
        let existing = text.attribute(key, at: range.location, effectiveRange: nil) as? Int
        if existing == activeValue {
            text.removeAttribute(key, range: range)
        } else {
            text.addAttribute(key, value: activeValue, range: range)
        }
        apply(text, selectedRange: range)
    }

    private func toggleBaseline(offset: CGFloat, sizeDelta: CGFloat) {
        guard let textView else { return }
        let range = textView.selectedRange
        if range.length == 0 {
            let current = textView.typingAttributes[.baselineOffset] as? CGFloat
            if current == offset {
                textView.typingAttributes.removeValue(forKey: .baselineOffset)
            } else {
                textView.typingAttributes[.baselineOffset] = offset
            }
            return
        }

        let text = mutableText()
        let existing = text.attribute(.baselineOffset, at: range.location, effectiveRange: nil) as? CGFloat
        if existing == offset {
            text.removeAttribute(.baselineOffset, range: range)
        } else {
            text.addAttribute(.baselineOffset, value: offset, range: range)
            text.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = (value as? UIFont) ?? SBTheme.bodyUIFont(size: 19)
                text.addAttribute(.font, value: font.withSize(max(font.pointSize + sizeDelta, 9)), range: subrange)
            }
        }
        apply(text, selectedRange: range)
    }

    private func replaceSelection(with replacement: NSAttributedString) {
        guard let textView else { return }
        let range = textView.selectedRange
        let text = mutableText()
        text.replaceCharacters(in: range, with: replacement)
        let newCursor = range.location + replacement.length
        apply(text, selectedRange: NSRange(location: newCursor, length: 0))
    }

    private func mutableText() -> NSMutableAttributedString {
        NSMutableAttributedString(attributedString: textView?.attributedText ?? NSAttributedString())
    }

    private func apply(_ text: NSAttributedString, selectedRange: NSRange? = nil, registerUndo: Bool = true) {
        guard let textView else { return }
        if registerUndo, let previousText = textView.attributedText?.copy() as? NSAttributedString {
            let previousRange = textView.selectedRange
            textView.undoManager?.registerUndo(withTarget: self) { target in
                target.apply(previousText, selectedRange: previousRange)
            }
        }
        let range = selectedRange ?? textView.selectedRange
        textView.attributedText = text
        textView.selectedRange = clamped(range, length: text.length)
        onMutation?(text)
    }

    private func clamped(_ range: NSRange, length: Int) -> NSRange {
        guard range.location <= length else {
            return NSRange(location: length, length: 0)
        }
        return NSRange(location: range.location, length: min(range.length, length - range.location))
    }

    private func effectiveSelection(in textView: UITextView) -> NSRange {
        if textView.selectedRange.length > 0 {
            return textView.selectedRange
        }
        return NSRange(location: 0, length: textView.attributedText.length)
    }

    private func paragraphRange(in textView: UITextView) -> NSRange {
        let nsString = textView.attributedText.string as NSString
        guard nsString.length > 0 else {
            return NSRange(location: 0, length: 0)
        }
        let cursor = min(textView.selectedRange.location, max(nsString.length - 1, 0))
        return nsString.paragraphRange(for: NSRange(location: cursor, length: max(textView.selectedRange.length, 0)))
    }
}

private final class ScriptoriumTextView: UITextView {
    weak var commandContext: RichTextContext?

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(keyBold), discoverabilityTitle: "Bold"),
            UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(keyItalic), discoverabilityTitle: "Italic"),
            UIKeyCommand(input: "u", modifierFlags: .command, action: #selector(keyUnderline), discoverabilityTitle: "Underline"),
            UIKeyCommand(input: "k", modifierFlags: .command, action: #selector(keyLink), discoverabilityTitle: "Link"),
            UIKeyCommand(input: "z", modifierFlags: .command, action: #selector(keyUndo), discoverabilityTitle: "Undo"),
            UIKeyCommand(input: "z", modifierFlags: [.command, .shift], action: #selector(keyRedo), discoverabilityTitle: "Redo"),
        ]
    }

    @objc private func keyBold() {
        commandContext?.toggleBold()
    }

    @objc private func keyItalic() {
        commandContext?.toggleItalic()
    }

    @objc private func keyUnderline() {
        commandContext?.toggleUnderline()
    }

    @objc private func keyLink() {
        commandContext?.insertLinkPlaceholder()
    }

    @objc private func keyUndo() {
        commandContext?.undo()
    }

    @objc private func keyRedo() {
        commandContext?.redo()
    }
}

private extension UIFont {
    func togglingTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if traits.contains(trait) {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }
        return applyingTraits(traits)
    }

    func addingTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(trait)
        return applyingTraits(traits)
    }

    func applyingTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
