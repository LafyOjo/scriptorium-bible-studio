import SwiftUI
import UIKit

enum ChapterStatus: String, CaseIterable, Identifiable {
    case notStarted = "not-started"
    case drafting
    case revised
    case complete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .drafting: return "Drafting"
        case .revised: return "Revised"
        case .complete: return "Complete"
        }
    }

    var tint: Color {
        switch self {
        case .notStarted: return .secondary
        case .drafting: return ScriptoriumPalette.amber
        case .revised: return ScriptoriumPalette.indigo
        case .complete: return ScriptoriumPalette.teal
        }
    }

    var uiColor: UIColor {
        switch self {
        case .notStarted: return .secondaryLabel
        case .drafting: return UIColor(red: 0.92, green: 0.59, blue: 0.16, alpha: 1)
        case .revised: return UIColor(red: 0.34, green: 0.43, blue: 0.88, alpha: 1)
        case .complete: return UIColor(red: 0.10, green: 0.55, blue: 0.47, alpha: 1)
        }
    }
}

enum Testament: String, CaseIterable, Identifiable {
    case old
    case new
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .old: return "Old Testament"
        case .new: return "New Testament"
        case .custom: return "Custom"
        }
    }
}

enum HighlightTheme: String, CaseIterable, Identifiable {
    case covenant
    case prophecy
    case wisdom
    case judgement
    case mercy
    case genealogy
    case law
    case gospel
    case personal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .covenant: return "Covenant"
        case .prophecy: return "Prophecy"
        case .wisdom: return "Wisdom"
        case .judgement: return "Judgement"
        case .mercy: return "Mercy"
        case .genealogy: return "Genealogy"
        case .law: return "Law"
        case .gospel: return "Gospel"
        case .personal: return "Personal Study"
        }
    }

    var color: Color {
        switch self {
        case .covenant: return Color(red: 0.95, green: 0.80, blue: 0.36)
        case .prophecy: return Color(red: 0.77, green: 0.68, blue: 0.96)
        case .wisdom: return Color(red: 0.49, green: 0.82, blue: 0.78)
        case .judgement: return Color(red: 0.95, green: 0.50, blue: 0.40)
        case .mercy: return Color(red: 0.55, green: 0.86, blue: 0.62)
        case .genealogy: return Color(red: 0.84, green: 0.80, blue: 0.67)
        case .law: return Color(red: 0.62, green: 0.72, blue: 0.95)
        case .gospel: return Color(red: 0.98, green: 0.76, blue: 0.24)
        case .personal: return Color(red: 0.92, green: 0.66, blue: 0.85)
        }
    }

    var uiColor: UIColor {
        UIColor(color).withAlphaComponent(0.48)
    }
}

enum StudioSection: String, CaseIterable, Identifiable {
    case dashboard
    case library
    case editor
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .library: return "Library"
        case .editor: return "Editor"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .library: return "books.vertical"
        case .editor: return "text.book.closed"
        case .search: return "magnifyingglass"
        case .settings: return "slider.horizontal.3"
        }
    }
}

enum EditorMode: String, CaseIterable, Identifiable {
    case write
    case read

    var id: String { rawValue }
    var label: String { self == .write ? "Write" : "Read" }
    var systemImage: String { self == .write ? "pencil.line" : "eye" }
}

struct FontOption: Identifiable, Hashable {
    let id: String
    let label: String

    static let all: [FontOption] = [
        FontOption(id: "system-serif", label: "System Serif"),
        FontOption(id: "NewYork-Regular", label: "New York"),
        FontOption(id: "Georgia", label: "Georgia"),
        FontOption(id: "AvenirNext-Regular", label: "Avenir Next"),
        FontOption(id: "HoeflerText-Regular", label: "Hoefler Text"),
        FontOption(id: "Menlo-Regular", label: "Menlo"),
    ]
}

enum ScriptoriumPalette {
    static let background = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let mutedInk = Color(red: 0.42, green: 0.43, blue: 0.48)
    static let indigo = Color(red: 0.34, green: 0.43, blue: 0.88)
    static let teal = Color(red: 0.10, green: 0.55, blue: 0.47)
    static let amber = Color(red: 0.92, green: 0.59, blue: 0.16)
    static let rose = Color(red: 0.82, green: 0.26, blue: 0.39)
    static let gold = Color(red: 0.76, green: 0.58, blue: 0.24)
}

extension NSAttributedString.Key {
    static let scriptoriumHighlightTheme = NSAttributedString.Key("ScriptoriumHighlightTheme")
}
