import Foundation
import SwiftData
import CloudKit

/// Tracks sync progress and persists the CKServerChangeToken (003-icloud-sync).
/// Coordinates pending upload/download counts and overall sync status.
@MainActor
final class SyncStateTracker {

    private let modelContext: ModelContext

    /// UserDefaults key for the serialized CKServerChangeToken.
    static let changeTokenKey = "iCloudSyncChangeToken"

    /// UserDefaults key for the local device ID.
    static let deviceIDKey = "deviceID"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Device ID

    /// Returns or generates the unique device ID for this installation.
    static var localDeviceID: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: deviceIDKey)
        return newID
    }

    // MARK: - Change Token Persistence

    /// Saves a CKServerChangeToken to UserDefaults via NSKeyedArchiver.
    static func saveChangeToken(_ token: CKServerChangeToken?) {
        guard let token else {
            UserDefaults.standard.removeObject(forKey: changeTokenKey)
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: changeTokenKey)
        } catch {
            print("[SyncStateTracker] Failed to archive change token: \(error)")
        }
    }

    /// Loads the persisted CKServerChangeToken from UserDefaults.
    static func loadChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: changeTokenKey) else {
            return nil
        }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
        } catch {
            print("[SyncStateTracker] Failed to unarchive change token: \(error)")
            return nil
        }
    }

    // MARK: - Pending Counts

    /// Recalculates pending upload/download counts from ClipboardItem sync statuses.
    func updateStatus() throws {
        let pendingUploadStatus = SyncStatus.pendingUpload
        let uploadDescriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.syncStatus == pendingUploadStatus }
        )
        let pendingUpload = try modelContext.fetchCount(uploadDescriptor)

        let pendingDownloadStatus = SyncStatus.pendingDownload
        let downloadDescriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.syncStatus == pendingDownloadStatus }
        )
        let pendingDownload = try modelContext.fetchCount(downloadDescriptor)

        // Update or create the SyncState for this device
        let deviceID = Self.localDeviceID
        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.deviceID == deviceID }
        )
        let existing = try modelContext.fetch(descriptor)

        if let state = existing.first {
            state.pendingUploadCount = pendingUpload
            state.pendingDownloadCount = pendingDownload
        } else {
            let state = SyncState(
                deviceID: deviceID,
                pendingUploadCount: pendingUpload,
                pendingDownloadCount: pendingDownload
            )
            modelContext.insert(state)
        }

        try modelContext.save()
    }

    /// Updates the sync status for this device.
    func setSyncStatus(_ status: SyncState.Status, error: String? = nil) throws {
        let deviceID = Self.localDeviceID
        let descriptor = FetchDescriptor<SyncState>(
            predicate: #Predicate { $0.deviceID == deviceID }
        )
        let existing = try modelContext.fetch(descriptor)

        if let state = existing.first {
            state.syncStatus = status
            state.lastError = error
            if status == .idle {
                state.lastSyncAt = Date()
            }
        } else {
            let state = SyncState(
                deviceID: deviceID,
                syncStatus: status,
                lastError: error
            )
            if status == .idle {
                state.lastSyncAt = Date()
            }
            modelContext.insert(state)
        }

        try modelContext.save()
    }
}
