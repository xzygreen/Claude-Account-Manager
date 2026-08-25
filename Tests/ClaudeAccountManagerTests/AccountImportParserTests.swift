import Foundation
import Testing
@testable import ClaudeAccountManager

@Test func parsesLegacyConcatenatedFormat() throws {
    let input = "person@example.comhttps://claude.ai/login?token=abc--example-session-key--2026-08-01 09:30"
    let result = AccountImportParser.parse(input)

    #expect(result.errors.isEmpty)
    let account = try #require(result.accounts.first)
    #expect(account.email == "person@example.com")
    #expect(account.loginLink == "https://claude.ai/login?token=abc")
    #expect(account.sessionKey == "example-session-key")
    #expect(AppFormatters.dateTime.string(from: account.registeredAt) == "2026-08-01 09:30")
}

@Test func legacyLinkMayContainDoubleHyphen() throws {
    let input = "person@example.comhttps://claude.ai/login?token=a--b--session-value--2026-08-01"
    let account = try #require(AccountImportParser.parse(input).accounts.first)

    #expect(account.loginLink == "https://claude.ai/login?token=a--b")
    #expect(account.sessionKey == "session-value")
}

@Test func parsesPipeFormatWithMetadata() throws {
    let input = "user@example.com | https://claude.ai/login | secret | 2026-07-02 | 受限 | 工作,备用 | 需要复核"
    let account = try #require(AccountImportParser.parse(input).accounts.first)

    #expect(account.status == .restricted)
    #expect(account.tags == ["工作", "备用"])
    #expect(account.note == "需要复核")
}

@Test func parsesJSON() throws {
    let input = #"[{"email":"json@example.com","login_link":"https://claude.ai","session_key":"secret","registered_at":"2026-06-10","status":"待验证","tags":["JSON","测试"]}]"#
    let result = AccountImportParser.parse(input)

    #expect(result.errors.isEmpty)
    let account = try #require(result.accounts.first)
    #expect(account.status == .pendingVerification)
    #expect(account.tags == ["JSON", "测试"])
}

@Test func reportsBadLinesWithoutDroppingValidOnes() {
    let input = "bad line\nvalid@example.com | https://claude.ai | key | 2026-08-10"
    let result = AccountImportParser.parse(input)

    #expect(result.accounts.count == 1)
    #expect(result.errors.count == 1)
    #expect(result.errors[0].contains("第 1 行"))
}
