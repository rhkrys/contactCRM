import SwiftUI

struct DashboardView: View {
    @StateObject private var contactsService = ContactsService.shared
    @State private var records: [CRMContactRecord] = []

    private var stageCounts: [(PipelineStage, Int)] {
        PipelineStage.allCases.map { stage in
            (stage, records.filter { $0.pipelineStageRaw == stage.rawValue }.count)
        }
    }

    private var recentActivity: [ActivityEntry] {
        records
            .flatMap { ($0.activities as? Set<ActivityEntry>) ?? [] }
            .sorted { $0.timestamp ?? .distantPast > $1.timestamp ?? .distantPast }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Pipeline overview") {
                    ForEach(stageCounts, id: \.0) { stage, count in
                        HStack {
                            Text(stage.rawValue)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Recent activity") {
                    if recentActivity.isEmpty {
                        Text("No activity logged yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentActivity, id: \.id) { entry in
                            HStack {
                                Image(systemName: ActivityType(rawValue: entry.typeRaw ?? "")?.systemImage ?? "circle")
                                VStack(alignment: .leading) {
                                    Text(CRMRepository.shared.plaintext(entry.encryptedSummary))
                                        .lineLimit(1)
                                    if let timestamp = entry.timestamp {
                                        Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
    }
}
