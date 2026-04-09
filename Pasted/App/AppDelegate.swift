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

        // Use the single shared ModelContainer to avoid schema conflicts.
        // Previously this created a separate container with only 3 models,
        // which conflicted with PastedApp's 5-model container on the same store.
        let container = SharedModelContainer.instance
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

        // Initialize iCloud sync engine lazily — only when user enables it.
        // CloudKit requires a valid provisioning profile and Apple Developer account;
        // eagerly creating CKContainer.default() crashes without one.
        configureSyncObserver(modelContext: context)
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

    private var syncModelContext: ModelContext?

    /// Observes sync settings changes. SyncEngine is only created when the user
    /// actually enables iCloud sync, avoiding CKContainer crashes when no
    /// Apple Developer account / provisioning profile is configured.
    private func configureSyncObserver(modelContext: ModelContext) {
        self.syncModelContext = modelContext

        NotificationCenter.default.addObserver(
            forName: .syncSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSyncSettingsChanged()
            }
        }

        // Only start sync if already enabled AND CloudKit is available
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            startSyncIfPossible()
        }
    }

    private func handleSyncSettingsChanged() {
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            startSyncIfPossible()
        } else {
            syncEngine?.stopSync()
            syncEngine = nil
        }
    }

    private func startSyncIfPossible() {
        guard let ctx = syncModelContext else { return }
        do {
            let manager = try CloudKitManager()
            syncEngine = SyncEngine(modelContext: ctx, cloudKitManager: manager)
            Task { await syncEngine?.startSync() }
        } catch {
            print("[AppDelegate] CloudKit not available: \(error.localizedDescription)")
        }
    }
}
