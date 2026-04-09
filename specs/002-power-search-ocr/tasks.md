# Tasks: Power Search & OCR

**Feature**: 002-power-search-ocr | **Date**: 2026-04-09  
**Spec**: `specs/002-power-search-ocr/spec.md`  
**Dependency**: Spec 001 (Clipboard History & Visual Preview) — this feature extends `ClipboardItem` from spec 001. Spec 001 must be implemented first.

---

## Phase 1: Setup

- [ ] T001 [P] Add Vision framework capability to the Xcode project target (link `Vision.framework` in Build Phases)
- [ ] T002 [P] Create directory `Pasted/Services/` (if not already present from spec 001)
- [ ] T003 [P] Create directory `Pasted/Views/Search/`
- [ ] T004 [P] Create directory `PastedTests/` (if not already present from spec 001)

---

## Phase 2: Foundational — Models, Index, and Test Infrastructure

- [ ] T005 Write tests for `SearchQuery` model — equality, `isEmpty`, `contentTypeFilters`, `sourceAppFilters`, `dateRangeFilter` computed properties — `PastedTests/SearchQueryTests.swift`
- [ ] T006 Implement `SearchQuery` struct (text + filters, computed helpers) — `Pasted/Models/SearchQuery.swift`
- [ ] T007 Write tests for `SearchFilter` enum — `Hashable` conformance, `Identifiable` id uniqueness for all cases — `PastedTests/FilterTests.swift`
- [ ] T008 Implement `SearchFilter` enum (`.contentType`, `.sourceApp`, `.dateRange`) — `Pasted/Models/SearchFilter.swift`
- [ ] T009 Write tests for `DateRange` enum — `startDate`/`endDate` computation for all cases including `.custom` — `PastedTests/FilterTests.swift`
- [ ] T010 Implement `DateRange` enum with `startDate`/`endDate` computed properties — `Pasted/Models/SearchFilter.swift`
- [ ] T011 Write tests for `ContentType` enum — `CaseIterable` conformance, raw values — `PastedTests/FilterTests.swift`
- [ ] T012 Implement `ContentType` enum (reuse from spec 001 if already defined, otherwise create) — `Pasted/Models/SearchFilter.swift`
- [ ] T013 Write tests for `OCRResult` SwiftData model — initialization, relationship to `ClipboardItem`, field defaults — `PastedTests/OCRServiceTests.swift`
- [ ] T014 Implement `OCRResult` @Model class with all fields (`id`, `clipboardItemID`, `recognizedText`, `confidence`, `language`, `processedAt`) and relationship — `Pasted/Models/OCRResult.swift`
- [ ] T015 Add `ocrResult: OCRResult?` optional relationship to existing `ClipboardItem` model (spec 001 extension) — `Pasted/Models/ClipboardItem.swift`
- [ ] T016 Add SwiftData index annotations on `ClipboardItem` fields: `@Attribute(.spotlight)` on `plainTextContent`, indexes on `contentType`, `sourceAppBundleID`, `capturedAt` — `Pasted/Models/ClipboardItem.swift`
- [ ] T017 Add `@Attribute(.spotlight)` index annotation on `OCRResult.recognizedText` — `Pasted/Models/OCRResult.swift`
- [ ] T018 Write tests for `SearchIndex` — incremental index update on new item, index consistency after OCR completion — `PastedTests/SearchEngineTests.swift`
- [ ] T019 Implement `SearchIndex` base service for incremental index management — `Pasted/Services/SearchIndex.swift`

---

## Phase 3: US1 — Instant Text Search (P1) MVP

- [ ] T020 [US1] Write tests for `SearchEngine` text search — case-insensitive substring match, empty query returns all, no-match returns empty, result ordering by recency — `PastedTests/SearchEngineTests.swift`
- [ ] T021 [US1] Write performance test for `SearchEngine` — search completes in <100ms with 50,000 mock items — `PastedTests/SearchEngineTests.swift`
- [ ] T022 [US1] Implement `SearchEngine` service with SwiftData `#Predicate` for text search using `localizedStandardContains` — `Pasted/Services/SearchEngine.swift`
- [ ] T023 [US1] Implement relevance ranking in `SearchEngine` — sort results by exact match > prefix match > substring match, then by recency — `Pasted/Services/SearchEngine.swift`
- [ ] T024 [US1] Write UI tests for `SearchBarView` — typing filters strip, clearing restores full list, empty state message on no matches — `PastedTests/SearchBarViewTests.swift`
- [ ] T025 [US1] Implement `SearchBarView` with text field, type-ahead search triggering, and Cmd+A/Delete to clear — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T026 [US1] Integrate `SearchBarView` into the clipboard strip view — wire search query to filter displayed `ClipboardItem` results — `Pasted/Views/ClipboardStrip/` (existing strip views)
- [ ] T027 [US1] Implement empty state view ("No matches found") shown when search yields zero results — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T028 [US1] Implement Return key behavior — pressing Return with active search pastes the first (most recent) matching item — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T029 [US1] Write test for real-time update — new clipboard item matching active search appears in filtered results — `PastedTests/SearchEngineTests.swift`
- [ ] T030 [US1] Implement real-time search update when new items arrive during active search — `Pasted/Services/SearchEngine.swift`

---

## Phase 4: US2 — Filter by Content Type (P2)

- [ ] T031 [US2] Write tests for content type predicate generation — each `ContentType` case produces correct `#Predicate` filtering `ClipboardItem.contentType` — `PastedTests/FilterTests.swift`
- [ ] T032 [US2] Implement content type predicate generation on `SearchFilter.contentType` — `Pasted/Services/SearchEngine.swift`
- [ ] T033 [US2] Write tests for AND composition — content type filter + text query returns only items matching both — `PastedTests/FilterTests.swift`
- [ ] T034 [US2] Implement compound predicate composition (AND logic) in `SearchEngine` for combining text search with content type filter — `Pasted/Services/SearchEngine.swift`
- [ ] T035 [US2] Write UI tests for `FilterTokenView` — renders label, shows remove button, triggers removal callback — `PastedTests/FilterTokenViewTests.swift`
- [ ] T036 [US2] Implement `FilterTokenView` — removable visual chip/token component for active filters — `Pasted/Views/Search/FilterTokenView.swift`
- [ ] T037 [US2] Write UI tests for `FilterPickerView` — shows content type options (Text, Images, Links, Files), selecting adds filter token — `PastedTests/FilterPickerViewTests.swift`
- [ ] T038 [US2] Implement `FilterPickerView` — filter selection popover/menu activated via Cmd+F or click — `Pasted/Views/Search/FilterPickerView.swift`
- [ ] T039 [US2] Integrate filter tokens into `SearchBarView` — display active filters as inline tokens, support removal via click or keyboard — `Pasted/Views/Search/SearchBarView.swift`

---

## Phase 5: US3 — Filter by Source Application (P2)

- [ ] T040 [US3] Write tests for source app predicate generation — filter by `sourceAppBundleID` produces correct `#Predicate` — `PastedTests/FilterTests.swift`
- [ ] T041 [US3] Implement source app predicate generation on `SearchFilter.sourceApp` — `Pasted/Services/SearchEngine.swift`
- [ ] T042 [US3] Write tests for app name/icon resolution — given a bundle ID, resolve display name and icon via `NSWorkspace`/`NSRunningApplication` — `PastedTests/FilterTests.swift`
- [ ] T043 [US3] Implement app name and icon resolution helper (bundle ID to display name and app icon) — `Pasted/Services/SearchEngine.swift`
- [ ] T044 [US3] Write tests for source app suggestion — typing in filter bar suggests only apps that have contributed clipboard items — `PastedTests/FilterTests.swift`
- [ ] T045 [US3] Implement source app suggestion logic — query distinct `sourceAppBundleID` values from `ClipboardItem` history — `Pasted/Services/SearchEngine.swift`
- [ ] T046 [US3] Implement source app filter token in `FilterTokenView` — displays app icon and name — `Pasted/Views/Search/FilterTokenView.swift`
- [ ] T047 [US3] Add source app option to `FilterPickerView` — shows list of contributing apps with icons — `Pasted/Views/Search/FilterPickerView.swift`

---

## Phase 6: US4 — OCR / Text Recognition in Images (P2)

- [ ] T048 [US4] Write tests for `OCRService` — recognizes text from a test image, returns `OCRResult` with recognized text and confidence — `PastedTests/OCRServiceTests.swift`
- [ ] T049 [US4] Write tests for `OCRService` edge cases — image with no text returns empty result, large image (>4096px) is downscaled before processing — `PastedTests/OCRServiceTests.swift`
- [ ] T050 [US4] Implement `OCRService` with `VNRecognizeTextRequest` (`.accurate` mode) wrapping Vision framework — `Pasted/Services/OCRService.swift`
- [ ] T051 [US4] Implement large image downscaling in `OCRService` — images exceeding 4096x4096 are scaled down before OCR — `Pasted/Services/OCRService.swift`
- [ ] T052 [US4] Write tests for background OCR processing — OCR runs as `Task(priority: .utility)`, does not block main actor — `PastedTests/OCRServiceTests.swift`
- [ ] T053 [US4] Implement background OCR dispatch — spawn `Task(priority: .utility)` per new image capture, persist `OCRResult` on completion — `Pasted/Services/OCRService.swift`
- [ ] T054 [US4] Write tests for OCR text indexing — after OCR completes, searching for recognized text returns the parent image `ClipboardItem` — `PastedTests/SearchEngineTests.swift`
- [ ] T055 [US4] Implement OCR text search integration in `SearchEngine` — extend text search predicate to also match `OCRResult.recognizedText` via relationship — `Pasted/Services/SearchEngine.swift`
- [ ] T056 [US4] Write tests for batch OCR migration — existing un-OCR'd image items are processed with `TaskGroup` (capped concurrency) — `PastedTests/OCRServiceTests.swift`
- [ ] T057 [US4] Implement one-time batch migration for existing un-OCR'd images using `TaskGroup` with max concurrency of 2-4 — `Pasted/Services/OCRService.swift`
- [ ] T058 [US4] Write tests for OCR cancellation — deleting a `ClipboardItem` while OCR is in progress cancels the OCR task — `PastedTests/OCRServiceTests.swift`
- [ ] T059 [US4] Implement cooperative OCR task cancellation on `ClipboardItem` deletion — `Pasted/Services/OCRService.swift`
- [ ] T060 [US4] Integrate OCR trigger into clipboard capture pipeline — when a new image `ClipboardItem` is saved, automatically enqueue OCR — `Pasted/Services/OCRService.swift`

---

## Phase 7: US5 — Filter by Date (P3)

- [ ] T061 [US5] Write tests for date range predicate generation — each `DateRange` case (`.today`, `.yesterday`, `.lastSevenDays`, `.lastThirtyDays`, `.custom`) produces correct `#Predicate` filtering on `ClipboardItem.capturedAt` — `PastedTests/FilterTests.swift`
- [ ] T062 [US5] Implement date range predicate generation on `SearchFilter.dateRange` — `Pasted/Services/SearchEngine.swift`
- [ ] T063 [US5] Write tests for compound predicate with date — date filter + text query + content type all compose with AND logic — `PastedTests/FilterTests.swift`
- [ ] T064 [US5] Implement date range compound predicate composition in `SearchEngine` — `Pasted/Services/SearchEngine.swift`
- [ ] T065 [US5] Implement date filter token in `FilterTokenView` — displays selected range label (e.g., "Today", "Last 7 Days") — `Pasted/Views/Search/FilterTokenView.swift`
- [ ] T066 [US5] Add date range options to `FilterPickerView` — shows presets (Today, Yesterday, Last 7 Days, Last 30 Days) and Custom Range option — `Pasted/Views/Search/FilterPickerView.swift`
- [ ] T067 [US5] Implement custom date range picker UI within `FilterPickerView` — two date pickers for from/to selection — `Pasted/Views/Search/FilterPickerView.swift`
- [ ] T068 [US5] Write UI test for date filter — applying "Today" filter shows only today's items, removing it restores all — `PastedTests/FilterPickerViewTests.swift`

---

## Phase 8: Polish — Performance, Accessibility, and Edge Cases

- [ ] T069 [P] Write performance benchmarks — search with 50,000 items across text + OCR + all filter types combined, assert <100ms — `PastedTests/SearchEngineTests.swift`
- [ ] T070 [P] Profile and optimize `SearchEngine` predicate performance — ensure compound index on (`capturedAt`, `contentType`) is leveraged — `Pasted/Services/SearchEngine.swift`
- [ ] T071 [P] Add accessibility labels and traits to `SearchBarView` — VoiceOver announces search field, filter tokens, and result count — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T072 [P] Add accessibility labels to `FilterTokenView` — VoiceOver announces filter type and removal action — `Pasted/Views/Search/FilterTokenView.swift`
- [ ] T073 [P] Add accessibility labels to `FilterPickerView` — VoiceOver announces available filter options — `Pasted/Views/Search/FilterPickerView.swift`
- [ ] T074 Verify keyboard-first navigation — Tab through search field, filter tokens, and strip items without mouse; Escape dismisses search — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T075 Handle edge case: search while new items are being copied — new matching items appear in real-time filtered results — `Pasted/Services/SearchEngine.swift`
- [ ] T076 Handle edge case: conflicting filters producing empty results — show clear empty state with guidance (e.g., "No items match all active filters") — `Pasted/Views/Search/SearchBarView.swift`
- [ ] T077 Handle edge case: OCR on very large images (8K+) — verify downscaling kicks in and processing stays under 2 seconds — `PastedTests/OCRServiceTests.swift`
- [ ] T078 Write end-to-end integration test — copy 50 items (mix of text, images with OCR text, files), search and filter across all dimensions, verify correct results — `PastedTests/SearchEngineTests.swift`

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| Phase 1: Setup | T001–T004 | Vision framework, directory structure |
| Phase 2: Foundational | T005–T019 | Models, enums, OCRResult @Model, SearchIndex |
| Phase 3: US1 (P1) | T020–T030 | Instant text search, SearchEngine, SearchBarView |
| Phase 4: US2 (P2) | T031–T039 | Content type filter, FilterTokenView, FilterPickerView |
| Phase 5: US3 (P2) | T040–T047 | Source app filter, app icon/name resolution |
| Phase 6: US4 (P2) | T048–T060 | OCR with VNRecognizeTextRequest, background processing |
| Phase 7: US5 (P3) | T061–T068 | Date range filter, date picker UI |
| Phase 8: Polish | T069–T078 | Performance optimization, accessibility, edge cases |
| **Total** | **78 tasks** | |
