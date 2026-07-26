import AppKit
import SwiftUI
import Combine
import os

/// 应用主代理
///
/// 职责：
/// - 创建 LingLongBar 菜单栏状态项
/// - 管理弹窗与设置窗口
/// - 请求辅助功能权限并轮询权限状态
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var statusItemManager: StatusItemManager!
    private var menuBarScanner: MenuBarScanner!
    private var cancellables = Set<AnyCancellable>()

    private var permissionCheckTimer: Timer?
    private var settingsWindow: NSWindow?

    /// 上次的 badge 数量，用于去重，避免无意义的 button.title 更新触发状态栏重绘
    private var lastBadgeCount: Int = Int.max

    private let logger = Logger(subsystem: AppConstants.lingLongBarBundleID, category: "app")

    // MARK: - App 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemManager = StatusItemManager()
        menuBarScanner = MenuBarScanner(statusItemManager: statusItemManager)

        setupStatusItem()
        setupPopover()
        setupBindings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettings"),
            object: nil
        )

        requestAccessibilityPermissions()

        // 首次启动展示位置引导
        if !AppPreferences.shared.hasShownPositionGuide {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showPositionGuide()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarScanner.stopScanning()
        permissionCheckTimer?.invalidate()

        // 主动从状态栏移除 LingLongBar 图标，避免 Dock 残留
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    /// 关闭最后一个窗口不退出应用（保持菜单栏常驻）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - 状态栏图标

    private func setupStatusItem() {
        // 使用 variableLength 以便显示收纳数量文字（squareLength 只能显示图标）
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "LingLongBar")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - 首次启动位置引导
    //
    // macOS 在菜单栏空间不足时会自动隐藏最左侧（最靠近刘海）的第三方图标。
    // 正确做法：引导用户将 LingLongBar 拖到最右侧（靠近系统图标），从根源上避免被隐藏。
    // 注意：不要做自动检测+弹窗的兜底，因为 modal alert 会阻塞主线程导致应用卡死。

    private func showPositionGuide() {
        let alert = NSAlert()
        alert.messageText = "欢迎使用 LingLongBar"
        alert.informativeText = "为了获得最佳体验，请将 LingLongBar 图标放到菜单栏最右侧：\n\n1. 按住 ⌘ 键\n2. 拖拽 LingLongBar 图标到菜单栏最右侧（靠近电池、WiFi 图标）\n\n这样 LingLongBar 就不会因为菜单栏空间不足而被系统自动隐藏了。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的，我来调整")
        alert.addButton(withTitle: "稍后再说")

        let response = alert.runModal()
        AppPreferences.shared.hasShownPositionGuide = true

        if response == .alertFirstButtonReturn {
            logger.info("用户确认调整 LingLongBar 图标位置")
        }
    }

    // MARK: - 弹窗

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false  // 关闭动画，让弹窗立即出现

        let contentView = CollapsedMenuView(
            statusItemManager: statusItemManager,
            menuBarScanner: menuBarScanner
        )
        popover.contentSize = NSSize(width: 320, height: 280)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    private func setupBindings() {
        statusItemManager.$collapsedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.updateStatusItemBadge(count: items.count)
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemBadge(count: Int) {
        // 去重：count 没变化时不更新 button.title，避免触发状态栏重绘导致图标闪烁
        if count == lastBadgeCount {
            return
        }
        lastBadgeCount = count

        guard let button = statusItem.button else { return }

        if count > 0 && AppPreferences.shared.showIconCount {
            button.title = " \(count)"
        } else {
            button.title = ""
        }
    }

    // MARK: - 菜单栏图标点击

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            showPopover()
            return
        }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "退出 LingLongBar",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - 设置窗口

    @objc private func openSettings() {
        // 已有窗口则复用
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 关闭后引用已置 nil，需要新建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LingLongBar 设置"
        window.titlebarAppearsTransparent = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView())
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func windowWillClose(_ notification: Notification) {
        // 关闭设置窗口时清除引用，下次打开重新创建；不退出应用
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 辅助功能权限

    private func requestAccessibilityPermissions() {
        // 仅触发系统授权弹窗，不再额外弹出应用自己的 Alert
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        let initiallyTrusted = AXIsProcessTrustedWithOptions(options)
        logger.info("🔐 [AX] 初始权限检查: \(initiallyTrusted ? "已授权" : "未授权", privacy: .public)")
        logger.info("🔐 [AX] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)")
        logger.info("🔐 [AX] Bundle Path: \(Bundle.main.bundlePath, privacy: .public)")

        startScanningIfPermitted()
    }

    private func startScanningIfPermitted() {
        let trusted = AXIsProcessTrusted()
        logger.info("🔐 [AX] startScanningIfPermitted: trusted=\(trusted, privacy: .public)")

        if trusted {
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil
            menuBarScanner.startScanning()
            logger.info("辅助功能权限已授权，开始扫描")
        } else {
            menuBarScanner.stopScanning()
            // 先 invalidate 旧 timer，再创建新 timer，避免 timer 泄漏导致指数级增长
            permissionCheckTimer?.invalidate()
            permissionCheckTimer = nil

            // 使用 .common mode，避免 popover 显示时定时器被暂停
            let timer = Timer(timeInterval: AppConstants.permissionCheckInterval, repeats: true) { [weak self] _ in
                self?.startScanningIfPermitted()
            }
            RunLoop.main.add(timer, forMode: .common)
            permissionCheckTimer = timer
        }
    }
}
