import CoreData
import Foundation

final class PipelineService: ObservableObject {
    static let shared = PipelineService()

    private let context: NSManagedObjectContext

    @Published var pipelines: [CustomPipeline] = []

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        reload()
    }

    func reload() {
        let request = CustomPipeline.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        pipelines = (try? context.fetch(request)) ?? []
    }

    func stages(for pipeline: CustomPipeline) -> [CustomPipelineStage] {
        let set = (pipeline.stages as? Set<CustomPipelineStage>) ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    func createPipeline(name: String) -> CustomPipeline {
        let pipeline = CustomPipeline(context: context)
        pipeline.id = UUID()
        pipeline.name = name
        pipeline.sortOrder = Int32((pipelines.count))
        let defaults = ["New Lead", "Contacted", "Proposal Sent", "Negotiation", "Closed Won", "Closed Lost"]
        for (i, stageName) in defaults.enumerated() {
            let stage = CustomPipelineStage(context: context)
            stage.id = UUID()
            stage.name = stageName
            stage.sortOrder = Int32(i)
            stage.pipeline = pipeline
        }
        save()
        reload()
        return pipeline
    }

    func addStage(name: String, to pipeline: CustomPipeline) {
        let stage = CustomPipelineStage(context: context)
        stage.id = UUID()
        stage.name = name
        stage.sortOrder = Int32(stages(for: pipeline).count)
        stage.pipeline = pipeline
        save()
        reload()
    }

    func deleteStage(_ stage: CustomPipelineStage) {
        context.delete(stage)
        save()
        reload()
    }

    func deletePipeline(_ pipeline: CustomPipeline) {
        context.delete(pipeline)
        save()
        reload()
    }

    func renamePipeline(_ pipeline: CustomPipeline, to name: String) {
        pipeline.name = name
        save()
        reload()
    }

    func renameStage(_ stage: CustomPipelineStage, to name: String) {
        stage.name = name
        save()
        reload()
    }

    private func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
