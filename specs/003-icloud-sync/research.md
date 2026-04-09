# Research: iCloud Sync

**Branch**: `003-icloud-sync` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)

## Decision 1: CloudKit Database Choice

**Question**: Which CloudKit database type should Pasted use for sync?

**Options Considered**:
- **Private database** (CKContainer.default().privateCloudDatabase) — data stored in the user's iCloud account, invisible to the developer and other users.
- **Shared database** — allows sharing records between users via CKShare.
- **Public database** — world-readable, developer-managed quota.

**Decision**: Private database.

**Rationale**: Pasted syncs a single user's clipboard history across their own devices. There is no multi-user sharing requirement. The private database stores data within the user's personal iCloud storage quota, meaning:
- Data is never visible to Pasted developers (aligns with Constitution Principle I: Privacy-First).
- No shared containers that could leak data between users.
- Storage counts against the user's iCloud plan, not the developer's CloudKit quota.
- Apple encrypts private database contents at rest.

The shared and public databases are unnecessary and would violate the privacy-first principle by making data potentially accessible to the developer or other users.

## Decision 2: Sync Strategy

**Question**: How should Pasted fetch and push changes between devices?

**Options Considered**:
- **CKFetchRecordZoneChangesOperation** with server change tokens — incremental fetch of only changed records since last sync.
- **CKQueryOperation** with date-based filtering — query all records newer than last sync time.
- **NSPersistentCloudKitContainer** — Apple's automatic CoreData+CloudKit sync.

**Decision**: CKFetchRecordZoneChangesOperation with server change tokens, combined with CKSubscription for push notifications.

**Rationale**:
- **Change tokens** are CloudKit's native mechanism for incremental sync. The server tracks what each client has seen and returns only new/modified/deleted records. This is far more efficient than date-based queries, especially for large histories.
- **CKSubscription** (specifically CKDatabaseSubscription) sends silent push notifications when records change in the zone, enabling near-real-time sync (within 30 seconds, meeting SC-001) without continuous polling.
- **NSPersistentCloudKitContainer** was rejected because Pasted uses SwiftData (not CoreData directly), and NSPersistentCloudKitContainer offers limited control over conflict resolution — it uses a system-determined merge policy that may not match our union-merge + delete-propagation requirements. Direct CloudKit operations give us full control.

**Sync flow**:
1. On app launch: fetch changes using stored server change token.
2. On push notification: fetch changes (incremental).
3. On local change: batch upload via CKModifyRecordsOperation.
4. On network restoration: drain offline queue (pending uploads).

## Decision 3: Conflict Resolution Strategy

**Question**: How should Pasted handle conflicts when the same data is modified on multiple devices while offline?

**Options Considered**:
- **Last-write-wins** for everything — simplest, but risks data loss for item content.
- **Union merge for items + last-write-wins for metadata** — preserves all clipboard items, uses timestamp for metadata conflicts.
- **User-facing conflict dialogs** — presents conflicts to the user for manual resolution.

**Decision**: Union merge for items, last-write-wins for metadata, delete-propagation for deletions.

**Rationale**:
- **Clipboard items are append-only by nature** — users don't edit clipboard entries, they create new ones. Two devices creating different items offline should result in all items being present on both devices after sync. This is a natural union merge.
- **Metadata conflicts** (e.g., an item pinned on one device but not another) are rare and low-stakes. Last-write-wins by `modifiedAt` timestamp is sufficient and avoids user-facing complexity.
- **Deletions propagate** — if a user deletes an item on any device, it should be deleted everywhere. This is implemented via a soft-delete flag (`isDeleted = true`) with a 30-day retention period before the record is permanently removed from CloudKit. The 30-day window allows all devices to receive the deletion even if they've been offline.
- **User-facing conflict dialogs were rejected** — they violate Constitution Principle V (Simplicity Over Features) and interrupt keyboard workflows (Principle III). Clipboard data does not warrant manual conflict resolution.

## Decision 4: Large Asset Handling

**Question**: How should Pasted handle clipboard items that exceed CloudKit's ~1MB per-field limit?

**Options Considered**:
- **CKAsset** (file-based storage attached to CKRecord) — CloudKit handles chunked upload/download.
- **Record splitting** — split large content across multiple CKRecords.
- **Local-only for large items** — don't sync items above a threshold.

**Decision**: CKAsset for items with content >1MB. Items exceeding CloudKit's absolute limit (~250MB) are stored locally only.

**Rationale**:
- **CKAsset** is CloudKit's built-in mechanism for large binary data. It handles chunked upload/download, progress tracking, and resumable transfers automatically. This is the simplest and most reliable approach.
- **Record splitting** adds significant complexity (reassembly logic, partial failure handling) for minimal benefit — CKAsset already solves this problem.
- **Threshold logic**: During CKRecord creation in SyncRecordMapper, if `rawData.count > 1_000_000`, the data is written to a temporary file and attached as a CKAsset instead of stored in a record field. This is transparent to the rest of the sync engine.
- **Absolute limit**: Items exceeding ~250MB (extremely rare for clipboard content — e.g., a massive file reference) are marked with `syncStatus = .localOnly` and a UI indicator explains that the item is too large to sync.

## Decision 5: Offline Queue Design

**Question**: How should Pasted track and drain items that need to be uploaded when the device was offline?

**Options Considered**:
- **Separate queue table** — a dedicated SwiftData model for pending operations.
- **Status field on ClipboardItem** — track sync state directly on the item model.
- **CloudKit operation queue** — rely on CloudKit's built-in retry/queue.

**Decision**: Status field on ClipboardItem (`syncStatus` enum) with SyncStateTracker coordinating the drain.

**Rationale**:
- Adding a `syncStatus` field directly to ClipboardItem is the simplest approach — no separate table, no join queries, no orphaned queue entries. The field values are: `.local` (not yet synced, or sync disabled), `.synced`, `.pendingUpload`, `.pendingDownload`.
- SyncStateTracker queries for items with `.pendingUpload` status and batches them into CKModifyRecordsOperation calls (max 400 records per operation, CloudKit's batch limit).
- On network restoration (detected via NWPathMonitor), SyncEngine triggers a queue drain automatically.
- CloudKit's built-in retry was not sufficient alone because it doesn't persist across app restarts — our SwiftData-backed status field survives restarts.

## Decision 6: Record Zone Strategy

**Question**: Should Pasted use the default zone or a custom CKRecordZone?

**Options Considered**:
- **Default zone** (`CKRecordZone.default()`) — simpler setup, but limited features.
- **Custom zone** (`CKRecordZone(zoneName: "PastedClipboardZone")`) — supports atomic commits and change tokens.

**Decision**: Custom CKRecordZone named "PastedClipboardZone".

**Rationale**:
- **Change tokens** (CKServerChangeToken) are only available with CKFetchRecordZoneChangesOperation on custom zones. Since our entire sync strategy depends on incremental change token-based fetching (Decision 2), a custom zone is required.
- **Atomic commits**: Custom zones support atomic batch operations — either all records in a CKModifyRecordsOperation succeed or none do. This prevents partial sync states where some items upload but others fail, leaving the history inconsistent.
- **Isolation**: A custom zone cleanly separates Pasted's data from any other CloudKit data in the container, making it easy to reset sync (delete and recreate the zone) without affecting other app data.
- The marginal setup cost (one CKModifyRecordZonesOperation on first launch) is trivial compared to the benefits.
