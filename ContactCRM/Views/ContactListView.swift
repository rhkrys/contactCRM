import SwiftUI

struct ContactListView: View {
    @StateObject private var contactsService = ContactsService.shared
    @State private var contacts: [AppContact] = []
    @State private var selectedCategory: ContactCategory?
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var needsPermission = false

    private var filtered: [AppContact] {
        contacts.filter { contact in
            let matchesCategory = selectedCategory == nil ||
                CRMRepository.shared.record(for: contact.id).categoryRaw == selectedCategory?.rawValue
            let matchesSearch = searchText.isEmpty ||
                contact.displayName.localizedCaseInsensitiveContains(searchText) ||
                contact.emails.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                contact.phones.contains { $0.contains(searchText) }
            return matchesCategory && matchesSearch
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
                                ContactRow(contact: contact, onUpdated: reload)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search name, email, phone")
                    .navigationDestination(for: AppContact.self) { contact in
                        ContactDetailView(contact: contact, onUpdated: reload)
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

    func reload() {
        contacts = contactsService.fetchAll()
    }
}

private struct ContactRow: View {
    let contact: AppContact
    var onUpdated: () -> Void
    @State private var showEdit = false

    var body: some View {
        HStack {
            ContactAvatarView(imageData: contact.imageData)
            VStack(alignment: .leading) {
                Text(contact.displayName)
                if !contact.jobTitle.isEmpty {
                    Text(contact.jobTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                .tint(.blue)
        }
        .sheet(isPresented: $showEdit) {
            EditContactView(contact: contact) { _ in onUpdated() }
        }
    }
}
