// LingLongBar 图标生成脚本
// 用法: swift generate_icon.swift <output_iconset_path>
//
// 设计说明:
//   - macOS Big Sur 风格的 squircle 圆角矩形背景
//   - 蓝紫渐变 (与 UI 配色一致)
//   - 中心叠加的"收纳栈"图形: 三层堆叠的菜单栏图标
//   - 一根收纳箭头从右侧插入，象征"收纳"动作

import AppKit
import Foundation

// MARK: - 主绘制函数

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // 1. 绘制 squircle 圆角矩形背景 (macOS 应用图标标准形状)
    let cornerRadius = size * 0.2237  // Apple 推荐的 squircle 圆角比例
    let inset = size * 0.02
    let iconRect = bounds.insetBy(dx: inset, dy: inset)
    let path = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    // 2. 渐变背景填充 (蓝紫渐变)
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.25, green: 0.47, blue: 0.95, alpha: 1.0),  // 蓝色
            CGColor(red: 0.55, green: 0.35, blue: 0.90, alpha: 1.0)   // 紫色
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    // 3. 顶部高光 (玻璃质感)
    let highlightGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.25),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        highlightGradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: 0, y: size * 0.5),
        options: []
    )

    // 4. 绘制中心图案: 三层收纳栈 (菜单栏图标堆叠)
    drawStackedItems(size: size, ctx: ctx)

    // 5. 绘制右侧的收纳箭头 (指向左侧收纳栈)
    drawCollectArrow(size: size, ctx: ctx)

    image.unlockFocus()
    return image
}

// MARK: - 三层堆叠图标

func drawStackedItems(size: CGFloat, ctx: CGContext) {
    let centerX = size * 0.42
    let centerY = size * 0.5

    // 三层堆叠，从后往前
    let layers: [(offset: CGFloat, scale: CGFloat, alpha: CGFloat)] = [
        (offset: size * 0.06, scale: 0.85, alpha: 0.55),  // 最后层
        (offset: size * 0.03, scale: 0.92, alpha: 0.80),  // 中间层
        (offset: 0,           scale: 1.00, alpha: 1.00)   // 最前层
    ]

    for layer in layers {
        ctx.saveGState()
        ctx.setAlpha(layer.alpha)

        let iconW = size * 0.22 * layer.scale
        let iconH = size * 0.18 * layer.scale
        let x = centerX - iconW / 2 + layer.offset
        let y = centerY - iconH / 2 + layer.offset

        // 白色圆角矩形 (模拟菜单栏小图标)
        let r = iconW * 0.22
        let iconRect = CGRect(x: x, y: y, width: iconW, height: iconH)
        let iconPath = CGPath(
            roundedRect: iconRect,
            cornerWidth: r,
            cornerHeight: r,
            transform: nil
        )
        ctx.addPath(iconPath)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fillPath()

        // 在图标内画一个小圆点 (象征应用图标)
        let dotR = iconW * 0.18
        let dotRect = CGRect(
            x: x + (iconW - dotR * 2) / 2,
            y: y + (iconH - dotR * 2) / 2,
            width: dotR * 2,
            height: dotR * 2
        )
        let dotPath = CGPath(ellipseIn: dotRect, transform: nil)
        ctx.addPath(dotPath)
        ctx.setFillColor(CGColor(red: 0.25, green: 0.47, blue: 0.95, alpha: 1))
        ctx.fillPath()

        ctx.restoreGState()
    }
}

// MARK: - 收纳箭头

func drawCollectArrow(size: CGFloat, ctx: CGContext) {
    // 从右下方有一个圆角矩形 (代表 LingLongBar 容器)，箭头从它指向左侧堆叠
    let containerW = size * 0.18
    let containerH = size * 0.18
    let containerX = size * 0.62
    let containerY = size * 0.5 - containerH / 2

    ctx.saveGState()

    // 容器 (LingLongBar 收纳盒)
    let r = containerW * 0.25
    let containerRect = CGRect(x: containerX, y: containerY, width: containerW, height: containerH)
    let containerPath = CGPath(
        roundedRect: containerRect,
        cornerWidth: r,
        cornerHeight: r,
        transform: nil
    )
    ctx.addPath(containerPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.fillPath()

    // 容器边框 (轻微的描边)
    ctx.addPath(containerPath)
    ctx.setStrokeColor(CGColor(red: 0.15, green: 0.20, blue: 0.45, alpha: 0.4))
    ctx.setLineWidth(size * 0.008)
    ctx.strokePath()

    // 容器内的 "收纳" 标识 (向下箭头 表示物品进入)
    let arrowColor = CGColor(red: 0.25, green: 0.47, blue: 0.95, alpha: 1)
    let ax = containerX + containerW / 2
    let ay = containerY + containerH / 2
    let arrowSize = containerW * 0.35

    // 向下箭头 (表示进入收纳盒)
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: ax - arrowSize * 0.4, y: ay + arrowSize * 0.3))
    arrowPath.addLine(to: CGPoint(x: ax + arrowSize * 0.4, y: ay + arrowSize * 0.3))
    arrowPath.addLine(to: CGPoint(x: ax, y: ay - arrowSize * 0.4))
    arrowPath.closeSubpath()

    ctx.addPath(arrowPath)
    ctx.setFillColor(arrowColor)
    ctx.fillPath()

    // 从容器到堆叠的指向虚线 (可选: 表示收纳动作)
    let lineStart = CGPoint(x: containerX - size * 0.005, y: containerY + containerH / 2)
    let lineEnd = CGPoint(x: size * 0.52, y: containerY + containerH / 2)

    ctx.setLineDash(phase: 0, lengths: [size * 0.015, size * 0.015])
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
    ctx.setLineWidth(size * 0.006)
    ctx.move(to: lineStart)
    ctx.addLine(to: lineEnd)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    ctx.restoreGState()
}

// MARK: - 主流程: 生成 .iconset 并转换为 .icns

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        FileHandle.standardError.write("用法: swift generate_icon.swift <output.icns>\n".data(using: .utf8)!)
        exit(1)
    }

    let outputPath = args[1]
    let outputURL = URL(fileURLWithPath: outputPath)

    // 创建临时 .iconset 目录
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent("LingLongBarIcon_\(getpid()).iconset")
    try? fm.removeItem(at: tempDir)
    try! fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    // 生成各尺寸图标
    let sizes: [(name: String, pixels: Int)] = [
        ("icon_16x16",         16),
        ("icon_16x16@2x",      32),
        ("icon_32x32",         32),
        ("icon_32x32@2x",      64),
        ("icon_128x128",      128),
        ("icon_128x128@2x",   256),
        ("icon_256x256",      256),
        ("icon_256x256@2x",   512),
        ("icon_512x512",      512),
        ("icon_512x512@2x",  1024)
    ]

    for (name, pixels) in sizes {
        let image = drawIcon(size: CGFloat(pixels))
        let pngURL = tempDir.appendingPathComponent("\(name).png")

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("生成 \(name) 失败\n".data(using: .utf8)!)
            exit(1)
        }
        try! pngData.write(to: pngURL)
    }

    // 用 iconutil 转换为 .icns
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", tempDir.path, "-o", outputURL.path]

    let pipe = Pipe()
    process.standardError = pipe
    try! process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorStr = String(data: errorData, encoding: .utf8) ?? "unknown error"
        FileHandle.standardError.write("iconutil 失败: \(errorStr)\n".data(using: .utf8)!)
        exit(process.terminationStatus)
    }

    print("✓ 图标已生成: \(outputURL.path)")
}

main()
