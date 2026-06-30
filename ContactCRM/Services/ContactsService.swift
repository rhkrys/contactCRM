import Contacts
import SwiftUI

struct AppContact: Identifiable, Hashable {
    let id: String // CNContact.identifier
    var givenName: String
    var familyName: String
    var jobTitle: String
    var emails: [String]
    var phones: [String]
    var imageData: Data?

    var displayName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// Minimal wrapper over CNContactStore. Only fetches the keys the CRM actually
/// needs — never a full unbounded dump of the address book.
final class ContactsService: ObservableObject {
    static let shared = ContactsService()

    private let store = CNContactStore()
    let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor
    ]

    @Published var authorizationStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run { self.authorizationStatus = CNContactStore.authorizationStatus(for: .contacts) }
            return granted
        } catch {
            return false
        }
    }

    func fetchAll() -> [AppContact] {
        var results: [AppContact] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        try? store.enumerateContacts(with: request) { contact, _ in
            results.append(Self.map(contact))
        }
        return results.sorted { $0.displayName < $1.displayName }
    }

    func fetch(identifier: String) -> AppContact? {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
        guard let contact = try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch).first else {
            return nil
        }
        return Self.map(contact)
    }

    func create(givenName: String, familyName: String, jobTitle: String, email: String?, phone: String?, imageData: Data?) throws -> AppContact {
        let mutable = CNMutableContact()
        apply(givenName: givenName, familyName: familyName, jobTitle: jobTitle,
              email: email, phone: phone, imageData: imageData, to: mutable)
        let saveRequest = CNSaveRequest()
        saveRequest.add(mutable, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
        return Self.map(mutable)
    }

    func update(contact: AppContact, givenName: String, familyName: String, jobTitle: String, email: String?, phone: String?, imageData: Data?) throws -> AppContact {
        let predicate = CNContact.predicateForContacts(withIdentifiers: [contact.id])
        guard let existing = try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch).first,
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactsError.notFound
        }
        apply(givenName: givenName, familyName: familyName, jobTitle: jobTitle,
              email: email, phone: phone, imageData: imageData, to: mutable)
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutable)
        try store.execute(saveRequest)
        return Self.map(mutable)
    }

    private func apply(givenName: String, familyName: String, jobTitle: String,
                       email: String?, phone: String?, imageData: Data?,
                       to mutable: CNMutableContact) {
        mutable.givenName = givenName
        mutable.familyName = familyName
        mutable.jobTitle = jobTitle
        if let email, !email.isEmpty {
            mutable.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone, !phone.isEmpty {
            mutable.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        if let imageData {
            mutable.imageData = imageData
        }
    }

    private static func map(_ contact: CNContact) -> AppContact {
        AppContact(
            id: contact.identifier,
            givenName: contact.givenName,
            familyName: contact.familyName,
            jobTitle: contact.jobTitle,
            emails: contact.emailAddresses.map { $0.value as String },
            phones: contact.phoneNumbers.map { $0.value.stringValue },
            imageData: contact.imageData
        )
    }
}

enum ContactsError: Error {
    case notFound
}
