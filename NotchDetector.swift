import Foundation
import AppKit

/// 刘海屏与菜单栏可用空间检测
///
/// 支持多显示器：遍历 `NSScreen.screens`，找出含刘海的屏幕（即 `safeAreaInsets.top > 0`）。
/// 若所有屏幕均无刘海，回退到主屏并返回屏幕中线作为左边界（此时菜单栏理论上不会拥挤）。
final class NotchDetector {

    // MARK: - 公共查询

    /// 当前是否检测到刘海屏
    func hasNotch() -> Bool {
        return notchScreen != nil
    }

    /// 菜单栏高度（pt）
    func getMenuBarHeight() -> CGFloat {
        return NSStatusBar.system.thickness
    }

    /// 右侧菜单栏的右边界（屏幕右边缘 X 坐标）
    func getRightEdge() -> CGFloat {
        guard let screen = notchScreen ?? NSScreen.main else { return 1440 }
        return screen.frame.maxX
    }

    /// 右侧菜单栏的左边界（刘海右边缘 X 坐标）
    ///
    /// macOS 菜单栏右侧图标从屏幕右边缘向左排列，左边界即刘海右侧。
    /// 刘海位于屏幕水平中央，半宽约屏幕宽度的 7%。多预留一点空间让 LingLongBar 能主动收纳更多图标。
    func getRightMenuBarLeftBoundary() -> CGFloat {
        guard let screen = notchScreen ?? NSScreen.main else { return 720 }

        if hasNotch() {
            let screenWidth = screen.frame.width
            // 刘海半宽估算为屏幕宽度的 7%，再额外预留 20pt 给 LingLongBar 占位
            let notchHalfWidth = screenWidth * 0.07
            let extraPadding: CGFloat = 20
            return screenWidth / 2 + notchHalfWidth + extraPadding
        } else {
            // 非刘海屏：菜单栏左侧应用菜单与右侧状态项各占一半
            return screen.frame.width / 2
        }
    }

    /// 右侧菜单栏可用宽度 = 右边界 - 左边界
    func getRightMenuBarAvailableWidth() -> CGFloat {
        return getRightEdge() - getRightMenuBarLeftBoundary()
    }

    /// 刘海尺寸（基于 safeAreaInsets）
    func getNotchSize() -> NSSize {
        guard let screen = notchScreen ?? NSScreen.main else { return .zero }
        let insets = screen.safeAreaInsets
        return NSSize(width: insets.left + insets.right, height: insets.top)
    }

    // MARK: - 屏幕选择

    /// 含刘海的屏幕；若全部无刘海返回 nil
    private var notchScreen: NSScreen? {
        return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
    }
}
