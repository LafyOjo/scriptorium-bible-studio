import CoreData
import Foundation

struct ScriptoriumBackup: Codable {
    var version: Int
    var collections: [CollectionDTO]
    var books: [BookDTO]
    var chapters: [ChapterDTO]
    var notes: [NoteDTO]
    var bookmarks: [BookmarkDTO]
    var settings: SettingsDTO?
}

struct CollectionDTO: Codable {
    var id: String
    var name: String
}

struct BookDTO: Codable {
    var id: String
    var name: String
    var testament: String
    var orderIndex: Int64
    var collectionId: String?
}

struct ChapterDTO: Codable {
    var id: String
    var bookId: String
    var number: Int64
    var title: String
    var rtfBase64: String?
    var plainText: String
    var status: String
    var tags: [String]
    var highlightThemes: [String]
    var updatedAt: Date
}

struct NoteDTO: Codable {
    var id: String
    var chapterId: String
    var text: String
    var excerpt: String
    var theme: String?
    var createdAt: Date
}

struct BookmarkDTO: Codable {
    var id: String
    var bookId: String
    var chapterId: String?
    var label: String
    var passage: String?
    var createdAt: Date
}

struct SettingsDTO: Codable {
    var fontName: String
    var fontSize: Double
    var lineSpacing: Double
    var defaultBold: Bool
    var defaultItalic: Bool
    var defaultUnderline: Bool
}

enum BackupService {
    static func makeBackup(
        books: [SBBook],
        chapters: [SBChapter],
        collections: [SBCollection],
        notes: [SBNote],
        bookmarks: [SBBookmark],
        settings: SBAppSettings?
    ) -> ScriptoriumBackup {
        ScriptoriumBackup(
            version: 1,
            collections: collections.map { CollectionDTO(id: $0.id, name: $0.name) },
            books: books.map {
                BookDTO(
                    id: $0.id,
                    name: $0.name,
                    testament: $0.testament,
                    orderIndex: $0.orderIndex,
                    collectionId: $0.collection?.id
                )
            },
            chapters: chapters.map {
                ChapterDTO(
                    id: $0.id,
                    bookId: $0.book?.id ?? "",
                    number: $0.number,
                    title: $0.title,
                    rtfBase64: $0.contentData?.base64EncodedString(),
                    plainText: $0.plainText,
                    status: $0.status,
                    tags: $0.tagArray,
                    highlightThemes: $0.themeArray.map(\.rawValue),
                    updatedAt: $0.updatedAt
                )
            },
            notes: notes.compactMap { note in
                guard let chapterId = note.chapter?.id else { return nil }
                return NoteDTO(
                    id: note.id,
                    chapterId: chapterId,
                    text: note.text,
                    excerpt: note.excerpt,
                    theme: note.theme,
                    createdAt: note.createdAt
                )
            },
            bookmarks: bookmarks.compactMap { bookmark in
                guard let bookId = bookmark.book?.id else { return nil }
                return BookmarkDTO(
                    id: bookmark.id,
                    bookId: bookId,
                    chapterId: bookmark.chapter?.id,
                    label: bookmark.label,
                    passage: bookmark.passage,
                    createdAt: bookmark.createdAt
                )
            },
            settings: settings.map {
                SettingsDTO(
                    fontName: $0.fontName,
                    fontSize: $0.fontSize,
                    lineSpacing: $0.lineSpacing,
                    defaultBold: $0.defaultBold,
                    defaultItalic: $0.defaultItalic,
                    defaultUnderline: $0.defaultUnderline
                )
            }
        )
    }

    static func encode(_ backup: ScriptoriumBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> ScriptoriumBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScriptoriumBackup.self, from: data)
    }

    static func restore(_ backup: ScriptoriumBackup, persistence: PersistenceController, context: NSManagedObjectContext) {
        persistence.deleteAllData(context: context)

        var collectionsById: [String: SBCollection] = [:]
        for dto in backup.collections {
            let collection = SBCollection(context: context)
            collection.id = dto.id
            collection.name = dto.name
            collectionsById[dto.id] = collection
        }

        var booksById: [String: SBBook] = [:]
        for dto in backup.books {
            let book = SBBook(context: context)
            book.id = dto.id
            book.name = dto.name
            book.testament = dto.testament
            book.orderIndex = dto.orderIndex
            if let collectionId = dto.collectionId {
                book.collection = collectionsById[collectionId]
            }
            booksById[dto.id] = book
        }

        var chaptersById: [String: SBChapter] = [:]
        for dto in backup.chapters {
            guard let book = booksById[dto.bookId] else { continue }
            let chapter = SBChapter(context: context)
            chapter.id = dto.id
            chapter.book = book
            chapter.number = dto.number
            chapter.title = dto.title
            chapter.contentData = dto.rtfBase64.flatMap { Data(base64Encoded: $0) }
            chapter.plainText = dto.plainText
            chapter.status = dto.status
            chapter.tags = dto.tags.joined(separator: ",")
            chapter.highlightThemes = dto.highlightThemes.joined(separator: ",")
            chapter.updatedAt = dto.updatedAt
            chaptersById[dto.id] = chapter
        }

        for dto in backup.notes {
            guard let chapter = chaptersById[dto.chapterId] else { continue }
            let note = SBNote(context: context)
            note.id = dto.id
            note.chapter = chapter
            note.text = dto.text
            note.excerpt = dto.excerpt
            note.theme = dto.theme
            note.createdAt = dto.createdAt
        }

        for dto in backup.bookmarks {
            guard let book = booksById[dto.bookId] else { continue }
            let bookmark = SBBookmark(context: context)
            bookmark.id = dto.id
            bookmark.book = book
            bookmark.chapter = dto.chapterId.flatMap { chaptersById[$0] }
            bookmark.label = dto.label
            bookmark.passage = dto.passage
            bookmark.createdAt = dto.createdAt
        }

        if let dto = backup.settings {
            let settings = SBAppSettings(context: context)
            settings.id = "default"
            settings.fontName = dto.fontName
            settings.fontSize = dto.fontSize
            settings.lineSpacing = dto.lineSpacing
            settings.defaultBold = dto.defaultBold
            settings.defaultItalic = dto.defaultItalic
            settings.defaultUnderline = dto.defaultUnderline
        } else {
            _ = ScriptoriumSeed.insertDefaultSettings(context: context)
        }

        persistence.save(context: context)
    }
}
