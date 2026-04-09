import AppKit
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
}
