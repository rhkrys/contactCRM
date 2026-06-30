import SwiftUI

struct SettingsView: View {
    @ObservedObject private var pipelineService = PipelineService.shared
    @State private var showNewPipeline = false
    @State private var newPipelineName = ""
    @State private var showDeleteDataConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Label("All notes, activity, and CRM data is encrypted with AES-GCM on this device only.",
                          systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label("Encryption key is stored in the Keychain, gated by Face ID / passcode.",
                          systemImage: "faceid")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Pipelines") {
                    ForEach(pipelineService.pipelines, id: \.id) { pipeline in
                        NavigationLink(pipeline.name ?? "Unnamed") {
                            PipelineEditorView(pipeline: pipeline)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.map { pipelineService.pipelines[$0] }
                            .forEach { pipelineService.deletePipeline($0) }
                    }
                    Button { showNewPipeline = true } label: {
                        Label("New pipeline", systemImage: "plus")
                    }
                }

                Section("Notifications") {
                    Button("Request notification permission") {
                        ReminderService.shared.requestNotificationPermission()
                    }
                }

                Section("Data") {
                    Button(role: .destructive) { showDeleteDataConfirm = true } label: {
                        Label("Delete all CRM data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Storage", value: "Local only — no cloud sync")
                }
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .alert("New Pipeline", isPresented: $showNewPipeline) {
                TextField("Pipeline name", text: $newPipelineName)
                Button("Create") {
                    guard !newPipelineName.isEmpty else { return }
                    pipelineService.createPipeline(name: newPipelineName)
                    newPipelineName = ""
                }
                Button("Cancel", role: .cancel) { newPipelineName = "" }
            }
            .alert("Delete all CRM data?", isPresented: $showDeleteDataConfirm) {
                Button("Delete everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all notes, activity logs, pipeline assignments, and reminders. Your contacts in the iOS Contacts app are NOT affected.")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func deleteAllData() {
        let ctx = PersistenceController.shared.container.viewContext
        for entityName in ["ActivityEntry", "ReminderEntry", "CRMContactRecord", "CustomPipelineStage", "CustomPipeline"] {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batch = NSBatchDeleteRequest(fetchRequest: fetch)
            try? ctx.execute(batch)
        }
        try? ctx.save()
        pipelineService.reload()
    }
}
