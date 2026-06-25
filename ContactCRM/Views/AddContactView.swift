import SwiftUI

struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var jobTitle = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var category: ContactCategory = .newLead
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $givenName)
                    TextField("Last name", text: $familyName)
                    TextField("Title", text: $jobTitle)
                }
                Section("Contact info") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ContactCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(givenName.isEmpty && familyName.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            let contact = try ContactsService.shared.create(
                givenName: givenName,
                familyName: familyName,
                jobTitle: jobTitle,
                email: email,
                phone: phone,
                imageData: nil
            )
            let record = CRMRepository.shared.record(for: contact.id)
            CRMRepository.shared.setCategory(category, for: record)
            CRMRepository.shared.setPipelineStage(.newLead, for: record)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
