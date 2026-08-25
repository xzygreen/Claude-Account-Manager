import Foundation
import Testing
@testable import ClaudeAccountManager

@Test func accountExportProducesPipeDelimitedFormat() throws {
    let account1 = Account(
        id: UUID(),
        email: "user1@example.com",
        registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
        status: .normal,
        lastUsed: nil,
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

    let expectedLine1 = "user1@example.com|https://claude.ai/login?token=abc|example-session-key|\(date1Text)"
    let expectedLine2 = "user2@example.com|||\(date2Text)"

    #expect(text == "\(expectedLine1)\n\(expectedLine2)\n")

    // Test round-trip import parsing
    let parseResult = AccountImportParser.parse(text)
    #expect(parseResult.errors.isEmpty)
    #expect(parseResult.accounts.count == 2)
    #expect(parseResult.accounts[0].email == "user1@example.com")
    #expect(parseResult.accounts[0].loginLink == "https://claude.ai/login?token=abc")
    #expect(parseResult.accounts[0].sessionKey == "example-session-key")
    #expect(parseResult.accounts[1].email == "user2@example.com")
}
