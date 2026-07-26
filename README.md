# LingLongBar

> 解决 macOS 刘海屏菜单栏图标被隐藏的问题

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-blue">
  <img alt="language" src="https://img.shields.io/badge/language-Swift-orange">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-green">
</p>

## 📖 项目简介

macOS 自 2021 款 MacBook Pro 引入刘海屏后，菜单栏右侧的图标空间被严重压缩。当应用图标数量较多时，会被刘海遮挡而完全无法看到和点击，严重影响使用体验。

LingLongBar 是一个轻量级的菜单栏辅助工具，能够：

- 🔍 **自动检测**：扫描系统中所有第三方应用在菜单栏的图标
- 📥 **智能收纳**：将被刘海遮挡或超出可视区域的图标自动收纳到 LingLongBar 中
- 🖱️ **一键访问**：点击 LingLongBar 菜单栏图标即可查看和操作所有被收纳的图标
- ⚙️ **可配置**：支持自定义收纳阈值、显示数量、开机启动等参数

## ✨ 功能特性

- **自动收纳**：检测被刘海遮挡的图标并自动收纳
- **点击访问**：收纳后的图标可一键点击恢复原应用
- **右键菜单**：右键 LingLongBar 图标可快速打开设置或退出
- **设置面板**：提供通用、外观、关于三个设置页签
- **开机启动**：通过 `SMAppService` 注册登录项，真正实现开机自启
- **数量显示**：可在菜单栏图标旁显示已收纳图标数量
- **深浅色适配**：跟随系统外观自动切换
- **多显示器支持**：自动识别含刘海的屏幕（遍历 `NSScreen.screens`）
- **性能优化**：AX 扫描在后台线程执行，不阻塞 UI

## 🚀 快速开始

### 环境要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode Command Line Tools
- Swift 5.9+

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/langhen5lin/LingLongBar.git
cd LingLongBar

# 执行构建脚本（自动复制应用图标）
bash build.sh

# 运行应用
open build/LingLongBar.app
```

构建产物位于 `build/LingLongBar.app`。

### 重新生成应用图标

图标使用 Swift 脚本生成（基于 CoreGraphics），如需调整设计：

```bash
# 修改脚本后重新生成
swift scripts/generate_icon.swift Resources/AppIcon.icns

# 然后重新构建应用
bash build.sh
```

### 权限说明

首次启动 LingLongBar 时，需要授予 **辅助功能（Accessibility）** 权限：

1. 系统会自动弹出授权弹窗，点击「打开系统设置」
2. 在「隐私与安全性 → 辅助功能」中开启 LingLongBar 开关
3. 返回 LingLongBar，应用会自动检测权限并开始扫描

> ⚠️ 没有辅助功能权限时，LingLongBar 无法读取其他应用的菜单栏图标信息。

## 🎯 使用方法

### 基本操作

- **点击菜单栏 LingLongBar 图标**：展开收纳面板，查看被隐藏的图标
- **点击收纳的图标**：直接打开对应应用
- **右键菜单栏 LingLongBar 图标**：打开设置或退出应用
- **右键收纳的图标**：打开应用、在 Finder 中显示、取消收纳

### 设置面板

| 选项 | 说明 |
| --- | --- |
| 自动收纳超出的菜单栏图标 | 开启后自动收纳被刘海遮挡的图标 |
| 收纳阈值 | 控制图标数量过多时开始收纳（预留参数） |
| 开机自动启动 | 通过系统登录项跟随系统启动 |
| 显示收纳数量 | 在菜单栏图标旁显示已收纳的数字 |

## 📁 项目结构

```
LingLongBar/
├── LingLongBarApp.swift            # 应用入口（@main）
├── AppConstants.swift        # 全局常量（bundleID、阈值等）
├── AppDelegate.swift         # 应用代理、状态栏图标、弹窗与设置窗口管理
├── StatusItemInfo.swift      # 状态栏图标数据模型
├── MenuBarScanner.swift      # 菜单栏图标扫描核心（基于 Accessibility API）
├── StatusItemManager.swift   # 收纳逻辑管理（判断可见/收纳）
├── NotchDetector.swift       # 刘海屏检测与可用宽度计算（支持多显示器）
├── AppPreferences.swift      # 用户偏好设置（持久化 + 登录项注册）
├── CollapsedMenuView.swift   # 收纳面板 SwiftUI 视图
├── SettingsView.swift        # 设置页面 SwiftUI 视图
├── Info.plist                # 应用配置
├── LingLongBar.entitlements        # 应用沙箱与权限配置
├── Package.swift             # Swift Package Manager 配置
├── build.sh                  # 构建脚本
│
├── Resources/
│   └── AppIcon.icns          # 应用图标（10 个尺寸）
│
└── scripts/
    └── generate_icon.swift   # 图标生成脚本
```

## 🧠 工作原理

### 1. 刘海屏检测

`NotchDetector` 遍历所有屏幕，找出有刘海的（`safeAreaInsets.top > 0`），然后基于屏幕宽度比例估算刘海尺寸，计算右侧菜单栏的可用宽度边界。

### 2. 状态栏图标扫描

`MenuBarScanner` 利用 macOS Accessibility API：

- 遍历 `NSWorkspace` 中的运行应用
- 通过 `AXExtrasMenuBar` 属性获取每个应用的状态栏图标
- 读取图标的 `frame`、`description` 等属性
- 扫描在 **后台线程** 执行，结果回主线程更新
- 使用 **确定性 UUID**（基于 bundleID + identifier 的 FNV-1a 哈希）保证同一图标多次扫描 ID 稳定

### 3. 收纳逻辑

`StatusItemManager` 根据以下规则分类：

- **系统图标**（`com.apple.*`）：始终视为可见，不收纳
- **第三方图标**：
  - `frame.width == 0`：已被 macOS 隐藏，需收纳
  - `frame.minX < lingLongBarRightEdge`：被刘海遮挡，需收纳
  - 其余视为可见

### 4. UI 交互

- 收纳面板使用 `NSPopover` 展示
- 收纳图标使用 SwiftUI `LazyVGrid` 网格布局
- 设置窗口使用 `NSWindow` + `NSHostingView` 嵌入 SwiftUI 视图

### 5. 开机启动

通过 `ServiceManagement.SMAppService.mainApp` 注册/注销登录项，开关状态与系统设置中的「登录项」实时同步。

## 🤝 贡献指南

欢迎提交 Issue 和 PR！

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m 'Add some feature'`
4. 推送分支：`git push origin feature/your-feature`
5. 提交 Pull Request

### 编码规范

- 使用 Swift 5.9+ 特性
- 优先使用 SwiftUI 与 Combine
- 保持文件单一职责
- 注释使用中文，便于国内开发者阅读
- 使用 `os.Logger` 记录日志，避免 `print`

## 📝 开发计划

- [ ] 支持手动拖拽排序收纳图标
- [ ] 支持自定义收纳面板尺寸
- [ ] 支持图标分组管理
- [ ] 国际化（中英文）
- [ ] 菜单栏图标右键可直接退出单个应用
- [x] 支持多显示器
- [x] 开机自动启动（SMAppService）
- [x] 后台线程扫描，UI 无卡顿

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

## 🙏 致谢

- macOS Accessibility API 提供的强大能力
- SwiftUI 与 AppKit 混合开发的可能
- 图标生成脚本灵感来自原生 CoreGraphics 绘制

## ⚠️ 免责声明

LingLongBar 通过 macOS Accessibility API 读取其他应用的菜单栏图标信息，仅在本地使用，不收集任何数据。请确保在使用时遵守所在地区的相关法律法规。
