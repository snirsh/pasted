import Foundation

/// Resolves conflicts between local ClipboardItems and remote SyncRecords (003-icloud-sync).
/// Strategy: union merge for new items, last-write-wins for metadata, delete propagation.
enum ConflictResolver {

    /// The action to take after comparing local and remote state.
    enum ConflictResolution {
        /// Remote item is new — insert it locally.
        case insertRemote
        /// Remote item is newer — update the local copy.
        case updateLocal
        /// Remote item was deleted — delete the local copy.
        case deleteLocal
        /// Local item is newer or identical — skip (local will push on next sync).
        case skip
    }

    /// Resolves a conflict between a local ClipboardItem and a remote SyncRecord.
    ///
    /// - Parameters:
    ///   - local: The local ClipboardItem, or nil if the item doesn't exist locally.
    ///   - remote: The remote SyncRecord fetched from CloudKit.
    /// - Returns: The resolution action to take.
    static func resolve(local: ClipboardItem?, remote: SyncRecord) -> ConflictResolution {
        // Remote says deleted — propagate the deletion
        if remote.isDeleted {
            if local != nil {
                return .deleteLocal
            }
            // Already gone locally — nothing to do
            return .skip
        }

        // No local copy — this is a new item from another device
        guard let local else {
            return .insertRemote
        }

        // Both exist — last-write-wins based on modifiedAt vs capturedAt
        // Use capturedAt as the local "modified" timestamp since ClipboardItem
        // doesn't have a separate modifiedAt field.
        if remote.modifiedAt > local.capturedAt {
            return .updateLocal
        }

        // Local is newer or equal — skip, local version will push on next sync
        return .skip
    }
}
