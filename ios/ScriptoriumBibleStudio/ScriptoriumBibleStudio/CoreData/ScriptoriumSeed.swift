import CoreData
import Foundation

enum ScriptoriumSeed {
    @discardableResult
    static func insertDefaultSettings(context: NSManagedObjectContext) -> SBAppSettings {
        let now = Date()
        let settings = SBAppSettings(context: context)
        settings.id = "default"
        settings.editorFontName = SBTheme.FontName.body
        settings.fontName = SBTheme.FontName.body
        settings.readerFontSize = 19
        settings.fontSize = 19
        settings.lineSpacing = 5
        settings.defaultBold = false
        settings.defaultItalic = false
        settings.defaultUnderline = false
        settings.readAloudRate = 0.48
        settings.autosaveEnabled = true
        settings.voiceIdentifier = nil
        settings.theme = "parchment"
        settings.createdAt = now
        settings.updatedAt = now
        return settings
    }

    static func insertSampleData(context: NSManagedObjectContext) {
        let settings = insertDefaultSettings(context: context)
        let now = Date()

        let oldDraft = collection("Old Testament Draft", order: 1, context: context)
        let newDraft = collection("New Testament Draft", order: 2, context: context)
        _ = collection("Completed Chapters", order: 3, context: context)
        _ = collection("Needs Revision", order: 4, context: context)
        _ = collection("Favourite Passages", order: 5, context: context)

        let genesis = book("Genesis", testament: .old, order: 1, collection: oldDraft, now: now, context: context)
        let psalms = book("Psalms", testament: .old, order: 2, collection: oldDraft, now: now, context: context)
        let john = book("John", testament: .new, order: 3, collection: newDraft, now: now, context: context)
        let revelation = book("Revelation", testament: .new, order: 4, collection: newDraft, now: now, context: context)

        _ = chapter(
            book: genesis,
            number: 1,
            title: "The Beginning",
            status: .drafting,
            tags: ["creation"],
            updatedAt: now,
            content: AttributedContent.makeSeeded(sectionTitle: "The Beginning", verses: [
                (1, "In the beginning, the Eternal spoke, and by the Word all things came to be - the heavens above and the earth beneath."),
                (2, "The earth was without shape, a deep silence upon the waters, and the Spirit of God moved gently over the face of the deep like a whisper over still glass."),
                (3, "Then God said, \"Let there be light\" - and light broke forth, warm and clean, dividing the darkness."),
                (4, "God saw the light, that it was good, and He set a boundary between the light and the darkness."),
                (5, "He named the light Day, and the darkness He named Night. And there was evening, and there was morning - the first day."),
            ], settings: settings),
            context: context
        )

        _ = chapter(
            book: psalms,
            number: 1,
            title: "The Two Paths",
            status: .revising,
            tags: ["wisdom", "poetry"],
            updatedAt: now.addingTimeInterval(-86_400),
            content: AttributedContent.makeSeeded(sectionTitle: "Psalm of the Two Paths", verses: [
                (1, "Blessed is the one who does not walk in the counsel of the wicked, nor linger in the way of scoffers."),
                (2, "But in the law of the Lord is their delight, and on His word they meditate through the long hours of the night."),
                (3, "They shall be like a tree planted beside living streams - bearing fruit in its season, whose leaf shall not wither."),
            ], settings: settings),
            context: context
        )

        let johnChapter = chapter(
            book: john,
            number: 1,
            title: "The Word",
            status: .final,
            tags: ["christology"],
            updatedAt: now.addingTimeInterval(-172_800),
            content: AttributedContent.makeSeeded(sectionTitle: "The Word Made Flesh", verses: [
                (1, "In the beginning was the Word, and the Word was with God, and the Word was God."),
                (2, "He was in the beginning with God."),
                (3, "Through Him all things were made; without Him nothing was made that has been made."),
                (4, "In Him was life, and that life was the light of humankind."),
                (5, "The light shines in the darkness, and the darkness has not overcome it."),
            ], settings: settings),
            context: context
        )

        _ = chapter(
            book: revelation,
            number: 1,
            title: "Vision on Patmos",
            status: .drafting,
            tags: ["apocalyptic"],
            updatedAt: now.addingTimeInterval(-259_200),
            content: AttributedContent.makeSeeded(sectionTitle: "The Vision on Patmos", verses: [
                (1, "The revelation of Jesus, the Anointed, which God gave Him to show His servants - things which must soon come to pass."),
                (2, "I, John, your brother and companion in tribulation, was upon the isle called Patmos, for the Word of God and the testimony of Jesus."),
                (3, "I was in the Spirit on the Lord's day, and I heard behind me a great voice, as of a trumpet."),
            ], settings: settings),
            context: context
        )

        let bookmark = SBBookmark(context: context)
        bookmark.id = UUID().uuidString
        bookmark.chapterID = johnChapter.id
        bookmark.label = "The Word Made Flesh"
        bookmark.snippet = "In the beginning was the Word"
        bookmark.passage = "John 1:1-5"
        bookmark.location = 0
        bookmark.createdAt = now
        bookmark.updatedAt = now
        bookmark.book = john
        bookmark.chapter = johnChapter
    }

    private static func collection(_ name: String, order: Int64 = 1, context: NSManagedObjectContext) -> SBCollection {
        let now = Date()
        let collection = SBCollection(context: context)
        collection.id = UUID().uuidString
        collection.name = name
        collection.orderIndex = order
        collection.createdAt = now
        collection.updatedAt = now
        return collection
    }

    private static func book(
        _ name: String,
        testament: Testament,
        order: Int64,
        collection: SBCollection,
        now: Date,
        context: NSManagedObjectContext
    ) -> SBBook {
        let book = SBBook(context: context)
        book.id = UUID().uuidString
        book.name = name
        book.testament = testament.rawValue
        book.orderIndex = order
        book.collection = collection
        book.createdAt = now
        book.updatedAt = now
        return book
    }

    @discardableResult
    private static func chapter(
        book: SBBook,
        number: Int64,
        title: String,
        status: ChapterStatus,
        tags: [String],
        updatedAt: Date,
        content: NSAttributedString,
        context: NSManagedObjectContext
    ) -> SBChapter {
        let chapter = SBChapter(context: context)
        chapter.id = UUID().uuidString
        chapter.book = book
        chapter.number = number
        chapter.title = title
        chapter.status = status.rawValue
        chapter.tags = tags.joined(separator: ",")
        chapter.highlightThemes = ""
        chapter.createdAt = updatedAt
        chapter.updatedAt = updatedAt
        let data = AttributedContent.rtfData(from: content)
        chapter.contentData = data
        chapter.attributedData = data
        chapter.plainText = content.string
        return chapter
    }
}
