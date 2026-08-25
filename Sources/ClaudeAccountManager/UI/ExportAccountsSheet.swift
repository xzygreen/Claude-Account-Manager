import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ExportAccountsSheet: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var previewText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.teal.gradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("导出 Claude 账号")
                        .font(.title3.weight(.semibold))
                    Text("将导出当前搜索与筛选结果，共 \(store.filteredAccounts.count) 个账号。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("导出格式：")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("mail|邮箱自动登录链接|sessionkey|注册时间")
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))

                        Text("每行一个账号，按竖线 `|` 分隔，可直接用于批量管理、分发或再次批量导入。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                if !previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("导出预览（前 3 条）：")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(previewSample)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("提示：导出内容将包含明文自动登录链接与 Session Key 凭据。请保存到安全受信任的磁盘目录，谨防泄露。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
            }
            .padding(20)

            Divider()

            HStack {
                Button {
                    copyToClipboard()
                } label: {
                    Label(copied ? "已复制到剪贴板" : "复制全部内容", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .tint(copied ? .green : .teal)

                Spacer()

                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("选择保存位置并导出…") { export() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 580)
        .onAppear {
            loadPreview()
        }
    }

    private var previewSample: String {
        let lines = previewText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.prefix(3).joined(separator: "\n")
    }

    private func loadPreview() {
        if let text = try? store.exportText() {
            previewText = text
        }
    }

    private func copyToClipboard() {
        do {
            let text = try store.exportText()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copied = false
            }
        } catch {
            store.errorMessage = "复制失败：\(error.localizedDescription)"
        }
    }

    private func export() {
        do {
            let data = try store.exportAccounts()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue = "claude-accounts-\(AppFormatters.dateOnly.string(from: Date())).txt"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            dismiss()
        } catch {
            store.errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

