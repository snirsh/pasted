# Tasks: iCloud Sync

**Branch**: `003-icloud-sync` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

> **Dependency**: This feature depends on **spec 001 (Clipboard History & Visual Preview)**. The existing `ClipboardItem` model (`Pasted/Models/ClipboardItem.swift`), `ClipboardStore` (`Pasted/Services/ClipboardStore.swift`), and `ClipboardMonitor` (`Pasted/Services/ClipboardMonitor.swift`) must be implemented before this feature can begin. Tasks in Phase 2+ extend these existing files.

---

## Phase 1: Setup

CloudKit capability, iCloud container, entitlements, and project scaffolding.

- [ ] T001 [P] Add iCloud capability with CloudKit to the Pasted target in Xcode — enable CloudKit under Signing & Capabilities and create container `iCloud.com.pasted.clipboard` in `Pasted/Pasted.entitlements`
- [ ] T002 [P] Add Background Modes capability with Remote Notifications to the Pasted target in `Pasted/Pasted.entitlements`
- [ ] T003 [P] Register for remote notifications in `Pasted/App/AppDelegate.swift` — add `NSApplication.shared.registerForRemoteNotifications()` in `applicationDidFinishLaunching` and add `didReceiveRemoteNotification` handler stub
- [ ] T004 [P] Create directory structure `Pasted/Services/Sync/` for sync service files

---

## Phase 2: Foundational

SyncRecord mapper, SyncState model, DeviceInfo model, CloudKitManager, CKRecordZone setup. No user story labels — these are shared infrastructure.

- [ ] T005 Add `syncStatus` enum (`local`, `synced`, `pendingUpload`, `pendingDownload`, `localOnly`) and `cloudRecordName: String?` property to existing `ClipboardItem` model in `Pasted/Models/ClipboardItem.swift`
- [ ] T006 [P] Create `SyncState` SwiftData `@Model` with `deviceID`, `lastSyncToken`, `pendingUploadCount`, `pendingDownloadCount`, `syncStatus`, `lastSyncAt`, `lastError` in `Pasted/Models/SyncState.swift`
- [ ] T007 [P] Create `DeviceInfo` SwiftData `@Model` with `deviceID`, `deviceName`, `pastedVersion`, `lastSeenAt` in `Pasted/Models/DeviceInfo.swift`
- [ ] T008 Create `SyncRecord` struct with all CKRecord field mappings (`recordName`, `contentType`, `rawData`, `asset`, `plainTextContent`, `sourceAppBundleID`, `capturedAt`, `deviceID`, `modifiedAt`, `isPinned`, `isDeleted`) in `Pasted/Models/SyncRecord.swift`
- [ ] T009 Create `SyncRecordMapper` with `toCloudKitRecord(_:zoneName:)` and `fromCloudKitRecord(_:)` methods for bidirectional mapping between `ClipboardItem` and `CKRecord` in `Pasted/Services/Sync/SyncRecordMapper.swift`
- [ ] T010 Write tests for `SyncRecordMapper` — round-trip mapping fidelity for text, image, URL, rich text, and file content types in `PastedTests/SyncRecordMapperTests.swift`
- [ ] T011 Implement CKAsset handling in `SyncRecordMapper` — items with `rawData.count > 1_000_000` use CKAsset via temp file; items >250MB marked `.localOnly` in `Pasted/Services/Sync/SyncRecordMapper.swift`
- [ ] T012 Write tests for large asset handling in `SyncRecordMapper` — verify threshold routing (inline vs. CKAsset vs. localOnly) in `PastedTests/SyncRecordMapperTests.swift`
- [ ] T013 Create `CloudKitManager` with CKContainer/CKDatabase wrapper, account status checking (`accountStatus`), and zone creation (`PastedClipboardZone`) in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T014 Implement `CKRecordZone` creation (idempotent) for `PastedClipboardZone` in `CloudKitManager.ensureZoneExists()` in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T015 Implement iCloud account status monitoring (`CKContainer.default().accountStatus`) with `NotificationCenter` observation for account changes in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T016 Create `SyncStateTracker` for per-device sync progress tracking, change token persistence (NSKeyedArchiver-encoded `CKServerChangeToken`), and pending count recalculation in `Pasted/Services/Sync/SyncStateTracker.swift`
- [ ] T017 Implement local device identity — generate UUID on first launch, persist in `UserDefaults`, and register `DeviceInfo` in SwiftData in `Pasted/Services/Sync/CloudKitManager.swift`

---

## Phase 3: US1 — Automatic Sync Between Macs (P1) MVP

SyncEngine orchestration, CKSubscription, upload/download operations. This is the core value of iCloud sync.

- [ ] T018 [US1] Write tests for SyncEngine upload — verify `ClipboardItem` with `.pendingUpload` status is converted to `CKRecord` and submitted via `CKModifyRecordsOperation` in `PastedTests/SyncEngineTests.swift`
- [ ] T019 [US1] Write tests for SyncEngine download — verify `CKRecord` fetched via `CKFetchRecordZoneChangesOperation` is converted to `ClipboardItem` and saved to SwiftData in `PastedTests/SyncEngineTests.swift`
- [ ] T020 [US1] Create `SyncEngine` with `shared` singleton, `fetchChanges()`, and `pushChanges()` orchestration methods in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T021 [US1] Implement `pushChanges()` — query `ClipboardItem` where `syncStatus == .pendingUpload`, batch into `CKModifyRecordsOperation` (max 400 per batch), update `syncStatus` to `.synced` on success in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T022 [US1] Implement `fetchChanges()` — use `CKFetchRecordZoneChangesOperation` with stored server change token from `SyncState`, process new/modified/deleted records, persist updated change token in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T023 [US1] Implement `CKDatabaseSubscription` creation (subscriptionID: `"clipboard-changes"`) with silent push notification in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T024 [US1] Wire `didReceiveRemoteNotification` in `Pasted/App/AppDelegate.swift` to trigger `SyncEngine.shared.fetchChanges()` when subscription notification arrives
- [ ] T025 [US1] Set newly captured items to `syncStatus = .pendingUpload` when sync is enabled in `Pasted/Services/ClipboardStore.swift`
- [ ] T026 [US1] Trigger `SyncEngine.shared.pushChanges()` after each clipboard capture when sync is enabled in `Pasted/Services/ClipboardStore.swift`
- [ ] T027 [US1] Implement initial sync flow — when `SyncState.lastSyncToken` is nil, perform full zone fetch (all records) with progressive processing (newest first) in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T028 [US1] Upload local `DeviceInfo` record to CloudKit on sync enable and update `lastSeenAt` on each successful sync in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T029 [US1] Write integration test — end-to-end round-trip: create ClipboardItem locally, push to CloudKit mock, fetch back, verify content fidelity in `PastedTests/SyncEngineTests.swift`

---

## Phase 4: US2 — Offline-First with Background Sync (P1)

Offline queue, network monitoring, automatic background drain on reconnection.

- [ ] T030 [US2] Write tests for offline queue — verify items captured while offline get `syncStatus = .pendingUpload` and persist across app restart in `PastedTests/SyncEngineTests.swift`
- [ ] T031 [US2] Write tests for network restoration drain — verify all `.pendingUpload` items are pushed when network becomes available in `PastedTests/SyncEngineTests.swift`
- [ ] T032 [US2] Implement `NWPathMonitor`-based network reachability observer in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T033 [US2] Trigger automatic queue drain (`pushChanges()` + `fetchChanges()`) when `NWPathMonitor` transitions from `.unsatisfied` to `.satisfied` in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T034 [US2] Update `SyncState.syncStatus` to `.offline` when network is unavailable and back to `.idle`/`.syncing` on restoration in `Pasted/Services/Sync/SyncStateTracker.swift`
- [ ] T035 [US2] Ensure `ClipboardMonitor` and `ClipboardStore` operate with zero degradation when network is unavailable — verify no sync code blocks clipboard capture path in `Pasted/Services/ClipboardStore.swift`
- [ ] T036 [US2] Implement batch drain with retry — process `.pendingUpload` items in batches of 400 with exponential backoff on `CKError.requestRateLimited` in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T037 [US2] Write test for merge of offline items from two devices — verify union merge produces combined history sorted by timestamp in `PastedTests/SyncEngineTests.swift`

---

## Phase 5: US3 — Conflict Resolution (P2)

ConflictResolver, merge strategies, deletion propagation.

- [ ] T038 [US3] Write tests for ConflictResolver — concurrent new items (union merge), delete vs. modify (delete wins), metadata last-write-wins (isPinned) in `PastedTests/ConflictResolverTests.swift`
- [ ] T039 [US3] Create `ConflictResolver` with `resolve(local:remote:) -> ClipboardItem` implementing union-merge for new items, last-write-wins for metadata, delete-propagation in `Pasted/Services/Sync/ConflictResolver.swift`
- [ ] T040 [US3] Implement union merge — when `fetchChanges()` receives a record not present locally, insert it; when a local item has no `cloudRecordName`, upload it; both items coexist in `Pasted/Services/Sync/ConflictResolver.swift`
- [ ] T041 [US3] Implement delete propagation — when a fetched record has `isDeleted == true`, mark the local `ClipboardItem` as deleted; when a local item is deleted, set `isDeleted = true` on the `CKRecord` in `Pasted/Services/Sync/ConflictResolver.swift`
- [ ] T042 [US3] Implement last-write-wins for metadata conflicts — compare `modifiedAt` timestamps; the more recent `isPinned` value wins in `Pasted/Services/Sync/ConflictResolver.swift`
- [ ] T043 [US3] Handle `CKError.serverRecordChanged` in `pushChanges()` — fetch server record, run through `ConflictResolver`, retry with resolved record in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T044 [US3] Implement soft-delete retention — records with `isDeleted == true` are retained in CloudKit for 30 days, then permanently deleted by a maintenance sweep in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T045 [US3] Write test for delete propagation — item deleted on one device, verify deletion appears on the other device after sync in `PastedTests/ConflictResolverTests.swift`
- [ ] T046 [US3] Write test for metadata conflict — item pinned on device A, unpinned on device B with later timestamp; verify unpinned wins in `PastedTests/ConflictResolverTests.swift`

---

## Phase 6: US4 — Sync Toggle & Status (P2)

SyncPreferencesView, status indicator, toggle control.

- [ ] T047 [US4] Create `SyncPreferencesView` with sync enable/disable toggle (opt-in, default off) in `Pasted/Views/Preferences/SyncPreferencesView.swift`
- [ ] T048 [US4] Display sync status indicator (idle, syncing, offline, error, paused) in `SyncPreferencesView` reading from `SyncState.syncStatus` in `Pasted/Views/Preferences/SyncPreferencesView.swift`
- [ ] T049 [US4] Display list of synced devices with names and last-seen timestamps from `DeviceInfo` records in `Pasted/Views/Preferences/SyncPreferencesView.swift`
- [ ] T050 [US4] Display last successful sync time and pending upload/download counts from `SyncState` in `Pasted/Views/Preferences/SyncPreferencesView.swift`
- [ ] T051 [US4] Implement toggle-off behavior — set `SyncState.syncStatus` to `.paused`, stop `SyncEngine` operations, new items get `syncStatus = .local` instead of `.pendingUpload` in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T052 [US4] Implement toggle-on behavior — set `SyncState.syncStatus` to `.idle`, mark existing unsynced local items as `.pendingUpload`, trigger full sync in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T053 [US4] Add sync tab/section to existing `PreferencesView` linking to `SyncPreferencesView` in `Pasted/Views/Preferences/PreferencesView.swift`
- [ ] T054 [US4] Display sync error message from `SyncState.lastError` with retry button in `Pasted/Views/Preferences/SyncPreferencesView.swift`
- [ ] T055 [US4] Ensure `SyncPreferencesView` is fully keyboard-navigable (toggle, retry button, device list) in `Pasted/Views/Preferences/SyncPreferencesView.swift`

---

## Phase 7: Polish

Error handling, edge cases, large asset handling, performance, and production readiness.

- [ ] T056 [P] Handle iCloud sign-out gracefully — detect via account status monitor, pause sync, show status, preserve local data, resume on sign-in in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T057 [P] Handle iCloud storage full — detect `CKError.quotaExceeded`, pause uploads, display status message, continue local capture in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T058 [P] Handle `CKError.partialFailure` — extract per-record errors from `partialErrorsByItemID`, retry individual failed records in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T059 [P] Handle `CKError.requestRateLimited` — respect `retryAfterSeconds`, implement exponential backoff across all CloudKit operations in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T060 [P] Handle `CKError.zoneNotFound` and `CKError.userDeletedZone` — recreate zone and trigger full re-sync in `Pasted/Services/Sync/CloudKitManager.swift`
- [ ] T061 [P] Ensure sync operations run on background queues — verify no CloudKit operations block the main thread or degrade UI responsiveness (FR-010) in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T062 [P] Implement progressive initial sync — fetch and process records newest-first to avoid blocking UI during large initial syncs in `Pasted/Services/Sync/SyncEngine.swift`
- [ ] T063 [P] Add sync status indicator to menu bar (optional, non-intrusive) showing sync state from `SyncState` in `Pasted/App/AppDelegate.swift`
- [ ] T064 [P] Verify iCloud storage efficiency — ensure synced clipboard data uses <500MB for 10,000 items with typical content (SC-006) in `PastedTests/SyncRecordMapperTests.swift`
- [ ] T065 [P] Write test for iCloud sign-out/sign-in cycle — verify sync pauses, local data preserved, sync resumes with no data loss in `PastedTests/SyncEngineTests.swift`
- [ ] T066 [P] Write test for CKError.quotaExceeded handling — verify uploads pause, local capture continues, status updates in `PastedTests/SyncEngineTests.swift`
- [ ] T067 [P] Deploy CloudKit schema to production via CloudKit Dashboard — verify record types `ClipboardItem` and `DeviceInfo` with all fields are deployed

---

## Summary

| Phase | Tasks | Test Tasks | Description |
|-------|-------|------------|-------------|
| 1: Setup | T001-T004 | 0 | CloudKit capability, entitlements, project structure |
| 2: Foundational | T005-T017 | T010, T012 | Models, mapper, CloudKitManager, zone setup |
| 3: US1 (P1 MVP) | T018-T029 | T018, T019, T029 | SyncEngine, subscriptions, upload/download |
| 4: US2 (P1) | T030-T037 | T030, T031, T037 | Offline queue, network monitor, background drain |
| 5: US3 (P2) | T038-T046 | T038, T045, T046 | ConflictResolver, merge strategies, deletions |
| 6: US4 (P2) | T047-T055 | 0 | SyncPreferencesView, toggle, status |
| 7: Polish | T056-T067 | T064, T065, T066 | Error handling, performance, production readiness |
| **Total** | **67** | **11** | |
