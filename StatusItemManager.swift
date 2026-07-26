import Foundation
import AppKit
import Combine
import os

/// 状态项管理器
///
/// 维护扫描得到的全部状态项，并依据刘海边界决定哪些图标需要收纳。
/// 所有 @Published 更新都基于 id 集合比较（顺序无关），避免状态栏重排导致反馈循环。
final class StatusItemManager: ObservableObject {
    @Published var allItems: [StatusItemInfo] = []
    @Published var collapsedItems: [StatusItemInfo] = []
    @Published var visibleItems: [StatusItemInfo] = []

    private let notchDetector = NotchDetector()
    private let preferences = AppPreferences.shared
    /// 滞后缓冲区（pt）：图标需要在边界外超出此距离才会切换分类，
    /// 避免图标在边界附近因微小位置波动而在 visible/collapsed 之间反复横跳。
    private static let hysteresisMargin: CGFloat = 12

    private let logger = Logger(subsystem: AppConstants.lingLongBarBundleID, category: "manager")

    /// 扫描结果更新入口
    ///
    /// 核心策略：直接用传入的 items 计算新的分类，然后基于 id 集合比较决定是否更新 @Published。
    /// 不依赖 allItems 的当前值，避免 inout 修改 @Published 触发额外发射。
    func updateItems(_ items: [StatusItemInfo]) {
        // 捕获当前分类状态用于滞后判断
        let prevVisibleIds = Set(visibleItems.map { $0.id })
        let prevCollapsedIds = Set(collapsedItems.map { $0.id })

        guard preferences.autoCollapse else {
            updateWithoutCollapse(items: items)
            return
        }

        let screenLeftBoundary = notchDetector.getRightMenuBarLeftBoundary()

        // 用传入的 items 直接计算新分类
        var newVisible: [StatusItemInfo] = []
        var newCollapsed: [StatusItemInfo] = []

        for item in items {
            if item.isSystemItem {
                newVisible.append(item)
                continue
            }

            // 判断图标是否被隐藏（带滞后区）：
            // - 之前可见的图标：只有远超边界才收纳
            // - 之前已收纳的图标：只有远超边界才释放
            // - 新出现的图标：按边界硬判断
            let wasVisible = prevVisibleIds.contains(item.id)
            let wasCollapsed = prevCollapsedIds.contains(item.id)
            // 1. frame.width == 0 → macOS 明确隐藏了该图标
            // 2. frame.maxX < 屏幕右侧区域左边界 → 整个图标在刘海左侧，完全不可见
            let isHidden: Bool
            if item.frame.width == 0 {
                isHidden = true
            } else {
                let maxX = item.frame.maxX
                if wasCollapsed {
                    isHidden = maxX < screenLeftBoundary + Self.hysteresisMargin
                } else if wasVisible {
                    isHidden = maxX < screenLeftBoundary - Self.hysteresisMargin
                } else {
                    isHidden = maxX < screenLeftBoundary
                }
            }

            if isHidden {
                newCollapsed.append(item)
            } else {
                newVisible.append(item)
            }
        }

        newVisible.sort { $0.frame.maxX > $1.frame.maxX }
        newCollapsed.sort { $0.frame.maxX > $1.frame.maxX }

        // 基于 id 集合比较（顺序无关），决定是否更新 @Published
        let newVisibleIds = Set(newVisible.map { $0.id })
        let oldVisibleIds = Set(visibleItems.map { $0.id })
        let newCollapsedIds = Set(newCollapsed.map { $0.id })
        let oldCollapsedIds = Set(collapsedItems.map { $0.id })

        guard newVisibleIds != oldVisibleIds || newCollapsedIds != oldCollapsedIds else {
            // 分类没变，完全不更新 @Published，避免触发 UI 重绘和反馈循环
            return
        }

        // 调试日志
        let names = newCollapsed.map { $0.title }.joined(separator: ", ")
        logger.debug("收纳变化: \(self.collapsedItems.count) → \(newCollapsed.count), 收纳项: \(names, privacy: .public)")

        allItems = items
        visibleItems = newVisible
        collapsedItems = newCollapsed
    }

    /// autoCollapse 关闭时：所有图标都可见，不收纳
    private func updateWithoutCollapse(items: [StatusItemInfo]) {
        let newIds = Set(items.map { $0.id })
        let oldIds = Set(visibleItems.map { $0.id })

        guard newIds != oldIds || !collapsedItems.isEmpty else { return }

        allItems = items
        visibleItems = items
        collapsedItems = []
    }

    func getCollapsedCount() -> Int {
        return collapsedItems.count
    }

    func moveToCollapsed(item: StatusItemInfo) {
        guard let index = allItems.firstIndex(where: { $0.id == item.id }) else { return }
        allItems[index].isCollapsed = true
        // 重新触发分类（使用 allItems 当前值）
        reclassifyFromAllItems()
    }

    func moveToVisible(item: StatusItemInfo) {
        guard let index = allItems.firstIndex(where: { $0.id == item.id }) else { return }
        allItems[index].isCollapsed = false
        reclassifyFromAllItems()
    }

    /// 手动移动时基于 allItems 重新分类
    private func reclassifyFromAllItems() {
        let items = allItems
        // 复用 updateItems 的逻辑
        updateItems(items)
    }
}
