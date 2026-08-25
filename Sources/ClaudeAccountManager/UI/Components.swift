import AppKit
import SwiftUI

struct StatusBadge: View {
    let status: AccountStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .font(.system(size: compact ? 9 : 10, weight: .bold))
            Text(status.title)
                .font(.system(size: compact ? 10 : 11, weight: .medium))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(status.color.opacity(0.24), lineWidth: 0.8)
        )
        .accessibilityLabel("状态：\(status.title)")
    }
}

struct ActiveBadge: View {
    var text: String = "当前使用中"

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.teal)
                .frame(width: 6, height: 6)
                .shadow(color: .teal.opacity(0.8), radius: 3)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.teal)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.teal.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.teal.opacity(0.25), lineWidth: 0.8)
        )
    }
}

struct AccountAvatarView: View {
    let email: String
    var size: CGFloat = 32

    private var initial: String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "C" }
        return String(first).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.teal, .indigo, .blue, .purple, .cyan, .mint, .orange]
        let hash = abs(email.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)
                .frame(width: size, height: size)
                .shadow(color: avatarColor.opacity(0.25), radius: 3, y: 1)
            
            Text(initial)
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

struct TagView: View {
    let text: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 3) {
                Text("#")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? Color.teal : Color.secondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.teal : Color.primary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? Color.teal.opacity(0.15) : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.teal.opacity(0.35) : Color.secondary.opacity(0.18), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct SecretPresenceRow: View {
    let title: String
    let value: String
    @State private var copied = false

    var body: some View {
        HStack {
            Label(title, systemImage: value.isEmpty ? "key.slash" : "key.fill")
                .foregroundStyle(value.isEmpty ? Color.secondary : Color.primary)
            Spacer()
            Text(value.isEmpty ? "未保存" : "已安全保存")
                .font(.caption)
                .foregroundStyle(value.isEmpty ? Color.secondary : Color.green)
            if !value.isEmpty {
                Button {
                    copyToClipboard(value)
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(copied ? "已复制" : "复制\(title)")
                .accessibilityLabel(copied ? "已复制\(title)" : "复制\(title)")
            }
        }
    }

    private func copyToClipboard(_ str: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if NSPasteboard.general.string(forType: .string) == str {
                NSPasteboard.general.clearContents()
            }
        }
    }
}

struct CredentialCardView: View {
    let title: String
    let value: String
    let icon: String
    var isLink: Bool = false
    @State private var revealed: Bool = false
    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(value.isEmpty ? .secondary : Color.teal)
                    .frame(width: 18)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if value.isEmpty {
                    Text("未配置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                        Text("钥匙串安全存储")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if !value.isEmpty {
                HStack(spacing: 8) {
                    Group {
                        if revealed {
                            Text(value)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .textSelection(.enabled)
                        } else {
                            Text(maskedText(value))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15), lineWidth: 1))

                    Button {
                        revealed.toggle()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help(revealed ? "隐藏明文" : "查看明文")

                    Button {
                        copyToClipboard(value)
                    } label: {
                        Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(copied ? .green : .teal)

                    if isLink, let url = URL(string: value), url.scheme != nil {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("打开登录", systemImage: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .help("在默认浏览器中打开登录链接")
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    private func maskedText(_ str: String) -> String {
        if str.count <= 12 {
            return String(repeating: "•", count: max(str.count, 8))
        }
        let prefix = str.prefix(6)
        let suffix = str.suffix(4)
        return "\(prefix)••••••••••••\(suffix)"
    }

    private func copyToClipboard(_ str: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(str, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if NSPasteboard.general.string(forType: .string) == str {
                NSPasteboard.general.clearContents()
            }
        }
    }
}

struct SidebarStatCard: View {
    let totalCount: Int
    let activeEmail: String?
    let normalCount: Int
    let restrictedCount: Int
    let invalidCount: Int
    let pendingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("状态概览")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totalCount) 个账号")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }

            // Proportion bar
            if totalCount > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if normalCount > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(width: max(4, geo.size.width * CGFloat(normalCount) / CGFloat(totalCount)))
                        }
                        if restrictedCount > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.orange)
                                .frame(width: max(4, geo.size.width * CGFloat(restrictedCount) / CGFloat(totalCount)))
                        }
                        if invalidCount > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: max(4, geo.size.width * CGFloat(invalidCount) / CGFloat(totalCount)))
                        }
                        if pendingCount > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: max(4, geo.size.width * CGFloat(pendingCount) / CGFloat(totalCount)))
                        }
                    }
                }
                .frame(height: 5)
                .clipShape(Capsule())
            }

            if let activeEmail {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.teal)
                        .frame(width: 5, height: 5)
                    Text("当前：\(activeEmail)")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }
}

