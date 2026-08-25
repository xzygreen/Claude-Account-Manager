import AppKit
import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var isEditing = false
    @State private var draft = AccountDraft()
    @State private var secrets = AccountSecrets()
    @State private var copiedEmail = false

    var body: some View {
        Group {
            if let account = store.selectedAccount {
                VStack(spacing: 0) {
                    detailHeader(account)
                    Divider()
                    if isEditing {
                        AccountEditorForm(draft: $draft)
                    } else {
                        summary(account)
                    }
                }
                .id(account.id)
                .task(id: account.id) {
                    isEditing = false
                    load(account)
                }
            } else {
                ContentUnavailableView(
                    "选择一个账号",
                    systemImage: "sidebar.right",
                    description: Text("在中间列表选择账号后，可在这里查看和编辑详情。")
                )
            }
        }
    }

    private func detailHeader(_ account: Account) -> some View {
        HStack(alignment: .center, spacing: 14) {
            AccountAvatarView(email: account.email, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.email)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .help(account.email)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(account.email, forType: .string)
                        copiedEmail = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedEmail = false }
                    } label: {
                        Image(systemName: copiedEmail ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(copiedEmail ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(copiedEmail ? "已复制邮箱" : "复制邮箱")
                }

                HStack(spacing: 8) {
                    StatusBadge(status: account.status)
                    if account.isCurrent {
                        ActiveBadge(text: "当前使用中")
                    }
                }
            }

            Spacer()

            if isEditing {
                Button("取消") {
                    load(account)
                    withAnimation { isEditing = false }
                }
                Button("保存") {
                    if store.save(draft) {
                        withAnimation { isEditing = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    draft = AccountDraft(account: account, secrets: secrets)
                    withAnimation { isEditing = true }
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func summary(_ account: Account) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Security & Credentials
                VStack(alignment: .leading, spacing: 10) {
                    Label("安全凭据", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    CredentialCardView(
                        title: "自动登录链接",
                        value: secrets.loginLink,
                        icon: "link",
                        isLink: true
                    )

                    CredentialCardView(
                        title: "Session Key",
                        value: secrets.sessionKey,
                        icon: "key.fill",
                        isLink: false
                    )
                }

                Divider()

                // Section 2: Timeline & Dates
                VStack(alignment: .leading, spacing: 10) {
                    Label("时间记录", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    VStack(spacing: 8) {
                        timelineRow(title: "注册时间", value: AppFormatters.display(account.registeredAt), icon: "calendar", highlight: true)
                        timelineRow(title: "最后使用", value: AppFormatters.display(account.lastUsed), icon: "clock", highlight: false)
                        timelineRow(title: "创建 / 导入", value: AppFormatters.display(account.createdAt), icon: "tray.and.arrow.down", highlight: false)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                }

                Divider()

                // Section 3: Tags
                VStack(alignment: .leading, spacing: 10) {
                    Label("标签", systemImage: "tag.fill")
                        .font(.headline)

                    if account.tags.isEmpty {
                        Text("未添加标签")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(account.tags, id: \.self) { TagView(text: $0) }
                        }
                    }
                }

                Divider()

                // Section 4: Notes
                VStack(alignment: .leading, spacing: 10) {
                    Label("备注", systemImage: "note.text")
                        .font(.headline)

                    Text(account.note.isEmpty ? "暂无备注" : account.note)
                        .font(.body)
                        .foregroundStyle(account.note.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                }

                // Section 5: Quick Action Bar
                HStack(spacing: 12) {
                    Button {
                        store.markCurrent(account)
                    } label: {
                        Label(account.isCurrent ? "刷新最后使用时间" : "设为当前使用中", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)

                    if let url = URL(string: secrets.loginLink), url.scheme != nil {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("在浏览器中打开", systemImage: "arrow.up.forward.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func timelineRow(title: String, value: String, icon: String, highlight: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(highlight ? Color.teal : Color.secondary)
                .frame(width: 18)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(highlight ? .medium : .regular))
                .monospacedDigit()
        }
    }

    private func load(_ account: Account) {
        do {
            secrets = try store.secrets(for: account.id)
            draft = AccountDraft(account: account, secrets: secrets)
        } catch {
            store.errorMessage = error.localizedDescription
            secrets = AccountSecrets()
            draft = AccountDraft(account: account, secrets: secrets)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

