import Foundation

/// 应用全局常量集中管理
enum AppConstants {
    /// LingLongBar 自身的 Bundle Identifier
    static let lingLongBarBundleID = "com.linglongbar.app"

    /// Apple 系统应用的 Bundle Identifier 前缀
    static let appleBundlePrefix = "com.apple."

    /// 控制中心 Bundle Identifier（特殊处理：跳过其无位置占位符）
    static let controlCenterBundleID = "com.apple.controlcenter"

    /// LingLongBar 在菜单栏中占用的宽度（pt），用于收纳边界计算
    static let lingLongBarItemWidth: CGFloat = 30

    /// 菜单栏扫描间隔（秒）
    /// 过短会频繁触发状态栏重绘，导致图标闪烁；过长则收纳不及时
    static let scanInterval: TimeInterval = 3.0

    /// 权限重试检查间隔（秒）
    static let permissionCheckInterval: TimeInterval = 2.0

    /// LingLongBar 图标可见性监测间隔（秒）
    static let statusItemMonitorInterval: TimeInterval = 1.0

    /// 收纳阈值默认值
    static let defaultCollapseThreshold = 8

    /// 收纳阈值范围上限
    static let maxCollapseThreshold = 20
}
