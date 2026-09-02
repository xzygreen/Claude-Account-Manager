import AppKit
import SwiftUI

struct AccountTableView: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            Table(store.filteredAccounts, selection: $store.selectedID) {
                TableColumn("") { account in
                    ZStack {
                        if account.isCurrent {
                            Circle()
                                .fill(Color.teal)
                                .frame(width: 8, height: 8)
                                .shadow(color: .teal.opacity(0.8), radius: 3)
                        } else {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .help(account.isCurrent ? "当前使用中" : "未标记为当前账号")
                    .accessibilityLabel(account.isCurrent ? "当前使用中" : "未在使用")
                }
                .width(28)

                TableColumn("邮箱 / 账号") { account in
                    HStack(spacing: 10) {
                        AccountAvatarView(email: account.email, size: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.email)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            if !account.note.isEmpty {
                                Text(account.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .width(min: 180, ideal: 220, max: 280)

                TableColumn("状态") { account in
                    StatusBadge(status: account.status, compact: true)
                }
                .width(78)

                TableColumn("注册时间") { account in
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(AppFormatters.display(account.registeredAt))
                            .monospacedDigit()
                    }
                }
                .width(min: 120, ideal: 130)

                TableColumn("最后使用") { account in
                    HStack(spacing: 4) {
                        if account.lastUsed != nil {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text(AppFormatters.display(account.lastUsed))
                            .foregroundStyle(account.lastUsed == nil ? .secondary : .primary)
                            .monospacedDigit()
                    }
                }
                .width(min: 120, ideal: 130)

                TableColumn("标签") { account in
                    if account.tags.isEmpty {
                        Text("—")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            ForEach(account.tags.prefix(3), id: \.self) { tag in
                                TagView(text: tag)
                            }
                            if account.tags.count > 3 {
                                Text("+\(account.tags.count - 3)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .help(account.tags.joined(separator: ", "))
                    }
                }
                .width(min: 100, ideal: 140)
            }
            .contextMenu(forSelectionType: UUID.self) { selectedIDs in
                if let selectedID = selectedIDs.first,
                   let account = store.accounts.first(where: { $0.id == selectedID }) {
                    Button {
                        store.markCurrent(account)
                    } label: {
                        Label(account.isCurrent ? "已是当前账号（点击刷新使用时间）" : "设为当前使用中", systemImage: "location.fill")
                    }

                    if let secrets = try? store.secrets(for: account.id),
                       LoginLink.isSafe(secrets.loginLink),
                       let url = URL(string: secrets.loginLink) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("在浏览器中打开登录", systemImage: "arrow.up.forward.square")
                        }
                    }

                    Divider()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(account.email, forType: .string)
                    } label: {
                        Label("复制邮箱", systemImage: "envelope")
                    }

                    Button {
                        if let secrets = try? store.secrets(for: account.id), !secrets.loginLink.isEmpty {
                            SecretClipboard.copy(secrets.loginLink)
                        }
                    } label: {
                        Label("复制自动登录链接", systemImage: "link")
                    }

                    Button {
                        if let secrets = try? store.secrets(for: account.id), !secrets.sessionKey.isEmpty {
                            SecretClipboard.copy(secrets.sessionKey)
                        }
                    } label: {
                        Label("复制 Session Key", systemImage: "key.fill")
                    }

                    Divider()

                    Button(role: .destructive) {
                        NotificationCenter.default.post(name: .confirmDeleteAccount, object: account.id)
                    } label: {
                        Label("删除账号", systemImage: "trash")
                    }
                }
            }
            .overlay {
                if store.filteredAccounts.isEmpty {
                    ContentUnavailableView {
                        Label(store.accounts.isEmpty ? "还没有账号" : "没有匹配结果", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text(store.accounts.isEmpty ? "添加单个账号，或粘贴现有文本批量导入。" : "尝试清除搜索词或调整筛选条件。")
                    } actions: {
                        if store.accounts.isEmpty && store.isAvailable {
                            Button("添加账号") {
                                NotificationCenter.default.post(name: .addAccount, object: nil)
                            }
                            Button("批量导入") {
                                NotificationCenter.default.post(name: .importAccounts, object: nil)
                            }
                        } else if !store.accounts.isEmpty {
                            Button("清除筛选") {
                                store.searchText = ""
                                store.selectedScope = .all
                                store.registrationRange = .all
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("注册时间", selection: $store.registrationRange) {
                    ForEach(RegistrationRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("排序", selection: $store.sort) {
                    ForEach(AccountSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            if hasActiveFilter {
                Button {
                    store.searchText = ""
                    store.selectedScope = .all
                    store.registrationRange = .all
                } label: {
                    Label("重置筛选", systemImage: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.filteredAccounts.count) 个账号")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }

    private var hasActiveFilter: Bool {
        !store.searchText.isEmpty || store.registrationRange != .all || store.selectedScope != .all
    }

    private var navigationTitle: String {
        switch store.selectedScope {
        case .all: "全部账号"
        case .current: "当前使用中"
        case .status(let status): status.title
        case .tag(let tag): "标签: \(tag)"
        }
    }
}

