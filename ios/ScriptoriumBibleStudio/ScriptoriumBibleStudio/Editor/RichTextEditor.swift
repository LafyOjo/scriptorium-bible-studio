import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var selectedText: String

    let context: RichTextContext
    let settings: SBAppSettings?
    let onTextChange: (NSAttributedString) -> Void

    func makeUIView(context coordinatorContext: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = coordinatorContext.coordinator
        textView.backgroundColor = .clear
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.allowsEditingTextAttributes = true
        textView.adjustsFontForContentSizeCategory = true
        textView.attributedText = text
        textView.typingAttributes = AttributedContent.baseAttributes(settings: settings)
        coordinatorContext.coordinator.install(textView: textView, commandContext: context)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context coordinatorContext: Context) {
        coordinatorContext.coordinator.onTextChange = onTextChange
        coordinatorContext.coordinator.selectedText = $selectedText
        coordinatorContext.coordinator.commandContext = self.context
        coordinatorContext.coordinator.commandContext?.textView = uiView

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

    func applyHeading() {
        guard let textView else { return }
        let range = paragraphRange(in: textView)
        let text = mutableText()
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = 14
        paragraph.paragraphSpacingBefore = 10
        text.addAttributes([
            .font: AttributedContent.displayFont(size: 25, weight: .semibold),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph,
        ], range: range)
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
        text.addAttribute(.paragraphStyle, value: paragraph, range: range)
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = (value as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
            text.addAttribute(.font, value: font.addingTrait(.traitItalic), range: subrange)
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
                .foregroundColor: UIColor(red: 0.60, green: 0.16, blue: 0.18, alpha: 1),
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
                .foregroundColor: UIColor(red: 0.60, green: 0.16, blue: 0.18, alpha: 1),
                .kern: 1.2,
                .paragraphStyle: paragraph,
            ]
        ))
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

    private func apply(_ text: NSAttributedString, selectedRange: NSRange? = nil) {
        guard let textView else { return }
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
