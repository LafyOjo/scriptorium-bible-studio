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
    var orderIndex: Int64?
    var createdAt: Date?
    var updatedAt: Date?
}

struct BookDTO: Codable {
    var id: String
    var name: String
    var testament: String
    var orderIndex: Int64
    var collectionId: String?
    var createdAt: Date?
    var updatedAt: Date?
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
    var createdAt: Date?
    var updatedAt: Date
}

struct NoteDTO: Codable {
    var id: String
    var chapterId: String
    var text: String
    var body: String?
    var excerpt: String
    var theme: String?
    var rangeLocation: Int64?
    var rangeLength: Int64?
    var createdAt: Date
    var updatedAt: Date?
}

struct BookmarkDTO: Codable {
    var id: String
    var bookId: String
    var chapterId: String?
    var chapterID: String?
    var label: String
    var snippet: String?
    var passage: String?
    var location: Int64?
    var createdAt: Date
    var updatedAt: Date?
}

struct SettingsDTO: Codable {
    var editorFontName: String?
    var fontName: String
    var readerFontSize: Double?
    var fontSize: Double
    var lineSpacing: Double
    var defaultBold: Bool
    var defaultItalic: Bool
    var defaultUnderline: Bool
    var readAloudRate: Double?
    var autosaveEnabled: Bool?
    var voiceIdentifier: String?
    var theme: String?
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
            version: 3,
            collections: collections.map {
                CollectionDTO(
                    id: $0.id,
                    name: $0.name,
                    orderIndex: $0.orderIndex,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            books: books.map {
                BookDTO(
                    id: $0.id,
                    name: $0.name,
                    testament: $0.testament,
                    orderIndex: $0.orderIndex,
                    collectionId: $0.collection?.id,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            chapters: chapters.map {
                ChapterDTO(
                    id: $0.id,
                    bookId: $0.book?.id ?? "",
                    number: $0.number,
                    title: $0.title,
                    rtfBase64: ($0.attributedData ?? $0.contentData)?.base64EncodedString(),
                    plainText: $0.plainText,
                    status: $0.status,
                    tags: $0.tagArray,
                    highlightThemes: $0.themeArray.map(\.rawValue),
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            notes: notes.compactMap { note in
                guard let chapterId = note.chapter?.id else { return nil }
                return NoteDTO(
                    id: note.id,
                    chapterId: chapterId,
                    text: note.text,
                    body: note.body,
                    excerpt: note.excerpt,
                    theme: note.theme,
                    rangeLocation: note.rangeLocation,
                    rangeLength: note.rangeLength,
                    createdAt: note.createdAt,
                    updatedAt: note.updatedAt
                )
            },
            bookmarks: bookmarks.compactMap { bookmark in
                guard let bookId = bookmark.book?.id else { return nil }
                return BookmarkDTO(
                    id: bookmark.id,
                    bookId: bookId,
                    chapterId: bookmark.chapter?.id,
                    chapterID: bookmark.chapterID,
                    label: bookmark.label,
                    snippet: bookmark.snippet,
                    passage: bookmark.passage,
                    location: bookmark.location,
                    createdAt: bookmark.createdAt,
                    updatedAt: bookmark.updatedAt
                )
            },
            settings: settings.map {
                SettingsDTO(
                    editorFontName: $0.editorFontName,
                    fontName: $0.fontName,
                    readerFontSize: $0.readerFontSize,
                    fontSize: $0.fontSize,
                    lineSpacing: $0.lineSpacing,
                    defaultBold: $0.defaultBold,
                    defaultItalic: $0.defaultItalic,
                    defaultUnderline: $0.defaultUnderline,
                    readAloudRate: $0.readAloudRate,
                    autosaveEnabled: $0.autosaveEnabled,
                    voiceIdentifier: $0.voiceIdentifier,
                    theme: $0.theme
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
            collection.orderIndex = dto.orderIndex ?? Int64(collectionsById.count + 1)
            collection.createdAt = dto.createdAt
            collection.updatedAt = dto.updatedAt
            collectionsById[dto.id] = collection
        }

        var booksById: [String: SBBook] = [:]
        for dto in backup.books {
            let book = SBBook(context: context)
            book.id = dto.id
            book.name = dto.name
            book.testament = dto.testament
            book.orderIndex = dto.orderIndex
            book.createdAt = dto.createdAt
            book.updatedAt = dto.updatedAt
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
            chapter.createdAt = dto.createdAt
            chapter.updatedAt = dto.updatedAt
            chapter.attributedData = chapter.contentData
            chaptersById[dto.id] = chapter
        }

        for dto in backup.notes {
            guard let chapter = chaptersById[dto.chapterId] else { continue }
            let note = SBNote(context: context)
            note.id = dto.id
            note.chapter = chapter
            note.body = dto.body ?? dto.text
            note.text = dto.text
            note.excerpt = dto.excerpt
            note.theme = dto.theme
            note.rangeLocation = dto.rangeLocation ?? 0
            note.rangeLength = dto.rangeLength ?? Int64(dto.excerpt.utf16.count)
            note.createdAt = dto.createdAt
            note.updatedAt = dto.updatedAt
        }

        for dto in backup.bookmarks {
            guard let book = booksById[dto.bookId] else { continue }
            let bookmark = SBBookmark(context: context)
            bookmark.id = dto.id
            bookmark.book = book
            bookmark.chapter = dto.chapterId.flatMap { chaptersById[$0] }
            bookmark.chapterID = dto.chapterID ?? dto.chapterId
            bookmark.label = dto.label
            bookmark.snippet = dto.snippet
            bookmark.passage = dto.passage
            bookmark.location = dto.location ?? 0
            bookmark.createdAt = dto.createdAt
            bookmark.updatedAt = dto.updatedAt
        }

        if let dto = backup.settings {
            let settings = SBAppSettings(context: context)
            settings.id = "default"
            settings.editorFontName = dto.editorFontName ?? dto.fontName
            settings.fontName = dto.fontName
            settings.readerFontSize = dto.readerFontSize ?? dto.fontSize
            settings.fontSize = dto.fontSize
            settings.lineSpacing = dto.lineSpacing
            settings.defaultBold = dto.defaultBold
            settings.defaultItalic = dto.defaultItalic
            settings.defaultUnderline = dto.defaultUnderline
            settings.readAloudRate = dto.readAloudRate ?? 0.48
            settings.autosaveEnabled = dto.autosaveEnabled ?? true
            settings.voiceIdentifier = dto.voiceIdentifier
            settings.theme = dto.theme ?? "parchment"
            settings.createdAt = Date()
            settings.updatedAt = Date()
        } else {
            _ = ScriptoriumSeed.insertDefaultSettings(context: context)
        }

        persistence.save(context: context)
    }
}
