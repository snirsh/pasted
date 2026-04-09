import Foundation

/// Type-safe intermediary between ClipboardItem and CKRecord (003-icloud-sync).
/// This is NOT a SwiftData model — it exists only during sync operations.
struct SyncRecord {

    // MARK: - Identity

    /// Matches ClipboardItem.id (UUID string) and CKRecord.ID.recordName.
    let recordName: String

    // MARK: - Content

    /// Content type identifier (e.g., "text", "image").
    let contentType: String

    /// Raw content bytes — nil when stored as CKAsset (items > 1MB).
    let rawData: Data?

    /// Plain text representation for search/preview.
    let plainTextContent: String?

    // MARK: - Metadata

    /// Bundle ID of the app where the item was copied.
    let sourceAppBundleID: String?

    /// Original capture timestamp from the source device.
    let capturedAt: Date

    /// UUID of the device that captured this item.
    let deviceID: String

    /// Last modification timestamp (used for last-write-wins conflict resolution).
    let modifiedAt: Date

    /// Soft-delete flag — true means the item was deleted by the user.
    let isDeleted: Bool
}
