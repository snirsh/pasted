# Data Model: Power Search & OCR

**Feature**: 002-power-search-ocr | **Date**: 2026-04-09

## Overview

This document defines the data model additions required for Power Search & OCR. These models extend the existing `ClipboardItem` entity from spec 001 (Clipboard History & Visual Preview).

---

## Persisted Models (SwiftData)

### OCRResult

Stores text recognized from an image clipboard item via Apple Vision framework.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `UUID` | Primary key, auto-generated |
| `clipboardItemID` | `UUID` | Foreign key referencing the parent `ClipboardItem.id` |
| `recognizedText` | `String` | Full recognized text content from the image (indexed for search) |
| `confidence` | `Double` | Average confidence score from Vision (0.0 to 1.0) |
| `language` | `String?` | Detected language code (e.g., "en"), nil if undetermined |
| `processedAt` | `Date` | Timestamp when OCR processing completed |

**Relationships**:
- `OCRResult` belongs to one `ClipboardItem` (one-to-one). A `ClipboardItem` has zero or one `OCRResult`.

**SwiftData Declaration**:
```swift
@Model
final class OCRResult {
    @Attribute(.unique) var id: UUID
    var clipboardItemID: UUID
    @Attribute(.spotlight) var recognizedText: String
    var confidence: Double
    var language: String?
    var processedAt: Date

    @Relationship(inverse: \ClipboardItem.ocrResult)
    var clipboardItem: ClipboardItem?
}
```

### ClipboardItem Additions (from spec 001)

The existing `ClipboardItem` model gains an optional relationship to `OCRResult`:

| Field | Type | Description |
|-------|------|-------------|
| `ocrResult` | `OCRResult?` | Optional OCR result for image items |

```swift
// Addition to existing ClipboardItem @Model
var ocrResult: OCRResult?
```

---

## Value Types (non-persisted)

### SearchFilter

Represents a single active filter. Value type (enum) used for composing search queries.

```swift
enum SearchFilter: Hashable, Identifiable {
    case contentType(ContentType)
    case sourceApp(bundleID: String, displayName: String)
    case dateRange(DateRange)

    var id: String {
        switch self {
        case .contentType(let type): return "type:\(type.rawValue)"
        case .sourceApp(let bundleID, _): return "app:\(bundleID)"
        case .dateRange(let range): return "date:\(range.id)"
        }
    }
}
```

### ContentType

Reuses the `ContentType` enum from spec 001 for filtering:

```swift
enum ContentType: String, CaseIterable {
    case text
    case image
    case link
    case file
    case richText
}
```

### DateRange

Defines date range options for the date filter:

```swift
enum DateRange: Hashable, Identifiable {
    case today
    case yesterday
    case lastSevenDays
    case lastThirtyDays
    case custom(from: Date, to: Date)

    var id: String {
        switch self {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .lastSevenDays: return "last7"
        case .lastThirtyDays: return "last30"
        case .custom(let from, let to): return "custom:\(from.timeIntervalSince1970):\(to.timeIntervalSince1970)"
        }
    }

    /// Returns the start date for this range relative to now.
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .yesterday:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
        case .lastSevenDays:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: now)!)
        case .lastThirtyDays:
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -30, to: now)!)
        case .custom(let from, _):
            return from
        }
    }

    /// Returns the end date for this range. Nil means "now" for preset ranges.
    var endDate: Date? {
        switch self {
        case .yesterday:
            let calendar = Calendar.current
            return calendar.startOfDay(for: Date())
        case .custom(_, let to):
            return to
        default:
            return nil // Open-ended (up to now)
        }
    }
}
```

### SearchQuery

Represents the complete user search state: text input plus active filters.

```swift
struct SearchQuery: Equatable {
    var text: String
    var filters: [SearchFilter]

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && filters.isEmpty
    }

    /// All active content type filters.
    var contentTypeFilters: [ContentType] {
        filters.compactMap {
            if case .contentType(let type) = $0 { return type }
            return nil
        }
    }

    /// All active source app filters.
    var sourceAppFilters: [(bundleID: String, displayName: String)] {
        filters.compactMap {
            if case .sourceApp(let bundleID, let displayName) = $0 {
                return (bundleID, displayName)
            }
            return nil
        }
    }

    /// The active date range filter (only one allowed at a time).
    var dateRangeFilter: DateRange? {
        filters.compactMap {
            if case .dateRange(let range) = $0 { return range }
            return nil
        }.first
    }
}
```

---

## Indexes

Indexes required for search performance (<100ms on 50,000 items):

| Model | Field(s) | Index Type | Purpose |
|-------|----------|------------|---------|
| `ClipboardItem` | `plainTextContent` | Text / Spotlight | Primary text search across clipboard text content |
| `OCRResult` | `recognizedText` | Text / Spotlight | OCR text search across recognized image text |
| `ClipboardItem` | `capturedAt` | Sorted (descending) | Date range filtering and result ordering by recency |
| `ClipboardItem` | `contentType` | Standard | Content type filtering |
| `ClipboardItem` | `sourceAppBundleID` | Standard | Source application filtering |
| `ClipboardItem` | `capturedAt`, `contentType` | Compound | Combined date + type filter queries |

**SwiftData Index Declaration**:
```swift
// On ClipboardItem
@Attribute(.spotlight) var plainTextContent: String?
@Attribute var contentType: String     // indexed via @Index
@Attribute var sourceAppBundleID: String?
@Attribute var capturedAt: Date        // indexed via @Index

// On OCRResult
@Attribute(.spotlight) var recognizedText: String
```

---

## Entity Relationship Diagram

```
┌─────────────────────────┐       ┌─────────────────────────┐
│     ClipboardItem       │       │       OCRResult          │
│ (from spec 001)         │       │ (new in spec 002)        │
├─────────────────────────┤       ├─────────────────────────┤
│ id: UUID (PK)           │       │ id: UUID (PK)            │
│ contentType: String     │  1  0..1  clipboardItemID: UUID (FK)│
│ plainTextContent: String?│◄─────┤ recognizedText: String   │
│ sourceAppBundleID: String?│      │ confidence: Double       │
│ capturedAt: Date         │       │ language: String?        │
│ ocrResult: OCRResult?    │       │ processedAt: Date        │
│ ...other spec 001 fields │       │ clipboardItem: ClipboardItem?│
└─────────────────────────┘       └─────────────────────────┘

┌─────────────────────────┐
│   SearchQuery (value)   │
├─────────────────────────┤       ┌─────────────────────────┐
│ text: String            │       │  SearchFilter (enum)     │
│ filters: [SearchFilter] │───────┤  .contentType(ContentType)│
│                         │  0..*  │  .sourceApp(bundleID, name)│
└─────────────────────────┘       │  .dateRange(DateRange)   │
                                  └─────────────────────────┘

                                  ┌─────────────────────────┐
                                  │   DateRange (enum)       │
                                  ├─────────────────────────┤
                                  │  .today                  │
                                  │  .yesterday              │
                                  │  .lastSevenDays          │
                                  │  .lastThirtyDays         │
                                  │  .custom(from, to)       │
                                  └─────────────────────────┘
```
