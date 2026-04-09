import SwiftData
import Foundation

/// Tracks iCloud sync progress for this device (003-icloud-sync).
/// One instance per device (singleton for the local device).
@Model
final class SyncState {

    /// Sync status enum representing the current sync state.
    enum Status: String, Codable {
        case idle       // No sync in progress, everything up to date
        case syncing    // Active fetch or push operation
        case offline    // No network connectivity
        case error      // Last sync attempt failed (see lastError)
        case paused     // User disabled sync or iCloud signed out
    }

    /// Unique device identifier (generated per Pasted installation).
    @Attribute(.unique)
    var deviceID: String

    /// Serialized CKServerChangeToken — used for incremental fetches.
    /// nil on first sync (triggers full fetch).
    var lastSyncToken: Data?

    /// Number of local items awaiting upload to CloudKit.
    var pendingUploadCount: Int = 0

    /// Number of remote items awaiting download from CloudKit.
    var pendingDownloadCount: Int = 0

    /// Raw string backing for syncStatus (persisted by SwiftData).
    var syncStatusRaw: String = "idle"

    /// Timestamp of last successful sync completion.
    var lastSyncAt: Date?

    /// Human-readable error description from last failed sync attempt.
    var lastError: String?

    /// Computed sync status backed by syncStatusRaw.
    var syncStatus: Status {
        get { Status(rawValue: syncStatusRaw) ?? .idle }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        deviceID: String,
        lastSyncToken: Data? = nil,
        pendingUploadCount: Int = 0,
        pendingDownloadCount: Int = 0,
        syncStatus: Status = .idle,
        lastSyncAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.deviceID = deviceID
        self.lastSyncToken = lastSyncToken
        self.pendingUploadCount = pendingUploadCount
        self.pendingDownloadCount = pendingDownloadCount
        self.syncStatusRaw = syncStatus.rawValue
        self.lastSyncAt = lastSyncAt
        self.lastError = lastError
    }
}
