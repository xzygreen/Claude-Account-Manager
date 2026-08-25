import AppKit
import SwiftUI

/// Owns the AppKit lifecycle behavior that SwiftUI's `WindowGroup` does not
/// provide after windows have been closed or when reopened from the Dock / status bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("ClaudeAccountManager.main-window")
    private(set) static var shared: AppDelegate?
    
    weak var mainWindow: NSWindow?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Single-workspace app: disable automatic window tabbing
        NSWindow.allowsAutomaticWindowTabbing = false
        setupAppIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupAppIcon()
    }

    private func setupAppIcon() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        } else if let iconURL = Bundle.main.url(forResource: "AppIcon_1024", withExtension: "png"),
                  let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
        if !hasVisibleWindow {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
        window.identifier = Self.mainWindowIdentifier
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        MainWindowCloseDelegate.shared.install(on: window)
    }

    func showMainWindow() {
        // Robust activation on macOS 14 & 15
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)

        let target = mainWindow ?? NSApp.windows.first {
            $0.identifier == Self.mainWindowIdentifier
        } ?? NSApp.windows.first {
            !($0 is NSPanel) && $0.canBecomeKey
        } ?? NSApp.windows.first {
            !($0 is NSPanel)
        }

        guard let window = target else { return }
        
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: - Dock Menu
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        let showItem = NSMenuItem(title: "显示主窗口", action: #selector(handleDockShowMainWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let addItem = NSMenuItem(title: "添加账号…", action: #selector(handleDockAddAccount), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)
        
        let importItem = NSMenuItem(title: "批量导入…", action: #selector(handleDockImportAccounts), keyEquivalent: "")
        importItem.target = self
        menu.addItem(importItem)
        
        return menu
    }

    @objc private func handleDockShowMainWindow() {
        showMainWindow()
    }

    @objc private func handleDockAddAccount() {
        showMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .addAccount, object: nil)
        }
    }

    @objc private func handleDockImportAccounts() {
        showMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .importAccounts, object: nil)
        }
    }
}

/// Marks the SwiftUI window as the main app window and keeps the NSWindow
/// instance alive when the user closes it. This lets the Dock reopen callback
/// order the same window front without creating duplicate stores or windows.
struct MainWindowLifecycleBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MainWindowMarkerView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class MainWindowMarkerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        AppDelegate.shared?.registerMainWindow(window)
        window.identifier = AppDelegate.mainWindowIdentifier
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        MainWindowCloseDelegate.shared.install(on: window)
    }
}

/// For a single-window app, the standard close action hides the workspace window instead.
private final class MainWindowCloseDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowCloseDelegate()

    private weak var swiftUIDelegate: NSWindowDelegate?

    func install(on window: NSWindow) {
        guard window.delegate !== self else { return }
        swiftUIDelegate = window.delegate
        window.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (swiftUIDelegate?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if swiftUIDelegate?.responds(to: selector) == true {
            return swiftUIDelegate
        }
        return super.forwardingTarget(for: selector)
    }
}

