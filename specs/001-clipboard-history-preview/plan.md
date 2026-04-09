# Implementation Plan: Clipboard History & Visual Preview

**Branch**: `001-clipboard-history-preview` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-clipboard-history-preview/spec.md`

## Summary

Implement the core clipboard management feature for Pasted: continuous clipboard monitoring via NSPasteboard polling, persistent history storage via SwiftData, a horizontal strip overlay UI with visual previews for all content types (text, rich text, images, URLs, files), keyboard-first navigation and paste injection, and quick-paste shortcuts (Cmd+1-9). This is the foundational feature that all future specs build upon. The strip must render within 200ms of invocation, support 10,000+ items before pruning, and survive application restarts with zero data loss.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: SwiftUI (macOS 14+), AppKit (NSPasteboard, NSPanel, NSImage), CoreGraphics (CGEvent for keyboard simulation)
**Storage**: SwiftData (@Model) for local clipboard history persistence
**Testing**: XCTest + Swift Testing framework
**Target Platform**: macOS 14.0+ (Sonoma and later)
**Project Type**: desktop-app (menu bar agent)
**Performance Goals**: Strip display within 200ms of shortcut invocation (SC-003), paste completes within 2 seconds end-to-end (SC-001), smooth 60fps strip scrolling
**Constraints**: Offline-capable (no network required), <1GB default storage limit with auto-pruning, no external runtime dependencies (Apple frameworks only), no private APIs, Accessibility permission required for global shortcuts and paste injection
**Scale/Scope**: 10,000+ clipboard items before pruning (SC-002), 5 content types (text, rich text, image, URL, file)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | **Privacy-First** | PASS | All data stored locally via SwiftData on-device. No telemetry, no analytics, no network calls. Users control retention via configurable storage limit. Excluded app support deferred to spec 004 but architecture accounts for it (sourceAppBundleID captured). |
| II | **Native macOS Citizen** | PASS | Built entirely with SwiftUI + AppKit + SwiftData. NSPasteboard for clipboard monitoring, NSPanel for overlay window, NSImage for thumbnailing, CGEvent for keyboard simulation. No third-party dependencies. Follows macOS HIG for floating panels and keyboard conventions. |
| III | **Keyboard-First UX** | PASS | Primary invocation via Shift+Cmd+V. Strip navigation via arrow keys. Paste via Return, dismiss via Escape. Quick-paste via Cmd+1-9. Plain text paste via Shift+Return and Shift+Cmd+1-9. Every action is keyboard-accessible. Mouse supported but never required. |
| IV | **Open Source Transparency** | PASS | No proprietary components. All dependencies are Apple system frameworks (publicly documented). No hidden monetization or tracking. MIT-licensed. Builds reproducible from source. |
| V | **Simplicity Over Features** | PASS | This spec covers the minimum viable clipboard experience: capture, display, paste. No search (separate spec), no sync (separate spec), no smart features. Direct SwiftData persistence without repository abstraction layers. Preview generation uses straightforward Apple APIs. |

## Project Structure

### Documentation (this feature)

```text
specs/001-clipboard-history-preview/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — ClipboardItem model
├── quickstart.md        # Phase 1 output — project bootstrap guide
├── checklists/          # Checklists
│   └── requirements.md  # Requirements traceability
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
Pasted/
├── App/
│   ├── PastedApp.swift              # @main SwiftUI App entry point, SwiftData container setup
│   └── AppDelegate.swift            # NSApplicationDelegate for menu bar agent, login item, lifecycle
├── Models/
│   └── ClipboardItem.swift          # @Model entity — clipboard entry with content type, raw data, preview
├── Services/
│   ├── ClipboardMonitor.swift       # NSPasteboard changeCount polling (0.5s timer), content extraction
│   ├── ClipboardStore.swift         # SwiftData CRUD, deduplication (FR-011), pruning (FR-009), pagination
│   └── PasteService.swift           # CGEvent-based paste injection into active app, plain text mode
├── Views/
│   ├── ClipboardStrip/
│   │   ├── ClipboardStripView.swift     # Horizontal ScrollView overlay, item layout, selection state
│   │   ├── ClipboardItemPreview.swift   # Content-type-specific preview rendering (text, image, URL, file, rich text)
│   │   └── StripNavigationHandler.swift # Arrow key navigation, Return/Escape handling, Cmd+1-9 in strip
│   └── Preferences/
│       └── PreferencesView.swift        # Storage limit, launch-at-login, shortcut customization
├── Utilities/
│   ├── KeyboardShortcutManager.swift    # CGEvent tap registration for global shortcuts (Shift+Cmd+V, Cmd+1-9)
│   └── PreviewGenerator.swift           # Thumbnail generation: NSImage scaling, text rendering, file icon lookup
└── Resources/
    └── Assets.xcassets                  # App icon, SF Symbol references

PastedTests/
├── ClipboardMonitorTests.swift      # Polling behavior, change detection, content extraction
├── ClipboardStoreTests.swift        # Persistence, deduplication, pruning, query performance
├── PasteServiceTests.swift          # Paste mode selection (rich/plain), target app handling
└── PreviewGeneratorTests.swift      # Preview output for each content type, edge cases (large items)
```

**Structure Decision**: Single macOS app target with a flat module structure. No frameworks, no packages, no workspace — the app is small enough that a single Xcode project with logical folder grouping is sufficient. Test target mirrors source structure. This aligns with Constitution Principle V (Simplicity Over Features) — avoid premature abstraction.

## Complexity Tracking

> No violations. All design decisions use standard Apple frameworks and straightforward architecture patterns. No extra projects, no repository layers, no dependency injection frameworks.
