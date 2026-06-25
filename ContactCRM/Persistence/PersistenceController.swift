import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "ContactCRM")

        guard let storeDescription = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }
        // Defense in depth: the SQLite file itself is inaccessible whenever the
        // device is locked, on top of the field-level AES-GCM encryption applied
        // to notes/likes/dislikes/activity summaries before they're stored.
        storeDescription.setOption(
            FileProtectionType.completeUnlessOpen as NSObject,
            forKey: NSPersistentStoreFileProtectionKey
        )

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load CRM store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
