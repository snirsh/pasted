# Data Model: Clipboard History & Visual Preview

**Feature**: `001-clipboard-history-preview` | **Date**: 2026-04-09
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Entities

### ClipboardItem

The primary entity representing a single captured clipboard entry. Maps directly to the Key Entity defined in the spec.

**SwiftData Model**:

```swift
import SwiftData
import Foundation

@Model
final class ClipboardItem {
    // MARK: - Identity
    
    /// Unique identifier for this clipboard entry.
    @Attribute(.unique)
    var id: UUID
    
    // MARK: - Content
    
    /// The type of content captured from the clipboard.
    var contentType: ContentType
    
    /// Raw clipboard data. For text types, this is UTF-8 encoded.
    /// For images, this is the original image data (PNG/TIFF).
    /// For files, this is the file URL encoded as UTF-8 string data.
    /// For rich text, this is the RTF or HTML data.
    @Attribute(.externalStorage)
    var rawData: Data
    
    /// Plain text representation of the content, if applicable.
    /// Populated for: text, richText, url. Nil for: image, file (unless filename).
    var plainTextContent: String?
    
    /// JPEG-compressed thumbnail for strip preview display.
    /// Pre-generated at capture time for instant strip rendering.
    @Attribute(.externalStorage)
    var previewThumbnail: Data?
    
    // MARK: - Metadata
    
    /// Bundle identifier of the app the content was copied from.
    /// e.g., "com.apple.Safari", "com.google.Chrome"
    var sourceAppBundleID: String?
    
    /// Display name of the source application.
    /// e.g., "Safari", "Chrome"
    var sourceAppName: String?
    
    /// Timestamp when this item was captured from the clipboard.
    var capturedAt: Date
    
    /// Size of rawData in bytes. Used for storage limit calculations (FR-009).
    var byteSize: Int64
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        contentType: ContentType,
        rawData: Data,
        plainTextContent: String? = nil,
        previewThumbnail: Data? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        capturedAt: Date = Date(),
        byteSize: Int64
    ) {
        self.id = id
        self.contentType = contentType
        self.rawData = rawData
        self.plainTextContent = plainTextContent
        self.previewThumbnail = previewThumbnail
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.capturedAt = capturedAt
        self.byteSize = byteSize
    }
}
```

### ContentType

Enum representing the five supported clipboard content types from the spec.

```swift
/// Content types that Pasted can capture and preview.
/// Maps to NSPasteboard UTTypes during clipboard monitoring.
enum ContentType: String, Codable, CaseIterable {
    /// Plain UTF-8 text (public.utf8-plain-text)
    case text
    
    /// Rich text with formatting — RTF or HTML (public.rtf, public.html)
    case richText
    
    /// Image data — PNG, TIFF, JPEG (public.image)
    case image
    
    /// URL string (public.url)
    case url
    
    /// File reference — path or file URL (public.file-url)
    case file
}
```

## Attribute Details

| Attribute | Type | Required | Indexed | Storage | Notes |
|-----------|------|----------|---------|---------|-------|
| `id` | `UUID` | Yes | Yes (unique) | Inline | Primary key. Auto-generated. |
| `contentType` | `ContentType` | Yes | Yes | Inline | Backed by `String` raw value for SwiftData Codable support. Indexed for filtered queries (e.g., "show only images"). |
| `rawData` | `Data` | Yes | No | External | Uses `@Attribute(.externalStorage)` — SwiftData stores large blobs as separate files, keeping the SQLite database lean. Critical for performance with 10K+ items. |
| `plainTextContent` | `String?` | No | Yes | Inline | Indexed for future full-text search (spec 002). Nil for images and files. For URLs, stores the URL string. For rich text, stores the stripped plain text version. |
| `previewThumbnail` | `Data?` | No | No | External | JPEG-compressed at ~80% quality. Target size: 240x160px (2x for Retina). Uses `@Attribute(.externalStorage)`. Generated at capture time by `PreviewGenerator`. |
| `sourceAppBundleID` | `String?` | No | Yes | Inline | Indexed for future app exclusion filtering (spec 004). Obtained from `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` at capture time. |
| `sourceAppName` | `String?` | No | No | Inline | Display-only. Obtained from `NSWorkspace.shared.frontmostApplication?.localizedName`. |
| `capturedAt` | `Date` | Yes | Yes | Inline | Primary sort key. Indexed for chronological ordering (newest first) and for pruning queries (oldest first). |
| `byteSize` | `Int64` | Yes | No | Inline | Size of `rawData` in bytes. Used to calculate total storage for pruning (FR-009). Aggregated via `SUM` query. |

## Indexing Strategy

SwiftData indexes are defined to support the primary access patterns:

```swift
// Applied to the ClipboardItem @Model via schema configuration
extension ClipboardItem {
    /// Indexes for primary query patterns.
    /// 1. Chronological listing (strip view): capturedAt DESC
    /// 2. Type filtering: contentType
    /// 3. Text search (future spec 002): plainTextContent
    /// 4. App filtering (future spec 004): sourceAppBundleID
    /// 5. Unique constraint: id
}
```

| Index | Columns | Purpose |
|-------|---------|---------|
| Primary | `capturedAt DESC` | Strip view ordering — newest first. Most frequent query. |
| Content Type | `contentType` | Filter by type (e.g., "show only images"). |
| Text Search | `plainTextContent` | Full-text search support (spec 002). |
| Source App | `sourceAppBundleID` | App exclusion filtering (spec 004). |
| Unique | `id` | Uniqueness constraint, direct lookups. |

## Validation Rules

| Rule | Field(s) | Description |
|------|----------|-------------|
| Non-empty data | `rawData` | `rawData` must have `count > 0`. Empty clipboard entries are discarded during capture. |
| Size limit | `rawData` | Items exceeding 50MB are captured with truncated preview and a size indicator (per spec edge case). Full data is still stored for pasting. |
| Deduplication | `rawData` | Consecutive identical entries are deduplicated (FR-011). Comparison via SHA-256 hash of `rawData` against the most recent item. |
| Valid content type | `contentType` | Must be one of the five defined `ContentType` enum cases. Unknown pasteboard types are mapped to `.text` with raw data preserved. |
| Timestamp | `capturedAt` | Must be a valid date. Defaults to `Date()` at capture time. |
| Byte size consistency | `byteSize`, `rawData` | `byteSize` must equal `rawData.count`. Enforced at initialization. |

## Relationships

This initial spec has no entity relationships. `ClipboardItem` is a standalone entity. Future specs may introduce:

- **Tags/Labels** (many-to-many): User-defined categorization.
- **Collections/Boards** (many-to-many): Grouped clipboard items (pinboards spec).
- **SyncMetadata** (one-to-one): CloudKit sync state tracking (iCloud sync spec).

## Storage Calculations

Estimating storage for the 10,000-item target (SC-002):

| Content Type | Avg rawData Size | Avg Thumbnail Size | Avg Total per Item |
|--------------|-----------------|-------------------|-------------------|
| Plain text | 2 KB | 5 KB | ~8 KB |
| Rich text | 10 KB | 8 KB | ~20 KB |
| Image | 500 KB | 15 KB | ~520 KB |
| URL | 0.5 KB | 5 KB | ~7 KB |
| File ref | 0.2 KB | 5 KB | ~7 KB |

**Estimated mix** (weighted toward text): 60% text, 10% rich text, 15% image, 10% URL, 5% file
**Average per item**: ~85 KB
**10,000 items**: ~850 MB (within the 1GB default limit)

Pruning activates when total `SUM(byteSize)` exceeds the configured limit. Items are deleted oldest-first in batches of 100 until storage drops below 90% of the limit (hysteresis to avoid pruning on every insert).

## ModelContainer Configuration

```swift
// In PastedApp.swift
@main
struct PastedApp: App {
    var body: some Scene {
        // ...
    }
    
    init() {
        // SwiftData container with ClipboardItem schema
        // Store location: ~/Library/Application Support/Pasted/
        // No CloudKit container for this spec (added in sync spec)
    }
}
```

**Store Location**: `~/Library/Application Support/Pasted/default.store`
**External Storage Directory**: `~/Library/Application Support/Pasted/external/` (for rawData and previewThumbnail blobs managed by SwiftData's `.externalStorage`)
