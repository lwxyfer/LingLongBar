import Foundation
import AppKit
import Combine
import ServiceManagement

/// 用户偏好设置，使用 UserDefaults 持久化
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    @Published var autoCollapse: Bool {
        didSet { UserDefaults.standard.set(autoCollapse, forKey: "autoCollapse") }
    }

    @Published var collapseThreshold: Int {
        didSet { UserDefaults.standard.set(collapseThreshold, forKey: "collapseThreshold") }
    }

    @Published var showIconCount: Bool {
        didSet { UserDefaults.standard.set(showIconCount, forKey: "showIconCount") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    /// 是否已展示过首次启动引导（位置调整提示）
    @Published var hasShownPositionGuide: Bool {
        didSet { UserDefaults.standard.set(hasShownPositionGuide, forKey: "hasShownPositionGuide") }
    }

    private init() {
        let defaults = UserDefaults.standard

        self.autoCollapse = defaults.object(forKey: "autoCollapse") as? Bool ?? true
        self.collapseThreshold = defaults.object(forKey: "collapseThreshold") as? Int ?? AppConstants.defaultCollapseThreshold
        self.showIconCount = defaults.object(forKey: "showIconCount") as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        self.hasShownPositionGuide = defaults.object(forKey: "hasShownPositionGuide") as? Bool ?? false
    }

    /// 通过 SMAppService 注册主应用为开机启动项（macOS 13+）
    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 注册失败时回滚 UI 状态，避免误导用户
            DispatchQueue.main.async {
                self.launchAtLogin = !self.launchAtLogin
            }
            NSLog("开机启动项注册失败: \(error.localizedDescription)")
        }
    }
}
