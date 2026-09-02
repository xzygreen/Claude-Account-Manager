import Foundation
import Testing
@testable import ClaudeAccountManager

@Test func accountExportProducesPipeDelimitedFormat() throws {
    let account1 = Account(
        id: UUID(),
        email: "user1@example.com",
        registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
        status: .normal,
        lastUsed: Date(timeIntervalSince1970: 1_700_010_000),
        tags: ["主力"],
        note: "测试1",
        createdAt: Date(timeIntervalSince1970: 1_700_000_100),
        updatedAt: Date(),
        isCurrent: true
    )
    let account2 = Account(
        id: UUID(),
        email: "user2@example.com",
        registeredAt: Date(timeIntervalSince1970: 1_700_050_000),
        status: .restricted,
        lastUsed: nil,
        tags: [],
        note: "",
        createdAt: Date(timeIntervalSince1970: 1_700_000_100),
        updatedAt: Date(),
        isCurrent: false
    )

    let secretsMap: [UUID: AccountSecrets] = [
        account1.id: AccountSecrets(loginLink: "https://claude.ai/login?token=abc", sessionKey: "example-session-key"),
        account2.id: AccountSecrets(loginLink: "", sessionKey: "")
    ]

    let text = try AccountExporter.format(accounts: [account1, account2]) { id in
        secretsMap[id] ?? AccountSecrets()
    }

    let date1Text = AppFormatters.dateTime.string(from: account1.registeredAt)
    let date2Text = AppFormatters.dateTime.string(from: account2.registeredAt)
    let lastUsedText = AppFormatters.dateTime.string(from: account1.lastUsed!)

    let expectedLine1 = "user1@example.com|https://claude.ai/login?token=abc|example-session-key|\(date1Text)|正常|主力|\(lastUsedText)|测试1"
    let expectedLine2 = "user2@example.com|||\(date2Text)|受限|||"

    #expect(text == "\(expectedLine1)\n\(expectedLine2)\n")

    let parseResult = AccountImportParser.parse(text)
    #expect(parseResult.errors.isEmpty)
    #expect(parseResult.accounts.count == 2)
    #expect(parseResult.accounts[0].email == "user1@example.com")
    #expect(parseResult.accounts[0].loginLink == "https://claude.ai/login?token=abc")
    #expect(parseResult.accounts[0].sessionKey == "example-session-key")
    #expect(parseResult.accounts[0].status == .normal)
    #expect(parseResult.accounts[0].tags == ["主力"])
    #expect(parseResult.accounts[0].note == "测试1")
    #expect(parseResult.accounts[1].email == "user2@example.com")
    #expect(parseResult.accounts[1].status == .restricted)
}

@Test func exportFailsWhenSecretsCannotBeRead() {
    let account = Account(
        id: UUID(),
        email: "broken@example.com",
        registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
        status: .normal,
        lastUsed: nil,
        tags: [],
        note: "",
        createdAt: Date(),
        updatedAt: Date(),
        isCurrent: false
    )
    #expect(throws: Error.self) {
        try AccountExporter.format(accounts: [account]) { _ in
            throw KeychainError.vaultCorrupt
        }
    }
}

@Test func legacyFourFieldExportStillImports() {
    let input = "user@example.com|https://claude.ai/login|secret|2026-08-20 12:00"
    let account = AccountImportParser.parse(input).accounts.first
    #expect(account?.email == "user@example.com")
    #expect(account?.status == nil)
    #expect(account?.tags.isEmpty == true)
}

@Test func bomPrefixedJSONIsParsed() {
    let input = "\u{FEFF}" + #"[{"email":"json@example.com","login_link":"https://claude.ai","session_key":"secret","registered_at":"2026-06-10"}]"#
    let result = AccountImportParser.parse(input)
    #expect(result.errors.isEmpty)
    #expect(result.accounts.first?.email == "json@example.com")
}

@Test func jsonRejectsNonHttpLoginLink() {
    let input = #"[{"email":"json@example.com","login_link":"file:///etc/passwd","session_key":"secret","registered_at":"2026-06-10"}]"#
    let result = AccountImportParser.parse(input)
    #expect(result.accounts.isEmpty)
    #expect(result.errors.contains(where: { $0.contains("http/https") }))
}
