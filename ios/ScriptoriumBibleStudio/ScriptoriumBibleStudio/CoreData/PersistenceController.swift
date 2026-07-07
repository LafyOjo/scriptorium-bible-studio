import CoreData
import Foundation

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "ScriptoriumModel",
            managedObjectModel: ScriptoriumModel.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

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
}
