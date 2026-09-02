import Combine
import Foundation

private enum AccountStoreError: LocalizedError {
    case rollbackFailed(operation: String, rollback: String)

    var errorDescription: String? {
        switch self {
        case .rollbackFailed(let operation, let rollback):
            return "操作失败（\(operation)），且凭据回滚也失败（\(rollback)）。请立即检查账号凭据。"
        }
    }
}

enum SidebarScope: Hashable {
    case all
    case current
    case status(AccountStatus)
    case tag(String)
}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var selectedID: UUID?
    @Published var selectedScope: SidebarScope = .all
    @Published var searchText = ""
    @Published var registrationRange: RegistrationRange = .all
    @Published var sort: AccountSort = .registeredNewest
    @Published var errorMessage: String?

    private let database: AccountDatabase?
    private let keychain: KeychainService

    init(database: AccountDatabase?, keychain: KeychainService = .shared, startupError: Error? = nil) {
        self.database = database
        self.keychain = keychain
        if let startupError {
            errorMessage = "本地数据库无法打开。为避免数据写入临时位置，账号操作已停用。\n\n\(startupError.localizedDescription)"
        } else {
            reload()
        }
    }

    static func live() -> AccountStore {
        do {
            return AccountStore(database: try AccountDatabase())
        } catch {
            return AccountStore(database: nil, startupError: error)
        }
    }

    var isAvailable: Bool { database != nil }

    var selectedAccount: Account? {
        accounts.first { $0.id == selectedID }
    }

    var currentAccount: Account? {
        accounts.first { $0.isCurrent }
    }

    var allTags: [String] {
        var set = Set<String>()
        for account in accounts {
            for tag in account.tags {
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    set.insert(trimmed)
                }
            }
        }
        return set.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var statusCounts: (normal: Int, restricted: Int, invalid: Int, pending: Int) {
        var normal = 0, restricted = 0, invalid = 0, pending = 0
        for account in accounts {
            switch account.status {
            case .normal: normal += 1
            case .restricted: restricted += 1
            case .invalid: invalid += 1
            case .pendingVerification: pending += 1
            }
        }
        return (normal, restricted, invalid, pending)
    }

    var filteredAccounts: [Account] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let filtered = accounts.filter { account in
            let matchesSearch = query.isEmpty || account.searchableText.contains(query)
            let matchesScope: Bool
            switch selectedScope {
            case .all: matchesScope = true
            case .current: matchesScope = account.isCurrent
            case .status(let status): matchesScope = account.status == status
            case .tag(let tag): matchesScope = account.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
            }
            return matchesSearch && matchesScope && registrationRange.contains(account.registeredAt)
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .registeredNewest: lhs.registeredAt > rhs.registeredAt
            case .registeredOldest: lhs.registeredAt < rhs.registeredAt
            case .lastUsedNewest: (lhs.lastUsed ?? .distantPast) > (rhs.lastUsed ?? .distantPast)
            case .emailAscending: lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
            }
        }
    }

    func count(for scope: SidebarScope) -> Int {
        switch scope {
        case .all: accounts.count
        case .current: accounts.filter(\.isCurrent).count
        case .status(let status): accounts.filter { $0.status == status }.count
        case .tag(let tag): accounts.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }.count
        }
    }

    func secrets(for id: UUID) throws -> AccountSecrets {
        AccountSecrets(
            loginLink: try keychain.read(accountID: id, kind: .loginLink),
            sessionKey: try keychain.read(accountID: id, kind: .sessionKey)
        )
    }

    func draft(for account: Account) throws -> AccountDraft {
        AccountDraft(account: account, secrets: try secrets(for: account.id))
    }

    @discardableResult
    func save(_ draft: AccountDraft) -> Bool {
        let email = draft.email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "请输入有效的邮箱地址。"
            return false
        }
        if accounts.contains(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame && $0.id != draft.id }) {
            errorMessage = "该邮箱已经存在。"
            return false
        }

        let existing = draft.id.flatMap { id in accounts.first { $0.id == id } }
        let id = existing?.id ?? UUID()
        let now = Date()
        let account = Account(
            id: id,
            email: email,
            registeredAt: draft.registeredAt,
            status: draft.status,
            lastUsed: draft.hasLastUsed ? draft.lastUsed : nil,
            tags: draft.tags,
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            isCurrent: draft.isCurrent
        )

        guard let database else {
            errorMessage = "本地数据库不可用，无法保存账号。请重新启动应用或检查磁盘权限。"
            return false
        }

        do {
            let previousSecrets = existing == nil ? AccountSecrets() : try secrets(for: id)
            do {
                try keychain.set(draft.loginLink.trimmingCharacters(in: .whitespacesAndNewlines), accountID: id, kind: .loginLink)
                try keychain.set(draft.sessionKey.trimmingCharacters(in: .whitespacesAndNewlines), accountID: id, kind: .sessionKey)
                try database.save(account)
            } catch {
                do {
                    try restore(previousSecrets, for: id)
                } catch let restoreError {
                    throw AccountStoreError.rollbackFailed(
                        operation: error.localizedDescription,
                        rollback: restoreError.localizedDescription
                    )
                }
                throw error
            }
            reload(selecting: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteSelected() {
        guard let id = selectedID else {
            errorMessage = "请先选择要删除的账号。"
            return
        }
        delete(id: id)
    }

    func delete(id: UUID) {
        guard let database else {
            errorMessage = "本地数据库不可用，无法删除账号。"
            return
        }
        do {
            let previousSecrets = try secrets(for: id)
            do {
                try keychain.deleteAll(accountID: id)
                try database.delete(id: id)
            } catch {
                do {
                    try restore(previousSecrets, for: id)
                } catch let restoreError {
                    throw AccountStoreError.rollbackFailed(
                        operation: error.localizedDescription,
                        rollback: restoreError.localizedDescription
                    )
                }
                throw error
            }
            if selectedID == id { selectedID = nil }
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markCurrent(_ account: Account) {
        guard let database else {
            errorMessage = "本地数据库不可用，无法更新账号。"
            return
        }
        var updated = account
        updated.isCurrent = true
        updated.lastUsed = Date()
        updated.updatedAt = Date()
        do {
            try database.save(updated)
            reload(selecting: account.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importAccounts(_ parsed: [ParsedAccount]) -> (created: Int, updated: Int, errors: [String]) {
        var created = 0
        var updated = 0
        var errors: [String] = []

        for item in parsed {
            let existing = accounts.first { $0.email.caseInsensitiveCompare(item.email) == .orderedSame }
            var draft: AccountDraft
            do {
                draft = try existing.map { try self.draft(for: $0) } ?? AccountDraft()
            } catch {
                errors.append("第 \(item.line) 项（\(item.email)）：无法读取现有钥匙串凭据，已跳过以免覆盖。\(error.localizedDescription)")
                continue
            }
            draft.id = existing?.id
            draft.email = item.email
            if !item.loginLink.isEmpty { draft.loginLink = item.loginLink }
            if !item.sessionKey.isEmpty { draft.sessionKey = item.sessionKey }
            draft.registeredAt = item.registeredAt
            if let status = item.status { draft.status = status }
            if item.lastUsed != nil {
                draft.hasLastUsed = true
                draft.lastUsed = item.lastUsed ?? Date()
            }
            if !item.tags.isEmpty { draft.tagsText = item.tags.joined(separator: ", ") }
            if !item.note.isEmpty { draft.note = item.note }
            if save(draft) {
                if existing == nil {
                    created += 1
                } else {
                    updated += 1
                }
            } else {
                errors.append("第 \(item.line) 项（\(item.email)）：\(errorMessage ?? "保存失败")")
            }
        }
        reload()
        return (created, updated, errors)
    }

    func exportAccounts() throws -> Data {
        try AccountExporter.data(accounts: filteredAccounts) { id in
            try self.secrets(for: id)
        }
    }

    func exportText() throws -> String {
        try AccountExporter.format(accounts: filteredAccounts) { id in
            try self.secrets(for: id)
        }
    }

    func exportCSV(includeSecrets: Bool = true) throws -> Data {
        try exportAccounts()
    }

    private func reload(selecting id: UUID? = nil) {
        guard let database else { return }
        do {
            accounts = try database.fetchAll()
            if let id { selectedID = id }
            if let selectedID, !accounts.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ secrets: AccountSecrets, for id: UUID) throws {
        try keychain.set(secrets.loginLink, accountID: id, kind: .loginLink)
        try keychain.set(secrets.sessionKey, accountID: id, kind: .sessionKey)
    }
}
