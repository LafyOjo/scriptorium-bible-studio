import CoreData
import Foundation

enum ScriptoriumModel {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let collection = entity("SBCollection", SBCollection.self, [
            attribute("id", .stringAttributeType),
            attribute("name", .stringAttributeType),
            attribute("orderIndex", .integer64AttributeType, defaultValue: 0),
            attribute("createdAt", .dateAttributeType, optional: true),
            attribute("updatedAt", .dateAttributeType, optional: true),
        ])

        let book = entity("SBBook", SBBook.self, [
            attribute("id", .stringAttributeType),
            attribute("name", .stringAttributeType),
            attribute("testament", .stringAttributeType),
            attribute("orderIndex", .integer64AttributeType),
            attribute("createdAt", .dateAttributeType, optional: true),
            attribute("updatedAt", .dateAttributeType, optional: true),
        ])

        let chapter = entity("SBChapter", SBChapter.self, [
            attribute("id", .stringAttributeType),
            attribute("number", .integer64AttributeType),
            attribute("title", .stringAttributeType),
            attribute("attributedData", .binaryDataAttributeType, optional: true, allowsExternalBinaryDataStorage: true),
            attribute("contentData", .binaryDataAttributeType, optional: true, allowsExternalBinaryDataStorage: true),
            attribute("plainText", .stringAttributeType),
            attribute("status", .stringAttributeType),
            attribute("tags", .stringAttributeType),
            attribute("highlightThemes", .stringAttributeType),
            attribute("createdAt", .dateAttributeType, optional: true),
            attribute("updatedAt", .dateAttributeType),
        ])

        let note = entity("SBNote", SBNote.self, [
            attribute("id", .stringAttributeType),
            attribute("body", .stringAttributeType, optional: true),
            attribute("text", .stringAttributeType),
            attribute("excerpt", .stringAttributeType),
            attribute("theme", .stringAttributeType, optional: true),
            attribute("rangeLocation", .integer64AttributeType, defaultValue: 0),
            attribute("rangeLength", .integer64AttributeType, defaultValue: 0),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType, optional: true),
        ])

        let bookmark = entity("SBBookmark", SBBookmark.self, [
            attribute("id", .stringAttributeType),
            attribute("chapterID", .stringAttributeType, optional: true),
            attribute("label", .stringAttributeType),
            attribute("snippet", .stringAttributeType, optional: true),
            attribute("passage", .stringAttributeType, optional: true),
            attribute("location", .integer64AttributeType, defaultValue: 0),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType, optional: true),
        ])

        let settings = entity("SBAppSettings", SBAppSettings.self, [
            attribute("id", .stringAttributeType),
            attribute("editorFontName", .stringAttributeType, optional: true),
            attribute("fontName", .stringAttributeType),
            attribute("readerFontSize", .doubleAttributeType, defaultValue: 19),
            attribute("fontSize", .doubleAttributeType),
            attribute("lineSpacing", .doubleAttributeType),
            attribute("defaultBold", .booleanAttributeType),
            attribute("defaultItalic", .booleanAttributeType),
            attribute("defaultUnderline", .booleanAttributeType),
            attribute("readAloudRate", .doubleAttributeType, defaultValue: 0.48),
            attribute("theme", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType, optional: true),
            attribute("updatedAt", .dateAttributeType, optional: true),
        ])

        let collectionBooks = relationship("books", destination: book, toMany: true, deleteRule: .nullifyDeleteRule)
        let bookCollection = relationship("collection", destination: collection, optional: true, inverse: collectionBooks)
        collectionBooks.inverseRelationship = bookCollection
        collection.properties.append(collectionBooks)
        book.properties.append(bookCollection)

        let bookChapters = relationship("chapters", destination: chapter, toMany: true, deleteRule: .cascadeDeleteRule)
        let chapterBook = relationship("book", destination: book, inverse: bookChapters)
        bookChapters.inverseRelationship = chapterBook
        book.properties.append(bookChapters)
        chapter.properties.append(chapterBook)

        let chapterNotes = relationship("notes", destination: note, toMany: true, deleteRule: .cascadeDeleteRule)
        let noteChapter = relationship("chapter", destination: chapter, inverse: chapterNotes)
        chapterNotes.inverseRelationship = noteChapter
        chapter.properties.append(chapterNotes)
        note.properties.append(noteChapter)

        let bookBookmarks = relationship("bookmarks", destination: bookmark, toMany: true, deleteRule: .cascadeDeleteRule)
        let bookmarkBook = relationship("book", destination: book, inverse: bookBookmarks)
        bookBookmarks.inverseRelationship = bookmarkBook
        book.properties.append(bookBookmarks)
        bookmark.properties.append(bookmarkBook)

        let chapterBookmarks = relationship("bookmarks", destination: bookmark, toMany: true, deleteRule: .nullifyDeleteRule)
        let bookmarkChapter = relationship("chapter", destination: chapter, optional: true, inverse: chapterBookmarks)
        chapterBookmarks.inverseRelationship = bookmarkChapter
        chapter.properties.append(chapterBookmarks)
        bookmark.properties.append(bookmarkChapter)

        model.entities = [collection, book, chapter, note, bookmark, settings]
        return model
    }

    private static func entity<T: NSManagedObject>(
        _ name: String,
        _ managedObjectClass: T.Type,
        _ properties: [NSPropertyDescription]
    ) -> NSEntityDescription {
        let description = NSEntityDescription()
        description.name = name
        description.managedObjectClassName = NSStringFromClass(managedObjectClass)
        description.properties = properties
        return description
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        allowsExternalBinaryDataStorage: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let description = NSAttributeDescription()
        description.name = name
        description.attributeType = type
        description.isOptional = optional
        description.allowsExternalBinaryDataStorage = allowsExternalBinaryDataStorage
        description.defaultValue = defaultValue
        return description
    }

    private static func relationship(
        _ name: String,
        destination: NSEntityDescription,
        optional: Bool = false,
        inverse: NSRelationshipDescription? = nil,
        toMany: Bool = false,
        deleteRule: NSDeleteRule = .nullifyDeleteRule
    ) -> NSRelationshipDescription {
        let description = NSRelationshipDescription()
        description.name = name
        description.destinationEntity = destination
        description.isOptional = optional
        description.inverseRelationship = inverse
        description.minCount = (optional || toMany) ? 0 : 1
        description.maxCount = toMany ? 0 : 1
        description.deleteRule = deleteRule
        return description
    }
}
