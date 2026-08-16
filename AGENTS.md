# Repository Guidelines

## Project Structure & Module Organization

LingLongBar is a macOS 13+ menu-bar application written in Swift 5.9. The Swift sources live at the repository root and are organized by responsibility:

- `LingLongBarApp.swift`, `AppDelegate.swift`: application and window lifecycle.
- `MenuBarScanner.swift`, `StatusItemManager.swift`, `NotchDetector.swift`: Accessibility scanning, visibility decisions, and notch/display geometry.
- `CollapsedMenuView.swift`, `SettingsView.swift`: SwiftUI UI.
- `AppPreferences.swift`, `AppConstants.swift`, `StatusItemInfo.swift`: persisted settings, constants, and data models.
- `Resources/`: bundled assets such as `AppIcon.icns`.
- `scripts/`: development utilities, including `generate_icon.swift`.
- `Package.swift`, `Info.plist`, and `LingLongBar.entitlements`: package, bundle, and permission configuration.

There is currently no test directory or dedicated test target.

## Build, Test, and Development Commands

```bash
swift build                 # Compile the Swift package
bash build.sh               # Build the arm64 .app bundle in build/
open build/LingLongBar.app  # Run the locally built application
swift scripts/generate_icon.swift Resources/AppIcon.icns
                            # Regenerate the application icon
```

Use macOS 13+ and Xcode Command Line Tools. The running app needs Accessibility permission to inspect other applications’ menu-bar items.

## Coding Style & Naming Conventions

Follow standard Swift conventions: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and descriptive names for state and UI components. Keep files focused on one responsibility. Prefer SwiftUI/AppKit APIs already used by the project, `os.Logger` over `print`, and comments that explain non-obvious macOS Accessibility or geometry behavior. Preserve the existing Chinese user-facing strings and comments unless a change intentionally adds localization.

## Testing Guidelines

No automated tests or coverage requirements are configured. Before submitting changes, run `swift build` and `bash build.sh`, then manually verify menu-bar scanning, notch handling, settings persistence, login-item behavior, and Accessibility permission flows on macOS. For UI or display changes, test both light/dark appearance and, when possible, multiple displays.

## Commit & Pull Request Guidelines

Use short, imperative commit subjects with a conventional prefix such as `feat:`, `fix:`, `refactor:`, or `docs:` (for example, `feat: add manual icon ordering`). Keep unrelated changes separate. Pull requests should explain the behavior change, identify macOS versions tested, include validation commands, and attach screenshots or a short recording for visible UI changes. Call out changes to entitlements, permissions, or login-item behavior explicitly.

## Security & Configuration Tips

Treat Accessibility access as sensitive: request only what the feature needs and do not add data collection. Keep bundle identifiers, entitlements, and `Info.plist` entries synchronized when changing app capabilities.
