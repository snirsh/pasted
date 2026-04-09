import SwiftData
import Foundation

/// Stores text recognized from an image clipboard item via Apple Vision framework.
/// Linked to the parent `ClipboardItem` by `clipboardItemID`.
@Model
final class OCRResult {
    @Attribute(.unique)
    var id: UUID

    /// Foreign key referencing the parent `ClipboardItem.id`.
    var clipboardItemID: UUID

    /// Full recognized text content from the image. Indexed for search.
    @Attribute(.spotlight)
    var recognizedText: String

    /// Average confidence score from Vision (0.0 to 1.0).
    var confidence: Double

    /// Detected language code (e.g., "en"), nil if undetermined.
    var language: String?

    /// Timestamp when OCR processing completed.
    var processedAt: Date

    init(
        id: UUID = UUID(),
        clipboardItemID: UUID,
        recognizedText: String,
        confidence: Double,
        language: String? = nil,
        processedAt: Date = Date()
    ) {
        self.id = id
        self.clipboardItemID = clipboardItemID
        self.recognizedText = recognizedText
        self.confidence = confidence
        self.language = language
        self.processedAt = processedAt
    }
}
