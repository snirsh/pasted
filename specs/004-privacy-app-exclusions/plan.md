# Implementation Plan: Privacy & App Exclusions

**Branch**: `004-privacy-app-exclusions` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-privacy-app-exclusions/spec.md`

## Summary

Implement privacy controls for Pasted: auto-exclude known password managers from clipboard capture using a built-in default list of bundle identifiers, allow users to configure additional app exclusions via a preferences UI with app picker, detect concealed clipboard content via the `org.nspasteboard.ConcealedType` pasteboard type, and provide secure history management (individual item deletion and full history clearing with synced deletion to iCloud). Exclusion checks use an in-memory `Set<String>` for O(1) lookup with zero latency impact on clipboard capture. The exclusion list syncs across devices via iCloud so privacy settings are consistent everywhere.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: SwiftUI (macOS 14+), AppKit (NSWorkspace for frontmost app detection, NSPasteboard for concealed type check, NSOpenPanel for app picker), SwiftData, CloudKit (iCloud sync of exclusion list)
**Storage**: SwiftData (@Model) for exclusion list persistence, UserDefaults for concealed detection toggle
**Testing**: XCTest + Swift Testing framework
**Target Platform**: macOS 14.0+ (Sonoma and later)
**Project Type**: desktop-app (menu bar agent)
**Performance Goals**: Zero latency impact on clipboard capture path — exclusion check must complete in microseconds, not milliseconds
**Constraints**: Exclusion check must be O(1) lookup (Set-based, not array scan), no false negatives for default excluded apps, exclusion list expected under 50 apps (no pagination needed), deletion must propagate to iCloud within 30 seconds, no residual data after history clear
**Scale/Scope**: ~9 default excluded apps, user list under 50 apps, deletion applies to full clipboard history (10,000+ items)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | **Privacy-First** | PASS | This feature directly implements the Privacy-First principle. Password manager content is never captured. Users have full control over what is stored (exclusion list) and can delete any or all history. No data leaves the user's device or private iCloud account. Concealed content detection adds an additional privacy layer. |
| II | **Native macOS Citizen** | PASS | Uses exclusively Apple-native APIs: NSWorkspace.shared.frontmostApplication for source app detection, NSPasteboard types for concealed content, SwiftData for persistence, CloudKit for iCloud sync, NSOpenPanel for app picker. No third-party dependencies. Preferences UI follows macOS HIG patterns. |
| III | **Keyboard-First UX** | PASS | Preferences views are fully keyboard-navigable. Exclusion list supports keyboard selection and deletion. App picker is accessible via keyboard. Delete key removes items from history. All controls have accessibility labels. |
| IV | **Open Source Transparency** | PASS | Default exclusion list is hardcoded in source code — fully auditable. No hidden behavior, no proprietary components. Users can inspect exactly which apps are excluded and why. MIT-licensed. |
| V | **Simplicity Over Features** | PASS | Straightforward Set-based exclusion check in the existing clipboard monitor. No complex pattern matching, no heuristics, no ML-based content classification. Bundle ID matching is deterministic and predictable. Concealed type detection is a single pasteboard type check. |

All five constitution principles pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/004-privacy-app-exclusions/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — AppExclusion model
├── quickstart.md        # Phase 1 output — implementation bootstrap guide
├── checklists/
│   └── requirements.md  # Requirements traceability
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
Pasted/
├── Services/
│   ├── Privacy/
│   │   ├── AppExclusionService.swift      # Exclusion list management: add, remove, query, sync in-memory Set
│   │   ├── ConcealedContentDetector.swift # NSPasteboard concealed type check (org.nspasteboard.ConcealedType)
│   │   └── DefaultExclusionList.swift     # Built-in password manager bundle ID list
│   └── ClipboardMonitor.swift             # (existing, updated: checks exclusions + concealed flag before capture)
├── Models/
│   ├── AppExclusion.swift                 # @Model — excluded app with bundle ID, display name, icon, isDefault
│   └── ClipboardItem.swift                # (existing, unchanged)
├── Views/
│   └── Preferences/
│       ├── PrivacyPreferencesView.swift   # Exclusion list management UI, concealed toggle, clear history
│       └── AppPickerView.swift            # App selection sheet (NSOpenPanel + running apps)

PastedTests/
├── AppExclusionServiceTests.swift         # Exclusion logic, default list, add/remove, O(1) lookup verification
├── ConcealedContentDetectorTests.swift    # Concealed type detection, toggle behavior
└── DefaultExclusionListTests.swift        # Default list completeness, bundle ID format validation
```

**Structure Decision**: New privacy-related services are grouped under `Services/Privacy/` to keep the growing `Services/` directory organized. This is a logical subdirectory, not a separate module or framework — consistent with the flat project structure established in spec 001. The `Privacy/` grouping is warranted because this feature introduces three closely related service files. Views extend the existing `Preferences/` directory. Tests remain flat in `PastedTests/` following the established convention.

## Complexity Tracking

> No violations. All design decisions use standard Apple frameworks and straightforward data structures. The in-memory Set for O(1) lookup is a standard Swift collection, not a custom data structure. No extra projects, no repository layers, no abstraction beyond what the feature requires. The `Services/Privacy/` subdirectory is organizational grouping, not architectural complexity.
