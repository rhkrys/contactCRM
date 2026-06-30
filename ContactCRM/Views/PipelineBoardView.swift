import SwiftUI

/// Kanban board. Supports both the built-in PipelineStage enum (default) and
/// user-created custom pipelines. Swipe a card to move it to an adjacent column;
/// tap to open detail.
struct PipelineBoardView: View {
    @StateObject private var pipelineService = PipelineService.shared
    @State private var contacts: [AppContact] = []
    @State private var selectedPipelineID: UUID?        // nil = built-in stages
    @State private var showNewPipeline = false
    @State private var newPipelineName = ""

    var body: some View {
        NavigationStack {
            Group {
                if pipelineService.pipelines.isEmpty {
                    builtInBoard
                } else {
                    VStack(spacing: 0) {
                        pipelinePicker
                        if let selectedPipelineID,
                           let pipeline = pipelineService.pipelines.first(where: { $0.id == selectedPipelineID }) {
                            customBoard(pipeline: pipeline)
                        } else {
                            builtInBoard
                        }
                    }
                }
            }
            .navigationTitle("Pipelines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New pipeline") { showNewPipeline = true }
                        if let id = selectedPipelineID,
                           let pipeline = pipelineService.pipelines.first(where: { $0.id == id }) {
                            NavigationLink("Edit pipeline") {
                                PipelineEditorView(pipeline: pipeline)
                            }
                            Button(role: .destructive) {
                                pipelineService.deletePipeline(pipeline)
                                selectedPipelineID = nil
                            } label: { Label("Delete pipeline", systemImage: "trash") }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .navigationDestination(for: AppContact.self) { contact in
                ContactDetailView(contact: contact, onUpdated: reload)
            }
            .alert("New Pipeline", isPresented: $showNewPipeline) {
                TextField("Pipeline name", text: $newPipelineName)
                Button("Create") {
                    guard !newPipelineName.isEmpty else { return }
                    let p = pipelineService.createPipeline(name: newPipelineName)
                    selectedPipelineID = p.id
                    newPipelineName = ""
                }
                Button("Cancel", role: .cancel) { newPipelineName = "" }
            }
            .onAppear(perform: reload)
        }
    }

    // MARK: - Built-in board (default PipelineStage enum)

    private var builtInBoard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(PipelineStage.allCases) { stage in
                    KanbanColumn(title: stage.rawValue, contacts: contactsForBuiltInStage(stage)) { contact, _ in
                        moveContact(contact, toBuiltInStage: stage)
                    }
                }
            }
            .padding()
        }
    }

    private func contactsForBuiltInStage(_ stage: PipelineStage) -> [AppContact] {
        contacts.filter { CRMRepository.shared.record(for: $0.id).pipelineStageRaw == stage.rawValue }
    }

    private func moveContact(_ contact: AppContact, toBuiltInStage stage: PipelineStage) {
        let record = CRMRepository.shared.record(for: contact.id)
        CRMRepository.shared.setPipelineStage(stage, for: record)
    }

    // MARK: - Custom pipeline board

    private func customBoard(pipeline: CustomPipeline) -> some View {
        let stages = pipelineService.stages(for: pipeline)
        return ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(stages, id: \.id) { stage in
                    KanbanColumn(title: stage.name ?? "", contacts: contactsForCustomStage(stage)) { contact, _ in
                        moveContact(contact, toCustomStage: stage, pipeline: pipeline)
                    }
                }
            }
            .padding()
        }
    }

    private func contactsForCustomStage(_ stage: CustomPipelineStage) -> [AppContact] {
        contacts.filter {
            let r = CRMRepository.shared.record(for: $0.id)
            return r.customStageID == stage.id
        }
    }

    private func moveContact(_ contact: AppContact, toCustomStage stage: CustomPipelineStage, pipeline: CustomPipeline) {
        let record = CRMRepository.shared.record(for: contact.id)
        record.customPipelineID = pipeline.id
        record.customStageID = stage.id
        record.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
    }

    // MARK: - Picker

    private var pipelinePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                PipelineChip(label: "Default", isSelected: selectedPipelineID == nil) {
                    selectedPipelineID = nil
                }
                ForEach(pipelineService.pipelines, id: \.id) { pipeline in
                    PipelineChip(label: pipeline.name ?? "Unnamed", isSelected: selectedPipelineID == pipeline.id) {
                        selectedPipelineID = pipeline.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func reload() {
        contacts = ContactsService.shared.fetchAll()
        pipelineService.reload()
    }
}

// MARK: - Kanban column

private struct KanbanColumn: View {
    let title: String
    let contacts: [AppContact]
    var onMove: (AppContact, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)
            ForEach(contacts) { contact in
                NavigationLink(value: contact) {
                    KanbanCard(contact: contact)
                }
                .buttonStyle(.plain)
            }
            if contacts.isEmpty {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(8)
            }
        }
        .frame(width: 175, alignment: .top)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct KanbanCard: View {
    let contact: AppContact

    var body: some View {
        HStack(spacing: 8) {
            ContactAvatarView(imageData: contact.imageData, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if !contact.jobTitle.isEmpty {
                    Text(contact.jobTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

private struct PipelineChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}
