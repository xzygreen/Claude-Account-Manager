import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImportAccountsSheet: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var result = ImportParseResult(accounts: [], errors: [])
    @State private var completionMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                inputPane
                    .frame(minWidth: 410)
                previewPane
                    .frame(minWidth: 350)
            }
            Divider()
            footer
        }
        .frame(width: 860, height: 640)
        .onChange(of: input) { _, newValue in
            result = AccountImportParser.parse(newValue)
            completionMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.teal.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("批量导入 Claude 账号")
                    .font(.title3.weight(.semibold))
                Text("导入时按邮箱更新已有账号；空白敏感字段不会覆盖钥匙串中的现有值。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openFile()
            } label: {
                Label("从文件打开…", systemImage: "folder")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("输入或粘贴文本").font(.headline)
                Spacer()
                if !input.isEmpty {
                    Button("清空") { input = "" }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("快速插入格式示例：")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button("双横线格式") {
                        appendTemplate("user@example.comhttps://claude.ai/login--example-session-key--2026-08-20")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("竖线管道格式") {
                        appendTemplate("user@example.com | https://claude.ai/login | example-session-key | 2026-08-20 12:00 | 正常 | 主力,工作 | 2026-08-20 13:00 | 备注说明")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("JSON 格式") {
                        appendTemplate("""
                        [
                          {
                            "email": "user@example.com",
                            "login_link": "https://claude.ai/login",
                            "session_key": "example-session-key",
                            "registered_at": "2026-08-20",
                            "status": "normal",
                            "tags": ["主力"]
                          }
                        ]
                        """)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("导入解析预览").font(.headline)
                Spacer()
                Text("\(result.accounts.count) 条有效")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.accounts.isEmpty ? Color.secondary : Color.green)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill((result.accounts.isEmpty ? Color.secondary : Color.green).opacity(0.12)))
            }

            List {
                ForEach(Array(result.accounts.enumerated()), id: \.offset) { _, account in
                    HStack(spacing: 10) {
                        AccountAvatarView(email: account.email, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.email)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                StatusBadge(status: account.status ?? .normal, compact: true)
                                Text(AppFormatters.display(account.registeredAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if !account.tags.isEmpty {
                                    Text(account.tags.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.teal)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                ForEach(Array(result.errors.enumerated()), id: \.offset) { _, error in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
            .overlay {
                if input.isEmpty {
                    ContentUnavailableView("等待输入", systemImage: "doc.text", description: Text("在左侧粘贴账号文本或点击下方格式示例。"))
                }
            }

            if let completionMessage {
                Label(completionMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout.weight(.medium))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.1)))
            }
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            if !result.errors.isEmpty {
                Label("\(result.errors.count) 条格式错误（将自动跳过）", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
            Spacer()
            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("确认导入 \(result.accounts.count) 条") { performImport() }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
                .disabled(result.accounts.isEmpty)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func appendTemplate(_ template: String) {
        if input.isEmpty {
            input = template
        } else {
            input += "\n" + template
        }
    }

    private func performImport() {
        let report = store.importAccounts(result.accounts)
        if report.errors.isEmpty {
            completionMessage = "已成功新增 \(report.created) 个，更新 \(report.updated) 个账号。"
            if result.errors.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
            }
        } else {
            result.errors.append(contentsOf: report.errors)
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            input = try String(contentsOf: url, encoding: .utf8)
        } catch {
            store.errorMessage = "无法读取文件：\(error.localizedDescription)"
        }
    }
}
