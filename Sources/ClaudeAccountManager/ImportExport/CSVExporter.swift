import Foundation

enum AccountExporter {
    static func format(
        accounts: [Account],
        secrets: (UUID) throws -> AccountSecrets
    ) throws -> String {
        var lines: [String] = []
        for account in accounts {
            let secret = (try? secrets(account.id)) ?? AccountSecrets()
            let email = account.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let loginLink = secret.loginLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let sessionKey = secret.sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let dateText = AppFormatters.dateTime.string(from: account.registeredAt)
            lines.append("\(email)|\(loginLink)|\(sessionKey)|\(dateText)")
        }
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    static func data(
        accounts: [Account],
        secrets: (UUID) throws -> AccountSecrets
    ) throws -> Data {
        let text = try format(accounts: accounts, secrets: secrets)
        return Data(text.utf8)
    }
}

// Retain CSVExporter alias for backwards compatibility
typealias CSVExporter = AccountExporter

