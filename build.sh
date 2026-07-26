#!/bin/bash
set -e

APP_NAME="LingLongBar"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SRC_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== 清理旧的构建目录 ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== 编译 Swift 源代码 ==="
SWIFT_FILES=(
    "$SRC_DIR/LingLongBarApp.swift"
    "$SRC_DIR/AppConstants.swift"
    "$SRC_DIR/AppDelegate.swift"
    "$SRC_DIR/StatusItemInfo.swift"
    "$SRC_DIR/StatusItemManager.swift"
    "$SRC_DIR/NotchDetector.swift"
    "$SRC_DIR/MenuBarScanner.swift"
    "$SRC_DIR/AppPreferences.swift"
    "$SRC_DIR/CollapsedMenuView.swift"
    "$SRC_DIR/SettingsView.swift"
)

# 获取 SDK 路径
MACOS_SDK=$(xcrun --show-sdk-path)

swiftc \
    -target arm64-apple-macosx13.0 \
    -sdk "$MACOS_SDK" \
    -framework AppKit \
    -framework SwiftUI \
    -framework ApplicationServices \
    -framework Carbon \
    -framework ServiceManagement \
    -O \
    -o "$BUILD_DIR/$APP_NAME" \
    "${SWIFT_FILES[@]}"

echo "=== 创建 .app bundle 结构 ==="
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "=== 复制可执行文件 ==="
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== 复制 Info.plist ==="
cp "$SRC_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "=== 复制应用图标 ==="
if [ -f "$SRC_DIR/Resources/AppIcon.icns" ]; then
    cp "$SRC_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "警告: 未找到 Resources/AppIcon.icns，跳过图标复制"
fi

echo "=== 复制 PkgInfo ==="
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "=== 设置可执行文件架构信息 ==="
FILE_INFO=$(file "$APP_BUNDLE/Contents/MacOS/$APP_NAME")
echo "$FILE_INFO"

echo "=== 验证 bundle 结构 ==="
find "$APP_BUNDLE" -type f

echo ""
echo "=== 构建成功 ==="
echo "App 位置: $APP_BUNDLE"
