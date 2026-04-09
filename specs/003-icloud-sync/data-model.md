# Data Model: iCloud Sync

**Branch**: `003-icloud-sync` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)

## Overview

The iCloud sync feature introduces three new models (SyncRecord, SyncState, DeviceInfo) and extends the existing ClipboardItem model with sync-related fields. SyncRecord is a logical mapping layer (not persisted locally) that bridges SwiftData and CloudKit. SyncState and DeviceInfo are persisted locally via SwiftData.

---

## ClipboardItem (existing model — additions)

**Location**: `Pasted/Models/ClipboardItem.swift`

New fields added to the existing `@Model` class:

```swift
/// Sync status for this clipboard item
enum SyncStatus: String, Codable {
    case local           // Not synced (sync disabled, or newly captured awaiting first sync)
    case synced          // Successfully synced to CloudKit
    case pendingUpload   // Captured locally, awaiting upload to CloudKit
    case pendingDownload // Placeholder — content being fetched from CloudKit
    case localOnly       // Too large to sync, or sync explicitly skipped
}

// Added to ClipboardItem @Model:
var syncStatus: SyncStatus = .local
var cloudRecordName: String?  // CKRecord.ID.recordName — nil if never synced
```

**Design notes**:
- `syncStatus` defaults to `.local` — items start unsynced. When sync is enabled, newly captured items are set to `.pendingUpload` by ClipboardStore.
- `cloudRecordName` is set after the first successful upload. It matches `CKRecord.ID.recordName` and is used to correlate local items with their CloudKit counterparts.
- These fields are persisted in SwiftData and survive app restarts, ensuring the offline queue is durable.

---

## SyncRecord (CloudKit mapping — not persisted locally)

**Location**: `Pasted/Models/SyncRecord.swift`

This is a Swift struct that provides type-safe access to CKRecord fields. It is not a SwiftData model — it exists only as an intermediary during sync operations.

```swift
struct SyncRecord {
    // Identity
    let recordName: String          // Matches ClipboardItem.id (UUID string)
    
    // Content
    let contentType: String         // UTType identifier (e.g., "public.utf8-plain-text", "public.png")
    let rawData: Data?              // Content bytes — nil when stored as CKAsset
    let asset: CKAsset?             // Used for items >1MB — mutually exclusive with rawData in-field
    let plainTextContent: String?   // Plain text representation for search/preview (if applicable)
    
    // Metadata
    let sourceAppBundleID: String?  // Bundle ID of the app where the item was copied
    let capturedAt: Date            // Original capture timestamp (from the source device)
    let deviceID: String            // UUID of the device that captured this item
    let modifiedAt: Date            // Last modification timestamp (used for last-write-wins)
    let isPinned: Bool              // Whether the item is pinned by the user
    
    // Sync control
    let isDeleted: Bool             // Soft-delete flag — true means item was deleted by user
}
```

**CKRecord field mapping**:

| SyncRecord field | CKRecord key | CKRecord type | Notes |
|---|---|---|---|
| recordName | (record ID) | CKRecord.ID | Primary key — matches ClipboardItem.id |
| contentType | "contentType" | String | UTType identifier |
| rawData | "rawData" | Bytes | Only for items <=1MB |
| asset | "asset" | CKAsset | Only for items >1MB |
| plainTextContent | "plainTextContent" | String | Searchable text representation |
| sourceAppBundleID | "sourceAppBundleID" | String | Nullable |
| capturedAt | "capturedAt" | Date/Time | Original capture time |
| deviceID | "deviceID" | String | Source device UUID |
| modifiedAt | "modifiedAt" | Date/Time | Last modification (conflict resolution key) |
| isPinned | "isPinned" | Int(64) | 0 or 1 — CloudKit lacks native Bool |
| isDeleted | "isDeleted" | Int(64) | 0 or 1 — soft-delete flag |

**CKRecord type name**: `"ClipboardItem"`
**CKRecord zone**: `"PastedClipboardZone"`

---

## SyncState (@Model — persisted locally)

**Location**: `Pasted/Models/SyncState.swift`

Tracks sync progress for this device. One instance per device (singleton for the local device).

```swift
@Model
final class SyncState {
    /// Sync status enum
    enum Status: String, Codable {
        case idle       // No sync in progress, everything up to date
        case syncing    // Active fetch or push operation
        case offline    // No network connectivity
        case error      // Last sync attempt failed (see lastError)
        case paused     // User disabled sync or iCloud signed out
    }
    
    /// Unique device identifier (generated per Pasted installation)
    @Attribute(.unique) var deviceID: String
    
    /// Serialized CKServerChangeToken — used for incremental fetches
    /// nil on first sync (triggers full fetch)
    var lastSyncToken: Data?
    
    /// Number of local items awaiting upload to CloudKit
    var pendingUploadCount: Int = 0
    
    /// Number of remote items awaiting download from CloudKit
    var pendingDownloadCount: Int = 0
    
    /// Current sync status
    var syncStatus: Status = .idle
    
    /// Timestamp of last successful sync completion
    var lastSyncAt: Date?
    
    /// Human-readable error description from last failed sync attempt
    var lastError: String?
}
```

**Design notes**:
- `lastSyncToken` stores a `NSKeyedArchiver`-encoded `CKServerChangeToken`. When nil, the next fetch retrieves all records in the zone (initial sync). After each successful fetch, the new token is persisted.
- `pendingUploadCount` and `pendingDownloadCount` are denormalized counts for UI display. They are recalculated from ClipboardItem.syncStatus queries periodically, not maintained incrementally (avoids drift).
- One SyncState record exists per device. On this device, only the local device's SyncState is written to. Remote device states are tracked via DeviceInfo.

---

## DeviceInfo (@Model — persisted locally)

**Location**: `Pasted/Models/DeviceInfo.swift`

Identifies devices participating in sync. Each device registers itself in CloudKit; other devices discover peers during sync.

```swift
@Model
final class DeviceInfo {
    /// Unique identifier for this Pasted installation (UUID, generated once and stored in UserDefaults)
    @Attribute(.unique) var deviceID: String
    
    /// Human-readable device name (from Host.current().localizedName ?? ProcessInfo.processInfo.hostName)
    var deviceName: String
    
    /// Pasted version string (from Bundle.main.infoDictionary["CFBundleShortVersionString"])
    var pastedVersion: String
    
    /// Last time this device was seen syncing (updated on each successful sync)
    var lastSeenAt: Date
}
```

**Design notes**:
- `deviceID` is a UUID generated on first launch and stored in `UserDefaults.standard` for durability. It is not tied to hardware identifiers (privacy-first).
- DeviceInfo records are synced to CloudKit as a separate record type (`"DeviceInfo"` in the same zone). This allows the preferences UI to show which devices are syncing and when they were last active.
- `deviceName` is informational only — used in the sync preferences view to show "Last synced from: Snir's MacBook Pro".

---

## Entity Relationships

```
ClipboardItem (existing, extended)
    ├── syncStatus: SyncStatus          [local field]
    ├── cloudRecordName: String?        [local field, maps to CKRecord.ID]
    └── ──maps to──> SyncRecord         [CloudKit CKRecord, not persisted locally]
                        └── deviceID ──references──> DeviceInfo.deviceID

SyncState (local only)
    └── deviceID ──references──> DeviceInfo.deviceID

DeviceInfo (local + CloudKit)
    └── synced as CKRecord type "DeviceInfo" in PastedClipboardZone
```

**Key invariants**:
- Every ClipboardItem with `syncStatus == .synced` has a non-nil `cloudRecordName`.
- Every ClipboardItem with `syncStatus == .pendingUpload` has a nil `cloudRecordName` (or an existing one if metadata was updated).
- SyncState.lastSyncToken is nil only before the first successful sync.
- DeviceInfo.deviceID is immutable after creation.
- Soft-deleted records (`isDeleted == true`) are retained in CloudKit for 30 days, then permanently deleted by a maintenance sweep in SyncEngine.
