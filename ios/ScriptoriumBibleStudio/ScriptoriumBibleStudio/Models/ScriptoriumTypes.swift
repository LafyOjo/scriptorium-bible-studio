import SwiftUI
import UIKit

enum ChapterStatus: String, CaseIterable, Identifiable {
    case notStarted
    case drafting
    case revising
    case final

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .drafting: return "Drafting"
        case .revising: return "Revising"
        case .final: return "Final"
        }
    }

    var tint: Color {
        switch self {
        case .notStarted: return SBTheme.mutedForeground
        case .drafting: return SBTheme.warning
        case .revising: return SBTheme.prophecy
        case .final: return SBTheme.promise
        }
    }

    var uiColor: UIColor {
        switch self {
        case .notStarted: return SBTheme.uiMutedForeground
        case .drafting: return UIColor(hex: 0xF1C87A)
        case .revising: return UIColor(hex: 0xB8C7E6)
        case .final: return UIColor(hex: 0xC8E1B4)
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
    case promise
    case warning
    case prophecy
    case prayer
    case doctrine
    case note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .promise: return "Promise"
        case .warning: return "Warning"
        case .prophecy: return "Prophecy"
        case .prayer: return "Prayer"
        case .doctrine: return "Doctrine"
        case .note: return "Note"
        }
    }

    var color: Color {
        switch self {
        case .promise: return SBTheme.promise
        case .warning: return SBTheme.warning
        case .prophecy: return SBTheme.prophecy
        case .prayer: return SBTheme.prayer
        case .doctrine: return SBTheme.doctrine
        case .note: return SBTheme.note
        }
    }

    var uiColor: UIColor {
        switch self {
        case .promise: return UIColor(hex: 0xC8E1B4, alpha: 0.42)
        case .warning: return UIColor(hex: 0xF1C87A, alpha: 0.42)
        case .prophecy: return UIColor(hex: 0xB8C7E6, alpha: 0.42)
        case .prayer: return UIColor(hex: 0xE5B4C8, alpha: 0.42)
        case .doctrine: return UIColor(hex: 0xC9B892, alpha: 0.42)
        case .note: return UIColor(hex: 0xE8D28A, alpha: 0.42)
        }
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
        FontOption(id: SBTheme.FontName.body, label: "Cormorant Garamond"),
        FontOption(id: SBTheme.FontName.display, label: "Cinzel"),
        FontOption(id: SBTheme.FontName.ui, label: "Inter"),
        FontOption(id: "Georgia", label: "Georgia"),
        FontOption(id: "HoeflerText-Regular", label: "Hoefler Text"),
        FontOption(id: SBTheme.FontName.monospace, label: "Menlo"),
    ]
}

extension NSAttributedString.Key {
    static let scriptoriumHighlightTheme = NSAttributedString.Key("ScriptoriumHighlightTheme")
}
