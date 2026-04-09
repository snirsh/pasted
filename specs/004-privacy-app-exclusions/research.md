# Research: Privacy & App Exclusions

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Date**: 2026-04-09

## Decision 1: Source App Detection

**Question**: How do we reliably identify which application placed content on the clipboard?

**Decision**: Use `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` at the moment clipboard change is detected.

**Rationale**: macOS does not expose the "source app" of a pasteboard change directly on `NSPasteboard`. However, the frontmost application at the time of a copy operation is almost always the source, because copy requires the app to be focused (Cmd+C targets the first responder in the key window). `NSWorkspace.shared.frontmostApplication` returns an `NSRunningApplication` with `.bundleIdentifier` — this is the most reliable and universal method.

**Alternatives considered**:
- **NSPasteboard source metadata**: Some apps write custom pasteboard types identifying themselves, but this is not standardized and most apps do not do it. Unreliable as a general solution.
- **NSPasteboard.name + ownerName**: The owner is often the app that last wrote to the pasteboard, but this API is deprecated and not available for the general pasteboard in modern macOS.
- **Accessibility API (AXUIElement)**: Could determine the focused app, but requires Accessibility permissions and is functionally equivalent to `frontmostApplication` with more complexity.

**Risk**: If a background app writes to the pasteboard without being frontmost (e.g., a clipboard manager extension), the frontmost app will be incorrectly identified. This is rare and acceptable — power users who encounter this can manually exclude the relevant app. The spec acknowledges this limitation (FR-005 says "frontmost app at time of copy").

## Decision 2: Concealed Content Detection

**Question**: How do we detect clipboard content that apps have marked as sensitive/concealed?

**Decision**: Check for `"org.nspasteboard.ConcealedType"` in `NSPasteboard.general.types` when processing a clipboard change.

**Rationale**: `org.nspasteboard.ConcealedType` is a community-standard pasteboard type established by the [nspasteboard.org](https://nspasteboard.org) initiative. When present in the pasteboard's types array, it signals that the content is sensitive and should not be persisted by clipboard managers. This is adopted by:
- 1Password (all versions)
- Bitwarden
- KeePassXC
- Many other security-conscious apps

The check is a single `contains` call on the types array — effectively O(n) on the number of types (typically under 10), which is negligible.

**Alternatives considered**:
- **Parsing pasteboard content for password patterns**: Heuristic, unreliable, and a privacy violation in itself (requires reading the content to decide whether to store it).
- **Apple's Keychain pasteboard flag**: macOS Keychain Access uses `org.nspasteboard.ConcealedType` as well, so this is already covered.
- **Custom concealment detection**: No standard exists beyond `org.nspasteboard.ConcealedType`. Inventing one would not help with existing apps.

**Implementation note**: The concealed check is independent of the app exclusion check. Both run before capture. If either triggers, the clipboard entry is skipped. A UserDefaults toggle (`concealedDetectionEnabled`, default `true`) allows users to opt out.

## Decision 3: Exclusion Storage and O(1) Lookup

**Question**: How do we persist the exclusion list while maintaining O(1) lookup performance during clipboard monitoring?

**Decision**: Dual-layer approach — SwiftData `@Model` for persistence and iCloud sync, plus an in-memory `Set<String>` of bundle identifiers for O(1) lookup at clipboard capture time.

**Rationale**: The clipboard monitor fires on every pasteboard change (every 0.5 seconds when polling). The exclusion check must add zero perceptible latency. A `Set<String>` lookup is O(1) average case. The Set is rebuilt from SwiftData:
1. On app launch (query all `AppExclusion` records, extract bundle IDs into Set).
2. On any exclusion list modification (add/remove triggers Set rebuild).
3. The Set is small (under 50 entries per spec assumption) so rebuild is instantaneous.

**Alternatives considered**:
- **SwiftData query on every clipboard change**: O(n) per query plus database overhead. Unacceptable for a hot path.
- **UserDefaults array**: Fast but does not support iCloud sync cleanly and lacks the structured data needed for display name, icon, etc.
- **In-memory only (no persistence)**: Would lose user customizations on app restart.
- **Bloom filter**: Overkill for under 50 entries. Set is simpler and has zero false positives.

## Decision 4: Default Exclusion List

**Question**: Which apps should be excluded by default, and how should the list be maintained?

**Decision**: Hardcode the following bundle identifiers in `DefaultExclusionList.swift`:

| App | Bundle Identifier |
|-----|-------------------|
| 1Password 8 | `com.1password.1password` |
| 1Password 7 | `com.agilebits.onepassword7` |
| Bitwarden | `com.bitwarden.desktop` |
| LastPass | `com.lastpass.LastPass` |
| KeePassXC | `org.keepassxc.keepassxc` |
| Dashlane | `com.dashlane.Dashlane` |
| Keychain Access | `com.apple.keychainaccess` |
| Enpass | `com.sinew.Enpass-Desktop` |
| Secrets | `com.nickvdp.Secrets` |

**Rationale**: These are the most widely used password managers on macOS. The list is hardcoded (not fetched from a remote source) to comply with Constitution Principle I (Privacy-First — no network calls) and Principle IV (Open Source Transparency — auditable in source). The list is updated with each Pasted app release.

**Note on bundle ID accuracy**: Bundle identifiers must be verified against actual app installations before shipping. The IDs listed above are based on publicly known identifiers. The `DefaultExclusionListTests` will validate format (reverse-DNS) but runtime verification requires installed apps.

**Alternatives considered**:
- **Remote exclusion list fetched from GitHub**: Would allow faster updates, but violates Privacy-First (network call) and introduces a dependency on external infrastructure.
- **Crowd-sourced list**: Complex governance, slow updates, trust issues.
- **No default list**: Shifts all burden to the user. Unacceptable — the spec requires zero-configuration protection (SC-001).

## Decision 5: History Deletion and iCloud Propagation

**Question**: How do we implement secure deletion that propagates across devices?

**Decision**: Two deletion paths:

1. **Individual item deletion**: SwiftData `modelContext.delete(item)` removes the `ClipboardItem` from local storage. If iCloud sync is enabled (spec 003), a deletion tombstone is written to CloudKit so the item is removed from other devices. Related data (OCR results from spec 002) is cascade-deleted via SwiftData relationship configuration.

2. **Clear all history**: Batch delete all `ClipboardItem` records via SwiftData. For iCloud, perform a CloudKit zone reset (`CKModifyRecordZonesOperation` to delete and recreate the custom zone) — this is the most efficient way to delete all records rather than sending individual deletion operations for potentially thousands of items.

**Rationale**: SwiftData handles local deletion cleanly. CloudKit zone reset is Apple's recommended approach for "delete everything" scenarios — it is atomic and avoids rate limits on individual record deletions.

**Deletion markers**: For individual deletions, CloudKit uses `CKRecord.ID` deletion which is tracked by the sync engine. For offline devices, the deletion syncs when the device comes online. The spec mentions a 30-day retention period for deletion markers — CloudKit handles this natively via its change token mechanism.

**Alternatives considered**:
- **Soft delete with isDeleted flag**: Adds complexity and risks data leaks if the flag is not checked everywhere. Hard delete is simpler and more secure.
- **Custom deletion sync protocol**: Unnecessary — CloudKit's built-in deletion propagation handles this.
- **Undo support / recycle bin**: Explicitly rejected by the spec for security reasons. Confirmation dialog is the safeguard.

## Decision 6: App Picker Implementation

**Question**: How should users select applications to add to the exclusion list?

**Decision**: Provide two selection methods in the `AppPickerView`:

1. **Browse installed apps**: Use `NSOpenPanel` configured with `allowedContentTypes: [.application]` and `directoryURL` pointing to `/Applications`. Users can navigate to any `.app` bundle. Extract the bundle identifier via `Bundle(url:)?.bundleIdentifier`.

2. **Running applications list**: Show `NSWorkspace.shared.runningApplications` filtered to `.activationPolicy == .regular` (excludes background daemons and agents). Display app icon + name. User taps to select.

The running apps list appears as the primary view (most convenient for "I want to exclude this app I'm currently using"), with a "Browse..." button that opens `NSOpenPanel` for apps not currently running.

**Rationale**: `NSOpenPanel` is the standard macOS file picker — users are familiar with it. The running apps list provides a faster workflow for the common case. Combining both covers all scenarios.

**Alternatives considered**:
- **Spotlight query for all installed apps**: `NSMetadataQuery` with `kMDItemContentType == "com.apple.application-bundle"` could list all apps, but is slower and requires building a custom list UI. `NSOpenPanel` is simpler and already handles navigation.
- **Drag-and-drop from Finder**: Nice enhancement but not sufficient as the sole method — requires mouse interaction, violating Keyboard-First principle. Could be added as a supplementary method in a future iteration.
- **Manual bundle ID entry**: Too technical for most users. Could be offered as an advanced option in a future iteration.
