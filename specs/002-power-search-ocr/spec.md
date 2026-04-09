# Feature Specification: Power Search & OCR

**Feature Branch**: `002-power-search-ocr`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "Instant search across clipboard history with smart filters, text recognition in images via Apple Vision framework, and visual filter tokens"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instant Text Search (Priority: P1)

A user remembers copying a snippet of code or a URL earlier in the day but it's no longer visible in the recent items of the horizontal strip. They start typing immediately after invoking Pasted, and the strip filters down in real time to show only items matching their query. They find the item and paste it.

**Why this priority**: Search is the primary way users find items beyond the most recent few. Without it, clipboard history beyond ~20 items is effectively inaccessible.

**Independent Test**: Copy 50 items including one with the word "quarterly", invoke Pasted, type "quarterly", and verify only matching items appear.

**Acceptance Scenarios**:

1. **Given** the user has 500 items in history, **When** they invoke Pasted and type "invoice", **Then** only items containing "invoice" (case-insensitive) appear in the strip within 100ms.
2. **Given** a search is active with 3 results, **When** the user presses Return, **Then** the first (most recent) matching item is pasted.
3. **Given** a search is active, **When** the user clears the search field (Cmd+A then Delete), **Then** the full clipboard history reappears.
4. **Given** no items match the query, **When** the user types a non-matching term, **Then** an empty state message is shown (e.g., "No matches found").

---

### User Story 2 - Filter by Content Type (Priority: P2)

A user knows they copied an image earlier but doesn't remember its content. They apply a content type filter to narrow the strip to only images, making it easy to visually scan thumbnails.

**Why this priority**: Content type filtering dramatically narrows results for visual scanning — especially useful for images and files where text search alone doesn't help.

**Independent Test**: Copy 10 items (mix of text, images, and files), invoke Pasted, apply the "Images" filter, and verify only image items appear.

**Acceptance Scenarios**:

1. **Given** the user invokes Pasted, **When** they activate the filter bar (Cmd+F or clicking the filter area), **Then** filter options appear for: Text, Images, Links, Files.
2. **Given** the "Images" filter is active, **When** viewing the strip, **Then** only image clipboard items are displayed.
3. **Given** a content type filter is active, **When** it is displayed in the search field, **Then** it appears as a removable visual token/chip.
4. **Given** multiple filters are active (e.g., "Images" + a text query), **When** viewing results, **Then** both filters apply (AND logic).

---

### User Story 3 - Filter by Source Application (Priority: P2)

A user remembers copying something from Safari but not what it was. They filter the clipboard history by source app to see only items copied from Safari.

**Why this priority**: Source app filtering is a powerful disambiguation tool, especially for users who copy from many apps throughout the day.

**Independent Test**: Copy items from 3 different apps, invoke Pasted, filter by one app, and verify only items from that app appear.

**Acceptance Scenarios**:

1. **Given** the user has items from Safari, VS Code, and Slack, **When** they apply the "Safari" source filter, **Then** only items copied from Safari appear.
2. **Given** the source filter is active, **When** it is displayed, **Then** it shows the source app's icon and name as a visual token.
3. **Given** the user starts typing an app name in the filter bar, **When** suggestions appear, **Then** only apps that have contributed clipboard items are shown.

---

### User Story 4 - Text Recognition in Images (Priority: P2)

A user took a screenshot of a conversation, a whiteboard, or a document. Later, they search for a word they remember from that screenshot. Pasted finds the screenshot because it recognized the text within the image, and highlights the matching text in the preview.

**Why this priority**: OCR search transforms screenshots from opaque blobs into searchable content — a significant differentiator. Uses built-in Apple Vision framework (no external dependencies).

**Independent Test**: Take a screenshot containing the word "budget", invoke Pasted, search for "budget", and verify the screenshot appears in results with the matching text highlighted.

**Acceptance Scenarios**:

1. **Given** the user copies/screenshots an image containing the text "Q4 Revenue", **When** they search for "revenue", **Then** the image appears in search results.
2. **Given** an image matches a text search via OCR, **When** it appears in the strip, **Then** the recognized matching text is visually highlighted or indicated on the preview.
3. **Given** an image with no recognizable text, **When** text recognition runs, **Then** the image is still stored but simply has no searchable text — it only appears for non-text filters.
4. **Given** a newly copied image, **When** it is captured, **Then** text recognition runs in the background without blocking the clipboard capture or UI.

---

### User Story 5 - Filter by Date (Priority: P3)

A user remembers copying something "yesterday" or "last week." They apply a date filter to narrow results to a specific time range.

**Why this priority**: Useful but less critical than text search and content type filtering. Most users find items by content rather than date.

**Independent Test**: Copy items across multiple days, invoke Pasted, filter by "Today", and verify only today's items appear.

**Acceptance Scenarios**:

1. **Given** the user applies the "Today" date filter, **When** viewing results, **Then** only items copied today are shown.
2. **Given** date filter options, **When** the user opens the date filter, **Then** they see: Today, Yesterday, Last 7 Days, Last 30 Days, and Custom Range.
3. **Given** a date filter is active, **When** displayed in the search field, **Then** it appears as a visual token showing the selected range.

---

### Edge Cases

- What happens when OCR runs on a very large image (e.g., 8K screenshot)? The image is downscaled before text recognition to cap processing time at a reasonable threshold. Recognition still runs in the background.
- What happens when the user searches while new items are being copied? New items matching the active search appear at the front of the filtered results in real time.
- What happens if multiple filters conflict (e.g., "Images" type filter + text search with no OCR matches)? The strip shows an empty state — filters always use AND logic.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide instant text search (under 100ms for up to 50,000 items) across all clipboard item text content and metadata.
- **FR-002**: System MUST support filtering by content type: Text, Images, Links, Files.
- **FR-003**: System MUST support filtering by source application (identified by bundle ID and display name).
- **FR-004**: System MUST support filtering by date range with presets (Today, Yesterday, Last 7 Days, Last 30 Days) and custom range.
- **FR-005**: System MUST perform text recognition (OCR) on all image clipboard items using Apple Vision framework.
- **FR-006**: OCR MUST run asynchronously in the background without blocking clipboard capture or UI responsiveness.
- **FR-007**: OCR-recognized text MUST be indexed and searchable alongside regular text content.
- **FR-008**: Active filters MUST be displayed as removable visual tokens/chips in the search field.
- **FR-009**: Multiple filters MUST compose using AND logic.
- **FR-010**: Search MUST be case-insensitive and support substring matching.
- **FR-011**: Search results MUST be ordered by relevance (exact match weight) and recency.

### Key Entities

- **SearchQuery**: A user's search input consisting of text query and zero or more active filters.
- **SearchFilter**: A typed filter — content type, source app, or date range. Displayed as a visual token.
- **OCRResult**: Recognized text extracted from an image clipboard item. Attributes: recognized text, confidence score, bounding boxes (for highlight), language detected.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Search results appear within 100ms of the user typing a character, for histories up to 50,000 items.
- **SC-002**: OCR text recognition completes within 2 seconds per image on average hardware.
- **SC-003**: OCR correctly recognizes text in at least 90% of screenshots containing legible printed text.
- **SC-004**: Users can find a specific item from a 1,000-item history within 10 seconds using search and filters.
- **SC-005**: Filter tokens are visually distinct and can be added/removed with a single click or keystroke.

## Assumptions

- Users have macOS 14 Sonoma or later (required for Vision framework text recognition APIs).
- Images contain primarily Latin-script text for initial OCR support. Additional language support can be added later using Vision's supported languages.
- Source application bundle identifiers are available from NSPasteboard metadata for most apps.
- Search indexing happens incrementally (index each new item on capture) rather than requiring full re-indexing.
