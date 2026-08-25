import Foundation

struct ParsedAccount: Sendable {
    var line: Int
    var email: String
    var loginLink: String
    var sessionKey: String
    var registeredAt: Date
    var status: AccountStatus
    var lastUsed: Date?
    var tags: [String]
    var note: String
}

struct ImportParseResult: Sendable {
    var accounts: [ParsedAccount]
    var errors: [String]
}

enum AccountImportParser {
    static func parse(_ input: String) -> ImportParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ImportParseResult(accounts: [], errors: ["没有可导入的内容。"])
        }
        if trimmed.first == "[" || trimmed.first == "{" {
            return parseJSON(trimmed)
        }
        return parseLines(trimmed)
    }

    private static func parseLines(_ input: String) -> ImportParseResult {
        var accounts: [ParsedAccount] = []
        var errors: [String] = []

        for (offset, rawLine) in input.components(separatedBy: .newlines).enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            do {
                accounts.append(try parseLine(line, number: lineNumber))
            } catch {
                errors.append("第 \(lineNumber) 行：\(error.localizedDescription)")
            }
        }
        return ImportParseResult(accounts: accounts, errors: errors)
    }

    private static func parseLine(_ line: String, number: Int) throws -> ParsedAccount {
        let fields: [String]
        if line.contains("|") {
            fields = line.components(separatedBy: "|").map(clean)
        } else {
            fields = line.components(separatedBy: "--").map(clean)
        }

        let email: String
        let loginLink: String
        let sessionKey: String
        let dateText: String
        var extras: ArraySlice<String> = []

        if fields.count >= 4, isEmail(fields[0]) {
            email = fields[0]
            loginLink = fields[1]
            sessionKey = fields[2]
            dateText = fields[3]
            extras = fields.dropFirst(4)
        } else if fields.count >= 3 {
            // The legacy link is not quoted and may itself contain "--". Read the
            // session key and date from the right so the link remains intact.
            let combined = fields.dropLast(2).joined(separator: "--")
            guard let match = emailAtStart(combined) else {
                throw ImportError.message("无法从开头识别邮箱。请使用 email|login_link|session_key|日期。")
            }
            email = match.email
            loginLink = match.remainder
            sessionKey = fields[fields.count - 2]
            dateText = fields[fields.count - 1]
        } else {
            throw ImportError.message("字段不足。支持“邮箱链接--sessionkey--注册时间”或“邮箱|链接|sessionkey|注册时间”。")
        }

        guard isEmail(email) else { throw ImportError.message("邮箱格式无效。") }
        guard loginLink.isEmpty || URL(string: loginLink)?.scheme?.hasPrefix("http") == true else {
            throw ImportError.message("自动登录链接必须是 http/https 地址。")
        }
        guard let registeredAt = parseDate(dateText) else {
            throw ImportError.message("注册时间无法识别，请使用 YYYY-MM-DD 或 YYYY-MM-DD HH:mm。")
        }

        let extraArray = Array(extras)
        let status = extraArray.first.flatMap(AccountStatus.parse) ?? .normal
        let tags = extraArray.count > 1
            ? extraArray[1].split(whereSeparator: { ",，;；".contains($0) }).map { clean(String($0)) }
            : []
        let note = extraArray.count > 2 ? extraArray.dropFirst(2).joined(separator: " | ") : ""

        return ParsedAccount(
            line: number,
            email: email,
            loginLink: loginLink,
            sessionKey: sessionKey,
            registeredAt: registeredAt,
            status: status,
            lastUsed: nil,
            tags: tags,
            note: note
        )
    }

    private static func parseJSON(_ input: String) -> ImportParseResult {
        do {
            let object = try JSONSerialization.jsonObject(with: Data(input.utf8))
            let dictionaries: [[String: Any]]
            if let array = object as? [[String: Any]] {
                dictionaries = array
            } else if let dictionary = object as? [String: Any] {
                dictionaries = [dictionary]
            } else {
                throw ImportError.message("JSON 顶层必须是对象或对象数组。")
            }

            var accounts: [ParsedAccount] = []
            var errors: [String] = []
            for (offset, dictionary) in dictionaries.enumerated() {
                do {
                    let row = offset + 1
                    guard let email = string(dictionary["email"]), isEmail(email) else {
                        throw ImportError.message("缺少有效的 email。")
                    }
                    guard let registeredText = string(dictionary["registered_at"]),
                          let registeredAt = parseDate(registeredText) else {
                        throw ImportError.message("缺少有效的 registered_at。")
                    }
                    let lastUsed = string(dictionary["last_used"]).flatMap(parseDate)
                    let tags: [String]
                    if let values = dictionary["tags"] as? [String] {
                        tags = values.map(clean).filter { !$0.isEmpty }
                    } else if let value = string(dictionary["tags"]) {
                        tags = value.split(whereSeparator: { ",，;；".contains($0) }).map { clean(String($0)) }
                    } else {
                        tags = []
                    }
                    accounts.append(ParsedAccount(
                        line: row,
                        email: email,
                        loginLink: string(dictionary["login_link"]) ?? "",
                        sessionKey: string(dictionary["session_key"]) ?? "",
                        registeredAt: registeredAt,
                        status: string(dictionary["status"]).flatMap(AccountStatus.parse) ?? .normal,
                        lastUsed: lastUsed,
                        tags: tags,
                        note: string(dictionary["note"]) ?? ""
                    ))
                } catch {
                    errors.append("JSON 第 \(offset + 1) 项：\(error.localizedDescription)")
                }
            }
            return ImportParseResult(accounts: accounts, errors: errors)
        } catch {
            return ImportParseResult(accounts: [], errors: ["JSON 解析失败：\(error.localizedDescription)"])
        }
    }

    static func parseDate(_ value: String) -> Date? {
        let value = clean(value)
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func emailAtStart(_ value: String) -> (email: String, remainder: String)? {
        if let linkRange = value.range(of: "https://") ?? value.range(of: "http://") {
            let email = String(value[..<linkRange.lowerBound])
            if isStandaloneEmail(email) {
                return (email, clean(String(value[linkRange.lowerBound...])))
            }
        }
        guard let email = standaloneEmailAtStart(value) else { return nil }
        return (email, clean(String(value.dropFirst(email.count))))
    }

    private static func standaloneEmailAtStart(_ value: String) -> String? {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range, in: value) else { return nil }
        return String(value[range])
    }

    private static func isStandaloneEmail(_ value: String) -> Bool {
        standaloneEmailAtStart(value)?.count == value.count
    }

    private static func isEmail(_ value: String) -> Bool {
        isStandaloneEmail(value)
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String)?.nilIfBlank
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum ImportError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let message) = self { return message }
            return nil
        }
    }
}
