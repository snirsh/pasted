# Research: Power Search & OCR

**Feature**: 002-power-search-ocr | **Date**: 2026-04-09

## Decision 1: Search Implementation

**Question**: How to implement full-text search that returns results in <100ms for up to 50,000 clipboard items?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| SwiftData compound predicates | Query ClipboardItem and OCRResult models using `#Predicate` with indexed fields | Zero dependencies; native to our stack; automatic persistence; compound predicates support substring matching and case-insensitive search | No built-in relevance ranking; limited to what `#Predicate` supports |
| SQLite FTS5 | Use SQLite's full-text search extension via a raw SQLite connection | Proven full-text search; built-in ranking; fast tokenization | Adds a parallel data layer alongside SwiftData; increases complexity; requires manual schema management |
| External library (Tantivy, Lunr) | Bring in a third-party search library | Purpose-built for search; rich query language | Violates constitution principle II (native Apple frameworks only) and the no-external-dependencies constraint |
| In-memory filtering | Load all items into memory, filter with Swift `contains` | Simplest implementation; no index to maintain | Does not scale to 50K items within 100ms; high memory footprint |

**Decision**: **SwiftData compound predicates with indexed fields**.

**Rationale**: SwiftData predicates with `@Attribute(.spotlight)` or manual index annotations on `plainTextContent`, `ocrText`, `sourceAppName`, `contentType`, and `capturedAt` provide efficient lookups without leaving the native stack. For 50,000 items with indexed string columns, case-insensitive `localizedStandardContains` predicates execute well under 100ms on Apple Silicon. Relevance ranking (exact match > prefix match > substring match) is implemented in application logic by sorting results after the predicate query returns. This avoids external dependencies entirely, satisfying the constitution.

---

## Decision 2: OCR Engine

**Question**: Which OCR engine to use for text recognition in clipboard images?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| Apple Vision VNRecognizeTextRequest | Native macOS Vision framework text recognition | Built into macOS; no dependencies; supports .accurate and .fast modes; handles multiple languages; privacy-preserving (on-device) | Limited customization; accuracy depends on image quality |
| Tesseract OCR | Open-source OCR engine | Highly configurable; supports many languages | External dependency (violates constitution); requires bundling binaries; slower than Vision on Apple hardware |
| Google ML Kit | Cloud or on-device ML-based OCR | High accuracy | External dependency; potential privacy concerns; violates constitution principles I and II |

**Decision**: **Apple Vision VNRecognizeTextRequest**.

**Rationale**: This is the only option that satisfies the constitution. Vision framework is built into macOS 14+, runs entirely on-device (privacy-first), uses Apple Neural Engine for acceleration, and requires zero external dependencies. It supports both `.accurate` (higher quality, slower) and `.fast` (lower quality, faster) recognition levels. We use `.accurate` for background processing since latency is not user-facing, and `.fast` is available as a fallback for very large images where `.accurate` would exceed the 2-second target.

---

## Decision 3: Search Index Strategy

**Question**: How to keep the search index up to date as new clipboard items arrive?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| Incremental indexing on capture | Index each new ClipboardItem the moment it is captured; OCR results are indexed when OCR completes | Always up to date; minimal work per item; no batch overhead | Slightly more complex capture pipeline |
| Periodic full re-index | Rebuild the entire index on a timer (e.g., every 5 minutes) | Simple implementation; no per-item logic | Stale results between rebuilds; wasteful for large histories; poor UX during re-index |
| On-demand index at search time | Build index only when the user initiates a search | No background work | Unacceptable latency for 50K items; violates 100ms requirement |

**Decision**: **Incremental indexing on capture**.

**Rationale**: Each new ClipboardItem is indexed immediately when captured via the existing clipboard monitoring pipeline. When an image is captured, OCR runs asynchronously in the background; upon completion, the OCRResult is persisted and linked to the ClipboardItem, making the recognized text immediately searchable. SwiftData handles index updates automatically when model properties change. No full re-index is ever required under normal operation. A one-time migration task processes existing un-OCR'd images when the feature is first enabled.

**Index Fields**:
- `ClipboardItem.plainTextContent` -- primary text search target
- `OCRResult.recognizedText` -- OCR text search target
- `ClipboardItem.sourceAppBundleID` -- source app filter
- `ClipboardItem.contentType` -- content type filter
- `ClipboardItem.capturedAt` -- date range filter and sort order

---

## Decision 4: Filter Architecture

**Question**: How to model composable search filters that display as visual tokens?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| Composable value types with predicate generation | Each `SearchFilter` is a value type (enum) that can produce a SwiftData `#Predicate`; filters combine with AND logic | Type-safe; testable; each filter is independent; easy to add new filter types | Requires predicate composition logic |
| Single monolithic query builder | One object that holds all filter state and builds a single query | Simple API surface | Hard to extend; mixing concerns; difficult to test individual filters |
| Core Data NSCompoundPredicate | Use NSPredicate composition from Core Data | Mature predicate composition | SwiftData uses `#Predicate` macro, not NSPredicate; mixing paradigms adds complexity |

**Decision**: **Composable value types with predicate generation**.

**Rationale**: Each `SearchFilter` case (`.contentType`, `.sourceApp`, `.dateRange`, `.textQuery`) is an independent value that knows how to produce a SwiftData `#Predicate<ClipboardItem>`. The `SearchQuery` model holds the text query string and an array of active `SearchFilter` values. At query time, all predicates are combined with AND logic into a single compound predicate. This architecture is:
- **Testable**: Each filter can be unit-tested in isolation.
- **Extensible**: Adding a new filter type means adding an enum case and its predicate.
- **UI-friendly**: Each filter maps directly to a visual token in the search bar.

---

## Decision 5: OCR Background Processing

**Question**: How to run OCR processing without blocking clipboard capture or UI?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| Swift structured concurrency (async/await + Task) | Individual `Task` per new image capture; `TaskGroup` for batch processing existing images | Native Swift concurrency; automatic cancellation; priority control; clean async/await code | Requires careful priority management to avoid saturating CPU |
| OperationQueue with dependencies | NSOperation-based queue with max concurrency | Fine-grained concurrency control; cancellation support | Older pattern; more boilerplate; doesn't integrate as cleanly with SwiftUI |
| GCD dispatch queues | Manual dispatch to background serial/concurrent queues | Low-level control | No structured cancellation; harder to reason about; more error-prone |

**Decision**: **Swift structured concurrency with Task and TaskGroup**.

**Rationale**: Swift structured concurrency is the modern, idiomatic approach that integrates directly with SwiftUI's `@Observable` and `async/await` patterns already used in the app. Implementation details:

- **New image capture**: A single `Task(priority: .utility)` is spawned per image. The `.utility` priority ensures OCR does not compete with UI work or clipboard capture (which runs at `.userInitiated`).
- **Batch migration**: When the feature is first enabled, a `TaskGroup` processes existing un-OCR'd images with controlled concurrency (`maxConcurrentTasks` capped at 2-4 depending on core count) to avoid CPU saturation.
- **Large image handling**: Images exceeding 4096x4096 pixels are downscaled before OCR to keep processing within the 2-second target.
- **Cancellation**: If the user deletes a clipboard item while its OCR is in progress, the task is cancelled via Swift's cooperative cancellation.
- **Result persistence**: On completion, the `OCRResult` is saved to SwiftData and linked to the parent `ClipboardItem`, making it immediately available for search queries.
