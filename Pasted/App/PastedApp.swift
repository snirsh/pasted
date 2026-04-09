import SwiftUI
import SwiftData

/// Single shared ModelContainer for the entire app.
/// Both PastedApp and AppDelegate use this to avoid schema conflicts.
enum SharedModelContainer {
    static let instance: ModelContainer = {
        let schema = Schema([
            ClipboardItem.self,
            OCRResult.self,
            AppExclusion.self,
            SyncState.self,
            DeviceInfo.self,
            Pinboard.self,
            PinboardEntry.self
        ])

        // Store at ~/Library/Application Support/Pasted/default.store
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = appSupportURL.appendingPathComponent("Pasted", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)

        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL.appendingPathComponent("default.store"),
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

@main
struct PastedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = SharedModelContainer.instance

    var body: some Scene {
        MenuBarExtra("Pasted", systemImage: "clipboard") {
            RecentItemsMenuSection(
                store: appDelegate.clipboardStore,
                pasteService: appDelegate.pasteService
            )

            Divider()

            Button("Show Clipboard History") {
                appDelegate.toggleStrip()
            }
            .keyboardShortcut("V", modifiers: [.shift, .command])

            Divider()

            Button("Preferences...") {
                appDelegate.showPreferences()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Pasted") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("Q", modifiers: .command)
        }

        Settings {
            TabView {
                PreferencesView()
                    .tabItem { Label("General", systemImage: "gear") }
                AppearancePreferencesView()
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                PrivacyPreferencesView()
                    .tabItem { Label("Privacy", systemImage: "hand.raised") }
                SyncPreferencesView()
                    .tabItem { Label("Sync", systemImage: "icloud") }
            }
            .modelContainer(sharedModelContainer)
        }
    }
}
