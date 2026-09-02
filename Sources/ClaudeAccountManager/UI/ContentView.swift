import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AccountStore
    @State private var showAdd = false
    @State private var showImport = false
    @State private var showExport = false
    @State private var showDeleteConfirmation = false
    @State private var pendingDeleteID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } content: {
            AccountTableView()
                .navigationSplitViewColumnWidth(min: 560, ideal: 720)
        } detail: {
            AccountDetailView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 390, max: 520)
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "搜索邮箱、备注或标签")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Label("添加账号", systemImage: "plus")
                }
                .disabled(!store.isAvailable)
                .help("添加账号（⌘N）")

                Button {
                    showImport = true
                } label: {
                    Label("批量导入", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.isAvailable)
                .help("批量导入（⌘I）")

                Button {
                    showExport = true
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .disabled(store.filteredAccounts.isEmpty || !store.isAvailable)
                .help("导出当前筛选结果（⌘E）")

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .disabled(store.selectedAccount == nil)
                .help("删除所选账号")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAccountSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showImport) {
            ImportAccountsSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showExport) {
            ExportAccountsSheet()
                .environmentObject(store)
        }
        .alert("删除账号？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { pendingDeleteID = nil }
            Button("删除", role: .destructive) {
                if let id = pendingDeleteID {
                    store.delete(id: id)
                } else {
                    store.deleteSelected()
                }
                pendingDeleteID = nil
            }
        } message: {
            let email = pendingDeleteID.flatMap { id in store.accounts.first { $0.id == id }?.email }
                ?? store.selectedAccount?.email
            Text("将从本地数据库和钥匙串中删除 \(email ?? "该账号")。此操作无法撤销。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .confirmDeleteAccount)) { notification in
            pendingDeleteID = notification.object as? UUID ?? store.selectedID
            showDeleteConfirmation = true
        }
        .alert("无法完成操作", isPresented: errorBinding) {
            Button("好", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "未知错误")
        }
        .onReceive(NotificationCenter.default.publisher(for: .addAccount)) { _ in showAdd = true }
        .onReceive(NotificationCenter.default.publisher(for: .importAccounts)) { _ in showImport = true }
        .onReceive(NotificationCenter.default.publisher(for: .exportAccounts)) { _ in showExport = true }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}
