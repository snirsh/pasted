# Data Model: Privacy & App Exclusions

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Date**: 2026-04-09

## Models

### AppExclusion (SwiftData @Model)

Represents an application excluded from clipboard capture. Persisted via SwiftData and synced to iCloud via CloudKit.

| Property | Type | Notes |
|----------|------|-------|
| `id` | `UUID` | Primary key, auto-generated |
| `bundleIdentifier` | `String` | Unique, indexed. Reverse-DNS format (e.g., `com.1password.1password`). Used for O(1) lookup. |
| `displayName` | `String` | Human-readable app name (e.g., "1Password"). Extracted from the app bundle at add time. |
| `iconData` | `Data?` | Optional. App icon thumbnail stored as PNG data (32x32). Cached at add time to avoid re-reading the app bundle. Nil if icon unavailable. |
| `isDefault` | `Bool` | `true` for apps in the built-in default list, `false` for user-added apps. Default apps are visually marked in the preferences UI. |
| `dateAdded` | `Date` | Timestamp of when the exclusion was created. Used for display ordering (newest first for user-added, alphabetical for defaults). |

**Constraints**:
- `bundleIdentifier` is unique — attempting to add a duplicate is a no-op (idempotent).
- `bundleIdentifier` is indexed for efficient SwiftData queries when rebuilding the in-memory Set.

```swift
@Model
final class AppExclusion {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var bundleIdentifier: String
    var displayName: String
    var iconData: Data?
    var isDefault: Bool
    var dateAdded: Date

    init(bundleIdentifier: String, displayName: String, iconData: Data? = nil, isDefault: Bool = false) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.iconData = iconData
        self.isDefault = isDefault
        self.dateAdded = Date()
    }
}
```

### ExclusionLookup (In-Memory, Not Persisted)

Runtime wrapper that provides O(1) bundle ID lookup for the clipboard monitor hot path. Not a SwiftData model — exists only in memory.

| Property | Type | Notes |
|----------|------|-------|
| `excludedBundleIDs` | `Set<String>` | In-memory set of all excluded bundle identifiers. Rebuilt from SwiftData on launch and on any exclusion list change. |

```swift
final class ExclusionLookup {
    private(set) var excludedBundleIDs: Set<String> = []

    func rebuild(from exclusions: [AppExclusion]) {
        excludedBundleIDs = Set(exclusions.map(\.bundleIdentifier))
    }

    func isExcluded(_ bundleIdentifier: String) -> Bool {
        excludedBundleIDs.contains(bundleIdentifier)
    }
}
```

### ConcealedContentFlag (Runtime Check, Not Persisted)

Not a data model — a runtime check performed on `NSPasteboard.general.types` during clipboard change processing.

**Pasteboard type**: `"org.nspasteboard.ConcealedType"`

```swift
extension NSPasteboard.PasteboardType {
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
}
```

**Detection logic**:
```swift
let isConcealed = NSPasteboard.general.types?.contains(.concealed) ?? false
```

No persistence needed. The concealed flag is evaluated once per clipboard change and the result determines whether to skip capture.

## UserDefaults Keys

| Key | Type | Default | Notes |
|-----|------|---------|-------|
| `concealedDetectionEnabled` | `Bool` | `true` | When `true`, clipboard entries with the concealed type are silently skipped. Users can disable this in Privacy preferences. |

## Integration with Existing Models

### ClipboardMonitor (from spec 001) — Updated Capture Flow

The `ClipboardMonitor` is updated with a pre-capture gate. Before processing any clipboard change:

1. **App exclusion check**: Get `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`. If it exists in `ExclusionLookup.excludedBundleIDs`, skip capture silently. Return without creating a `ClipboardItem`.
2. **Concealed content check**: If `UserDefaults.standard.bool(forKey: "concealedDetectionEnabled")` is `true`, check `NSPasteboard.general.types?.contains(.concealed)`. If concealed, skip capture silently.
3. If neither check triggers, proceed with normal capture (create `ClipboardItem`, generate preview, run OCR, etc.).

Both checks occur before any clipboard content is read, ensuring sensitive data is never even loaded into memory.

### ClipboardItem (from spec 001) — Deletion Support

No model changes needed. Deletion uses existing SwiftData operations:
- **Individual delete**: `modelContext.delete(item)` — SwiftData handles cascade to related OCR results (spec 002) if relationships are configured with `.cascade` delete rule.
- **Clear all**: `try modelContext.delete(model: ClipboardItem.self)` — batch delete all records.

### iCloud Sync (from spec 003) — Exclusion List Sync

`AppExclusion` records are included in the CloudKit sync scope alongside `ClipboardItem`. When a user adds or removes an exclusion on one device, the change propagates to all devices via the existing CloudKit sync infrastructure. On receiving a remote exclusion change, the `ExclusionLookup` Set is rebuilt.

## Relationships Diagram

```text
┌─────────────────────┐
│   ClipboardMonitor   │
│   (spec 001)         │
│                      │
│  on clipboard change │
│         │            │
│         ▼            │
│  ┌──────────────┐    │
│  │ Pre-capture   │    │
│  │ gate          │    │
│  │               │    │
│  │ 1. App excl?  │────┼──▶ ExclusionLookup (Set<String>)
│  │ 2. Concealed? │────┼──▶ NSPasteboard.types.contains(.concealed)
│  │               │    │
│  │ Both pass?    │    │
│  │    │          │    │
│  │    ▼          │    │
│  │ Capture item  │    │
│  └──────────────┘    │
└─────────────────────┘

┌─────────────────────┐     ┌─────────────────────┐
│  AppExclusionService │────▶│  AppExclusion        │
│                      │     │  (@Model, SwiftData)  │
│  add / remove /      │     │                      │
│  rebuild lookup      │     │  bundleIdentifier    │
│         │            │     │  displayName         │
│         ▼            │     │  iconData            │
│  ExclusionLookup     │     │  isDefault           │
│  (in-memory Set)     │     │  dateAdded           │
└─────────────────────┘     └─────────────────────┘
                                      │
                                      ▼
                             ┌─────────────────────┐
                             │  DefaultExclusionList │
                             │  (hardcoded bundle    │
                             │   IDs, seeds on first │
                             │   launch)             │
                             └─────────────────────┘
```
