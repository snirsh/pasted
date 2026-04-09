import Foundation
import CloudKit

/// Maps between ClipboardItem (SwiftData) and CKRecord (CloudKit) (003-icloud-sync).
/// Handles CKAsset for large items and the localOnly threshold.
enum SyncRecordMapper {

    /// CloudKit record type name for clipboard items.
    static let recordType = "ClipboardItem"

    /// Items above this threshold (1MB) use CKAsset instead of inline data.
    static let assetThresholdBytes = 1_000_000

    /// Items above this threshold (250MB) are marked localOnly and not synced.
    static let localOnlyThresholdBytes = 250_000_000

    // MARK: - ClipboardItem → CKRecord

    /// Converts a ClipboardItem to a CKRecord for upload to CloudKit.
    /// - Parameters:
    ///   - item: The local clipboard item to convert.
    ///   - zoneID: The custom CKRecordZone.ID for PastedClipboardZone.
    /// - Returns: A CKRecord ready for upload, or nil if the item exceeds the localOnly threshold.
    static func toCloudKitRecord(_ item: ClipboardItem, zoneID: CKRecordZone.ID) -> CKRecord? {
        let dataSize = item.rawData.count

        // Items exceeding 250MB are too large to sync
        guard dataSize <= localOnlyThresholdBytes else {
            return nil
        }

        let recordID = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record["contentType"] = item.contentType.rawValue as CKRecordValue
        record["plainTextContent"] = item.plainTextContent as CKRecordValue?
        record["sourceAppBundleID"] = item.sourceAppBundleID as CKRecordValue?
        record["capturedAt"] = item.capturedAt as CKRecordValue
        record["modifiedAt"] = Date() as CKRecordValue
        record["isDeleted"] = 0 as CKRecordValue

        let deviceID = UserDefaults.standard.string(forKey: "deviceID") ?? "unknown"
        record["deviceID"] = deviceID as CKRecordValue

        // Use CKAsset for large items, inline data for small ones
        if dataSize > assetThresholdBytes {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            do {
                try item.rawData.write(to: tempURL)
                record["asset"] = CKAsset(fileURL: tempURL)
            } catch {
                // Fall back to inline if temp file write fails
                record["rawData"] = item.rawData as CKRecordValue
            }
        } else {
            record["rawData"] = item.rawData as CKRecordValue
        }

        return record
    }

    // MARK: - CKRecord → SyncRecord

    /// Converts a CKRecord fetched from CloudKit into a type-safe SyncRecord.
    /// - Parameter record: The CKRecord from a fetch or subscription notification.
    /// - Returns: A SyncRecord with all fields extracted.
    static func fromCloudKitRecord(_ record: CKRecord) -> SyncRecord {
        let recordName = record.recordID.recordName

        let contentType = record["contentType"] as? String ?? ContentType.text.rawValue
        let plainTextContent = record["plainTextContent"] as? String
        let sourceAppBundleID = record["sourceAppBundleID"] as? String
        let capturedAt = record["capturedAt"] as? Date ?? Date()
        let deviceID = record["deviceID"] as? String ?? "unknown"
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? Date()
        let isDeletedInt = record["isDeleted"] as? Int ?? 0
        let isDeleted = isDeletedInt != 0

        // Read data from either CKAsset or inline field
        var rawData: Data?
        if let asset = record["asset"] as? CKAsset, let fileURL = asset.fileURL {
            rawData = try? Data(contentsOf: fileURL)
        } else {
            rawData = record["rawData"] as? Data
        }

        return SyncRecord(
            recordName: recordName,
            contentType: contentType,
            rawData: rawData,
            plainTextContent: plainTextContent,
            sourceAppBundleID: sourceAppBundleID,
            capturedAt: capturedAt,
            deviceID: deviceID,
            modifiedAt: modifiedAt,
            isDeleted: isDeleted
        )
    }
}
