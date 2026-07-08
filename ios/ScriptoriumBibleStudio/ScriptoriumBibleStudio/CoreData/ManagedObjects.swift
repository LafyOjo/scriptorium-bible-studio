import CoreData
import Foundation

@objc(SBCollection)
final class SBCollection: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var orderIndex: Int64
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var books: NSSet?
}

extension SBCollection {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBCollection> {
        NSFetchRequest<SBCollection>(entityName: "SBCollection")
    }

    var bookArray: [SBBook] {
        (books as? Set<SBBook> ?? [])
            .sorted { left, right in
                if left.orderIndex == right.orderIndex {
                    return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
                }
                return left.orderIndex < right.orderIndex
            }
    }
}

@objc(SBBook)
final class SBBook: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var testament: String
    @NSManaged var orderIndex: Int64
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var collection: SBCollection?
    @NSManaged var chapters: NSSet?
    @NSManaged var bookmarks: NSSet?
}

extension SBBook {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBBook> {
        NSFetchRequest<SBBook>(entityName: "SBBook")
    }

    var testamentValue: Testament {
        Testament(rawValue: testament) ?? .custom
    }

    var chapterArray: [SBChapter] {
        (chapters as? Set<SBChapter> ?? [])
            .sorted { left, right in
                if left.number == right.number {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return left.number < right.number
            }
    }
}

@objc(SBChapter)
final class SBChapter: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var number: Int64
    @NSManaged var title: String
    @NSManaged var attributedData: Data?
    @NSManaged var contentData: Data?
    @NSManaged var plainText: String
    @NSManaged var status: String
    @NSManaged var tags: String
    @NSManaged var highlightThemes: String
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date
    @NSManaged var book: SBBook?
    @NSManaged var notes: NSSet?
    @NSManaged var bookmarks: NSSet?
}

extension SBChapter {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBChapter> {
        NSFetchRequest<SBChapter>(entityName: "SBChapter")
    }

    var statusValue: ChapterStatus {
        switch status {
        case "not-started": return .notStarted
        case "revised": return .revising
        case "complete": return .final
        default: return ChapterStatus(rawValue: status) ?? .notStarted
        }
    }

    var tagArray: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var themeArray: [HighlightTheme] {
        highlightThemes
            .split(separator: ",")
            .compactMap { HighlightTheme(rawValue: String($0)) }
    }

    var noteArray: [SBNote] {
        (notes as? Set<SBNote> ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    var bookmarkArray: [SBBookmark] {
        (bookmarks as? Set<SBBookmark> ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }
}

@objc(SBNote)
final class SBNote: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var body: String?
    @NSManaged var text: String
    @NSManaged var excerpt: String
    @NSManaged var theme: String?
    @NSManaged var rangeLocation: Int64
    @NSManaged var rangeLength: Int64
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date?
    @NSManaged var chapter: SBChapter?
}

extension SBNote {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBNote> {
        NSFetchRequest<SBNote>(entityName: "SBNote")
    }

    var themeValue: HighlightTheme? {
        guard let theme else { return nil }
        return HighlightTheme(rawValue: theme)
    }
}

@objc(SBBookmark)
final class SBBookmark: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var chapterID: String?
    @NSManaged var label: String
    @NSManaged var snippet: String?
    @NSManaged var passage: String?
    @NSManaged var location: Int64
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date?
    @NSManaged var book: SBBook?
    @NSManaged var chapter: SBChapter?
}

extension SBBookmark {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBBookmark> {
        NSFetchRequest<SBBookmark>(entityName: "SBBookmark")
    }
}

@objc(SBAppSettings)
final class SBAppSettings: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var editorFontName: String?
    @NSManaged var fontName: String
    @NSManaged var readerFontSize: Double
    @NSManaged var fontSize: Double
    @NSManaged var lineSpacing: Double
    @NSManaged var defaultBold: Bool
    @NSManaged var defaultItalic: Bool
    @NSManaged var defaultUnderline: Bool
    @NSManaged var readAloudRate: Double
    @NSManaged var autosaveEnabled: Bool
    @NSManaged var voiceIdentifier: String?
    @NSManaged var theme: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

extension SBAppSettings {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SBAppSettings> {
        NSFetchRequest<SBAppSettings>(entityName: "SBAppSettings")
    }
}
