# Quick Start: Power Search & OCR

**Feature**: 002-power-search-ocr | **Date**: 2026-04-09

## Prerequisites

1. **Spec 001 (Clipboard History & Visual Preview) must be implemented first.** Power Search depends on the `ClipboardItem` model, the clipboard monitoring pipeline, and the horizontal strip UI from spec 001.
2. **macOS 14 Sonoma or later** -- required for Vision framework text recognition APIs and SwiftData.
3. **Xcode 15+** with Swift 5.9+ toolchain.

## Setup Steps

### Step 1: Add Vision Framework

Add the Vision framework to the Xcode project:

1. Select the Pasted target in Xcode.
2. Go to **General > Frameworks, Libraries, and Embedded Content**.
3. Click **+** and add `Vision.framework`.
4. No additional entitlements are required -- Vision runs on-device with no special permissions.

### Step 2: Create the OCR Service

Create `Pasted/Services/OCRService.swift`:

- Wrap `VNRecognizeTextRequest` with an async Swift interface.
- Use `.accurate` recognition level for background processing.
- Accept a `CGImage` or `Data` input and return recognized text with confidence.
- Handle image downscaling for images larger than 4096x4096 pixels.
- Run as a `Task(priority: .utility)` to avoid blocking UI.

This is the lowest-dependency new component -- it has no dependencies on other new code from this spec.

### Step 3: Create the OCRResult Model

Create `Pasted/Models/OCRResult.swift`:

- Define the `@Model` class with fields: `id`, `clipboardItemID`, `recognizedText`, `confidence`, `language`, `processedAt`.
- Add the `@Relationship` to `ClipboardItem`.
- Update `ClipboardItem` to add an optional `ocrResult` property.
- Register `OCRResult` in the SwiftData `ModelContainer` configuration.

### Step 4: Create Search Filter Models

Create `Pasted/Models/SearchFilter.swift` and `Pasted/Models/SearchQuery.swift`:

- Define the `SearchFilter` enum with cases: `.contentType`, `.sourceApp`, `.dateRange`.
- Define the `DateRange` enum with preset and custom options.
- Define the `SearchQuery` struct holding text and active filters.
- See `data-model.md` for complete type definitions.

### Step 5: Create the Search Engine

Create `Pasted/Services/SearchEngine.swift`:

- Accept a `SearchQuery` and return filtered `[ClipboardItem]` results.
- Build SwiftData `#Predicate` from each active `SearchFilter`.
- Combine all predicates with AND logic.
- Text search uses `localizedStandardContains` for case-insensitive substring matching.
- Query both `ClipboardItem.plainTextContent` and related `OCRResult.recognizedText`.
- Sort results by recency (`capturedAt` descending), with exact matches weighted first.

### Step 6: Build the Search Bar UI

Create views under `Pasted/Views/Search/`:

- **SearchBarView.swift**: Text field that triggers search on each keystroke. Displays active filter tokens inline. Appears at the top of the clipboard strip or integrates into the existing strip header.
- **FilterTokenView.swift**: Individual chip showing filter type and value with a remove button. Keyboard-accessible (Delete key removes focused token).
- **FilterPickerView.swift**: Popover or menu for selecting filters. Shows content type options, recently used source apps, and date range presets.

### Step 7: Integrate with Clipboard Strip

Update the existing `ClipboardStrip` views from spec 001:

- Pass `SearchQuery` state from `SearchBarView` into the strip's data source.
- When a search is active, the strip shows only matching items.
- When search is cleared, the full history reappears.
- Empty state view when no results match.

## First Milestone

**Goal**: Basic text search across clipboard history (no OCR, no filters).

Build and verify:
1. `SearchEngine` with text-only `#Predicate` queries against `ClipboardItem.plainTextContent`.
2. `SearchBarView` with a simple text field (no filter tokens yet).
3. Integration: typing in the search bar filters the clipboard strip in real time.
4. Test: copy 50 items, search for a unique word, verify it appears within 100ms.

This milestone validates the core search pipeline end-to-end before adding OCR and filter complexity.

## Testing Strategy

- **Unit tests** (`SearchEngineTests.swift`): Test predicate building for each filter type, AND composition, empty query handling, case-insensitive matching.
- **Unit tests** (`OCRServiceTests.swift`): Test OCR on known test images with expected text, confidence thresholds, large image downscaling, error handling.
- **Unit tests** (`FilterTests.swift`): Test filter equality, ID generation, date range calculations, SearchQuery composition.
- **Integration tests**: Test full pipeline from clipboard capture through OCR to search result appearance.
- **Performance tests**: Measure search latency with 50,000 synthetic ClipboardItem records to validate <100ms target.

Follow the test-first workflow per the constitution: write failing tests, then implement to make them pass.
