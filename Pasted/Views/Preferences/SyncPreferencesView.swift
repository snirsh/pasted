import SwiftUI
import SwiftData

/// Preferences pane for iCloud sync settings (003-icloud-sync).
/// Allows enabling/disabling sync and shows sync status, pending items, and connected devices.
struct SyncPreferencesView: View {

    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    @Query(sort: \DeviceInfo.lastSeenAt, order: .reverse)
    private var devices: [DeviceInfo]

    @Query private var syncStates: [SyncState]

    private var localSyncState: SyncState? {
        let deviceID = SyncStateTracker.localDeviceID
        return syncStates.first { $0.deviceID == deviceID }
    }

    private var currentStatus: SyncState.Status {
        localSyncState?.syncStatus ?? .paused
    }

    var body: some View {
        Form {
            // MARK: - Sync Toggle

            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $iCloudSyncEnabled)
                    .onChange(of: iCloudSyncEnabled) { _, newValue in
                        handleSyncToggle(newValue)
                    }

                if iCloudSyncEnabled {
                    statusRow
                    lastSyncRow
                    pendingItemsRow
                }
            }

            // MARK: - Devices

            if iCloudSyncEnabled && !devices.isEmpty {
                Section("Synced Devices") {
                    ForEach(devices, id: \.deviceID) { device in
                        deviceRow(device)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Subviews

    private var statusRow: some View {
        LabeledContent("Status") {
            HStack(spacing: 6) {
                statusIndicator
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch currentStatus {
        case .idle:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch currentStatus {
        case .idle: return "Up to date"
        case .syncing: return "Syncing..."
        case .offline: return "Offline"
        case .error: return localSyncState?.lastError ?? "Error"
        case .paused: return "Paused"
        }
    }

    private var lastSyncRow: some View {
        LabeledContent("Last Sync") {
            if let lastSync = localSyncState?.lastSyncAt {
                Text(lastSync, style: .relative)
                    .foregroundStyle(.secondary)
            } else {
                Text("Never")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var pendingItemsRow: some View {
        let uploadCount = localSyncState?.pendingUploadCount ?? 0
        let downloadCount = localSyncState?.pendingDownloadCount ?? 0

        if uploadCount > 0 || downloadCount > 0 {
            LabeledContent("Pending") {
                VStack(alignment: .trailing) {
                    if uploadCount > 0 {
                        Text("\(uploadCount) to upload")
                            .foregroundStyle(.secondary)
                    }
                    if downloadCount > 0 {
                        Text("\(downloadCount) to download")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceInfo) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.deviceName)
                Text("v\(device.pastedVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(device.lastSeenAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func handleSyncToggle(_ enabled: Bool) {
        if enabled {
            // SyncEngine will be started by AppDelegate on next opportunity
            NotificationCenter.default.post(name: .syncSettingsChanged, object: nil)
        } else {
            NotificationCenter.default.post(name: .syncSettingsChanged, object: nil)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    /// Posted when iCloud sync settings change, triggering SyncEngine start/stop.
    static let syncSettingsChanged = Notification.Name("com.pasted.syncSettingsChanged")
}
