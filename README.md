# ContactCRM

A local-first, encrypted personal CRM for iPhone. It layers notes, likes/dislikes,
categories, sales pipelines, and an activity log (points of contact, including emails)
on top of your existing iOS Contacts entries — without ever syncing data off-device.

See [PLAN.md](PLAN.md) for the full feature/architecture/security writeup.

## Build

This project is scaffolded with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen   # one-time
xcodegen generate
open ContactCRM.xcodeproj
```

Then build/run on a simulator or device running iOS 16+. On first launch you'll be asked
to grant Contacts access and to set up Face ID/passcode unlock.

## Security highlights

- All CRM data (notes, likes/dislikes, activity log) is encrypted with AES-GCM
  (CryptoKit) before it's written to disk.
- The encryption key is generated on-device, stored only in the Keychain, and requires
  Face ID/Touch ID + device passcode to access — it's never in iCloud Keychain.
- The CoreData store file is also protected with `NSFileProtectionCompleteUnlessOpen`.
- No network entitlement, no analytics, no third-party SDKs — the app cannot phone home.
