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
    private var syncEngine: SyncEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
        configureLaunchAtLogin()

        // Initialize services once model container is available
        if let container = try? ModelContainer(
            for: ClipboardItem.self, SyncState.self, DeviceInfo.self
        ) {
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

            // Initialize iCloud sync engine (003-icloud-sync)
            configureSyncEngine(modelContext: context)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        keyboardShortcutManager?.unregisterShortcuts()
        syncEngine?.stopSync()
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

    // MARK: - iCloud Sync (003-icloud-sync)

    /// Initializes the sync engine and observes settings changes.
    private func configureSyncEngine(modelContext: ModelContext) {
        syncEngine = SyncEngine(modelContext: modelContext)

        // Observe sync settings toggle from SyncPreferencesView
        NotificationCenter.default.addObserver(
            forName: .syncSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSyncSettingsChanged()
            }
        }

        // Start sync if already enabled
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            Task {
                await syncEngine?.startSync()
            }
        }
    }

    private func handleSyncSettingsChanged() {
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            Task {
                await syncEngine?.startSync()
            }
        } else {
            syncEngine?.stopSync()
        }
    }
}
