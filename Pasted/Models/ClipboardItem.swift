import SwiftData
import Foundation
import CryptoKit

/// Content types that Pasted can capture and preview.
/// Maps to NSPasteboard UTTypes during clipboard monitoring.
enum ContentType: String, Codable, CaseIterable {
    case text
    case richText
    case image
    case url
    case file
}

/// Sync status for a clipboard item (003-icloud-sync).
enum SyncStatus: String, Codable {
    case local           // Not synced (sync disabled, or newly captured awaiting first sync)
    case synced          // Successfully synced to CloudKit
    case pendingUpload   // Captured locally, awaiting upload to CloudKit
    case pendingDownload // Placeholder — content being fetched from CloudKit
    case localOnly       // Too large to sync, or sync explicitly skipped
}

@Model
final class ClipboardItem {
    @Attribute(.unique)
    var id: UUID

    var contentType: ContentType

    /// Stored raw string of contentType for SwiftData #Predicate queries
    /// (SwiftData cannot traverse enum .rawValue in predicates).
    var contentTypeRaw: String

    @Attribute(.externalStorage)
    var rawData: Data

    var plainTextContent: String?

    @Attribute(.externalStorage)
    var previewThumbnail: Data?

    var sourceAppBundleID: String?
    var sourceAppName: String?
    var capturedAt: Date
    var byteSize: Int64

    // MARK: - Sync Fields (003-icloud-sync)

    /// Current sync status for this item.
    var syncStatus: SyncStatus = SyncStatus.local

    /// CKRecord.ID.recordName — nil if never synced to CloudKit.
    var cloudRecordName: String?

    init(
        id: UUID = UUID(),
        contentType: ContentType,
        rawData: Data,
        plainTextContent: String? = nil,
        previewThumbnail: Data? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        capturedAt: Date = Date(),
        byteSize: Int64? = nil,
        syncStatus: SyncStatus = .local,
        cloudRecordName: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.contentTypeRaw = contentType.rawValue
        self.rawData = rawData
        self.plainTextContent = plainTextContent
        self.previewThumbnail = previewThumbnail
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.capturedAt = capturedAt
        self.byteSize = byteSize ?? Int64(rawData.count)
        self.syncStatus = syncStatus
        self.cloudRecordName = cloudRecordName
    }

    /// SHA-256 hash of rawData for deduplication (FR-011).
    var dataHash: String {
        let digest = SHA256.hash(data: rawData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
