import Foundation
import Testing
@testable import ClaudeAccountManager

@Test func databaseRoundTripAndSingleCurrentConstraint() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let database = try AccountDatabase(url: directory.appendingPathComponent("test.sqlite"))
    let first = makeAccount(email: "one@example.com", current: true)
    let second = makeAccount(email: "two@example.com", current: true)
    try database.save(first)
    try database.save(second)

    let accounts = try database.fetchAll()
    #expect(accounts.count == 2)
    #expect(accounts.filter(\.isCurrent).count == 1)
    #expect(accounts.first(where: { $0.isCurrent })?.email == "two@example.com")
    #expect(accounts.first(where: { $0.email == "one@example.com" })?.tags == ["主力", "测试"])
}

@Test func databaseDelete() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).sqlite")
    defer {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }
    let database = try AccountDatabase(url: url)
    let account = makeAccount(email: "delete@example.com", current: false)
    try database.save(account)
    try database.delete(id: account.id)
    #expect(try database.fetchAll().isEmpty)
}

private func makeAccount(email: String, current: Bool) -> Account {
    Account(
        id: UUID(),
        email: email,
        registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
        status: .normal,
        lastUsed: nil,
        tags: ["主力", "测试"],
        note: "本地测试",
        createdAt: Date(timeIntervalSince1970: 1_700_000_100),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_200),
        isCurrent: current
    )
}
