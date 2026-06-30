import SwiftUI

struct DashboardView: View {
    @State private var records: [CRMContactRecord] = []
    @State private var upcomingReminders: [(ReminderEntry, CRMContactRecord)] = []
    @State private var contacts: [String: AppContact] = [:]

    private var stageCounts: [(PipelineStage, Int)] {
        PipelineStage.allCases.map { stage in
            (stage, records.filter { $0.pipelineStageRaw == stage.rawValue }.count)
        }
    }

    private var recentActivity: [ActivityEntry] {
        records
            .flatMap { ($0.activities as? Set<ActivityEntry>) ?? [] }
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Pipeline overview") {
                    ForEach(stageCounts, id: \.0) { stage, count in
                        HStack {
                            Circle()
                                .fill(stageColor(stage))
                                .frame(width: 8, height: 8)
                            Text(stage.rawValue)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                if !upcomingReminders.isEmpty {
                    Section("Upcoming reminders") {
                        ForEach(upcomingReminders.prefix(5), id: \.0.id) { reminder, record in
                            HStack {
                                Image(systemName: "bell.fill").foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ReminderService.shared.plainTitle(reminder))
                                        .lineLimit(1)
                                    if let id = record.contactIdentifier, let contact = contacts[id] {
                                        Text(contact.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let due = reminder.dueDate {
                                    Text(due.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Recent activity") {
                    if recentActivity.isEmpty {
                        Text("No activity logged yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentActivity, id: \.id) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: ActivityType(rawValue: entry.typeRaw ?? "")?.systemImage ?? "circle")
                                    .foregroundStyle(.accent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let id = entry.contact?.contactIdentifier, let contact = contacts[id] {
                                        Text(contact.displayName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(CRMRepository.shared.plaintext(entry.encryptedSummary))
                                        .lineLimit(2)
                                    if let timestamp = entry.timestamp {
                                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        records = CRMRepository.shared.allRecords()
        upcomingReminders = ReminderService.shared.allUpcoming()
        let allContacts = ContactsService.shared.fetchAll()
        contacts = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0) })
    }

    private func stageColor(_ stage: PipelineStage) -> Color {
        switch stage {
        case .newLead: return .blue
        case .contacted: return .cyan
        case .appointmentSet: return .orange
        case .negotiation: return .purple
        case .won: return .green
        case .lost: return .red
        }
    }
}
