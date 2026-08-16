import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import os

/// 菜单栏图标扫描器
///
/// 通过 Accessibility API 遍历运行中的应用，读取其 `AXExtrasMenuBar` 下的状态栏图标。
/// 扫描在后台线程执行，结果回主线程更新。
final class MenuBarScanner {
    private var timer: Timer?
    private weak var statusItemManager: StatusItemManager?
    /// 防止扫描重叠：上一次扫描未完成时跳过本次
    private var isScanning = false

    private let logger = Logger(subsystem: AppConstants.lingLongBarBundleID, category: "scanner")

    init(statusItemManager: StatusItemManager) {
        self.statusItemManager = statusItemManager
    }

    // MARK: - 扫描生命周期

    func startScanning() {
        guard timer == nil else { return }
        // 使用 .common mode，避免 popover 滚动或 modal 显示时定时器被暂停
        let timer = Timer(timeInterval: AppConstants.scanInterval, repeats: true) { [weak self] _ in
            self?.scanMenuBarItems()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // 立即触发一次
        scanMenuBarItems()
    }

    func stopScanning() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 扫描入口

    private func scanMenuBarItems() {
        // 互斥：上一次扫描未完成时跳过，避免重叠扫描导致 CPU 飙升
        guard !isScanning else { return }
        isScanning = true

        // AX 调用是同步阻塞的，放到后台线程执行
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let items = self.scanStatusBarItemsViaAccessibility()
            DispatchQueue.main.async {
                self.isScanning = false
                self.statusItemManager?.updateItems(items)
            }
        }
    }

    // MARK: - Accessibility 扫描核心

    private func scanStatusBarItemsViaAccessibility() -> [StatusItemInfo] {
        var items: [StatusItemInfo] = []

        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        var scannedApps: [String] = []

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // 跳过 LingLongBar 自身：避免将自己的状态项加入扫描结果后又过滤，
            // 这个过程可能触发 macOS 状态栏重绘，导致 LingLongBar 图标闪烁
            if bundleID == AppConstants.lingLongBarBundleID {
                continue
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var extrasBar: AnyObject?
            let barResult = AXUIElementCopyAttributeValue(
                appElement,
                "AXExtrasMenuBar" as CFString,
                &extrasBar
            )

            guard barResult == .success, let extrasBar = extrasBar else {
                // 大部分应用没有状态栏图标，这是正常情况，不记日志
                continue
            }

            // AXExtrasMenuBar 通常直接返回图标本身，而不是包含图标的容器。
            // 只有返回值确实是 AXMenuBar 时，才需要继续读取 AXChildren。
            let extrasBarElement = extrasBar as! AXUIElement
            let menuBarItems = menuBarExtraElements(from: extrasBarElement)

            guard !menuBarItems.isEmpty else {
                logger.warning("AXExtrasMenuBar 没有可用图标 bundleID=\(bundleID, privacy: .public)")
                continue
            }

            for child in menuBarItems {
                guard let item = buildStatusItem(from: child, app: app, bundleID: bundleID) else { continue }
                items.append(item)
                scannedApps.append("\(bundleID) [w=\(item.frame.width), x=\(item.frame.minX)]")
            }
        }

        // 从右到左排序（macOS 菜单栏右侧图标的实际顺序）
        items.sort { $0.frame.maxX > $1.frame.maxX }

        logger.info("🔍 [Scan] 扫描到 \(items.count, privacy: .public) 个状态栏图标:")
        for app in scannedApps {
            logger.info("   - \(app, privacy: .public)")
        }

        return items
    }

    /// 将 AXExtrasMenuBar 转换为一个或多个图标元素。
    ///
    /// Apple 的 accessibilityExtrasMenuBar 属性返回应用菜单栏中的图标本身；
    /// 某些实现可能返回 AXMenuBar 容器，因此保留对 AXChildren 的兼容处理。
    private func menuBarExtraElements(from extrasBar: AXUIElement) -> [AXUIElement] {
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(
            extrasBar,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        guard roleValue as? String == "AXMenuBar" else {
            return [extrasBar]
        }

        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            extrasBar,
            kAXChildrenAttribute as CFString,
            &childrenValue
        )

        guard result == .success,
              let children = childrenValue as? [AXUIElement] else {
            return []
        }
        return children
    }

    /// 将单个 AX 子元素组装成 StatusItemInfo
    private func buildStatusItem(
        from child: AXUIElement,
        app: NSRunningApplication,
        bundleID: String
    ) -> StatusItemInfo? {
        let frame = getAXFrame(child)

        // 控制中心的无位置占位符跳过（不是真正的图标）
        if bundleID == AppConstants.controlCenterBundleID && frame.width == 0 {
            return nil
        }

        let title = readTitle(from: child, app: app, bundleID: bundleID)
        let identifier = readIdentifier(from: child, bundleID: bundleID, pid: app.processIdentifier)
        let id = makeStableUUID(from: identifier)

        return StatusItemInfo(
            id: id,
            title: title,
            bundleIdentifier: bundleID,
            icon: app.icon,
            frame: frame,
            isSystemItem: bundleID.hasPrefix(AppConstants.appleBundlePrefix),
            isCollapsed: false,
            axElement: child,
            pid: app.processIdentifier
        )
    }

    /// 读取图标标题：优先 description，其次应用名，最后用 bundleID
    private func readTitle(from child: AXUIElement, app: NSRunningApplication, bundleID: String) -> String {
        var description: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &description)

        if let desc = description as? String, !desc.isEmpty {
            return desc
        }
        return app.localizedName ?? bundleID
    }

    /// 读取图标 Accessibility Identifier
    private func readIdentifier(from child: AXUIElement, bundleID: String, pid: pid_t) -> String {
        var identifier: AnyObject?
        AXUIElementCopyAttributeValue(child, kAXIdentifierAttribute as CFString, &identifier)

        if let idStr = identifier as? String, !idStr.isEmpty {
            return "\(bundleID)::\(idStr)"
        }
        return "\(bundleID)::pid\(pid)"
    }

    /// 基于 bundleID + identifier 生成确定性 UUID，保证同一图标多次扫描 id 稳定
    private func makeStableUUID(from seed: String) -> UUID {
        // 直接尝试当作 UUID 字符串解析（极少匹配，但兼容旧逻辑）
        if let uuid = UUID(uuidString: seed) {
            return uuid
        }
        // 用 SHA-256 摘要前 16 字节作为 UUID v5 风格的确定性 ID
        // 这里采用简单的 FNV-1a hash 即可，确定性 UUID 的版本号不影响功能
        var hash: UInt64 = 0xcbf29ce484222325
        let fnvPrime: UInt64 = 0x100000001b3
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* fnvPrime
        }
        // 拆成 16 字节填充 UUID
        let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) } + Array(repeating: UInt8(0), count: 8)
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            uuidBytes[i] = bytes[i % bytes.count]
        }
        // 标记为 v4 风格（不影响功能，仅形式合规）
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
        let uuid = uuid_t(
            uuidBytes[0],  uuidBytes[1],  uuidBytes[2],  uuidBytes[3],
            uuidBytes[4],  uuidBytes[5],  uuidBytes[6],  uuidBytes[7],
            uuidBytes[8],  uuidBytes[9],  uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        )
        return UUID(uuid: uuid)
    }

    /// 读取 AX 元素的 frame（使用 CGRect 类型严谨化）
    private func getAXFrame(_ element: AXUIElement) -> NSRect {
        var frameValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &frameValue)

        guard result == .success, let fv = frameValue else { return .zero }

        guard CFGetTypeID(fv) == AXValueGetTypeID() else {
            return .zero
        }
        let axValue = fv as! AXValue
        var cgRect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &cgRect) else { return .zero }
        return NSRect(origin: cgRect.origin, size: cgRect.size)
    }

    // MARK: - 位置查询与交互

    func getStatusItemPosition(for bundleIdentifier: String) -> NSPoint? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            guard app.bundleIdentifier == bundleIdentifier else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var extrasBar: AnyObject?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                "AXExtrasMenuBar" as CFString,
                &extrasBar
            )

            guard result == .success, let extrasBar = extrasBar else { continue }

            let extrasBarElement = extrasBar as! AXUIElement
            guard let first = menuBarExtraElements(from: extrasBarElement).first else { continue }

            let frame = getAXFrame(first)
            guard frame.width > 0 else { continue }

            return NSPoint(x: frame.midX, y: frame.midY)
        }

        return nil
    }

    func getPositionForItem(_ item: StatusItemInfo) -> NSPoint? {
        if let element = item.axElement {
            let frame = getAXFrame(element)
            guard frame.width > 0 else { return nil }
            return NSPoint(x: frame.midX, y: frame.midY)
        }

        return getStatusItemPosition(for: item.bundleIdentifier)
    }

    /// 执行点击动作：实时查找 AX element 并调用 PressAction，不依赖缓存
    ///
    /// 缓存的 axElement 可能失效（尤其是被刘海遮挡的图标），
    /// 因此每次点击都重新查找，确保 element 是 fresh 的。
    func performAction(on item: StatusItemInfo) {
        logger.info("🎯 [Action] 开始执行点击: \(item.title, privacy: .public) bundleID=\(item.bundleIdentifier, privacy: .public)")

        let workspace = NSWorkspace.shared
        let targetApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier })

        // 方案 1：实时查找 AX element 并调用 PressAction
        if let freshElement = findStatusItemElement(for: item.bundleIdentifier) {
            let result = AXUIElementPerformAction(freshElement, kAXPressAction as CFString)
            logger.info("🎯 [Action] 方案1(实时AX Press) 结果: \(result.rawValue, privacy: .public)")
            if result == .success {
                logger.info("🎯 [Action] ✅ 方案1 成功")
                // 检查应用是否激活，若未激活则强制显示窗口
                if let app = targetApp, !app.isActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.ensureAppWindowVisible(app: app)
                    }
                }
                return
            }
        } else {
            logger.warning("🎯 [Action] 方案1 失败：找不到 fresh AX element")
        }

        // 方案 2：用缓存的 axElement 再试一次
        if let element = item.axElement {
            let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
            logger.info("🎯 [Action] 方案2(缓存AX Press) 结果: \(result.rawValue, privacy: .public)")
            if result == .success {
                logger.info("🎯 [Action] ✅ 方案2 成功")
                if let app = targetApp, !app.isActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.ensureAppWindowVisible(app: app)
                    }
                }
                return
            }
        }

        // 方案 3：模拟鼠标点击坐标
        if let position = getPositionForItem(item) {
            logger.info("🎯 [Action] 方案3(模拟点击坐标): \(position.x, privacy: .public), \(position.y, privacy: .public)")
            clickStatusItem(at: position)
            // 模拟点击后检查窗口状态
            if let app = targetApp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.ensureAppWindowVisible(app: app)
                }
            }
            return
        }

        // 方案 4：直接打开/显示应用窗口
        logger.warning("🎯 [Action] 以上方案均失败，尝试直接打开应用")
        if let app = targetApp {
            ensureAppWindowVisible(app: app)
        } else if let appURL = workspace.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            workspace.openApplication(at: appURL, configuration: config)
        }
    }

    /// 确保应用窗口可见：激活应用并尝试显示窗口
    private func ensureAppWindowVisible(app: NSRunningApplication) {
        logger.info("🎯 [Action] ensureAppWindowVisible: \(app.bundleIdentifier ?? "", privacy: .public)")
        
        // 先激活应用
        app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        logger.info("🎯 [Action] 已激活应用并尝试显示所有窗口")
        
        // 直接尝试通过 AppleScript 强制显示窗口（更可靠）
        showAppWindowViaAppleScript(bundleID: app.bundleIdentifier ?? "")
    }

    /// 通过 AppleScript 强制显示应用窗口
    private func showAppWindowViaAppleScript(bundleID: String) {
        guard !bundleID.isEmpty else { return }
        
        let script = """
        tell application id "\(bundleID)"
            activate
            if it is running then
                try
                    set visible of every window to true
                end try
                try
                    reopen
                end try
            end if
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            logger.error("🎯 [Action] AppleScript 执行失败: \(error.debugDescription, privacy: .public)")
        } else {
            logger.info("🎯 [Action] ✅ AppleScript 执行成功")
        }
    }

    /// 实时查找指定 bundleID 的状态栏图标 AX element
    private func findStatusItemElement(for bundleID: String) -> AXUIElement? {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            guard app.bundleIdentifier == bundleID else { continue }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var extrasBar: AnyObject?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                "AXExtrasMenuBar" as CFString,
                &extrasBar
            )

            guard result == .success, let extrasBar = extrasBar else { continue }

            let extrasBarElement = extrasBar as! AXUIElement
            let menuBarItems = menuBarExtraElements(from: extrasBarElement)
            guard !menuBarItems.isEmpty else { continue }

            // 返回第一个有效子元素（大多数状态栏 app 只有一个图标）
            return menuBarItems.first
        }

        return nil
    }

    private func clickStatusItem(at point: NSPoint) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)

        let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        upEvent?.post(tap: .cghidEventTap)
    }
}
