import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        List(selection: selection) {
            Section("账号") {
                sidebarRow(.all, title: "全部账号", symbol: "person.2.fill", color: .accentColor)
                sidebarRow(.current, title: "当前使用中", symbol: "location.fill", color: .teal)
            }

            Section("状态分类") {
                ForEach(AccountStatus.allCases) { status in
                    sidebarRow(.status(status), title: status.title, symbol: status.symbol, color: status.color)
                }
            }

            if !store.allTags.isEmpty {
                Section("标签") {
                    ForEach(store.allTags, id: \.self) { tag in
                        sidebarRow(.tag(tag), title: tag, symbol: "tag.fill", color: .secondary)
                    }
                }
            }

            Section("概览") {
                let counts = store.statusCounts
                SidebarStatCard(
                    totalCount: store.accounts.count,
                    activeEmail: store.currentAccount?.email,
                    normalCount: counts.normal,
                    restrictedCount: counts.restricted,
                    invalidCount: counts.invalid,
                    pendingCount: counts.pending
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Claude 账号")
    }

    @ViewBuilder
    private func sidebarRow(
        _ scope: SidebarScope,
        title: String,
        symbol: String,
        color: Color = .secondary
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
            Spacer()
            Text(store.count(for: scope).formatted())
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                )
        }
        .tag(scope)
        .accessibilityLabel("\(title)，\(store.count(for: scope)) 个账号")
    }

    private var selection: Binding<SidebarScope?> {
        Binding(
            get: { store.selectedScope },
            set: { if let scope = $0 { store.selectedScope = scope } }
        )
    }
}

