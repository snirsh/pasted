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

@Model
final class ClipboardItem {
    @Attribute(.unique)
    var id: UUID

    var contentType: ContentType

    @Attribute(.externalStorage)
    var rawData: Data

    var plainTextContent: String?

    @Attribute(.externalStorage)
    var previewThumbnail: Data?

    var sourceAppBundleID: String?
    var sourceAppName: String?
    var capturedAt: Date
    var byteSize: Int64

    init(
        id: UUID = UUID(),
        contentType: ContentType,
        rawData: Data,
        plainTextContent: String? = nil,
        previewThumbnail: Data? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        capturedAt: Date = Date(),
        byteSize: Int64? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.rawData = rawData
        self.plainTextContent = plainTextContent
        self.previewThumbnail = previewThumbnail
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.capturedAt = capturedAt
        self.byteSize = byteSize ?? Int64(rawData.count)
    }

    /// SHA-256 hash of rawData for deduplication (FR-011).
    var dataHash: String {
        let digest = SHA256.hash(data: rawData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
