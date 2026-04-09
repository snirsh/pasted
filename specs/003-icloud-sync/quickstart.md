# Quick Start: iCloud Sync

**Branch**: `003-icloud-sync` | **Date**: 2026-04-09 | **Spec**: [spec.md](./spec.md)

## Prerequisites

- Xcode 15+ with macOS 14 SDK
- An Apple Developer account (required for CloudKit)
- Two Macs signed into the same Apple ID (for end-to-end testing)

## Step 1: Enable CloudKit Capability in Xcode

1. Open the Pasted project in Xcode.
2. Select the **Pasted** target.
3. Go to **Signing & Capabilities**.
4. Click **+ Capability** and add **iCloud**.
5. Under the iCloud capability, check **CloudKit**.
6. In the **Containers** section, click **+** and create: `iCloud.com.pasted.clipboard`
7. Ensure the container is selected (checked).

This adds the `com.apple.developer.icloud-container-identifiers` entitlement to the app.

## Step 2: Create the Custom Record Zone

On first launch (or first sync enable), the app must create the custom record zone. This is done programmatically by CloudKitManager:

```swift
let zone = CKRecordZone(zoneName: "PastedClipboardZone")
let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone])
operation.modifyRecordZonesResultBlock = { result in
    switch result {
    case .success:
        print("PastedClipboardZone created")
    case .failure(let error):
        print("Zone creation failed: \(error)")
    }
}
CKContainer.default().privateCloudDatabase.add(operation)
```

Zone creation is idempotent — calling it when the zone already exists is a no-op.

## Step 3: Define CKRecord Schema

The CloudKit schema is defined implicitly by saving records with the correct fields (development environment), or explicitly via the CloudKit Dashboard (production).

**Record Type: `ClipboardItem`** (in zone `PastedClipboardZone`)

| Field Name | Type | Notes |
|---|---|---|
| contentType | String | UTType identifier |
| rawData | Bytes | Content for items <=1MB |
| asset | Asset | Content for items >1MB |
| plainTextContent | String | Searchable text |
| sourceAppBundleID | String | Source app |
| capturedAt | Date/Time | Original capture time |
| deviceID | String | Source device UUID |
| modifiedAt | Date/Time | Conflict resolution key |
| isPinned | Int(64) | 0 or 1 |
| isDeleted | Int(64) | 0 or 1 (soft delete) |

**Record Type: `DeviceInfo`** (in zone `PastedClipboardZone`)

| Field Name | Type | Notes |
|---|---|---|
| deviceName | String | Human-readable |
| pastedVersion | String | App version |
| lastSeenAt | Date/Time | Last sync time |

In development, CloudKit auto-creates the schema when you first save a record with these fields. For production, deploy the schema via **CloudKit Dashboard > Schema > Deploy to Production**.

## Step 4: Add CKSubscription for Push Notifications

Subscribe to changes in the record zone to enable near-real-time sync:

```swift
let subscription = CKDatabaseSubscription(subscriptionID: "clipboard-changes")
let notificationInfo = CKSubscription.NotificationInfo()
notificationInfo.shouldSendContentAvailable = true  // Silent push
subscription.notificationInfo = notificationInfo

let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])
operation.modifySubscriptionsResultBlock = { result in
    switch result {
    case .success:
        print("Subscription created")
    case .failure(let error):
        print("Subscription failed: \(error)")
    }
}
CKContainer.default().privateCloudDatabase.add(operation)
```

**Also required**: In the Pasted target's **Signing & Capabilities**, add **Background Modes** (if not already present) and enable **Remote notifications**. Register for remote notifications in AppDelegate:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.registerForRemoteNotifications()
}

func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
    // Trigger incremental sync via SyncEngine
    let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
    if notification?.subscriptionID == "clipboard-changes" {
        SyncEngine.shared.fetchChanges()
    }
}
```

## Step 5: Verify Account Status

Before attempting any sync operations, check that the user is signed into iCloud:

```swift
CKContainer.default().accountStatus { status, error in
    switch status {
    case .available:
        // iCloud is available — proceed with sync
    case .noAccount:
        // User not signed into iCloud — show status in preferences
    case .restricted, .couldNotDetermine, .temporarilyUnavailable:
        // Handle gracefully — sync paused
    @unknown default:
        break
    }
}
```

## Step 6: First Milestone — Round-Trip Sync

The first implementation milestone is uploading a single ClipboardItem to CloudKit and reading it back on another device:

1. Capture a clipboard item locally (existing ClipboardMonitor).
2. Map it to a CKRecord via SyncRecordMapper.
3. Save it to CloudKit via CKModifyRecordsOperation.
4. On the second Mac, fetch changes via CKFetchRecordZoneChangesOperation.
5. Map the CKRecord back to a ClipboardItem via SyncRecordMapper.
6. Verify the item appears in the clipboard history with correct content type and data.

**Success criteria for this milestone**: A plain text clipboard item copied on Mac A appears in Pasted's history on Mac B within 30 seconds, with identical content.

## Common Issues

- **"No iCloud container"**: Ensure the container identifier matches exactly (`iCloud.com.pasted.clipboard`) and the Apple Developer account has the container provisioned.
- **Schema not deploying**: In development, save a record first to auto-create the schema. Then deploy to production via CloudKit Dashboard.
- **Push notifications not arriving**: Verify the app is registered for remote notifications and the subscription exists (check via CloudKit Dashboard > Subscriptions).
- **"Partial failure" errors**: CloudKit batch operations can partially fail. Check `CKError.partialErrorsByItemID` for per-record errors and retry failed records.
- **Rate limiting (CKError.requestRateLimited)**: CloudKit may throttle requests. Respect the `retryAfterSeconds` value in the error and retry with backoff.
