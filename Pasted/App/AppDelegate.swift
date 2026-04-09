import AppKit
import ServiceManagement
import SwiftData

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardMonitor: ClipboardMonitor?
    private var keyboardShortcutManager: KeyboardShortcutManager?
    private var stripPanel: StripPanelController?
    private var clipboardStore: ClipboardStore?
    private var pasteService: PasteService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
        configureLaunchAtLogin()

        // Initialize services once model container is available
        if let container = try? ModelContainer(for: ClipboardItem.self) {
            let context = ModelContext(container)
            clipboardStore = ClipboardStore(modelContext: context)

            clipboardMonitor = ClipboardMonitor(store: clipboardStore!)
            clipboardMonitor?.startMonitoring()

            pasteService = PasteService()
            stripPanel = StripPanelController(store: clipboardStore!, pasteService: pasteService!)

            keyboardShortcutManager = KeyboardShortcutManager(
                stripPanel: stripPanel!,
                store: clipboardStore!,
                pasteService: pasteService!
            )
            keyboardShortcutManager?.registerShortcuts()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        keyboardShortcutManager?.unregisterShortcuts()
    }

    func toggleStrip() {
        stripPanel?.toggle()
    }

    func showPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Registers or unregisters launch-at-login using SMAppService based on the user's preference.
    private func configureLaunchAtLogin() {
        let launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("[AppDelegate] Launch at login configuration failed: \(error)")
        }
    }
}
