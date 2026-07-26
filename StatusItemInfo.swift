import Foundation
import AppKit
import ApplicationServices

/// 单个菜单栏状态项的快照信息
struct StatusItemInfo: Identifiable, Hashable {
    let id: UUID
    let title: String
    let bundleIdentifier: String
    let icon: NSImage?
    var frame: NSRect
    let isSystemItem: Bool
    var isCollapsed: Bool = false
    var axElement: AXUIElement?
    var pid: pid_t = 0

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: Equatable
    // 仅比较 id + isCollapsed，忽略 frame 的微小变化，避免死循环。
    // frame 变化会通过 isCollapsed 变化体现，不需要单独比较。
    // axElement 和 NSImage 不参与比较。

    static func == (lhs: StatusItemInfo, rhs: StatusItemInfo) -> Bool {
        lhs.id == rhs.id
            && lhs.isCollapsed == rhs.isCollapsed
    }
}
