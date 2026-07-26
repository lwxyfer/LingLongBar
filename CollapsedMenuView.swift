import SwiftUI
import AppKit
import os

private let clickLogger = Logger(subsystem: AppConstants.lingLongBarBundleID, category: "click")

struct CollapsedMenuView: View {
    @ObservedObject var statusItemManager: StatusItemManager
    let menuBarScanner: MenuBarScanner
    @State private var isHoveringItem: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            dividerSection
            contentSection
        }
        .padding(12)
        .frame(width: 320)
        .frame(minHeight: 200, maxHeight: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LingLongBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            settingsButton
        }
        .padding(.bottom, 4)
    }
    
    private var statusText: String {
        let count = statusItemManager.collapsedItems.count
        if count == 0 {
            return "所有图标都已显示"
        } else {
            return "\(count) 个图标已收纳"
        }
    }
    
    private var dividerSection: some View {
        Divider()
            .padding(.vertical, 8)
    }
    
    private var contentSection: some View {
        Group {
            if statusItemManager.collapsedItems.isEmpty {
                emptyState
            } else {
                iconsGrid
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 4) {
                Text("所有图标都已显示")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("菜单栏空间充足")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var iconsGrid: some View {
        ScrollView {
            LazyVGrid(columns: Self.gridColumns, spacing: 12) {
                ForEach(statusItemManager.collapsedItems) { item in
                    StatusItemIconView(
                        item: item,
                        menuBarScanner: menuBarScanner,
                        isHovering: isHoveringItem == item.id
                    )
                    .onHover { hovering in
                        isHoveringItem = hovering ? item.id : nil
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private static let gridColumns = [
        GridItem(.adaptive(minimum: 68, maximum: 80), spacing: 10)
    ]
    
    private var settingsButton: some View {
        Button(action: {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .help("设置")
    }
}

struct StatusItemIconView: View {
    let item: StatusItemInfo
    let menuBarScanner: MenuBarScanner
    let isHovering: Bool

    var body: some View {
        VStack(spacing: 6) {
            iconContainer
            titleLabel
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            handleClick()
        }
        .onTapGesture(count: 1) {
            handleClick()
        }
        .help(item.title)
        .contextMenu {
            contextMenuItems
        }
    }

    private var iconContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
                .frame(width: 52, height: 52)
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)

            iconContent
        }
    }

    private var iconContent: some View {
        Group {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var titleLabel: some View {
        Text(displayTitle)
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 68)
            .foregroundColor(isHovering ? .primary : .secondary)
    }

    private var displayTitle: String {
        let title = item.title
        if title.count > 8 {
            let index = title.index(title.startIndex, offsetBy: 8)
            return String(title[..<index]) + "..."
        }
        return title
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
