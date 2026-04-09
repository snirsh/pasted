# Feature Specification: Privacy & App Exclusions

**Feature Branch**: `004-privacy-app-exclusions`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "Auto-exclude password managers from clipboard capture, user-configurable app exclusion list, and secure data handling"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auto-Exclude Password Managers (Priority: P1)

A user copies a password from 1Password, Bitwarden, or another known password manager. Pasted does NOT capture this clipboard entry — it is silently skipped. The user's passwords never appear in clipboard history, on any device, or in search results.

**Why this priority**: Capturing passwords is a direct security and privacy risk. This must work correctly from the very first launch with zero configuration required.

**Independent Test**: Copy a password from 1Password, invoke Pasted, and verify the password does NOT appear in clipboard history.

**Acceptance Scenarios**:

1. **Given** the user copies text from 1Password, **When** Pasted checks the clipboard source, **Then** the clipboard entry is silently discarded and does not appear in history.
2. **Given** the user copies from Bitwarden, LastPass, Dashlane, KeePassXC, or macOS Keychain Access, **When** Pasted checks the clipboard source, **Then** the entry is silently discarded.
3. **Given** a password manager copy is skipped, **When** the user invokes Pasted, **Then** there is no gap or placeholder — the skipped entry simply doesn't exist in history.
4. **Given** the user copies a non-sensitive item from a password manager app (e.g., a note title), **When** Pasted checks the source, **Then** it is still excluded (exclusion is per-app, not per-content).

---

### User Story 2 - User-Configurable App Exclusions (Priority: P1)

A user works with a proprietary internal tool that handles confidential data. They want to exclude this app from Pasted's clipboard capture. They open Pasted preferences, add the app to the exclusion list, and from that point on, nothing copied from that app is captured.

**Why this priority**: Users have diverse privacy needs that can't be fully covered by a default list. User control is essential for trust.

**Independent Test**: Add "Notes" to the exclusion list, copy text from Notes, and verify it does NOT appear in clipboard history.

**Acceptance Scenarios**:

1. **Given** the user opens Pasted preferences, **When** they navigate to the Privacy section, **Then** they see a list of excluded apps with the default password managers pre-populated.
2. **Given** the user clicks "Add App", **When** an app picker appears, **Then** they can select any installed application to add to the exclusion list.
3. **Given** the user adds "Terminal" to the exclusion list, **When** they copy text from Terminal afterward, **Then** the clipboard entry is not captured.
4. **Given** an app is on the exclusion list, **When** the user removes it, **Then** future clipboard entries from that app ARE captured (removal is not retroactive — previously excluded items remain absent).
5. **Given** the default password managers are in the exclusion list, **When** the user views them, **Then** they are marked as "Default" but can still be removed if the user chooses.

---

### User Story 3 - Concealed Content Detection (Priority: P3)

Some apps mark clipboard content as "concealed" (NSPasteboard's `concealed` type). Pasted detects this flag and automatically skips these entries, even if the source app is not on the exclusion list.

**Why this priority**: Nice-to-have that catches sensitive content from well-behaved apps not on the exclusion list. Lower priority because few apps use this flag consistently.

**Independent Test**: Programmatically set a clipboard entry with the concealed flag, verify Pasted does not capture it.

**Acceptance Scenarios**:

1. **Given** an app places content on the clipboard with the concealed type/flag, **When** Pasted detects the new clipboard content, **Then** it is silently discarded.
2. **Given** a user has disabled concealed content detection in preferences (opt-out), **When** concealed content is copied, **Then** it IS captured like normal content.

---

### User Story 4 - Clear History on Demand (Priority: P2)

A user wants to erase specific items or their entire clipboard history for privacy reasons. They can delete individual items from the strip or clear all history from preferences.

**Why this priority**: Users must have full control over stored data. Essential for trust, but less urgent than preventing sensitive capture in the first place.

**Independent Test**: Copy 5 items, delete one from the strip, verify it's gone. Then clear all history from preferences and verify the strip is empty.

**Acceptance Scenarios**:

1. **Given** an item is selected in the strip, **When** the user presses Delete (or Backspace), **Then** the item is permanently removed from local storage and synced deletion to iCloud.
2. **Given** the user opens preferences, **When** they click "Clear All History", **Then** a confirmation dialog appears. Upon confirmation, all clipboard items are permanently deleted from local storage and iCloud.
3. **Given** items have been cleared, **When** the user invokes Pasted, **Then** the strip shows an empty state with a helpful message.

---

### Edge Cases

- What happens if a new password manager is installed that isn't in the default list? Users must manually add it to the exclusion list. The default list is updated with each app release.
- What happens if an excluded app changes its bundle identifier (e.g., after an update)? The exclusion list is based on bundle ID. If the bundle ID changes, the user must re-add the new version. A notification could be shown if a previously excluded bundle ID disappears.
- What happens if the user clears history on one device while another is offline? The deletion syncs via iCloud when the offline device comes online. Deletion markers are kept for a retention period (30 days) to ensure propagation.
- What happens if the user tries to recover a deleted item? Deleted items are permanently removed. No recycle bin or undo for security reasons. The confirmation dialog warns about this.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST ship with a default exclusion list of known password managers: 1Password, Bitwarden, LastPass, Dashlane, KeePassXC, Enpass, macOS Keychain Access, and Secrets.
- **FR-002**: System MUST allow users to add any installed application to the exclusion list via an app picker in preferences.
- **FR-003**: System MUST allow users to remove any app from the exclusion list, including default entries.
- **FR-004**: System MUST silently discard clipboard entries from excluded apps — no history entry, no preview, no sync, no search indexing.
- **FR-005**: System MUST identify the source application of each clipboard entry using the NSPasteboard source app metadata (frontmost app at time of copy).
- **FR-006**: System MUST detect and skip clipboard entries marked with the NSPasteboard concealed content type.
- **FR-007**: System MUST provide a preference toggle to enable/disable concealed content detection (enabled by default).
- **FR-008**: System MUST allow users to delete individual items from clipboard history (with synced deletion to iCloud).
- **FR-009**: System MUST allow users to clear all clipboard history with a confirmation dialog.
- **FR-010**: System MUST store the exclusion list locally and sync it to iCloud so exclusion rules are consistent across devices.
- **FR-011**: All clipboard data stored on disk MUST be protected by macOS file-level encryption (Data Protection / FileVault).

### Key Entities

- **AppExclusion**: An application excluded from clipboard capture. Attributes: bundle identifier, display name, icon, is_default (boolean), date added.
- **ExclusionList**: Ordered collection of AppExclusions. Synced across devices via iCloud.
- **ConcealedContentFlag**: A boolean property on a clipboard entry indicating the source app marked it as sensitive.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero password manager clipboard entries are captured with the default configuration — 100% exclusion rate for apps in the default list.
- **SC-002**: Users can add a custom app to the exclusion list within 15 seconds (open preferences, click add, select app, done).
- **SC-003**: Exclusion takes effect immediately — no restart required after adding an app.
- **SC-004**: Concealed clipboard content is never captured when the concealed detection setting is enabled.
- **SC-005**: History clearing permanently removes all data — no residual data in local storage, search index, or iCloud after clear operation.
- **SC-006**: Exclusion list syncs across devices within 30 seconds, ensuring consistent privacy settings.

## Assumptions

- NSPasteboard provides the frontmost application's bundle identifier at the time of copy, or equivalent metadata to identify the source app. (macOS does provide this via `NSWorkspace.shared.frontmostApplication`.)
- The concealed content type (`org.nspasteboard.ConcealedType`) is respected by password managers that support it.
- Users trust macOS FileVault / Data Protection for at-rest encryption — Pasted does not implement its own encryption layer beyond what the OS provides.
- Bundle identifiers for default excluded apps are stable and well-known.
- The exclusion list is expected to be small (under 50 apps) and does not require pagination.
