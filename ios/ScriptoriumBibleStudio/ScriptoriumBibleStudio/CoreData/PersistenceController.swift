import CoreData
import Foundation

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "ScriptoriumModel",
            managedObjectModel: ScriptoriumModel.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = UndoManager()

        seedIfNeeded(context: container.viewContext)
    }

    func save(context: NSManagedObjectContext? = nil) {
        let context = context ?? container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Core Data save failed: \(error.localizedDescription)")
        }
    }

    func seedIfNeeded(context: NSManagedObjectContext) {
        let request = SBBook.fetchRequest()
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        if count == 0 {
            ScriptoriumSeed.insertSampleData(context: context)
            save(context: context)
        } else {
            ensureSettings(context: context)
        }
    }

    func ensureSettings(context: NSManagedObjectContext) {
        let request = SBAppSettings.fetchRequest()
        request.fetchLimit = 1
        if ((try? context.count(for: request)) ?? 0) == 0 {
            _ = ScriptoriumSeed.insertDefaultSettings(context: context)
            save(context: context)
        } else if let settings = try? context.fetch(request).first {
            normalize(settings: settings)
            save(context: context)
        }
    }

    func resetToSeed(context: NSManagedObjectContext) {
        deleteAllData(context: context)
        ScriptoriumSeed.insertSampleData(context: context)
        save(context: context)
    }

    func deleteAllData(context: NSManagedObjectContext) {
        ["SBBookmark", "SBNote", "SBChapter", "SBBook", "SBCollection", "SBAppSettings"]
            .forEach { entityName in
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.includesPropertyValues = false
                if let objects = try? context.fetch(request) {
                    objects.forEach(context.delete)
                }
            }
    }

    private func normalize(settings: SBAppSettings) {
        let now = Date()
        if settings.fontName.isEmpty {
            settings.fontName = SBTheme.FontName.body
        }
        if settings.editorFontName == nil {
            settings.editorFontName = settings.fontName
        }
        if settings.fontSize == 0 {
            settings.fontSize = 19
        }
        if settings.readerFontSize == 0 {
            settings.readerFontSize = settings.fontSize
        }
        if settings.readAloudRate == 0 {
            settings.readAloudRate = 0.48
        }
        if settings.appAppearance == nil {
            switch settings.theme {
            case "light": settings.appAppearance = "light"
            case "dark": settings.appAppearance = "dark"
            default: settings.appAppearance = "system"
            }
        }
        if settings.readerTheme == nil {
            settings.readerTheme = settings.theme ?? "parchment"
        }
        if settings.theme == nil {
            settings.theme = settings.readerTheme ?? "parchment"
        }
        if settings.createdAt == nil {
            settings.createdAt = now
        }
        settings.updatedAt = settings.updatedAt ?? now
    }
}
