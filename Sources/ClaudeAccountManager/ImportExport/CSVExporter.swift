import Foundation

enum AccountExporter {
    static func format(
        accounts: [Account],
        secrets: (UUID) throws -> AccountSecrets
    ) throws -> String {
        var lines: [String] = []
        var errors: [String] = []
        for account in accounts {
            let secret: AccountSecrets
            do {
                secret = try secrets(account.id)
            } catch {
                errors.append("\(account.email)：\(error.localizedDescription)")
                continue
            }
            let email = account.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let loginLink = secret.loginLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let sessionKey = secret.sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let dateText = AppFormatters.dateTime.string(from: account.registeredAt)
            let lastUsedText = account.lastUsed.map { AppFormatters.dateTime.string(from: $0) } ?? ""
            let tags = account.tags.joined(separator: ",")
            let note = account.note.replacingOccurrences(of: "|", with: "/")
            lines.append(
                "\(email)|\(loginLink)|\(sessionKey)|\(dateText)|\(account.status.title)|\(tags)|\(lastUsedText)|\(note)"
            )
        }
        if !errors.isEmpty {
            throw ExportError.message("部分账号的凭据无法读取，已中止导出以免写出空备份。\n" + errors.joined(separator: "\n"))
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

    private enum ExportError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let message) = self { return message }
            return nil
        }
    }
}

typealias CSVExporter = AccountExporter
