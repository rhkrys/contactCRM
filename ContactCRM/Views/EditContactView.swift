import PhotosUI
import SwiftUI

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    let contact: AppContact
    var onSaved: (AppContact) -> Void

    @State private var givenName: String
    @State private var familyName: String
    @State private var jobTitle: String
    @State private var email: String
    @State private var phone: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var errorMessage: String?

    init(contact: AppContact, onSaved: @escaping (AppContact) -> Void) {
        self.contact = contact
        self.onSaved = onSaved
        _givenName = State(initialValue: contact.givenName)
        _familyName = State(initialValue: contact.familyName)
        _jobTitle = State(initialValue: contact.jobTitle)
        _email = State(initialValue: contact.emails.first ?? "")
        _phone = State(initialValue: contact.phones.first ?? "")
        _imageData = State(initialValue: contact.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ContactAvatarView(imageData: imageData, size: 80)
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                imageData = try? await item?.loadTransferable(type: Data.self)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Name") {
                    TextField("First name", text: $givenName)
                    TextField("Last name", text: $familyName)
                    TextField("Title / role", text: $jobTitle)
                }
                Section("Contact info") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(givenName.isEmpty && familyName.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            let updated = try ContactsService.shared.update(
                contact: contact,
                givenName: givenName,
                familyName: familyName,
                jobTitle: jobTitle,
                email: email,
                phone: phone,
                imageData: imageData
            )
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
