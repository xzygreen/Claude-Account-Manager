import SwiftUI

@main
struct ClaudeAccountManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AccountStore

    init() {
        _store = StateObject(wrappedValue: AccountStore.live())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 620)
                .tint(.teal)
                .background(MainWindowLifecycleBridge().frame(width: 0, height: 0))
        }
        .defaultSize(width: 1320, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加账号…") {
                    appDelegate.showMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        NotificationCenter.default.post(name: .addAccount, object: nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!store.isAvailable)

                Button("批量导入…") {
                    appDelegate.showMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        NotificationCenter.default.post(name: .importAccounts, object: nil)
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(!store.isAvailable)
            }

            CommandGroup(after: .saveItem) {
                Button("导出当前结果…") {
                    appDelegate.showMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        NotificationCenter.default.post(name: .exportAccounts, object: nil)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.filteredAccounts.isEmpty || !store.isAvailable)
            }

            CommandGroup(replacing: .windowArrangement) {
                Button("显示主窗口") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            SidebarCommands()
        }

        MenuBarExtra("Claude 账号管理", systemImage: "sparkles") {
            MenuBarContentView(store: store, appDelegate: appDelegate)
        }
    }
}

struct MenuBarContentView: View {
    @ObservedObject var store: AccountStore
    let appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading) {
            Text("Claude 账号台账")
                .font(.headline)

            Text("共 \(store.accounts.count) 个账号")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if let current = store.currentAccount {
                Text("当前使用中：\(current.email)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)

                Button("复制当前邮箱") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(current.email, forType: .string)
                }

                if let secrets = try? store.secrets(for: current.id) {
                    if !secrets.loginLink.isEmpty {
                        Button("复制自动登录链接") {
                            SecretClipboard.copy(secrets.loginLink)
                        }

                        if LoginLink.isSafe(secrets.loginLink), let url = URL(string: secrets.loginLink) {
                            Button("在浏览器中打开登录") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    if !secrets.sessionKey.isEmpty {
                        Button("复制 Session Key") {
                            SecretClipboard.copy(secrets.sessionKey)
                        }
                    }
                }
            } else {
                Text("尚未选择当前使用账号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !store.accounts.isEmpty {
                Menu("切换当前账号") {
                    ForEach(store.accounts) { account in
                        Button {
                            store.markCurrent(account)
                        } label: {
                            HStack {
                                if account.isCurrent {
                                    Text("✓ " + account.email)
                                } else {
                                    Text(account.email)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            Button("打开 Claude.ai 官网") {
                if let url = URL(string: "https://claude.ai") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("显示主窗口") {
                appDelegate.showMainWindow()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("添加账号…") {
                appDelegate.showMainWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    NotificationCenter.default.post(name: .addAccount, object: nil)
                }
            }
            .disabled(!store.isAvailable)

            Button("批量导入…") {
                appDelegate.showMainWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    NotificationCenter.default.post(name: .importAccounts, object: nil)
                }
            }
            .disabled(!store.isAvailable)

            Divider()

            Button("退出 Claude 账号管理") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let addAccount = Notification.Name("ClaudeAccountManager.addAccount")
    static let importAccounts = Notification.Name("ClaudeAccountManager.importAccounts")
    static let exportAccounts = Notification.Name("ClaudeAccountManager.exportAccounts")
    static let confirmDeleteAccount = Notification.Name("ClaudeAccountManager.confirmDeleteAccount")
}

