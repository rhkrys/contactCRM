import CoreData
import Foundation
import UserNotifications

final class ReminderService {
    static let shared = ReminderService()
    private let context = PersistenceController.shared.container.viewContext
    private let crypto = EncryptionManager.shared

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func add(title: String, dueDate: Date, to record: CRMContactRecord) {
        let entry = ReminderEntry(context: context)
        entry.id = UUID()
        entry.dueDate = dueDate
        entry.encryptedTitle = try? crypto.encryptString(title)
        entry.isCompleted = false
        entry.contact = record
        record.updatedAt = Date()

        scheduleNotification(id: entry.id!.uuidString, title: title, dueDate: dueDate,
                             contactName: plainContactName(for: record))
        entry.notificationID = entry.id!.uuidString
        try? context.save()
    }

    func complete(_ reminder: ReminderEntry) {
        reminder.isCompleted = true
        if let notifID = reminder.notificationID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
        }
        try? context.save()
    }

    func delete(_ reminder: ReminderEntry) {
        if let notifID = reminder.notificationID {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
        }
        context.delete(reminder)
        try? context.save()
    }

    func reminders(for record: CRMContactRecord, includeCompleted: Bool = false) -> [ReminderEntry] {
        let set = (record.reminders as? Set<ReminderEntry>) ?? []
        return set
            .filter { includeCompleted || !$0.isCompleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func allUpcoming() -> [(ReminderEntry, CRMContactRecord)] {
        let request = ReminderEntry.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO AND dueDate >= %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        let entries = (try? context.fetch(request)) ?? []
        return entries.compactMap { entry in
            guard let record = entry.contact else { return nil }
            return (entry, record)
        }
    }

    func plainTitle(_ reminder: ReminderEntry) -> String {
        guard let data = reminder.encryptedTitle else { return "" }
        return (try? crypto.decryptString(data)) ?? ""
    }

    private func scheduleNotification(id: String, title: String, dueDate: Date, contactName: String) {
        let content = UNMutableNotificationContent()
        content.title = contactName.isEmpty ? "Reminder" : "Reminder: \(contactName)"
        content.body = title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func plainContactName(for record: CRMContactRecord) -> String {
        guard let id = record.contactIdentifier,
              let contact = ContactsService.shared.fetch(identifier: id) else { return "" }
        return contact.displayName
    }
}
