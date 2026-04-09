# Implementation Plan: Power Search & OCR

**Branch**: `002-power-search-ocr` | **Date**: 2026-04-09 | **Spec**: `specs/002-power-search-ocr/spec.md`
**Input**: Feature specification from `/specs/002-power-search-ocr/spec.md`

## Summary

Instant full-text search across clipboard history with smart filters (content type, source app, date range) and text recognition in images via Apple Vision framework. Search returns results within 100ms for up to 50,000 items. Images are automatically processed with OCR in the background so their text content becomes searchable. Active filters are displayed as removable visual tokens in the search bar, composing with AND logic.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: SwiftUI (macOS 14+), Apple Vision framework (VNRecognizeTextRequest), SwiftData
**Storage**: SwiftData for local clipboard history and search indexing
**Testing**: XCTest + Swift Testing framework
**Target Platform**: macOS 14.0 (Sonoma) desktop application
**Project Type**: desktop-app
**Performance Goals**: Search results in <100ms for 50,000 items; OCR completes within 2 seconds per image on average hardware; 90%+ OCR accuracy on legible printed text
**Constraints**: Background OCR must not block clipboard capture or UI; no external runtime dependencies (all Apple-native); incremental indexing (no full re-index); keyboard-first interaction for all search and filter controls
**Scale/Scope**: Up to 50,000 clipboard items with search; images processed for OCR on capture

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Rationale |
|-----------|--------|-----------|
| **I. Privacy-First** | PASS | All search indexing and OCR processing happen entirely on-device. No data leaves the machine. Recognized text is stored locally in SwiftData alongside clipboard history. No telemetry or external servers involved. |
| **II. Native macOS Citizen** | PASS | Uses exclusively Apple-native frameworks: SwiftUI for search UI, Vision framework (VNRecognizeTextRequest) for OCR, SwiftData for index persistence. No external libraries or cross-platform abstractions. Filter tokens follow macOS HIG patterns. |
| **III. Keyboard-First UX** | PASS | Search activates immediately on keystroke (type-ahead). Filters are accessible via Cmd+F. Filter tokens can be added/removed with keyboard. Return pastes the first match. All interactions work without mouse. |
| **IV. Open Source Transparency** | PASS | No proprietary components introduced. Vision framework is part of macOS SDK, publicly documented. All code remains MIT-licensed and auditable. No hidden dependencies. |
| **V. Simplicity Over Features** | PASS | Search and OCR are justified by the spec's user scenarios -- without search, clipboard history beyond ~20 items is inaccessible. Implementation uses direct SwiftData predicates rather than building a custom search engine. OCR uses Vision's built-in API with no custom ML models. |

All five constitution principles pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/002-power-search-ocr/
├── plan.md              # This file
├── research.md          # Phase 0 output - research decisions
├── data-model.md        # Phase 1 output - data model additions
├── quickstart.md        # Phase 1 output - getting started guide
├── checklists/
│   └── requirements.md  # Requirements checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
Pasted/
├── Services/
│   ├── SearchEngine.swift          # Full-text search with SwiftData predicates and filtering
│   ├── SearchIndex.swift           # Incremental search index management
│   └── OCRService.swift            # Vision framework text recognition wrapper
├── Views/
│   ├── Search/
│   │   ├── SearchBarView.swift     # Search field with inline filter tokens
│   │   ├── FilterTokenView.swift   # Individual removable filter chip component
│   │   └── FilterPickerView.swift  # Filter selection popover/menu UI
│   └── ClipboardStrip/
│       └── (existing views updated to accept filtered results)
├── Models/
│   ├── SearchQuery.swift           # Combined search text + active filters model
│   ├── SearchFilter.swift          # Filter type definitions (content type, source app, date range)
│   └── OCRResult.swift             # OCR recognized text with confidence and metadata

PastedTests/
├── SearchEngineTests.swift         # Search query execution, predicate building, performance
├── OCRServiceTests.swift           # Vision framework integration, background processing
└── FilterTests.swift               # Filter composition, AND logic, token management
```

**Structure Decision**: Single macOS application project. New files are organized into existing `Services/`, `Views/`, and `Models/` directories following the patterns established in spec 001 (Clipboard History). Search views get their own subdirectory under `Views/Search/` since they introduce multiple related components. Tests follow the flat `PastedTests/` convention.

## Complexity Tracking

No complexity violations detected. All implementation choices use direct Apple-native APIs and straightforward SwiftData predicates. No external dependencies, no custom search engine, no abstraction layers beyond what the feature requires.
