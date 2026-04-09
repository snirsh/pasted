import SwiftUI
import ServiceManagement

/// Preferences window displayed via Settings scene or menu bar item.
struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("storageLimitMB") private var storageLimitMB: Double = 1024 // 1 GB default
    @AppStorage("maxHistoryItems") private var maxHistoryItems: Int = 5000

    @State private var currentUsageMB: Double = 0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            // MARK: - General

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            // MARK: - Storage

            Section("Storage") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage Limit: \(Int(storageLimitMB)) MB")
                    Slider(value: $storageLimitMB, in: 128...4096, step: 128) {
                        Text("Storage Limit")
                    }
                    .accessibilityLabel("Storage limit slider")

                    HStack {
                        Text("Current usage:")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f MB", currentUsageMB))
                            .foregroundStyle(
                                currentUsageMB > storageLimitMB * 0.9
                                    ? .red
                                    : .primary
                            )
                        Text("of \(Int(storageLimitMB)) MB")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    ProgressView(value: min(currentUsageMB / storageLimitMB, 1.0))
                        .tint(currentUsageMB > storageLimitMB * 0.9 ? .red : .accentColor)
                }

                Stepper(
                    "Max history items: \(maxHistoryItems)",
                    value: $maxHistoryItems,
                    in: 100...50000,
                    step: 500
                )
            }

            // MARK: - About

            Section("About") {
                LabeledContent("Version") {
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Source") {
                    Link("GitHub", destination: URL(string: "https://github.com/snirs/pasted")!)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 380)
        .navigationTitle("Preferences")
        .onAppear {
            refreshStorageUsage()
        }
    }

    // MARK: - Actions

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Preferences] Failed to set launch at login: \(error)")
            // Revert the toggle on failure
            launchAtLogin = !enabled
        }
    }

    private func refreshStorageUsage() {
        // Estimate by checking the Application Support directory size
        let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first
        let storeURL = appSupportURL?.appendingPathComponent("Pasted", isDirectory: true)

        guard let storeURL else {
            currentUsageMB = 0
            return
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: storeURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            currentUsageMB = 0
            return
        }

        var totalBytes: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalBytes += Int64(fileSize)
            }
        }

        currentUsageMB = Double(totalBytes) / (1024 * 1024)
    }
}
