import Foundation
import UIKit

enum AttributedContent {
    static func makeEmpty(settings: SBAppSettings? = nil) -> NSAttributedString {
        NSAttributedString(string: "", attributes: baseAttributes(settings: settings))
    }

    static func makeSeeded(sectionTitle: String, verses: [(Int, String)], settings: SBAppSettings? = nil) -> NSAttributedString {
        let content = NSMutableAttributedString()
        let sectionParagraph = NSMutableParagraphStyle()
        sectionParagraph.alignment = .center
        sectionParagraph.paragraphSpacing = 12

        content.append(NSAttributedString(
            string: sectionTitle.uppercased() + "\n\n",
            attributes: [
                .font: displayFont(size: 18, weight: .semibold),
                .foregroundColor: SBTheme.uiCrimson,
                .kern: 1.2,
                .paragraphStyle: sectionParagraph,
            ]
        ))

        for (number, text) in verses {
            content.append(verseNumber(number))
            content.append(NSAttributedString(
                string: text + "\n\n",
                attributes: baseAttributes(settings: settings)
            ))
        }

        return content
    }

    static func fromRTFData(_ data: Data?, settings: SBAppSettings? = nil) -> NSAttributedString {
        guard let data else { return makeEmpty(settings: settings) }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) {
            return attributed
        }
        if let fallback = String(data: data, encoding: .utf8) {
            return NSAttributedString(string: fallback, attributes: baseAttributes(settings: settings))
        }
        return makeEmpty(settings: settings)
    }

    static func rtfData(from attributedString: NSAttributedString) -> Data? {
        guard attributedString.length > 0 else {
            return Data()
        }
        return try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func htmlData(from attributedString: NSAttributedString) -> Data? {
        guard attributedString.length > 0 else {
            return Data()
        }
        return try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        )
    }

    static func baseAttributes(settings: SBAppSettings?) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = settings?.lineSpacing ?? 4
        paragraph.paragraphSpacing = 10

        var font = editorFont(
            name: settings?.fontName ?? SBTheme.FontName.body,
            size: settings?.fontSize ?? 19,
            bold: settings?.defaultBold ?? false,
            italic: settings?.defaultItalic ?? false
        )

        if settings?.defaultUnderline == true {
            font = font.withTraits(font.fontDescriptor.symbolicTraits)
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: SBTheme.uiInk,
            .paragraphStyle: paragraph,
        ]

        if settings?.defaultUnderline == true {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    static func verseNumber(_ number: Int) -> NSAttributedString {
        NSAttributedString(
            string: "\(number) ",
            attributes: [
                .font: displayFont(size: 12, weight: .bold),
                .foregroundColor: SBTheme.uiGold,
                .baselineOffset: 7,
            ]
        )
    }

    static func displayFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        SBTheme.displayUIFont(size: size, weight: weight)
    }

    static func editorFont(name: String, size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        let base: UIFont
        if name == "system-serif" {
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.serif)
            base = UIFont(descriptor: descriptor ?? .preferredFontDescriptor(withTextStyle: .body), size: size)
        } else if name == SBTheme.FontName.body {
            base = SBTheme.bodyUIFont(size: size)
        } else if name == SBTheme.FontName.display {
            base = SBTheme.displayUIFont(size: size)
        } else if name == SBTheme.FontName.ui {
            base = SBTheme.uiUIFont(size: size)
        } else {
            base = UIFont(name: name, size: size) ?? SBTheme.bodyUIFont(size: size)
        }

        var traits = base.fontDescriptor.symbolicTraits
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        return base.withTraits(traits)
    }
}

private extension UIFont {
    func withDesign(_ descriptor: UIFontDescriptor) -> UIFont {
        UIFont(descriptor: descriptor, size: pointSize)
    }

    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
