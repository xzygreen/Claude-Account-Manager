import SwiftUI

struct AccountEditorForm: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var draft: AccountDraft
    @State private var revealLoginLink = false
    @State private var revealSessionKey = false

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("邮箱", text: $draft.email, prompt: Text("name@example.com"))
                        .textContentType(.emailAddress)

                    if !draft.email.isEmpty {
                        Image(systemName: isEmailValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(isEmailValid ? .green : .orange)
                            .font(.caption)
                    }
                }

                Picker("状态", selection: $draft.status) {
                    ForEach(AccountStatus.allCases) { status in
                        Label(status.title, systemImage: status.symbol).tag(status)
                    }
                }

                DatePicker("注册时间", selection: $draft.registeredAt)

                Toggle("设为当前使用中", isOn: $draft.isCurrent)
            } header: {
                Label("账号信息", systemImage: "person.crop.circle")
            }

            Section {
                Toggle("记录最后使用时间", isOn: $draft.hasLastUsed)
                if draft.hasLastUsed {
                    DatePicker("最后使用", selection: $draft.lastUsed)
                }
            } header: {
                Label("使用记录", systemImage: "clock")
            }

            Section {
                secretField(
                    title: "自动登录链接",
                    text: $draft.loginLink,
                    revealed: $revealLoginLink,
                    prompt: "https://claude.ai/…"
                )
                secretField(
                    title: "Session Key",
                    text: $draft.sessionKey,
                    revealed: $revealSessionKey,
                    prompt: "example-session-key"
                )
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                    Text("这些内容存入 macOS 登录钥匙串，不写入 SQLite。")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Label("安全凭据", systemImage: "shield.lefthalf.filled")
            }

            Section {
                TextField("标签", text: $draft.tagsText, prompt: Text("主力, 备用, 工作"))
                
                if !store.allTags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("快捷添加已有标签：")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach(store.allTags, id: \.self) { tag in
                                let isIncluded = draft.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
                                Button {
                                    toggleTag(tag)
                                } label: {
                                    HStack(spacing: 2) {
                                        Text(isIncluded ? "✓" : "+")
                                            .font(.caption2.weight(.bold))
                                        Text(tag)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isIncluded ? Color.teal.opacity(0.18) : Color.secondary.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().strokeBorder(isIncluded ? Color.teal.opacity(0.4) : Color.clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text("使用逗号、分号或换行分隔多个标签。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("备注", text: $draft.note, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Label("整理与分类", systemImage: "tag.fill")
            }
        }
        .formStyle(.grouped)
    }

    private var isEmailValid: Bool {
        draft.email.contains("@") && draft.email.contains(".")
    }

    private func toggleTag(_ tag: String) {
        var currentTags = draft.tags
        if let idx = currentTags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            currentTags.remove(at: idx)
        } else {
            currentTags.append(tag)
        }
        draft.tagsText = currentTags.joined(separator: ", ")
    }

    @ViewBuilder
    private func secretField(
        title: String,
        text: Binding<String>,
        revealed: Binding<Bool>,
        prompt: String
    ) -> some View {
        HStack {
            if revealed.wrappedValue {
                TextField(title, text: text, prompt: Text(prompt))
            } else {
                SecureField(title, text: text, prompt: Text(prompt))
            }
            Button {
                revealed.wrappedValue.toggle()
            } label: {
                Image(systemName: revealed.wrappedValue ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(revealed.wrappedValue ? "隐藏\(title)" : "显示\(title)")
            .accessibilityLabel(revealed.wrappedValue ? "隐藏\(title)" : "显示\(title)")
        }
    }
}
