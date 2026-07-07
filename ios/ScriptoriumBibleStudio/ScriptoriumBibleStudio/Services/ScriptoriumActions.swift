import CoreData
import Foundation

enum ScriptoriumActions {
    @discardableResult
    static func createCollection(name: String, context: NSManagedObjectContext) -> SBCollection {
        let collection = SBCollection(context: context)
        collection.id = UUID().uuidString
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let book = SBBook(context: context)
        book.id = UUID().uuidString
        book.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        book.testament = testament.rawValue
        book.orderIndex = (existingBooks.map(\.orderIndex).max() ?? 0) + 1
        book.collection = collection
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
        chapter.updatedAt = Date()
        chapter.plainText = content.string
        chapter.contentData = AttributedContent.rtfData(from: content)
        save(context)
        return chapter
    }

    static func deleteChapter(_ chapter: SBChapter, context: NSManagedObjectContext) {
        context.delete(chapter)
        save(context)
    }

    static func addBookmark(book: SBBook, chapter: SBChapter?, passage: String?, context: NSManagedObjectContext) {
        let bookmark = SBBookmark(context: context)
        bookmark.id = UUID().uuidString
        bookmark.book = book
        bookmark.chapter = chapter
        bookmark.passage = passage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        bookmark.createdAt = Date()

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
        context: NSManagedObjectContext
    ) {
        let note = SBNote(context: context)
        note.id = UUID().uuidString
        note.chapter = chapter
        note.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        note.excerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
        note.theme = theme?.rawValue
        note.createdAt = Date()
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
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Save failed: \(error.localizedDescription)")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
