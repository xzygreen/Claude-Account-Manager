import Foundation
import SQLite3

enum DatabaseError: LocalizedError {
    case open(String)
    case statement(String)
    case execute(String)
    case corruptRow

    var errorDescription: String? {
        switch self {
        case .open(let message): "无法打开本地数据库：\(message)"
        case .statement(let message): "无法准备数据库操作：\(message)"
        case .execute(let message): "无法保存本地数据：\(message)"
        case .corruptRow: "数据库中存在无法读取的账号记录。"
        }
    }
}

final class AccountDatabase: @unchecked Sendable {
    private var database: OpaquePointer?
    private let queue = DispatchQueue(label: "com.local.ClaudeAccountManager.sqlite")

    init(url: URL? = nil) throws {
        let databaseURL = try url ?? Self.defaultDatabaseURL()
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
            if let handle { sqlite3_close(handle) }
            throw DatabaseError.open(message)
        }
        database = handle
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try migrate()
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    func fetchAll() throws -> [Account] {
        try queue.sync {
            let sql = """
            SELECT id, email, registered_at, status, last_used, tags_json, note,
                   created_at, updated_at, is_current
            FROM accounts;
            """
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            var accounts: [Account] = []
            while true {
                let code = sqlite3_step(statement)
                if code == SQLITE_DONE { break }
                guard code == SQLITE_ROW else {
                    throw DatabaseError.execute(lastError())
                }
                guard
                    let idText = columnText(statement, 0),
                    let id = UUID(uuidString: idText),
                    let email = columnText(statement, 1),
                    let statusText = columnText(statement, 3),
                    let status = AccountStatus(rawValue: statusText),
                    let tagsJSON = columnText(statement, 5),
                    let note = columnText(statement, 6)
                else { continue }

                let tagsData = Data(tagsJSON.utf8)
                let tags = uniqueTags((try? JSONDecoder().decode([String].self, from: tagsData)) ?? [])
                let lastUsed: Date? = sqlite3_column_type(statement, 4) == SQLITE_NULL
                    ? nil
                    : Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))

                accounts.append(Account(
                    id: id,
                    email: email,
                    registeredAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    status: status,
                    lastUsed: lastUsed,
                    tags: tags,
                    note: note,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
                    updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8)),
                    isCurrent: sqlite3_column_int(statement, 9) == 1
                ))
            }
            return accounts
        }
    }

    func save(_ account: Account) throws {
        try queue.sync {
            try executeUnlocked("BEGIN IMMEDIATE;")
            do {
                if account.isCurrent {
                    try executeUnlocked("UPDATE accounts SET is_current = 0;")
                }
                let sql = """
                INSERT INTO accounts
                    (id, email, registered_at, status, last_used, tags_json, note,
                     created_at, updated_at, is_current)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    email = excluded.email,
                    registered_at = excluded.registered_at,
                    status = excluded.status,
                    last_used = excluded.last_used,
                    tags_json = excluded.tags_json,
                    note = excluded.note,
                    updated_at = excluded.updated_at,
                    is_current = excluded.is_current;
                """
                let statement = try prepare(sql)
                defer { sqlite3_finalize(statement) }
                bind(account.id.uuidString, to: statement, index: 1)
                bind(account.email, to: statement, index: 2)
                sqlite3_bind_double(statement, 3, account.registeredAt.timeIntervalSince1970)
                bind(account.status.rawValue, to: statement, index: 4)
                if let lastUsed = account.lastUsed {
                    sqlite3_bind_double(statement, 5, lastUsed.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(statement, 5)
                }
                let tagsData = try JSONEncoder().encode(uniqueTags(account.tags))
                bind(String(decoding: tagsData, as: UTF8.self), to: statement, index: 6)
                bind(account.note, to: statement, index: 7)
                sqlite3_bind_double(statement, 8, account.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(statement, 9, account.updatedAt.timeIntervalSince1970)
                sqlite3_bind_int(statement, 10, account.isCurrent ? 1 : 0)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw DatabaseError.execute(lastError())
                }
                try executeUnlocked("COMMIT;")
            } catch {
                try? executeUnlocked("ROLLBACK;")
                throw error
            }
        }
    }

    func delete(id: UUID) throws {
        try queue.sync {
            let statement = try prepare("DELETE FROM accounts WHERE id = ?;")
            defer { sqlite3_finalize(statement) }
            bind(id.uuidString, to: statement, index: 1)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.execute(lastError())
            }
        }
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            registered_at REAL NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('normal','restricted','invalid','pendingVerification')),
            last_used REAL,
            tags_json TEXT NOT NULL DEFAULT '[]',
            note TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            is_current INTEGER NOT NULL DEFAULT 0 CHECK(is_current IN (0,1))
        );
        CREATE INDEX IF NOT EXISTS idx_accounts_registered_at ON accounts(registered_at);
        CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts(status);
        CREATE INDEX IF NOT EXISTS idx_accounts_last_used ON accounts(last_used);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_one_current
            ON accounts(is_current) WHERE is_current = 1;
        """)
    }

    private static func defaultDatabaseURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ClaudeAccountManager", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("accounts.sqlite")
    }

    private func execute(_ sql: String) throws {
        try queue.sync { try executeUnlocked(sql) }
    }

    private func executeUnlocked(_ sql: String) throws {
        guard let database else { throw DatabaseError.open("数据库未初始化") }
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastError()
            sqlite3_free(errorPointer)
            throw DatabaseError.execute(message)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let database else { throw DatabaseError.open("数据库未初始化") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw DatabaseError.statement(lastError())
        }
        return statement
    }

    private func bind(_ value: String, to statement: OpaquePointer, index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func columnText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func lastError() -> String {
        guard let database else { return "数据库未初始化" }
        return String(cString: sqlite3_errmsg(database))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func uniqueTags(_ tags: [String]) -> [String] {
    tags.reduce(into: [String]()) { result, value in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        result.append(trimmed)
    }
}
