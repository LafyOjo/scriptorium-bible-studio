import CoreData
import Foundation

enum ScriptoriumActions {
    @discardableResult
    static func createCollection(name: String, context: NSManagedObjectContext) -> SBCollection {
        let now = Date()
        let collection = SBCollection(context: context)
        collection.id = UUID().uuidString
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.orderIndex = nextCollectionOrder(context: context)
        collection.createdAt = now
        collection.updatedAt = now
        save(context)
        return collection
    }

    @discardableResult
    static func createBook(
        name: String,
        testament: Testament,
        collection: SBCollection?,
        existingBooks: [SBBook],
        context: NSManagedObjectContext
    ) -> SBBook {
        let now = Date()
        let book = SBBook(context: context)
        book.id = UUID().uuidString
        book.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        book.testament = testament.rawValue
        book.orderIndex = (existingBooks.map(\.orderIndex).max() ?? 0) + 1
        book.collection = collection
        book.createdAt = now
        book.updatedAt = now
        collection?.updatedAt = now
        save(context)
        return book
    }

    @discardableResult
    static func createChapter(book: SBBook, settings: SBAppSettings?, context: NSManagedObjectContext) -> SBChapter {
        let chapter = SBChapter(context: context)
        let nextNumber = (book.chapterArray.map(\.number).max() ?? 0) + 1
        let content = AttributedContent.makeEmpty(settings: settings)
        chapter.id = UUID().uuidString
        chapter.book = book
        chapter.number = nextNumber
        chapter.title = "Chapter \(nextNumber)"
        chapter.status = ChapterStatus.notStarted.rawValue
        chapter.tags = ""
        chapter.highlightThemes = ""
        let now = Date()
        chapter.createdAt = now
        chapter.updatedAt = now
        chapter.plainText = content.string
        let data = AttributedContent.rtfData(from: content)
        chapter.contentData = data
        chapter.attributedData = data
        book.updatedAt = now
        save(context)
        return chapter
    }

    static func deleteChapter(_ chapter: SBChapter, context: NSManagedObjectContext) {
        context.delete(chapter)
        save(context)
    }

    static func renameChapter(_ chapter: SBChapter, title: String, context: NSManagedObjectContext) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        chapter.title = clean
        chapter.updatedAt = Date()
        save(context)
    }

    static func renameBook(_ book: SBBook, name: String, context: NSManagedObjectContext) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        book.name = clean
        book.updatedAt = Date()
        save(context)
    }

    static func deleteBook(_ book: SBBook, context: NSManagedObjectContext) {
        context.delete(book)
        save(context)
    }

    static func moveBook(_ book: SBBook, direction: MoveDirection, in books: [SBBook], context: NSManagedObjectContext) {
        let ordered = books.sorted { $0.orderIndex < $1.orderIndex }
        guard let index = ordered.firstIndex(where: { $0.objectID == book.objectID }) else { return }
        let targetIndex = direction == .up ? index - 1 : index + 1
        guard ordered.indices.contains(targetIndex) else { return }

        let other = ordered[targetIndex]
        let originalOrder = book.orderIndex
        book.orderIndex = other.orderIndex
        other.orderIndex = originalOrder
        book.updatedAt = Date()
        other.updatedAt = Date()
        save(context)
    }

    static func moveChapter(_ chapter: SBChapter, direction: MoveDirection, in book: SBBook, context: NSManagedObjectContext) {
        let ordered = book.chapterArray
        guard let index = ordered.firstIndex(where: { $0.objectID == chapter.objectID }) else { return }
        let targetIndex = direction == .up ? index - 1 : index + 1
        guard ordered.indices.contains(targetIndex) else { return }

        let other = ordered[targetIndex]
        let originalNumber = chapter.number
        chapter.number = other.number
        other.number = originalNumber
        let now = Date()
        chapter.updatedAt = now
        other.updatedAt = now
        book.updatedAt = now
        save(context)
    }

    static func renameCollection(_ collection: SBCollection, name: String, context: NSManagedObjectContext) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        collection.name = clean
        collection.updatedAt = Date()
        save(context)
    }

    static func deleteCollection(_ collection: SBCollection, context: NSManagedObjectContext) {
        collection.bookArray.forEach { $0.collection = nil }
        context.delete(collection)
        save(context)
    }

    static func addBookmark(book: SBBook, chapter: SBChapter?, passage: String?, context: NSManagedObjectContext) {
        let now = Date()
        let cleanPassage = passage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let bookmark = SBBookmark(context: context)
        bookmark.id = UUID().uuidString
        bookmark.book = book
        bookmark.chapter = chapter
        bookmark.chapterID = chapter?.id
        bookmark.passage = cleanPassage
        bookmark.snippet = cleanPassage ?? chapter?.plainText.prefixString(90)
        bookmark.location = chapter.flatMap { location(of: cleanPassage, in: $0.plainText) } ?? 0
        bookmark.createdAt = now
        bookmark.updatedAt = now

        if let chapter {
            bookmark.label = "\(book.name) \(chapter.number)"
        } else {
            bookmark.label = book.name
        }

        save(context)
    }

    static func deleteBookmark(_ bookmark: SBBookmark, context: NSManagedObjectContext) {
        context.delete(bookmark)
        save(context)
    }

    static func addNote(
        chapter: SBChapter,
        text: String,
        excerpt: String,
        theme: HighlightTheme?,
        rangeLocation: Int64? = nil,
        rangeLength: Int64? = nil,
        context: NSManagedObjectContext
    ) {
        let now = Date()
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanExcerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = SBNote(context: context)
        note.id = UUID().uuidString
        note.chapter = chapter
        note.body = cleanText
        note.text = cleanText
        note.excerpt = cleanExcerpt
        note.theme = theme?.rawValue
        note.rangeLocation = rangeLocation ?? location(of: cleanExcerpt.nilIfEmpty, in: chapter.plainText)
        note.rangeLength = rangeLength ?? Int64(cleanExcerpt.utf16.count)
        note.createdAt = now
        note.updatedAt = now
        chapter.updatedAt = now
        save(context)
    }

    static func deleteNote(_ note: SBNote, context: NSManagedObjectContext) {
        context.delete(note)
        save(context)
    }

    static func addTag(_ tag: String, to chapter: SBChapter, context: NSManagedObjectContext) {
        let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var tags = chapter.tagArray
        guard !tags.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        tags.append(value)
        chapter.tags = tags.joined(separator: ",")
        chapter.updatedAt = Date()
        save(context)
    }

    static func removeTag(_ tag: String, from chapter: SBChapter, context: NSManagedObjectContext) {
        chapter.tags = chapter.tagArray
            .filter { $0.caseInsensitiveCompare(tag) != .orderedSame }
            .joined(separator: ",")
        chapter.updatedAt = Date()
        save(context)
    }

    static func recordHighlightTheme(_ theme: HighlightTheme, in chapter: SBChapter, context: NSManagedObjectContext) {
        var themes = chapter.themeArray.map(\.rawValue)
        guard !themes.contains(theme.rawValue) else { return }
        themes.append(theme.rawValue)
        chapter.highlightThemes = themes.joined(separator: ",")
        chapter.updatedAt = Date()
        save(context)
    }

    static func save(_ context: NSManagedObjectContext) {
        do {
            try saveThrowing(context)
        } catch {
            assertionFailure("Save failed: \(error.localizedDescription)")
        }
    }

    static func saveThrowing(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    private static func nextCollectionOrder(context: NSManagedObjectContext) -> Int64 {
        let request = SBCollection.fetchRequest()
        let collections = (try? context.fetch(request)) ?? []
        return (collections.map(\.orderIndex).max() ?? 0) + 1
    }

    private static func location(of snippet: String?, in text: String) -> Int64 {
        guard let snippet, let range = text.range(of: snippet) else { return 0 }
        return Int64(text.distance(from: text.startIndex, to: range.lowerBound))
    }
}

enum MoveDirection {
    case up
    case down
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func prefixString(_ count: Int) -> String {
        String(prefix(count))
    }
}
