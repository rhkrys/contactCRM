import CryptoKit
import Foundation
import Security

/// Encrypts/decrypts CRM payloads with AES-GCM. The symmetric key lives only in the
/// Secure Enclave-backed Keychain, gated by the device passcode + current biometry set,
/// and is never synced to iCloud Keychain or written to disk in plaintext.
final class EncryptionManager {
    static let shared = EncryptionManager()

    private let keyTag = "com.contactcrm.app.crmDataKey"
    private var cachedKey: SymmetricKey?

    private init() {}

    func encrypt(_ plaintext: Data) throws -> Data {
        let key = try keyMaterial()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    func decrypt(_ ciphertext: Data) throws -> Data {
        let key = try keyMaterial()
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }

    func encryptString(_ string: String) throws -> Data {
        try encrypt(Data(string.utf8))
    }

    func decryptString(_ data: Data) throws -> String {
        let plain = try decrypt(data)
        return String(decoding: plain, as: UTF8.self)
    }

    // MARK: - Key lifecycle

    private func keyMaterial() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        if let existing = try readKeyFromKeychain() {
            cachedKey = existing
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try writeKeyToKeychain(newKey)
        cachedKey = newKey
        return newKey
    }

    private func readKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw EncryptionError.keychain(status)
        }
    }

    private func writeKeyToKeychain(_ key: SymmetricKey) throws {
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            nil
        )
        let keyData = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: accessControl as Any,
            kSecAttrSynchronizable as String: false
        ]
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag
        ] as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychain(status)
        }
    }
}

enum EncryptionError: Error {
    case sealFailed
    case keychain(OSStatus)
}
