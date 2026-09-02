import CryptoKit
import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    case vaultCorrupt
    case vaultUnavailable

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "未知错误"
            return "钥匙串操作失败：\(message)（\(status)）"
        case .vaultCorrupt:
            return "无法解密本地安全凭据保险库。现有凭据未被覆盖，请检查钥匙串权限后重试。"
        case .vaultUnavailable:
            return "无法创建本地凭据目录。请检查磁盘权限后重试。"
        }
    }
}

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private let service = "com.local.ClaudeAccountManager"
    private let masterKeyAccount = "ClaudeAccountManager.MasterKey.v1"
    private let lock = NSLock()

    private var memoryCache: [String: String]? = nil
    private var cachedMasterKey: SymmetricKey? = nil

    enum SecretKind: String {
        case loginLink = "login-link"
        case sessionKey = "session-key"
    }

    func read(accountID: UUID, kind: SecretKind) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let key = cacheKey(accountID: accountID, kind: kind)
        try ensureVaultLoaded()

        if let value = memoryCache?[key] {
            return value
        }

        if let legacyValue = tryReadLegacyKeychain(accountID: accountID, kind: kind), !legacyValue.isEmpty {
            memoryCache?[key] = legacyValue
            try saveVaultUnlocked()
            return legacyValue
        }

        return ""
    }

    func set(_ value: String, accountID: UUID, kind: SecretKind) throws {
        lock.lock()
        defer { lock.unlock() }

        try ensureVaultLoaded()
        let key = cacheKey(accountID: accountID, kind: kind)

        if value.isEmpty {
            memoryCache?.removeValue(forKey: key)
        } else {
            memoryCache?[key] = value
        }

        try saveVaultUnlocked()
        deleteLegacyKeychainItem(accountID: accountID, kind: kind)
    }

    func deleteAll(accountID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }

        try ensureVaultLoaded()
        memoryCache?.removeValue(forKey: cacheKey(accountID: accountID, kind: .loginLink))
        memoryCache?.removeValue(forKey: cacheKey(accountID: accountID, kind: .sessionKey))

        try saveVaultUnlocked()
        deleteLegacyKeychainItem(accountID: accountID, kind: .loginLink)
        deleteLegacyKeychainItem(accountID: accountID, kind: .sessionKey)
    }

    private func cacheKey(accountID: UUID, kind: SecretKind) -> String {
        "\(accountID.uuidString).\(kind.rawValue)"
    }

    private func vaultFileURL() throws -> URL {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("ClaudeAccountManager", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
            return dir.appendingPathComponent("credentials.vault")
        } catch {
            throw KeychainError.vaultUnavailable
        }
    }

    private func ensureVaultLoaded() throws {
        if memoryCache != nil { return }

        let masterKey = try getOrCreateMasterKey()
        let url = try vaultFileURL()

        guard FileManager.default.fileExists(atPath: url.path) else {
            memoryCache = [:]
            return
        }

        do {
            let encryptedData = try Data(contentsOf: url)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: masterKey)
            let dict = try JSONDecoder().decode([String: String].self, from: decryptedData)
            memoryCache = dict
        } catch {
            throw KeychainError.vaultCorrupt
        }
    }

    private func saveVaultUnlocked() throws {
        guard let memoryCache else { return }
        let masterKey = try getOrCreateMasterKey()
        let jsonData = try JSONEncoder().encode(memoryCache)
        let sealedBox = try AES.GCM.seal(jsonData, using: masterKey)
        guard let combined = sealedBox.combined else {
            throw KeychainError.vaultCorrupt
        }
        let url = try vaultFileURL()
        try combined.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func getOrCreateMasterKey() throws -> SymmetricKey {
        if let key = cachedMasterKey {
            return key
        }

        if let existing = try readMasterKeyData() {
            tightenMasterKeyAccessibilityIfPossible()
            let key = SymmetricKey(data: existing)
            cachedMasterKey = key
            return key
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addition = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as [String: Any]

        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            guard let existing = try readMasterKeyData() else {
                throw KeychainError.unhandled(addStatus)
            }
            let key = SymmetricKey(data: existing)
            cachedMasterKey = key
            return key
        }
        if addStatus != errSecSuccess {
            throw KeychainError.unhandled(addStatus)
        }

        cachedMasterKey = newKey
        return newKey
    }

    private func readMasterKeyData() throws -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = result as? Data, data.count == 32 else {
            throw KeychainError.vaultCorrupt
        }
        return data
    }

    private func tightenMasterKeyAccessibilityIfPossible() {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount
        ] as [String: Any]
        let attributes = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as [String: Any]
        _ = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    private func tryReadLegacyKeychain(accountID: UUID, kind: SecretKind) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountID.uuidString).\(kind.rawValue)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteLegacyKeychainItem(accountID: UUID, kind: SecretKind) {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountID.uuidString).\(kind.rawValue)"
        ] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
}
