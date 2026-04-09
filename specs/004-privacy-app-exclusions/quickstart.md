# Quick Start: Privacy & App Exclusions

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Data Model**: [data-model.md](./data-model.md)
**Date**: 2026-04-09

## Implementation Order

Build in this sequence. Each step produces a testable increment. Do not skip ahead.

### Step 1: Default Exclusion List

**Create**: `Pasted/Services/Privacy/DefaultExclusionList.swift`

Define a static list of known password manager bundle identifiers with their display names. This is a pure data file with no dependencies.

```swift
struct DefaultExclusionEntry {
    let bundleIdentifier: String
    let displayName: String
}

enum DefaultExclusionList {
    static let entries: [DefaultExclusionEntry] = [
        .init(bundleIdentifier: "com.1password.1password", displayName: "1Password"),
        .init(bundleIdentifier: "com.agilebits.onepassword7", displayName: "1Password 7"),
        .init(bundleIdentifier: "com.bitwarden.desktop", displayName: "Bitwarden"),
        .init(bundleIdentifier: "com.lastpass.LastPass", displayName: "LastPass"),
        .init(bundleIdentifier: "org.keepassxc.keepassxc", displayName: "KeePassXC"),
        .init(bundleIdentifier: "com.dashlane.Dashlane", displayName: "Dashlane"),
        .init(bundleIdentifier: "com.apple.keychainaccess", displayName: "Keychain Access"),
        .init(bundleIdentifier: "com.sinew.Enpass-Desktop", displayName: "Enpass"),
        .init(bundleIdentifier: "com.nickvdp.Secrets", displayName: "Secrets"),
    ]

    static var bundleIdentifiers: Set<String> {
        Set(entries.map(\.bundleIdentifier))
    }
}
```

**Test**: `PastedTests/DefaultExclusionListTests.swift` — verify the list is non-empty, all bundle IDs are in reverse-DNS format, no duplicates.

### Step 2: AppExclusion SwiftData Model

**Create**: `Pasted/Models/AppExclusion.swift`

Define the `@Model` class as specified in [data-model.md](./data-model.md). Register it in the SwiftData `ModelContainer` configuration in `PastedApp.swift` alongside the existing `ClipboardItem` model.

```swift
// In PastedApp.swift, update the model container:
let schema = Schema([ClipboardItem.self, AppExclusion.self])
```

**Test**: Write a unit test that creates an `AppExclusion`, saves it, and queries it back by bundle identifier.

### Step 3: AppExclusionService + Exclusion Lookup

**Create**: `Pasted/Services/Privacy/AppExclusionService.swift`

This is the core service. Responsibilities:
1. On first launch, seed the SwiftData store with `DefaultExclusionList` entries (check if already seeded to avoid duplicates on subsequent launches).
2. Maintain an `ExclusionLookup` (in-memory `Set<String>`) rebuilt from SwiftData.
3. Provide `add(bundleIdentifier:displayName:iconData:)` and `remove(bundleIdentifier:)` methods that update both SwiftData and the in-memory Set.
4. Provide `isExcluded(_ bundleIdentifier: String) -> Bool` for the clipboard monitor.

**Test**: `PastedTests/AppExclusionServiceTests.swift` — test seeding, add, remove, lookup correctness, and verify O(1) characteristic (lookup time does not grow with list size).

### Step 4: Integrate Exclusion Check into ClipboardMonitor

**Update**: `Pasted/Services/ClipboardMonitor.swift`

Add a pre-capture gate at the top of the clipboard change handler. Before reading any pasteboard content:

```swift
// 1. Check app exclusion
if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
   appExclusionService.isExcluded(bundleID) {
    return // Skip capture silently
}
```

This is the critical integration point. After this step, copying from any excluded app will produce no history entry.

**Test**: Mock `AppExclusionService` with a known excluded bundle ID. Simulate a clipboard change with that bundle ID as frontmost app. Verify no `ClipboardItem` is created.

### Step 5: Concealed Content Detection

**Create**: `Pasted/Services/Privacy/ConcealedContentDetector.swift`

Single-responsibility class that checks for `org.nspasteboard.ConcealedType` in pasteboard types.

```swift
enum ConcealedContentDetector {
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    static func isConcealed(_ pasteboard: NSPasteboard = .general) -> Bool {
        guard UserDefaults.standard.bool(forKey: "concealedDetectionEnabled") else {
            return false
        }
        return pasteboard.types?.contains(concealedType) ?? false
    }
}
```

**Update** `ClipboardMonitor.swift` to add the concealed check after the app exclusion check:

```swift
// 2. Check concealed content
if ConcealedContentDetector.isConcealed() {
    return // Skip capture silently
}
```

**Test**: `PastedTests/ConcealedContentDetectorTests.swift` — test with mock pasteboard containing the concealed type, test with toggle disabled, test with pasteboard lacking the type.

### Step 6: Privacy Preferences UI

**Create**: `Pasted/Views/Preferences/PrivacyPreferencesView.swift`

SwiftUI view showing:
- List of excluded apps (icon + name + "Default" badge for built-in entries)
- "Add App..." button that presents `AppPickerView`
- Remove button (or swipe-to-delete) for each entry
- Toggle for "Detect concealed clipboard content" (bound to `concealedDetectionEnabled` UserDefaults key)
- "Clear All History..." button with confirmation alert

**Create**: `Pasted/Views/Preferences/AppPickerView.swift`

Sheet presenting:
- List of currently running regular applications (filtered from `NSWorkspace.shared.runningApplications`)
- "Browse..." button to open `NSOpenPanel` for `/Applications`
- Selection adds the app to the exclusion list via `AppExclusionService`

**Test**: Manual verification — add Notes to exclusion list, copy from Notes, verify no capture. Remove Notes, copy again, verify capture resumes.

## First Milestone Verification

After completing steps 1-4, perform this end-to-end verification:

1. Launch Pasted.
2. Open 1Password and copy a password.
3. Invoke Pasted (Shift+Cmd+V).
4. **Verify**: The password does NOT appear in clipboard history.
5. Switch to Safari, copy a URL.
6. Invoke Pasted.
7. **Verify**: The URL DOES appear in clipboard history.

This validates the core privacy guarantee: password managers are excluded, other apps are not.

## Dependencies on Prior Specs

| Dependency | Spec | What's Needed |
|-----------|------|---------------|
| `ClipboardMonitor` | 001 | The polling service that detects clipboard changes — we add the pre-capture gate here |
| `ClipboardItem` | 001 | The model we prevent from being created for excluded content |
| `ClipboardStore` | 001 | Used for individual and batch deletion of history items |
| `OCRResult` cascade | 002 | Deletion of a `ClipboardItem` must cascade to its OCR results |
| CloudKit sync | 003 | Exclusion list sync and deletion propagation to iCloud |

Steps 1-5 can be implemented without specs 002 and 003 being complete. The OCR cascade and iCloud sync integration are additive and can be wired in when those specs ship.
