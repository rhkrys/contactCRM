import SwiftUI

struct PipelineBoardView: View {
    @State private var contactsByStage: [PipelineStage: [(AppContact, CRMContactRecord)]] = [:]

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(PipelineStage.allCases) { stage in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stage.rawValue)
                                .font(.headline)
                            ForEach(contactsByStage[stage] ?? [], id: \.0.id) { contact, record in
                                NavigationLink(value: contact) {
                                    VStack(alignment: .leading) {
                                        Text(contact.displayName)
                                            .font(.subheadline)
                                        if let category = record.categoryRaw {
                                            Text(category)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(8)
                                    .frame(width: 160, alignment: .leading)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 180, alignment: .top)
                    }
                }
                .padding()
            }
            .navigationDestination(for: AppContact.self) { contact in
                ContactDetailView(contact: contact)
            }
            .navigationTitle("Pipelines")
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        let allContacts = ContactsService.shared.fetchAll()
        var grouped: [PipelineStage: [(AppContact, CRMContactRecord)]] = [:]
        for contact in allContacts {
            let record = CRMRepository.shared.record(for: contact.id)
            let stage = PipelineStage(rawValue: record.pipelineStageRaw ?? "") ?? .newLead
            grouped[stage, default: []].append((contact, record))
        }
        contactsByStage = grouped
    }
}
