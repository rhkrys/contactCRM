import SwiftUI

/// Global reminders list — shows all upcoming reminders across contacts, grouped by due date.
struct RemindersView: View {
    @State private var upcoming: [(ReminderEntry, CRMContactRecord)] = []

    private var grouped: [(String, [(ReminderEntry, CRMContactRecord)])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        var dict: [(String, [(ReminderEntry, CRMContactRecord)])] = []
        var seen: [String: Int] = [:]
        for pair in upcoming {
            let key = formatter.string(from: pair.0.dueDate ?? Date())
            if let idx = seen[key] {
                dict[idx].1.append(pair)
            } else {
                seen[key] = dict.count
                dict.append((key, [pair]))
            }
        }
        return dict
    }

    var body: some View {
        NavigationStack {
            Group {
                if upcoming.isEmpty {
                    ContentUnavailableView("No reminders", systemImage: "checkmark.circle",
                                          description: Text("Add a reminder from any contact's detail screen."))
                } else {
                    List {
                        ForEach(grouped, id: \.0) { dateLabel, pairs in
                            Section(dateLabel) {
                                ForEach(pairs, id: \.0.id) { reminder, record in
                                    ReminderRow(reminder: reminder, record: record) { reload() }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        upcoming = ReminderService.shared.allUpcoming()
    }
}

struct ReminderRow: View {
    let reminder: ReminderEntry
    let record: CRMContactRecord
    var onChanged: () -> Void

    @State private var contactName = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(ReminderService.shared.plainTitle(reminder))
                    .font(.subheadline)
                if !contactName.isEmpty {
                    Text(contactName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let due = reminder.dueDate {
                    Text(due.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
            }
            Spacer()
            Button {
                ReminderService.shared.complete(reminder)
                onChanged()
            } label: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                ReminderService.shared.delete(reminder)
                onChanged()
            } label: { Label("Delete", systemImage: "trash") }
        }
        .onAppear {
            if let id = record.contactIdentifier,
               let contact = ContactsService.shared.fetch(identifier: id) {
                contactName = contact.displayName
            }
        }
    }
}
