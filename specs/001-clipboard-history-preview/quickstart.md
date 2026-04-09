# Quick Start: Clipboard History & Visual Preview

**Feature**: `001-clipboard-history-preview` | **Date**: 2026-04-09
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Prerequisites

- **macOS 14.0 Sonoma** or later
- **Xcode 15.0+** (Swift 5.9+, SwiftUI for macOS 14, SwiftData)
- No external dependencies — everything uses Apple system frameworks

## Step 1: Create the Xcode Project

1. Open Xcode and select **File > New > Project**
2. Choose **macOS > App**
3. Configure the project:
   - **Product Name**: `Pasted`
   - **Organization Identifier**: `org.pasted` (or your preferred identifier)
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData
4. Set the **Minimum Deployment Target** to **macOS 14.0**
5. Save the project at the repository root

## Step 2: Configure Entitlements

Open `Pasted.entitlements` and add the following:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for CGEvent tap — global keyboard shortcuts and paste injection -->
    <key>com.apple.security.accessibility</key>
    <true/>
    
    <!-- Required for launch-at-login via ServiceManagement (FR-010) -->
    <key>com.apple.developer.service-management.login-item</key>
    <true/>
    
    <!-- App Sandbox: disabled for clipboard manager functionality -->
    <!-- CGEvent taps and NSPasteboard monitoring require unsandboxed execution -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

**Note on sandboxing**: macOS clipboard managers cannot run inside the App Sandbox because `CGEvent.tapCreate` and full `NSPasteboard` access require unsandboxed execution. This is standard for this category of app. Distribution will be via direct download and/or the Developer ID notarization path, not the Mac App Store sandbox.

## Step 3: Configure Info.plist for Menu Bar Agent

Add to `Info.plist` (or via Xcode target settings):

```xml
<!-- Run as a background agent (menu bar only, no Dock icon) -->
<key>LSUIElement</key>
<true/>
```

This makes Pasted a menu bar agent — it appears only in the menu bar with no Dock icon and no main window, which is the expected behavior for a clipboard manager (FR-010).

## Step 4: Create the Project Structure

Create the following folder structure inside the `Pasted` target:

```
Pasted/
├── App/
│   ├── PastedApp.swift              # Already created by Xcode — move here and update
│   └── AppDelegate.swift            # New file
├── Models/
│   └── ClipboardItem.swift          # New file
├── Services/
│   ├── ClipboardMonitor.swift       # New file
│   ├── ClipboardStore.swift         # New file
│   └── PasteService.swift           # New file
├── Views/
│   ├── ClipboardStrip/
│   │   ├── ClipboardStripView.swift     # New file
│   │   ├── ClipboardItemPreview.swift   # New file
│   │   └── StripNavigationHandler.swift # New file
│   └── Preferences/
│       └── PreferencesView.swift        # New file
├── Utilities/
│   ├── KeyboardShortcutManager.swift    # New file
│   └── PreviewGenerator.swift           # New file
└── Resources/
    └── Assets.xcassets                  # Already created by Xcode — move here
```

Create the corresponding test target structure:

```
PastedTests/
├── ClipboardMonitorTests.swift
├── ClipboardStoreTests.swift
├── PasteServiceTests.swift
└── PreviewGeneratorTests.swift
```

## Step 5: Bootstrap the App Entry Point

Replace the Xcode-generated `PastedApp.swift` with the skeleton:

```swift
import SwiftUI
import SwiftData

@main
struct PastedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ClipboardItem.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        // Menu bar extra — the only visible UI element when strip is hidden
        MenuBarExtra("Pasted", systemImage: "clipboard") {
            // Menu bar dropdown content (placeholder)
            Button("Show Clipboard History") {
                // Toggle strip — will be connected to KeyboardShortcutManager
            }
            .keyboardShortcut("V", modifiers: [.shift, .command])
            
            Divider()
            
            Button("Preferences...") {
                // Open preferences window
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button("Quit Pasted") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("Q", modifiers: .command)
        }
    }
}
```

## Step 6: Create the AppDelegate Skeleton

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardMonitor: ClipboardMonitor?
    private var keyboardShortcutManager: KeyboardShortcutManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Request Accessibility permission if not granted
        requestAccessibilityPermission()
        
        // 2. Start clipboard monitoring
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor?.startMonitoring()
        
        // 3. Register global keyboard shortcuts
        keyboardShortcutManager = KeyboardShortcutManager()
        keyboardShortcutManager?.registerShortcuts()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        keyboardShortcutManager?.unregisterShortcuts()
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
```

## Step 7: Verify the Build

1. Build the project: **Cmd+B** — should compile with zero errors
2. Run the project: **Cmd+R** — should launch as a menu bar agent (clipboard icon in menu bar, no Dock icon)
3. Verify no Dock icon appears (LSUIElement working)
4. Verify menu bar icon appears with dropdown menu

## First Milestone Target

After completing the quickstart setup, the first implementation milestone is:

**Milestone 1 — Clipboard Capture + Basic Strip** (covers User Story 1, acceptance scenarios 1-4):

1. `ClipboardItem.swift` — Data model (from [data-model.md](./data-model.md))
2. `ClipboardMonitor.swift` — NSPasteboard polling, content extraction, deduplication
3. `ClipboardStore.swift` — SwiftData CRUD, basic query (newest first)
4. `ClipboardStripView.swift` — Horizontal ScrollView with placeholder previews
5. `KeyboardShortcutManager.swift` — Shift+Cmd+V to toggle strip, arrow keys, Return, Escape

This milestone delivers the end-to-end flow: copy something, press Shift+Cmd+V, see it in the strip, press Return to paste it back. Visual previews (Milestone 2) and quick-paste shortcuts (Milestone 3) build on this foundation.

## Development Tips

- **Accessibility permission**: Must be granted in System Settings > Privacy & Security > Accessibility for CGEvent taps to work. During development, Xcode-launched apps typically inherit this from Xcode itself.
- **Testing clipboard monitoring**: Use `pbcopy` in Terminal to simulate clipboard changes: `echo "test" | pbcopy`
- **Debugging the strip panel**: Set `panel.isOpaque = false` and `panel.backgroundColor = .red.withAlphaComponent(0.3)` to visualize panel bounds during development.
- **SwiftData in tests**: Use `ModelConfiguration(isStoredInMemoryOnly: true)` for test `ModelContainer` to avoid disk I/O and ensure test isolation.
- **Menu bar icon**: The `clipboard` SF Symbol is used as a placeholder. Consider a custom icon for production.
