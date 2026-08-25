import SwiftUI

struct AddAccountSheet: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AccountDraft()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.teal.gradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("添加 Claude 账号")
                        .font(.title3.weight(.semibold))
                    Text("敏感信息将加密保存至 macOS 钥匙串，元数据存入本地。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()
            AccountEditorForm(draft: $draft)
            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("添加账号") {
                    if store.save(draft) { dismiss() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 560, idealWidth: 640, maxWidth: 720, minHeight: 540, idealHeight: 650, maxHeight: 740)
    }
}

