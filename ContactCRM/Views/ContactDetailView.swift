import SwiftUI

struct ContactDetailView: View {
    let contact: AppContact

    @State private var record: CRMContactRecord?
    @State private var notes = ""
    @State private var likes = ""
    @State private var dislikes = ""
    @State private var category: ContactCategory = .other
    @State private var pipelineStage: PipelineStage = .newLead
    @State private var newActivitySummary = ""
    @State private var newActivityType: ActivityType = .note

    private var activities: [ActivityEntry] {
        guard let record else { return [] }
        let set = (record.activities as? Set<ActivityEntry>) ?? []
        return set.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
    }

    var body: some View {
        Form {
            Section("Profile") {
                Text(contact.displayName)
                if !contact.jobTitle.isEmpty { Text(contact.jobTitle).foregroundStyle(.secondary) }
                ForEach(contact.emails, id: \.self) { Text($0) }
                ForEach(contact.phones, id: \.self) { Text($0) }
            }

            Section("Pipeline") {
                Picker("Category", selection: $category) {
                    ForEach(ContactCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: category) { _, value in
                    guard let record else { return }
                    CRMRepository.shared.setCategory(value, for: record)
                }
                Picker("Stage", selection: $pipelineStage) {
                    ForEach(PipelineStage.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: pipelineStage) { _, value in
                    guard let record else { return }
                    CRMRepository.shared.setPipelineStage(value, for: record)
                }
            }

            Section("Notes (encrypted at rest)") {
                TextEditor(text: $notes).frame(minHeight: 80)
                    .onChange(of: notes) { _, value in
                        guard let record else { return }
                        CRMRepository.shared.updateNotes(value, for: record)
                    }
            }
            Section("Likes") {
                TextEditor(text: $likes).frame(minHeight: 50)
                    .onChange(of: likes) { _, value in
                        guard let record else { return }
                        CRMRepository.shared.updateLikes(value, for: record)
                    }
            }
            Section("Dislikes") {
                TextEditor(text: $dislikes).frame(minHeight: 50)
                    .onChange(of: dislikes) { _, value in
                        guard let record else { return }
                        CRMRepository.shared.updateDislikes(value, for: record)
                    }
            }

            Section("Log a point of contact") {
                Picker("Type", selection: $newActivityType) {
                    ForEach(ActivityType.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("e.g. \"Emailed proposal v2, awaiting reply\"", text: $newActivitySummary)
                Button("Add") {
                    guard let record, !newActivitySummary.isEmpty else { return }
                    CRMRepository.shared.addActivity(type: newActivityType, summary: newActivitySummary, to: record)
                    newActivitySummary = ""
                }
            }

            Section("Activity feed") {
                if activities.isEmpty {
                    Text("No activity yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(activities, id: \.id) { entry in
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: ActivityType(rawValue: entry.typeRaw ?? "")?.systemImage ?? "circle")
                                Text(entry.typeRaw ?? "")
                                Spacer()
                                if let timestamp = entry.timestamp {
                                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(CRMRepository.shared.plaintext(entry.encryptedSummary))
                        }
                    }
                }
            }
        }
        .navigationTitle(contact.displayName)
        .onAppear(perform: load)
    }

    private func load() {
        let r = CRMRepository.shared.record(for: contact.id)
        record = r
        notes = CRMRepository.shared.plaintext(r.encryptedNotes)
        likes = CRMRepository.shared.plaintext(r.encryptedLikes)
        dislikes = CRMRepository.shared.plaintext(r.encryptedDislikes)
        category = ContactCategory(rawValue: r.categoryRaw ?? "") ?? .other
        pipelineStage = PipelineStage(rawValue: r.pipelineStageRaw ?? "") ?? .newLead
    }
}
