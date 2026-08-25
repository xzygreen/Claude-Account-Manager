import CryptoKit
import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    case vaultCorrupt

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "未知错误"
            return "钥匙串操作失败：\(message)（\(status)）"
        case .vaultCorrupt:
            return "无法解密本地安全凭据保险库。"
        }
    }
}

final class KeychainService: @unchecked Sendable {
    static let shared = KeychainService()

    private let service = "com.local.ClaudeAccountManager"
    private let masterKeyAccount = "ClaudeAccountManager.MasterKey.v1"
    private let lock = NSLock()

    // In-memory cache of decrypted credentials for zero-prompt instant access
    private var memoryCache: [String: String]? = nil
    private var cachedMasterKey: SymmetricKey? = nil

    enum SecretKind: String {
        case loginLink = "login-link"
        case sessionKey = "session-key"
    }

    private var vaultFileURL: URL {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("ClaudeAccountManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("credentials.vault")
    }

    func read(accountID: UUID, kind: SecretKind) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        let key = cacheKey(accountID: accountID, kind: kind)
        try ensureVaultLoaded()

        if let value = memoryCache?[key] {
            return value
        }

        // Fallback: check legacy individual Keychain item for backward compatibility
        if let legacyValue = tryReadLegacyKeychain(accountID: accountID, kind: kind), !legacyValue.isEmpty {
            memoryCache?[key] = legacyValue
            try? saveVaultUnlocked()
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
        // Clean legacy Keychain item if present to prevent future legacy prompts
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

    // MARK: - Private Vault & Master Key Management

    private func cacheKey(accountID: UUID, kind: SecretKind) -> String {
        "\(accountID.uuidString).\(kind.rawValue)"
    }

    private func ensureVaultLoaded() throws {
        if memoryCache != nil { return }

        let masterKey = try getOrCreateMasterKey()
        let url = vaultFileURL

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
            // If decryption fails, start fresh cache to avoid crashing
            memoryCache = [:]
        }
    }

    private func saveVaultUnlocked() throws {
        guard let memoryCache else { return }
        let masterKey = try getOrCreateMasterKey()
        let jsonData = try JSONEncoder().encode(memoryCache)
        let sealedBox = try AES.GCM.seal(jsonData, using: masterKey)
        guard let combined = sealedBox.combined else { return }
        try combined.write(to: vaultFileURL, options: .atomic)
    }

    private func getOrCreateMasterKey() throws -> SymmetricKey {
        if let key = cachedMasterKey {
            return key
        }

        // Query Keychain once for the Master Key
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, data.count == 32 {
            let key = SymmetricKey(data: data)
            cachedMasterKey = key
            return key
        }

        // Generate new 256-bit AES Master Key and save to Keychain
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        let addition = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ] as [String: Any]

        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            // If Keychain fails, still hold key in memory for this session
            cachedMasterKey = newKey
            return newKey
        }

        cachedMasterKey = newKey
        return newKey
    }

    // MARK: - Legacy Migration Helpers

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

