import SwiftUI
import AppKit
import os

private let clickLogger = Logger(subsystem: AppConstants.lingLongBarBundleID, category: "click")

struct CollapsedMenuView: View {
    @ObservedObject var statusItemManager: StatusItemManager
    let menuBarScanner: MenuBarScanner

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(statusText)
                    .font(.headline.weight(.semibold))

                Spacer()

                settingsButton
            }
            .padding(.horizontal, 4)

            if statusItemManager.collapsedItems.isEmpty {
                emptyState
            } else {
                iconsList
            }
        }
        .padding(16)
        .frame(width: 340, height: 400)
        .modifier(LiquidGlassSurface())
    }

    private var statusText: String {
        "\(statusItemManager.collapsedItems.count) 个图标已收纳"
    }

    private var iconsList: some View {
        ScrollView {
            LiquidGlassContainer(spacing: 8) {
                LazyVStack(spacing: 8) {
                    ForEach(statusItemManager.collapsedItems) { item in
                        StatusItemRowView(
                            item: item,
                            menuBarScanner: menuBarScanner
                        )
                    }
                }
                .padding(2)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        Text("暂无收纳图标")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .modifier(LiquidGlassButtonSurface())
        .help("设置")
    }
}

struct StatusItemRowView: View {
    let item: StatusItemInfo
    let menuBarScanner: MenuBarScanner
    @State private var isHovering = false

    var body: some View {
        Button(action: handleClick) {
            HStack(spacing: 12) {
                iconContent
                    .frame(width: 30, height: 30)

                Text(item.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .modifier(LiquidGlassRowSurface(isHighlighted: isHovering))
        .onHover { isHovering = $0 }
        .help(item.title)
        .contextMenu {
            contextMenuItems
        }
    }

    private var iconContent: some View {
        Group {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var contextMenuItems: some View {
        Group {
            Button("打开应用") {
                handleClick()
            }

            Button("在 Finder 中显示") {
                showInFinder()
            }

            Divider()

            Button("退出 \(item.title)") {
                quitApp()
            }
        }
    }

    /// 点击：触发 app 状态栏图标的主操作
    ///
    /// 委托给 menuBarScanner.performAction，该方法有多层回退机制。
    private func handleClick() {
        clickLogger.info("🔍 [Click] item=\(self.item.title, privacy: .public) bundleID=\(self.item.bundleIdentifier, privacy: .public)")
        menuBarScanner.performAction(on: item)
    }

    private func showInFinder() {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: item.bundleIdentifier) {
            workspace.activateFileViewerSelecting([appURL])
        }
    }

    private func quitApp() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications.filter { $0.bundleIdentifier == item.bundleIdentifier }
        for app in runningApps {
            app.terminate()
        }
    }
}

private struct LiquidGlassSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            content
                .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

private struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

private struct LiquidGlassRowSurface: ViewModifier {
    let isHighlighted: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(isHighlighted ? 0.1 : 0.045))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct LiquidGlassButtonSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(Circle().fill(Color.primary.opacity(0.06)))
                .clipShape(Circle())
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
