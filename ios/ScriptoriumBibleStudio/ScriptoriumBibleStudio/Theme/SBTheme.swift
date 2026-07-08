import SwiftUI
import UIKit

enum SBTheme {
    static let parchment = Color(hex: 0xF4EAD5)
    static let ivory = Color(hex: 0xFBF6EA)
    static let parchmentDeep = Color(hex: 0xE8D9B8)
    static let ink = Color(hex: 0x2A1F14)
    static let primary = Color(hex: 0x4A2C17)
    static let gold = Color(hex: 0xB8912F)
    static let goldSoft = Color(hex: 0xE8D28A)
    static let crimson = Color(hex: 0x7A1F13)
    static let mutedForeground = Color(hex: 0x7A6A55)
    static let border = Color(hex: 0xD9C69A)

    static let promise = Color(hex: 0xC8E1B4).opacity(0.42)
    static let warning = Color(hex: 0xF1C87A).opacity(0.42)
    static let prophecy = Color(hex: 0xB8C7E6).opacity(0.42)
    static let prayer = Color(hex: 0xE5B4C8).opacity(0.42)
    static let doctrine = Color(hex: 0xC9B892).opacity(0.42)
    static let note = Color(hex: 0xE8D28A).opacity(0.42)

    static let uiParchment = UIColor(hex: 0xF4EAD5)
    static let uiIvory = UIColor(hex: 0xFBF6EA)
    static let uiInk = UIColor(hex: 0x2A1F14)
    static let uiPrimary = UIColor(hex: 0x4A2C17)
    static let uiGold = UIColor(hex: 0xB8912F)
    static let uiGoldSoft = UIColor(hex: 0xE8D28A)
    static let uiCrimson = UIColor(hex: 0x7A1F13)
    static let uiMutedForeground = UIColor(hex: 0x7A6A55)
    static let uiBorder = UIColor(hex: 0xD9C69A)

    enum FontName {
        static let display = "Cinzel-Regular"
        static let displayBold = "CinzelRoman-Bold"
        static let body = "CormorantGaramond-Regular"
        static let bodyItalic = "CormorantGaramond-Italic"
        static let bodySemiBold = "CormorantGaramond-SemiBold"
        static let ui = "Inter-Regular"
        static let uiMedium = "Inter-Regular_Medium"
        static let monospace = "Menlo-Regular"
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(FontName.display, size: size).weight(weight)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(FontName.body, size: size).weight(weight)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(FontName.ui, size: size).weight(weight)
    }

    static func displayUIFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        let name = weight.rawValue >= UIFont.Weight.bold.rawValue ? FontName.displayBold : FontName.display
        if let font = UIFont(name: name, size: size) {
            return font.withWeightAndSlant(weight: weight, italic: false)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    static func bodyUIFont(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let preferredName: String
        if italic {
            preferredName = FontName.bodyItalic
        } else if weight.rawValue >= UIFont.Weight.semibold.rawValue {
            preferredName = FontName.bodySemiBold
        } else {
            preferredName = FontName.body
        }

        if let font = UIFont(name: preferredName, size: size) {
            return font
        }

        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.serif)
        return UIFont(descriptor: descriptor ?? .preferredFontDescriptor(withTextStyle: .body), size: size)
            .withWeightAndSlant(weight: weight, italic: italic)
    }

    static func uiUIFont(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        let name = weight.rawValue >= UIFont.Weight.medium.rawValue ? FontName.uiMedium : FontName.ui
        if let font = UIFont(name: name, size: size) {
            return italic ? font.withSlant() : font
        }
        return UIFont.systemFont(ofSize: size, weight: weight).withWeightAndSlant(weight: weight, italic: italic)
    }
}

enum ScriptoriumPalette {
    static let background = SBTheme.parchment
    static let panel = SBTheme.ivory
    static let ink = SBTheme.ink
    static let mutedInk = SBTheme.mutedForeground
    static let indigo = SBTheme.prophecy
    static let teal = SBTheme.promise
    static let amber = SBTheme.warning
    static let rose = SBTheme.crimson
    static let gold = SBTheme.gold
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

private extension UIFont {
    func withWeightAndSlant(weight: UIFont.Weight, italic: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if italic {
            traits.insert(.traitItalic)
        }
        let weighted = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight],
        ])
        guard let descriptor = weighted.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    func withSlant() -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
