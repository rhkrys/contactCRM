import CoreData
import Foundation

/// All reads/writes of sensitive fields go through here so encryption is never
/// bypassed accidentally by a view or view model.
final class CRMRepository {
    static let shared = CRMRepository()

    private let context: NSManagedObjectContext
    private let crypto = EncryptionManager.shared

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func record(for contactIdentifier: String) -> CRMContactRecord {
        let request = CRMContactRecord.fetchRequest()
        request.predicate = NSPredicate(format: "contactIdentifier == %@", contactIdentifier)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let created = CRMContactRecord(context: context)
        created.contactIdentifier = contactIdentifier
        created.createdAt = Date()
        created.updatedAt = Date()
        save()
        return created
    }

    func updateNotes(_ text: String, for record: CRMContactRecord) {
        record.encryptedNotes = try? crypto.encryptString(text)
        record.updatedAt = Date()
        save()
    }

    func updateLikes(_ text: String, for record: CRMContactRecord) {
        record.encryptedLikes = try? crypto.encryptString(text)
        record.updatedAt = Date()
        save()
    }

    func updateDislikes(_ text: String, for record: CRMContactRecord) {
        record.encryptedDislikes = try? crypto.encryptString(text)
        record.updatedAt = Date()
        save()
    }

    func plaintext(_ data: Data?) -> String {
        guard let data, let value = try? crypto.decryptString(data) else { return "" }
        return value
    }

    func setCategory(_ category: ContactCategory, for record: CRMContactRecord) {
        record.categoryRaw = category.rawValue
        record.updatedAt = Date()
        save()
    }

    func setPipelineStage(_ stage: PipelineStage, for record: CRMContactRecord) {
        record.pipelineStageRaw = stage.rawValue
        record.updatedAt = Date()
        save()
    }

    func addActivity(type: ActivityType, summary: String, to record: CRMContactRecord) {
        let entry = ActivityEntry(context: context)
        entry.id = UUID()
        entry.typeRaw = type.rawValue
        entry.timestamp = Date()
        entry.encryptedSummary = try? crypto.encryptString(summary)
        entry.contact = record
        record.updatedAt = Date()
        save()
    }

    func allRecords() -> [CRMContactRecord] {
        let request = CRMContactRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
