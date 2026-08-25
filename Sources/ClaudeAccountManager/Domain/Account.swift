import Foundation
import SwiftUI

enum AccountStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case restricted
    case invalid
    case pendingVerification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "正常"
        case .restricted: "受限"
        case .invalid: "失效"
        case .pendingVerification: "待验证"
        }
    }

    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .restricted: "exclamationmark.triangle.fill"
        case .invalid: "xmark.circle.fill"
        case .pendingVerification: "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .normal: .green
        case .restricted: .orange
        case .invalid: .red
        case .pendingVerification: .blue
        }
    }

    static func parse(_ value: String) -> AccountStatus? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { status in
            [status.rawValue.lowercased(), status.title].contains(normalized)
        }
    }
}

struct Account: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var email: String
    var registeredAt: Date
    var status: AccountStatus
    var lastUsed: Date?
    var tags: [String]
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var isCurrent: Bool

    var searchableText: String {
        ([email, note, status.title, status.rawValue] + tags).joined(separator: " ").localizedLowercase
    }
}

struct AccountSecrets: Equatable, Sendable {
    var loginLink: String = ""
    var sessionKey: String = ""
}

struct AccountDraft: Sendable {
    var id: UUID?
    var email = ""
    var loginLink = ""
    var sessionKey = ""
    var registeredAt = Date()
    var status: AccountStatus = .normal
    var hasLastUsed = false
    var lastUsed = Date()
    var tagsText = ""
    var note = ""
    var isCurrent = false

    var tags: [String] {
        tagsText
            .split(whereSeparator: { ",，;；\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    result.append(value)
                }
            }
    }

    init() {}

    init(account: Account, secrets: AccountSecrets) {
        id = account.id
        email = account.email
        loginLink = secrets.loginLink
        sessionKey = secrets.sessionKey
        registeredAt = account.registeredAt
        status = account.status
        hasLastUsed = account.lastUsed != nil
        lastUsed = account.lastUsed ?? Date()
        tagsText = account.tags.joined(separator: ", ")
        note = account.note
        isCurrent = account.isCurrent
    }
}

enum AccountSort: String, CaseIterable, Identifiable {
    case registeredNewest
    case registeredOldest
    case lastUsedNewest
    case emailAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .registeredNewest: "注册时间：最新优先"
        case .registeredOldest: "注册时间：最早优先"
        case .lastUsedNewest: "最后使用：最新优先"
        case .emailAscending: "邮箱：A–Z"
        }
    }
}

enum RegistrationRange: String, CaseIterable, Identifiable {
    case all, last30Days, last90Days, thisYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部时间"
        case .last30Days: "最近 30 天注册"
        case .last90Days: "最近 90 天注册"
        case .thisYear: "今年注册"
        }
    }

    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .all:
            return true
        case .last30Days:
            guard let threshold = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= threshold
        case .last90Days:
            guard let threshold = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return date >= threshold
        case .thisYear:
            guard let threshold = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return true }
            return date >= threshold
        }
    }
}
