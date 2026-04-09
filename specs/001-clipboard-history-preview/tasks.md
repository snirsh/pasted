# Tasks: Clipboard History & Visual Preview

**Feature**: `001-clipboard-history-preview` | **Date**: 2026-04-09
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Data Model**: [data-model.md](./data-model.md)

---

## Phase 1: Setup

- [ ] T001 [P] Create Xcode project "Pasted" as a macOS App (SwiftUI lifecycle, deployment target macOS 14.0+), configure as menu bar agent (`LSUIElement = YES` in Info.plist) — `Pasted/`
- [ ] T002 [P] Create folder structure: `Pasted/App/`, `Pasted/Models/`, `Pasted/Services/`, `Pasted/Views/ClipboardStrip/`, `Pasted/Views/Preferences/`, `Pasted/Utilities/`, `Pasted/Resources/Assets.xcassets`
- [ ] T003 [P] Create test target `PastedTests/` with XCTest + Swift Testing framework configured
- [ ] T004 Add Accessibility entitlement and sandbox configuration (or disable sandbox) for CGEvent tap and NSPasteboard access — `Pasted/Pasted.entitlements`
- [ ] T005 Configure SwiftData `ModelContainer` with `ClipboardItem` schema in the app entry point, store location `~/Library/Application Support/Pasted/default.store` — `Pasted/App/PastedApp.swift`
- [ ] T006 Create `AppDelegate.swift` with `NSApplicationDelegate` for menu bar agent lifecycle, status bar item setup, and Accessibility permission prompt on first launch — `Pasted/App/AppDelegate.swift`

---

## Phase 2: Foundational

- [ ] T007 Implement `ContentType` enum with cases: `text`, `richText`, `image`, `url`, `file` — raw value `String`, conforming to `Codable`, `CaseIterable` — `Pasted/Models/ClipboardItem.swift`
- [ ] T008 Implement `ClipboardItem` `@Model` class with all attributes (`id`, `contentType`, `rawData`, `plainTextContent`, `previewThumbnail`, `sourceAppBundleID`, `sourceAppName`, `capturedAt`, `byteSize`), `@Attribute(.externalStorage)` on `rawData` and `previewThumbnail`, `@Attribute(.unique)` on `id` — `Pasted/Models/ClipboardItem.swift`
- [ ] T009 Write unit tests for `ClipboardItem` initialization, validation (non-empty rawData, byteSize consistency), and `ContentType` encoding/decoding — `PastedTests/ClipboardItemTests.swift`
- [ ] T010 Implement `ClipboardStore` service with SwiftData CRUD operations: `save(_:)`, `fetchRecent(limit:offset:)`, `fetchAll()`, `delete(_:)`, `totalByteSize()` — `Pasted/Services/ClipboardStore.swift`
- [ ] T011 Implement deduplication logic in `ClipboardStore` (FR-011): SHA-256 hash comparison of `rawData` against the most recent item before persisting — `Pasted/Services/ClipboardStore.swift`
- [ ] T012 Write unit tests for `ClipboardStore`: save, fetch, delete, deduplication (consecutive identical items rejected), query ordering (newest first) — `PastedTests/ClipboardStoreTests.swift`

---

## Phase 3: US1 — Copy and Access Clipboard History (P1) MVP

### Tests First

- [ ] T013 Write tests for `ClipboardMonitor`: polling detects `changeCount` changes, content extraction for each `ContentType`, ignores unchanged changeCount, extracts `sourceAppBundleID` from `NSWorkspace` — `PastedTests/ClipboardMonitorTests.swift`
- [ ] T014 Write tests for `KeyboardShortcutManager`: Shift+Cmd+V toggles strip, Escape dismisses strip, Return triggers paste, arrow keys change selection index — `PastedTests/KeyboardShortcutManagerTests.swift`
- [ ] T015 Write tests for `PasteService`: writes correct UTType to pasteboard, simulates Cmd+V CGEvent, restores original pasteboard contents after paste, handles missing Accessibility permission gracefully — `PastedTests/PasteServiceTests.swift`

### Implementation

- [ ] T016 Implement `ClipboardMonitor` service: `Timer.scheduledTimer` at 0.5s interval polling `NSPasteboard.general.changeCount`, content extraction for all 5 `ContentType` cases (text, richText, image, url, file), source app detection via `NSWorkspace.shared.frontmostApplication`, delegate/callback to `ClipboardStore.save(_:)` — `Pasted/Services/ClipboardMonitor.swift`
- [ ] T017 Implement `KeyboardShortcutManager`: `CGEvent.tapCreate` for global keyboard interception, register Shift+Cmd+V to toggle strip, add event tap to run loop as `CFRunLoopSource`, request Accessibility permission if not granted — `Pasted/Utilities/KeyboardShortcutManager.swift`
- [ ] T018 Implement `NSPanel` floating overlay: borderless, non-activating (`styleMask: [.nonactivatingPanel, .borderless]`), `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, `NSVisualEffectView` with `.hudWindow` material, host SwiftUI via `NSHostingView`, centered horizontally near bottom of active screen — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`
- [ ] T019 Implement `ClipboardStripView` SwiftUI view: horizontal `ScrollView(.horizontal)` with `@Query` sorted by `capturedAt` descending, selection state tracking, visual highlight on selected item, basic text label per item (full previews in Phase 4) — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`
- [ ] T020 Implement `StripNavigationHandler`: arrow key left/right to move selection, Return to trigger paste of selected item, Escape to dismiss strip, update selection highlight — `Pasted/Views/ClipboardStrip/StripNavigationHandler.swift`
- [ ] T021 Implement `PasteService`: save current pasteboard contents, write selected `ClipboardItem.rawData` to `NSPasteboard.general` with correct UTType, simulate Cmd+V via `CGEvent` (keycode 9 + Cmd flag, keyDown + keyUp), restore original pasteboard after ~100ms delay, dismiss strip before paste — `Pasted/Services/PasteService.swift`
- [ ] T022 Wire up end-to-end flow: `PastedApp` initializes `ClipboardMonitor` + `KeyboardShortcutManager`, Shift+Cmd+V shows/hides strip panel, strip loads items from `ClipboardStore`, Return pastes via `PasteService` — `Pasted/App/PastedApp.swift`

### Verification

- [ ] T023 Integration test: copy 5 different items (text, image, URL, file, rich text), invoke Pasted, verify all 5 appear in chronological order, select one, confirm paste — acceptance scenarios US1.1-US1.4 — `PastedTests/ClipboardMonitorTests.swift`

---

## Phase 4: US2 — Visual Previews for All Content Types (P1)

### Tests First

- [ ] T024 [P] Write tests for `PreviewGenerator` plain text: input UTF-8 text data, output JPEG thumbnail showing first ~4 lines, handles empty string, handles 100K-line text (truncated preview with size indicator) — `PastedTests/PreviewGeneratorTests.swift`
- [ ] T025 [P] Write tests for `PreviewGenerator` rich text: input RTF data, output JPEG thumbnail with styled text; input HTML data, output JPEG thumbnail with formatted text — `PastedTests/PreviewGeneratorTests.swift`
- [ ] T026 [P] Write tests for `PreviewGenerator` image: input PNG/TIFF data, output scaled JPEG thumbnail (target 240x160pt @2x), handles large images (50MB+), preserves aspect ratio — `PastedTests/PreviewGeneratorTests.swift`
- [ ] T027 [P] Write tests for `PreviewGenerator` URL: input URL string data, output thumbnail with link icon and URL text, handles title metadata when available — `PastedTests/PreviewGeneratorTests.swift`
- [ ] T028 [P] Write tests for `PreviewGenerator` file: input file URL data, output thumbnail with file icon from `NSWorkspace.shared.icon(forFile:)` and filename — `PastedTests/PreviewGeneratorTests.swift`

### Implementation

- [ ] T029 Implement `PreviewGenerator` core: dispatcher method that routes to type-specific generators based on `ContentType`, returns `Data?` (JPEG compressed ~80% quality) — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T030 [P] Implement plain text preview: render first ~4 lines using `NSTextField`/`NSTextView` snapshot with system monospace font, truncate with ellipsis, capture as `NSImage`, compress to JPEG — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T031 [P] Implement rich text preview: convert RTF/HTML `Data` to `NSAttributedString`, render in fixed-size `NSTextView`, snapshot to `NSImage`, compress to JPEG — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T032 [P] Implement image preview: scale `NSImage` to 240x160pt (480x320px @2x Retina) preserving aspect ratio, compress to JPEG — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T033 [P] Implement URL preview: render URL string with `link.badge` SF Symbol, show page title if available in pasteboard metadata, capture as `NSImage`, compress to JPEG — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T034 [P] Implement file preview: retrieve file icon via `NSWorkspace.shared.icon(forFile:)`, render icon with filename label below, capture as `NSImage`, compress to JPEG — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T035 Integrate `PreviewGenerator` into `ClipboardMonitor`: generate `previewThumbnail` at capture time, store in `ClipboardItem.previewThumbnail` before persisting — `Pasted/Services/ClipboardMonitor.swift`
- [ ] T036 Implement `ClipboardItemPreview` SwiftUI view: display `previewThumbnail` from `ClipboardItem` as an `Image`, show content-type icon badge, handle missing thumbnail gracefully (fallback to type icon) — `Pasted/Views/ClipboardStrip/ClipboardItemPreview.swift`
- [ ] T037 Replace basic text labels in `ClipboardStripView` with `ClipboardItemPreview` for each item in the horizontal strip — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`

### Verification

- [ ] T038 Integration test: copy one item of each type (text, rich text, image, URL, file), invoke strip, verify each has a distinguishable content-appropriate preview thumbnail — acceptance scenarios US2.1-US2.5 — `PastedTests/PreviewGeneratorTests.swift`

---

## Phase 5: US5 — Persistent History Across Restarts (P1)

### Tests First

- [ ] T039 Write tests for persistence: save 100 items, create new `ModelContainer` from same store URL, verify all 100 items are present with correct data, previews, and ordering — `PastedTests/ClipboardStoreTests.swift`
- [ ] T040 Write tests for auto-pruning (FR-009): insert items exceeding 1GB total `byteSize`, verify oldest items are deleted in batches of 100 until storage drops below 90% of limit (hysteresis) — `PastedTests/ClipboardStoreTests.swift`

### Implementation

- [ ] T041 Implement auto-pruning in `ClipboardStore`: after each save, check `totalByteSize()` against configurable storage limit (default 1GB), if exceeded delete oldest items in batches of 100 until below 90% threshold — `Pasted/Services/ClipboardStore.swift`
- [ ] T042 Implement launch-at-login using `SMAppService.mainApp` (macOS 13+) in `AppDelegate`, add toggle in preferences — `Pasted/App/AppDelegate.swift`
- [ ] T043 Implement `PreferencesView` with storage limit slider, launch-at-login toggle, and current storage usage display — `Pasted/Views/Preferences/PreferencesView.swift`
- [ ] T044 Verify SwiftData store survives app termination: configure `ModelContainer` with explicit store URL (`~/Library/Application Support/Pasted/default.store`), ensure `autosaveEnabled` is true — `Pasted/App/PastedApp.swift`

### Verification

- [ ] T045 Integration test: save 5 items, tear down `ModelContainer`, create new container from same store, verify all 5 items persist with original previews — acceptance scenarios US5.1-US5.2 — `PastedTests/ClipboardStoreTests.swift`

---

## Phase 6: US3 — Quick Paste via Number Shortcuts (P2)

### Tests First

- [ ] T046 Write tests for `KeyboardShortcutManager` Cmd+1-9: when strip is hidden, Cmd+N triggers quick paste of Nth most recent item; when strip is visible, Cmd+N selects and pastes Nth item and dismisses strip; Cmd+N with N > history count does nothing (no error) — `PastedTests/KeyboardShortcutManagerTests.swift`

### Implementation

- [ ] T047 Extend `KeyboardShortcutManager` to intercept Cmd+1 through Cmd+9 (keycodes 18-26), resolve to Nth most recent `ClipboardItem` via `ClipboardStore.fetchRecent(limit:offset:)`, trigger `PasteService` — `Pasted/Utilities/KeyboardShortcutManager.swift`
- [ ] T048 Handle Cmd+1-9 when strip is visible in `StripNavigationHandler`: select the Nth item, paste, and dismiss — `Pasted/Views/ClipboardStrip/StripNavigationHandler.swift`

### Verification

- [ ] T049 Integration test: copy 3 items, press Cmd+2 (strip hidden), verify 2nd most recent item is pasted; press Cmd+5 with only 3 items, verify nothing happens — acceptance scenarios US3.1-US3.3 — `PastedTests/KeyboardShortcutManagerTests.swift`

---

## Phase 7: US4 — Paste as Plain Text (P2)

### Tests First

- [ ] T050 Write tests for `PasteService` plain text mode: Shift+Return pastes only `public.utf8-plain-text` representation (formatting stripped), Shift+Return on image item does nothing or shows indication, Shift+Cmd+1-9 pastes Nth item as plain text — `PastedTests/PasteServiceTests.swift`

### Implementation

- [ ] T051 Extend `PasteService` with `pasteAsPlainText(_:)` method: write only `public.utf8-plain-text` to `NSPasteboard.general` using `ClipboardItem.plainTextContent`, skip items where `plainTextContent` is nil (images, files without text) — `Pasted/Services/PasteService.swift`
- [ ] T052 Register Shift+Return in `StripNavigationHandler`: when strip is visible and item selected, call `PasteService.pasteAsPlainText(_:)` instead of regular paste — `Pasted/Views/ClipboardStrip/StripNavigationHandler.swift`
- [ ] T053 Register Shift+Cmd+1-9 in `KeyboardShortcutManager`: resolve Nth item, call `PasteService.pasteAsPlainText(_:)` — `Pasted/Utilities/KeyboardShortcutManager.swift`

### Verification

- [ ] T054 Integration test: copy rich HTML text, invoke strip, select item, press Shift+Return, verify plain text (no formatting) pasted; copy image, Shift+Return does nothing — acceptance scenarios US4.1-US4.3 — `PastedTests/PasteServiceTests.swift`

---

## Phase 8: Polish

- [ ] T055 Accessibility: add VoiceOver labels and traits to `ClipboardStripView` items (content type, text preview snippet, position in list), ensure strip navigation is announced — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`
- [ ] T056 Accessibility: add VoiceOver support to `ClipboardItemPreview` (describe content type and text content for non-visual users) — `Pasted/Views/ClipboardStrip/ClipboardItemPreview.swift`
- [ ] T057 [P] Animate strip panel: slide-up + fade-in on show, slide-down + fade-out on dismiss, keep duration under 150ms to stay within 200ms strip display budget (SC-003) — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`
- [ ] T058 [P] Performance: profile strip rendering with 10,000 items using Instruments, ensure `LazyHStack` or virtualized scrolling is used, verify 60fps scroll and <200ms initial display (SC-003) — `Pasted/Views/ClipboardStrip/ClipboardStripView.swift`
- [ ] T059 [P] Performance: profile `PreviewGenerator` for large items (50MB image, 100K-line text), ensure preview generation completes within 500ms and does not block main thread — `Pasted/Utilities/PreviewGenerator.swift`
- [ ] T060 Add app icon to `Assets.xcassets`, configure menu bar status item icon (SF Symbol `clipboard`) — `Pasted/Resources/Assets.xcassets`
- [ ] T061 Final pass: run full test suite, verify all acceptance scenarios (US1-US5), check for memory leaks with Instruments Leaks template, confirm all FR-001 through FR-011 are met

---

## Dependencies & Execution Order

```
Phase 1: Setup (T001-T006)
    |
    v
Phase 2: Foundational (T007-T012) -- depends on project + SwiftData container
    |
    v
Phase 3: US1 - MVP (T013-T023) -- depends on ClipboardItem model + ClipboardStore
    |
    v
Phase 4: US2 (T024-T038) --+-- depends on ClipboardMonitor + StripView from Phase 3
    |                       |
    v                       |
Phase 5: US5 (T039-T045) --+-- depends on ClipboardStore from Phase 2 (can start in parallel with Phase 4)
    |
    v
Phase 6: US3 (T046-T049) -- depends on KeyboardShortcutManager + PasteService from Phase 3
    |
    v
Phase 7: US4 (T050-T054) -- depends on PasteService from Phase 3 + Cmd+1-9 from Phase 6
    |
    v
Phase 8: Polish (T055-T061) -- depends on all prior phases
```

**Critical Path**: Phase 1 -> Phase 2 -> Phase 3 -> Phase 6 -> Phase 7 -> Phase 8

**Parallel Opportunities**:
- Phase 4 (US2) and Phase 5 (US5) can run in parallel after Phase 3 completes
- Within Phase 4, all five content-type preview generators (T030-T034) are independent and parallelizable
- Within Phase 4, all five content-type preview tests (T024-T028) are independent and parallelizable
- Within Phase 1, project creation (T001), folder structure (T002), and test target (T003) can run in parallel
- Within Phase 8, animation (T057), performance profiling (T058-T059), and app icon (T060) can run in parallel

---

## Parallel Execution Example

**Two-agent split after Phase 3 completes:**

| Step | Agent A | Agent B |
|------|---------|---------|
| 1 | Phase 4: T024-T028 (preview tests) | Phase 5: T039-T040 (persistence tests) |
| 2 | Phase 4: T029-T034 (preview generators) | Phase 5: T041-T044 (pruning, login, prefs) |
| 3 | Phase 4: T035-T038 (integration + views) | Phase 5: T045 (verification) |
| 4 | Phase 6: T046-T049 (Cmd+1-9 shortcuts) | Phase 8: T057-T059 (animation + perf) |
| 5 | Phase 7: T050-T054 (plain text paste) | Phase 8: T055-T056 (accessibility) |
| 6 | -- sync -- | -- sync -- |
| 7 | Phase 8: T060-T061 (icon + final) | -- |

---

## Implementation Strategy

### TDD Enforcement
Every phase (except Setup) follows test-first: write failing tests, then implement until tests pass. Test tasks are explicitly listed before implementation tasks in each phase.

### Task Sizing
Each task targets 30-90 minutes of implementation time. Tasks with `[P]` can be assigned to parallel agents or worked on simultaneously when dependencies are satisfied.

### File Ownership
- `Pasted/Models/ClipboardItem.swift` — owned by Phase 2 (T007-T008), read by all subsequent phases
- `Pasted/Services/ClipboardStore.swift` — owned by Phase 2 (T010-T011), extended in Phase 5 (T041)
- `Pasted/Services/ClipboardMonitor.swift` — owned by Phase 3 (T016), extended in Phase 4 (T035)
- `Pasted/Services/PasteService.swift` — owned by Phase 3 (T021), extended in Phase 7 (T051)
- `Pasted/Utilities/KeyboardShortcutManager.swift` — owned by Phase 3 (T017), extended in Phase 6 (T047) and Phase 7 (T053)
- `Pasted/Views/ClipboardStrip/StripNavigationHandler.swift` — owned by Phase 3 (T020), extended in Phase 6 (T048) and Phase 7 (T052)
- `Pasted/Utilities/PreviewGenerator.swift` — owned by Phase 4 (T029-T034)

### Requirements Traceability
| Requirement | Tasks |
|-------------|-------|
| FR-001 (clipboard monitoring) | T013, T016 |
| FR-002 (persistent storage) | T039-T041, T044-T045 |
| FR-003 (horizontal strip overlay) | T018-T019 |
| FR-004 (visual previews) | T024-T038 |
| FR-005 (keyboard navigation) | T014, T017, T020 |
| FR-006 (paste into active app) | T015, T021 |
| FR-007 (Cmd+1-9 quick paste) | T046-T049 |
| FR-008 (plain text paste) | T050-T054 |
| FR-009 (auto-pruning) | T040-T041 |
| FR-010 (launch at login) | T042 |
| FR-011 (deduplication) | T011-T012 |

### Success Criteria Coverage
| Criterion | Verified By |
|-----------|-------------|
| SC-001 (paste within 2s) | T061 (final pass) |
| SC-002 (10K items before pruning) | T040-T041, T058 |
| SC-003 (strip display within 200ms) | T057-T058 |
| SC-004 (recognizable previews) | T038 |
| SC-005 (all content types captured) | T023 |
| SC-006 (history intact after restart) | T045 |
