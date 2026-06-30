import SwiftUI

struct ContactDetailView: View {
    @State private var contact: AppContact
    var onUpdated: (() -> Void)?

    @State private var record: CRMContactRecord?
    @State private var notes = ""
    @State private var likes = ""
    @State private var dislikes = ""
    @State private var category: ContactCategory = .other
    @State private var pipelineStage: PipelineStage = .newLead
    @State private var newActivitySummary = ""
    @State private var newActivityType: ActivityType = .note
    @State private var showEdit = false
    @State private var reminders: [ReminderEntry] = []
    @State private var showAddReminder = false
    @State private var newReminderTitle = ""
    @State private var newReminderDate = Date().addingTimeInterval(3600)

    init(contact: AppContact, onUpdated: (() -> Void)? = nil) {
        _contact = State(initialValue: contact)
        self.onUpdated = onUpdated
    }

    private var activities: [ActivityEntry] {
        guard let record else { return [] }
        let set = (record.activities as? Set<ActivityEntry>) ?? []
        return set.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ContactAvatarView(imageData: contact.imageData, size: 72)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text(contact.displayName).font(.title3.bold())
                        if !contact.jobTitle.isEmpty {
                            Text(contact.jobTitle).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Contact info") {
                ForEach(contact.emails, id: \.self) { email in
                    Label(email, systemImage: "envelope")
                }
                ForEach(contact.phones, id: \.self) { phone in
                    Label(phone, systemImage: "phone")
                }
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

            Section("Notes (encrypted)") {
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
                .pickerStyle(.segmented)
                TextField("Brief summary…", text: $newActivitySummary)
                Button("Add entry") {
                    guard let record, !newActivitySummary.isEmpty else { return }
                    CRMRepository.shared.addActivity(type: newActivityType, summary: newActivitySummary, to: record)
                    newActivitySummary = ""
                }
                .disabled(newActivitySummary.isEmpty)
            }

            Section {
                Button { showAddReminder = true } label: {
                    Label("Add reminder", systemImage: "bell.badge.plus")
                }
                ForEach(reminders, id: \.id) { reminder in
                    ReminderRow(reminder: reminder, record: record ?? CRMContactRecord()) {
                        reloadReminders()
                    }
                }
            } header: {
                Text("Reminders")
            }

            Section("Activity feed") {
                if activities.isEmpty {
                    Text("No activity logged yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(activities, id: \.id) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: ActivityType(rawValue: entry.typeRaw ?? "")?.systemImage ?? "circle")
                                .foregroundStyle(.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(CRMRepository.shared.plaintext(entry.encryptedSummary))
                                if let ts = entry.timestamp {
                                    Text(ts.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Text("Edit") }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditContactView(contact: contact) { updated in
                contact = updated
                onUpdated?()
            }
        }
        .alert("New Reminder", isPresented: $showAddReminder) {
            TextField("Reminder", text: $newReminderTitle)
            DatePicker("", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            Button("Add") {
                guard let record, !newReminderTitle.isEmpty else { return }
                ReminderService.shared.add(title: newReminderTitle, dueDate: newReminderDate, to: record)
                newReminderTitle = ""
                reloadReminders()
            }
            Button("Cancel", role: .cancel) { newReminderTitle = "" }
        }
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
        reloadReminders()
    }

    private func reloadReminders() {
        guard let record else { return }
        reminders = ReminderService.shared.reminders(for: record)
    }
}
