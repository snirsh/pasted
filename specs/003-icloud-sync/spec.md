# Feature Specification: iCloud Sync

**Feature Branch**: `003-icloud-sync`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "Sync clipboard history across the user's Mac devices via iCloud, with offline-first design and automatic conflict resolution"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatic Sync Between Macs (Priority: P1)

A user has Pasted installed on their work MacBook and home iMac, both signed into the same iCloud account. They copy a code snippet on their work Mac. When they get home and invoke Pasted on their iMac, the code snippet is available in the clipboard history without any manual action.

**Why this priority**: Cross-device sync is the primary reason users enable iCloud — this is the core value of this feature.

**Independent Test**: Copy an item on Mac A, wait for sync, invoke Pasted on Mac B, and verify the item appears in clipboard history.

**Acceptance Scenarios**:

1. **Given** two Macs signed into the same iCloud account with Pasted installed, **When** the user copies an item on Mac A, **Then** the item appears in Mac B's clipboard history within 30 seconds (when both are online).
2. **Given** a synced item appears on Mac B, **When** the user selects it and presses Return, **Then** it pastes correctly with the same content type and formatting as the original.
3. **Given** the user copies an image on Mac A, **When** it syncs to Mac B, **Then** the image preview and full content are available (not just a placeholder).

---

### User Story 2 - Offline-First with Background Sync (Priority: P1)

A user copies items while on an airplane with no internet. All items are captured to local storage as usual. When the Mac reconnects to the internet, Pasted automatically syncs the queued items to iCloud, and they appear on the user's other devices.

**Why this priority**: Clipboard capture must never depend on network availability. The app must always work locally first.

**Independent Test**: Disable network, copy 5 items, re-enable network, and verify all 5 items sync to iCloud within 60 seconds.

**Acceptance Scenarios**:

1. **Given** the Mac has no internet connection, **When** the user copies items, **Then** all items are captured to local storage with zero degradation in behavior.
2. **Given** the Mac reconnects to the internet after being offline, **When** there are unsynced items, **Then** they sync to iCloud automatically in the background within 60 seconds.
3. **Given** items were created offline on two different Macs, **When** both come online, **Then** all items from both devices appear in the merged history on both Macs.

---

### User Story 3 - Conflict Resolution (Priority: P2)

Two Macs are offline simultaneously. The user copies different items on each. When both come online, Pasted merges the histories without data loss and without prompting the user to manually resolve conflicts.

**Why this priority**: Conflicts are inevitable with multi-device offline use. Automatic resolution prevents data loss and avoids confusing the user.

**Independent Test**: Copy unique items offline on two Macs, bring both online, and verify both histories are merged with all items present on both devices.

**Acceptance Scenarios**:

1. **Given** Mac A has items [A1, A2] created offline and Mac B has items [B1, B2] created offline, **When** both sync, **Then** both Macs show [A1, A2, B1, B2] sorted by timestamp.
2. **Given** the same item was deleted on Mac A but not on Mac B, **When** sync occurs, **Then** the deletion wins (delete propagates to Mac B).
3. **Given** conflicting metadata (e.g., item pinned on one device, not on another), **When** sync occurs, **Then** the most recent change wins (last-write-wins).

---

### User Story 4 - Sync Toggle and Status (Priority: P2)

A user wants to know if their clipboard history is in sync or wants to disable sync temporarily (e.g., for privacy reasons while working on sensitive material).

**Why this priority**: Users need control over sync behavior and visibility into sync status, but the sync feature works without this UI.

**Independent Test**: Toggle sync off in preferences, copy items, verify they don't appear on other devices, toggle sync back on, and verify sync resumes.

**Acceptance Scenarios**:

1. **Given** the user opens Pasted preferences, **When** they view sync settings, **Then** they see a toggle to enable/disable iCloud sync and a status indicator (synced, syncing, offline, error).
2. **Given** the user disables sync, **When** they copy new items, **Then** items are stored locally only and not uploaded to iCloud.
3. **Given** sync was disabled and items were captured locally, **When** the user re-enables sync, **Then** locally captured items sync to iCloud.

---

### Edge Cases

- What happens if the user signs out of iCloud? Sync pauses gracefully. Local history remains intact. A non-intrusive indicator in the menu bar shows sync is unavailable. When the user signs back in, sync resumes.
- What happens if iCloud storage is full? Sync pauses with a clear status message. Local clipboard capture continues uninterrupted. The user is informed that sync is paused due to iCloud storage limits.
- What happens if one Mac has a much older history than another? Initial sync merges all items by timestamp. No items are lost. Large initial syncs happen progressively (newest first) to avoid blocking the UI.
- What happens when a synced item exceeds CloudKit record size limits? Large items (e.g., >5MB images) are stored as CloudKit assets. Items exceeding CloudKit's absolute maximum are stored locally only with a sync status indicator.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST sync clipboard history across all Macs signed into the same iCloud account with Pasted installed.
- **FR-002**: System MUST operate in offline-first mode — all clipboard capture and local functionality MUST work without an internet connection.
- **FR-003**: System MUST automatically sync queued items when the network becomes available, without user intervention.
- **FR-004**: System MUST resolve conflicts automatically using a merge strategy: new items are merged by timestamp, deletions propagate, metadata conflicts use last-write-wins.
- **FR-005**: System MUST provide a user-facing toggle to enable/disable iCloud sync in preferences.
- **FR-006**: System MUST display sync status (synced, syncing, offline, error, paused) in the preferences and optionally in the menu bar.
- **FR-007**: System MUST handle iCloud sign-out, sign-in, and storage-full scenarios gracefully without data loss or crashes.
- **FR-008**: System MUST sync all content types (text, images, files, URLs, rich text) with full fidelity.
- **FR-009**: System MUST use CloudKit for synchronization (Apple's recommended framework for iCloud data sync).
- **FR-010**: Sync MUST NOT block or degrade the local clipboard capture or UI responsiveness.

### Key Entities

- **SyncRecord**: A CloudKit record representing a clipboard item. Contains: record ID, content type, content data (or CloudKit asset reference for large items), source device identifier, timestamp, deletion flag.
- **SyncState**: Tracks per-device sync progress. Attributes: last sync timestamp, pending upload count, pending download count, sync status (active/paused/error), change token for incremental fetches.
- **DeviceInfo**: Identifies a device participating in sync. Attributes: device name, device ID, Pasted version, last seen timestamp.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Items sync between devices within 30 seconds when both are online.
- **SC-002**: Zero data loss during conflict resolution — all items from all devices are preserved.
- **SC-003**: Offline clipboard capture has identical performance to online mode (no perceptible difference).
- **SC-004**: Initial sync of 1,000 items completes within 5 minutes on standard broadband.
- **SC-005**: Sync status is always accurate and updated within 5 seconds of a state change.
- **SC-006**: iCloud storage usage is efficient — synced clipboard data uses less than 500MB of iCloud storage for 10,000 items with typical content.

## Assumptions

- Users have iCloud enabled on all Macs they want to sync between.
- Users are signed into the same Apple ID on all target devices.
- CloudKit is available on macOS 14+ (it is — this is a well-established Apple framework).
- Network conditions vary; the system must handle intermittent connectivity gracefully.
- CloudKit has record size limits (~1MB per record field, larger via CKAsset). The sync strategy must accommodate this.
- iCloud sync is opt-in by default (requires user to enable in preferences on first launch).
