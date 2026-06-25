import SwiftUI

struct ContactListView: View {
    @StateObject private var contactsService = ContactsService.shared
    @State private var contacts: [AppContact] = []
    @State private var selectedCategory: ContactCategory?
    @State private var showAddContact = false
    @State private var needsPermission = false

    private var filtered: [AppContact] {
        guard let selectedCategory else { return contacts }
        return contacts.filter { contact in
            CRMRepository.shared.record(for: contact.id).categoryRaw == selectedCategory.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if needsPermission {
                    ContentUnavailableView {
                        Label("Contacts access needed", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("Grant access so ContactCRM can link notes and pipeline stages to your existing contacts.")
                    } actions: {
                        Button("Grant Access") { Task { await requestAccess() } }
                    }
                } else {
                    List {
                        Picker("Category", selection: $selectedCategory) {
                            Text("All").tag(ContactCategory?.none)
                            ForEach(ContactCategory.allCases) { category in
                                Text(category.rawValue).tag(ContactCategory?.some(category))
                            }
                        }
                        .pickerStyle(.menu)

                        ForEach(filtered) { contact in
                            NavigationLink(value: contact) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                    .navigationDestination(for: AppContact.self) { contact in
                        ContactDetailView(contact: contact)
                    }
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddContact = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddContact) {
                AddContactView { reload() }
            }
            .task { await requestAccess() }
        }
    }

    private func requestAccess() async {
        let granted = await contactsService.requestAccess()
        await MainActor.run {
            needsPermission = !granted
            if granted { reload() }
        }
    }

    private func reload() {
        contacts = contactsService.fetchAll()
    }
}

private struct ContactRow: View {
    let contact: AppContact

    var body: some View {
        HStack {
            if let imageData = contact.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text(contact.displayName)
                if !contact.jobTitle.isEmpty {
                    Text(contact.jobTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
