# ContactCRM — iOS App Plan

## Concept
A personal CRM layered on top of the native iOS Contacts app. Names/phones/emails/photos
live in `CNContact` (so they stay in sync with the user's real address book); everything
CRM-specific — notes, likes/dislikes, pipeline stage, category tags, activity log/points
of contact — lives in a **local, encrypted** datastore keyed off each contact's stable
`CNContact.identifier`. Nothing leaves the device.

## Features (mapped from the transcript)

| Transcript idea | Feature |
|---|---|
| "Dashboard" | `DashboardView` — counts by stage, recent activity, upcoming reminders |
| "Add contact with title/first/last/image" | `AddContactView` — writes to `CNContactStore`, mirrors a CRM record |
| "Click contact → activity feed / messages bucket" | `ContactDetailView` — chronological `ActivityEntry` log (call, email, meeting, note) |
| "Categorize contacts (vendor, new lead...)" | `Category` tag on each CRM record, filterable list |
| "Programs: appointments, previous clients, new/warm leads, pipelines" | `PipelineStage` enum + `PipelineBoardView` (kanban-style) |
| "Sales — create a pipeline" | Custom pipelines: ordered list of stages, drag a contact between columns |
| "Points of contact / emails" | `ActivityEntry(type: .email/.call/.meeting/.note)` — logged manually or via Share Extension (we do NOT read Mail/Messages content automatically — that would require risky entitlements and is a privacy red flag) |

## Security & Privacy (the "make it more secure" requirement)
- **No cloud, no analytics, no third-party SDKs.** Pure on-device.
- **Field-level encryption**: CRM data (notes, likes/dislikes, activity log) encrypted with
  **AES-GCM (CryptoKit)** before it touches disk. The symmetric key is generated on first
  launch and stored in the **Keychain** with `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`
  + `kSecAccessControlBiometryCurrentSet` — i.e. it requires Face ID/Touch ID and never
  leaves the device or syncs to iCloud Keychain.
- **App lock**: Face ID/Touch ID (`LocalAuthentication`) gate on every cold launch and on
  background→foreground.
- **CoreData store** uses `NSFileProtectionCompleteUnlessOpen` (file inaccessible while
  device is locked) in addition to the field-level encryption — defense in depth.
- **Contacts permission** requested with a clear purpose string; only the minimal `CNContact`
  keys we need are fetched (no full database dump).
- **No background network entitlement** — the app doesn't request `NSAppTransportSecurity`
  exceptions or any network capability at all, so it physically cannot phone home.
- Export/backup (if ever added) would require re-authenticating and would produce an
  encrypted file the user explicitly shares — not implemented in v1 by design.

## Architecture
- SwiftUI + MVVM.
- `ContactsService`: thin wrapper over `CNContactStore` (fetch/create/update, photo handling).
- `CRMStore` (CoreData + CryptoKit): persists `CRMContactRecord`, `ActivityEntry`, `Category`,
  `Pipeline`/`PipelineStage`, keyed by `CNContact.identifier`.
- `EncryptionManager`: Keychain-backed AES-GCM encrypt/decrypt used by a CoreData
  `NSManagedObject` transformer, so encryption is transparent to the rest of the app.
- Views: `DashboardView`, `ContactListView`, `ContactDetailView`, `AddContactView`,
  `PipelineBoardView`, `AppLockView`.

## Project layout
Scaffolded with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) so it
generates a real `.xcodeproj` — run `xcodegen generate` then open `ContactCRM.xcodeproj`.
