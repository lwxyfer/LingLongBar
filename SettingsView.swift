import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var preferences = AppPreferences.shared

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            appearanceSettings
                .tabItem {
                    Label("外观", systemImage: "paintpalette")
                }

            aboutSettings
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - 通用

    private var generalSettings: some View {
        Form {
            Section {
                Toggle("自动收纳超出的菜单栏图标", isOn: $preferences.autoCollapse)
                    .toggleStyle(.switch)

                if preferences.autoCollapse {
                    HStack {
                        Text("收纳阈值")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(preferences.collapseThreshold) 个")
                            .foregroundColor(.accentColor)
                            .monospacedDigit()
                            .frame(minWidth: 48, alignment: .trailing)
                        Stepper(
                            value: $preferences.collapseThreshold,
                            in: 1...AppConstants.maxCollapseThreshold
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                        .disabled(!preferences.autoCollapse)
                    }
                }
            } header: {
                Text("自动收纳")
            } footer: {
                Text("当菜单栏图标数量超过阈值或被刘海遮挡时，自动收纳到 LingLongBar 中。")
                    .font(.caption2)
            }

            Section {
                Toggle("开机自动启动", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.switch)
            } header: {
                Text("启动")
            } footer: {
                Text("开启后系统设置中的「登录项」会显示 LingLongBar，可在系统设置中关闭。")
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 外观

    private var appearanceSettings: some View {
        Form {
            Section {
                Toggle("显示收纳数量", isOn: $preferences.showIconCount)
                    .toggleStyle(.switch)

                if preferences.showIconCount {
                    Text("在菜单栏 LingLongBar 图标旁显示已收纳的图标数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("菜单栏图标")
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("调整图标位置")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("按住 ⌘ 键，将 LingLongBar 图标拖拽到菜单栏最右侧（靠近电池、WiFi 图标），避免被系统自动隐藏。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Text("图标位置")
            } footer: {
                Text("macOS 会从最左侧开始隐藏状态栏图标，将 LingLongBar 放在最右侧可确保始终可见。")
                    .font(.caption2)
            }

            Section {
                HStack(spacing: 12) {
                    settingsIconPreview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LingLongBar 菜单栏图标预览")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("收纳数量: \(preferences.showIconCount ? "显示" : "隐藏")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } header: {
                Text("预览")
            } footer: {
                Text("菜单栏图标外观跟随系统深浅色模式自动切换。")
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var settingsIconPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 44, height: 24)

            HStack(spacing: 2) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                if preferences.showIconCount {
                    Text("3")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - 关于

    private var aboutSettings: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 32, weight: .semibold))
            }

            Text("LingLongBar")
                .font(.title2)
                .fontWeight(.bold)

            Text("版本 \(appVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("解决 macOS 刘海屏菜单栏图标隐藏问题")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("© 2026 LingLongBar")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    /// 从 Bundle 读取真实版本号，避免硬编码
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
