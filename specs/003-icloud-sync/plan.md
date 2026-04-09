# Implementation Plan: iCloud Sync

**Branch**: `003-icloud-sync` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-icloud-sync/spec.md`

## Summary

Sync clipboard history across the user's Mac devices via CloudKit, using an offline-first architecture with automatic conflict resolution. Each Mac captures clipboard items locally via SwiftData as usual, then syncs them to the user's private iCloud database in the background. Incremental sync uses CKFetchRecordZoneChangesOperation with server change tokens for efficiency. Conflicts are resolved automatically — new items are union-merged by timestamp, deletions propagate via soft-delete flags, and metadata conflicts use last-write-wins. A custom record zone ("PastedClipboardZone") enables atomic commits and per-device change tracking. The user controls sync via a toggle in preferences and sees real-time sync status.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: CloudKit (CKContainer, CKDatabase, CKRecord, CKAsset, CKSubscription), SwiftUI (macOS 14+), AppKit (network reachability)
**Storage**: SwiftData (@Model) for local clipboard history; CloudKit private database (CKRecord/CKAsset) for remote sync
**Testing**: XCTest + Swift Testing framework
**Target Platform**: macOS 14.0+ (Sonoma and later)
**Project Type**: desktop-app (menu bar agent)
**Performance Goals**: Items sync between devices within 30 seconds when both online (SC-001), initial sync of 1,000 items within 5 minutes (SC-004), sync status updates within 5 seconds of state change (SC-005)
**Constraints**: Offline-first (clipboard capture must never depend on network), <500MB iCloud storage for 10,000 items (SC-006), CloudKit record field limit ~1MB (larger items via CKAsset), CloudKit absolute asset limit ~250MB, no external runtime dependencies
**Scale/Scope**: 10,000+ synced clipboard items across unlimited Mac devices per Apple ID

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | **Privacy-First** | PASS | All data syncs exclusively through the user's private iCloud database (CKContainer.default().privateCloudDatabase). Data is never visible to Pasted developers, other users, or any external server. No shared containers, no public database. Sync is opt-in — disabled by default until the user explicitly enables it in preferences. Users can disable sync at any time, and local data is never deleted by disabling sync. |
| II | **Native macOS Citizen** | PASS | Built entirely with CloudKit (Apple's first-party sync framework), SwiftData, and SwiftUI. CloudKit is the Apple-recommended approach for iCloud data synchronization. No third-party sync libraries, no custom server infrastructure, no WebSocket layers. Uses CKSubscription for push-based notifications — the native CloudKit mechanism. |
| III | **Keyboard-First UX** | PASS | Sync operates entirely in the background with no user interaction required during normal operation. The sync preferences view (toggle, status) is accessible via keyboard navigation like all other preferences. No sync-related modal dialogs or conflict resolution prompts that would interrupt keyboard workflows. |
| IV | **Open Source Transparency** | PASS | No proprietary components. CloudKit is a publicly documented Apple framework. All sync logic is in-repo and auditable. No hidden server-side code — CloudKit infrastructure is managed by Apple as part of every iCloud account. MIT-licensed. |
| V | **Simplicity Over Features** | PASS | Uses CloudKit's built-in change token mechanism rather than building a custom sync protocol. Conflict resolution is fully automatic (no user-facing conflict dialogs). Single custom record zone rather than complex multi-zone architecture. No CoreData+CloudKit (NSPersistentCloudKitContainer) abstraction — direct CloudKit operations for full control over sync behavior and error handling. |

## Project Structure

### Documentation (this feature)

```text
specs/003-icloud-sync/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology decisions
├── data-model.md        # Phase 1 output — sync data models
├── quickstart.md        # Phase 1 output — CloudKit bootstrap guide
├── checklists/          # Checklists
│   └── requirements.md  # Requirements traceability
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
Pasted/
├── Services/
│   ├── Sync/
│   │   ├── SyncEngine.swift             # CloudKit sync orchestration — coordinates fetch, push, and subscription lifecycle
│   │   ├── SyncRecordMapper.swift       # Bidirectional mapping between SwiftData ClipboardItem and CKRecord
│   │   ├── ConflictResolver.swift       # Timestamp-based merge strategy: union-merge items, last-write-wins metadata, delete-propagation
│   │   ├── SyncStateTracker.swift       # Per-device sync progress tracking, change token persistence, pending counts
│   │   └── CloudKitManager.swift        # CKContainer/CKDatabase wrapper — zone creation, subscriptions, account status monitoring
│   ├── ClipboardMonitor.swift           # (existing — unchanged)
│   ├── ClipboardStore.swift             # (existing — minor addition: syncStatus updates on save)
│   └── PasteService.swift               # (existing — unchanged)
├── Models/
│   ├── ClipboardItem.swift              # (existing — additions: syncStatus enum, cloudRecordName property)
│   ├── SyncRecord.swift                 # CloudKit record model — maps CKRecord fields for type-safe access
│   ├── SyncState.swift                  # @Model — per-device sync progress (change token, pending counts, status)
│   └── DeviceInfo.swift                 # @Model — device identification (UUID, name, version, last seen)
├── Views/
│   └── Preferences/
│       ├── PreferencesView.swift        # (existing — add sync tab/section)
│       └── SyncPreferencesView.swift    # Sync toggle, status indicator, device list, last sync time

PastedTests/
├── SyncEngineTests.swift                # End-to-end sync orchestration, offline queue drain, subscription handling
├── ConflictResolverTests.swift          # Merge scenarios: concurrent edits, delete vs. modify, metadata conflicts
└── SyncRecordMapperTests.swift          # Round-trip mapping fidelity for all content types, large asset handling
```

**Structure Decision**: Sync services are grouped under a `Services/Sync/` subdirectory to keep the sync concern cohesive without introducing a separate framework or package. This mirrors the existing flat structure from spec 001 while acknowledging that sync has enough internal components (5 files) to warrant a subfolder. No new Xcode targets — sync code lives in the main app target. Test files are added to the existing PastedTests target.

## Complexity Tracking

> No violations. All design decisions use Apple's first-party CloudKit framework with straightforward orchestration patterns. No custom sync protocols, no external dependencies, no repository abstraction layers. Direct CloudKit operations (CKFetchRecordZoneChangesOperation, CKModifyRecordsOperation) are used instead of higher-level abstractions like NSPersistentCloudKitContainer to maintain full control over conflict resolution and sync behavior — this is the simpler path for our specific requirements.
