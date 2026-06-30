import SwiftUI

struct PipelineEditorView: View {
    @ObservedObject var pipelineService = PipelineService.shared
    let pipeline: CustomPipeline

    @State private var pipelineName: String
    @State private var newStageName = ""

    init(pipeline: CustomPipeline) {
        self.pipeline = pipeline
        _pipelineName = State(initialValue: pipeline.name ?? "")
    }

    private var stages: [CustomPipelineStage] {
        pipelineService.stages(for: pipeline)
    }

    var body: some View {
        Form {
            Section("Pipeline name") {
                TextField("Name", text: $pipelineName)
                    .onSubmit { pipelineService.renamePipeline(pipeline, to: pipelineName) }
            }

            Section("Stages") {
                ForEach(stages, id: \.id) { stage in
                    StageRow(stage: stage)
                }
                .onDelete { indexSet in
                    indexSet.map { stages[$0] }.forEach { pipelineService.deleteStage($0) }
                }
            }

            Section("Add stage") {
                HStack {
                    TextField("Stage name", text: $newStageName)
                    Button("Add") {
                        guard !newStageName.isEmpty else { return }
                        pipelineService.addStage(name: newStageName, to: pipeline)
                        newStageName = ""
                    }
                    .disabled(newStageName.isEmpty)
                }
            }
        }
        .navigationTitle("Edit Pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }
}

private struct StageRow: View {
    let stage: CustomPipelineStage
    @State private var name: String

    init(stage: CustomPipelineStage) {
        self.stage = stage
        _name = State(initialValue: stage.name ?? "")
    }

    var body: some View {
        TextField("Stage name", text: $name)
            .onSubmit { PipelineService.shared.renameStage(stage, to: name) }
    }
}
