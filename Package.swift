// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LingLongBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LingLongBar", targets: ["LingLongBar"])
    ],
    targets: [
        .executableTarget(
            name: "LingLongBar",
            path: ".",
            sources: [
                "LingLongBarApp.swift",
                "AppConstants.swift",
                "AppDelegate.swift",
                "StatusItemInfo.swift",
                "StatusItemManager.swift",
                "NotchDetector.swift",
                "MenuBarScanner.swift",
                "AppPreferences.swift",
                "CollapsedMenuView.swift",
                "SettingsView.swift"
            ],
            resources: [],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
