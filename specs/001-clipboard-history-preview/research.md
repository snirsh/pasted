# Research: Clipboard History & Visual Preview

**Feature**: `001-clipboard-history-preview` | **Date**: 2026-04-09
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Decision 1: Clipboard Monitoring Strategy

**Question**: How should Pasted detect new clipboard content?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. NSPasteboard changeCount polling | Poll `NSPasteboard.general.changeCount` on a repeating Timer (0.5s interval). When the count changes, read pasteboard contents. | Standard macOS approach. Public API. App Store safe. No special entitlements beyond Accessibility. Used by most clipboard managers (Maccy, CopyClip). | Polling consumes minimal but non-zero CPU. 0.5s max latency between copy and capture. |
| B. NSPasteboard notifications | Listen for pasteboard change notifications. | Event-driven, no polling. | `NSPasteboard` does not post public notifications for content changes. No reliable public API exists. |
| C. Private API / SPI | Use undocumented APIs (`_NSPasteboardChanged`, etc.) | Instant detection, no polling overhead. | App Store rejection. Breaks on macOS updates. Violates Constitution Principle II (native, no private APIs) and Principle IV (open source auditability). |
| D. Accessibility API observation | Use AX APIs to observe copy actions in apps. | Could detect source app context. | Unreliable across apps. Over-engineered for clipboard detection. Higher permission requirements. |

**Decision**: **Option A — NSPasteboard changeCount polling (0.5s interval)**

**Rationale**: This is the standard, documented approach used by virtually all macOS clipboard managers. It requires no private APIs (Constitution Principle II), is App Store compatible, and the 0.5s polling interval provides an excellent balance between responsiveness and resource usage. The polling overhead is negligible (one integer comparison per tick). Constitution Principle V (simplicity) also favors this — it is the simplest correct approach.

**Implementation Notes**:
- Use `Timer.scheduledTimer` with 0.5s interval on the main run loop
- Compare `NSPasteboard.general.changeCount` against stored value
- On change: read all available pasteboard types, extract content, create `ClipboardItem`
- Handle multiple representations per pasteboard item (e.g., rich text items have both RTF and plain text)
- Deduplication check (FR-011): compare raw data hash with the most recent item before persisting

---

## Decision 2: Data Persistence

**Question**: How should clipboard history be stored on disk?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. SwiftData (@Model) | Use Apple's SwiftData framework with `@Model` macro for persistence. | Modern Swift-native API. Automatic migration support. Integrates with SwiftUI via `@Query`. Built-in CloudKit sync path for future spec (iCloud sync). Constitution Principle II compliance. | macOS 14+ only (acceptable — our deployment target). Relatively new framework (less community knowledge). |
| B. Core Data | Use Core Data with NSManagedObject subclasses. | Battle-tested. Rich querying. Well-documented. | Verbose boilerplate. Objective-C heritage feels non-native in pure Swift codebase. SwiftData is Apple's intended successor. |
| C. SQLite (direct or via GRDB/SQLite.swift) | Use SQLite directly or via a Swift wrapper library. | Maximum control. High performance. | External dependency (violates Constitution: no external runtime dependencies). More code to maintain. No automatic SwiftUI integration. |
| D. File-based (JSON/Plist per item) | Store each clipboard item as a file in a directory. | Simple to implement. Easy to inspect. | Poor query performance at 10K+ items. No indexing. Pagination requires manual work. |

**Decision**: **Option A — SwiftData with @Model**

**Rationale**: SwiftData is the Apple-endorsed persistence framework for modern Swift apps targeting macOS 14+ (our deployment target). It aligns with Constitution Principle II (native Apple frameworks) and has zero external dependencies (Constitution Principle IV). The `@Query` property wrapper integrates directly with SwiftUI views for reactive UI updates. SwiftData's CloudKit integration provides a future path for the iCloud sync spec without re-architecting persistence. Core Data was rejected as the legacy option; SQLite was rejected for requiring external dependencies.

**Implementation Notes**:
- Define `ClipboardItem` as a `@Model` class
- Configure `ModelContainer` in the App entry point with a persistent store URL
- Use `@Query` in strip view for paginated, sorted access (newest first)
- Store raw clipboard data as `Data` blobs within the model
- Preview thumbnails stored as `Data` (JPEG compressed) for efficiency
- Implement storage pruning via a background `ModelContext` that deletes oldest items when total byteSize exceeds threshold

---

## Decision 3: Preview Generation

**Question**: How should visual previews be generated for each content type?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. Native Apple APIs per type | NSImage thumbnailing for images, AttributedString for rich text, NSWorkspace for file icons, SF Symbols for type indicators. | No dependencies. Fast. High-quality native rendering. Constitution compliant. | Must implement per-type logic (5 types). |
| B. WebKit rendering | Render all previews as HTML in a WKWebView snapshot. | Unified rendering path. Handles rich text/HTML well. | Heavy for simple text. Memory overhead. Latency for WebKit spin-up. Over-engineered (Constitution Principle V). |
| C. QuickLook thumbnailing | Use QuickLook's `QLThumbnailGenerator` for all types. | Single API for all types. | Designed for files, not arbitrary clipboard data. Poor fit for plain text or URLs. Async with unpredictable latency. |

**Decision**: **Option A — Native Apple APIs per content type**

**Rationale**: Each content type has a natural, efficient rendering path using Apple's built-in frameworks. This approach is fast (meets the 200ms strip display requirement), has no dependencies, and produces high-quality previews that match the macOS aesthetic. Constitution Principle II (native) and V (simplicity — each renderer is 20-40 lines) both support this choice.

**Implementation Notes**:
- **Plain text**: Render first ~4 lines using `Text` view with system monospace font. Truncate with ellipsis.
- **Rich text**: Convert RTF/HTML `Data` to `NSAttributedString`, render in a fixed-size `NSTextView` snapshot, capture as `NSImage`.
- **Images**: Scale source `NSImage` to thumbnail size (e.g., 120x80pt) using `NSImage.resize(to:)`. Store JPEG-compressed `Data`.
- **URLs**: Display URL string with `link.badge` SF Symbol. If pasteboard includes title metadata, show that too.
- **Files**: Use `NSWorkspace.shared.icon(forFile:)` for the file icon. Display filename below the icon.
- All preview thumbnails are generated at capture time (not on-demand) and stored in `previewThumbnail` for instant strip rendering.

---

## Decision 4: Global Keyboard Shortcuts

**Question**: How should Pasted register and handle global keyboard shortcuts?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. CGEvent tap | Install a CGEvent tap (`CGEvent.tapCreate`) to intercept keyboard events system-wide. | Full control over modifier + key combinations. Can handle Shift+Cmd+V, Cmd+1-9, Shift+Cmd+1-9. Standard approach for clipboard managers. | Requires Accessibility permission. Runs on a background thread (must dispatch to main for UI). |
| B. NSEvent.addGlobalMonitorForEvents | Use AppKit's global event monitor. | Simpler API. No raw event tap setup. | Cannot consume events (only observe). Cannot prevent key from reaching the active app. Limited modifier handling. |
| C. Carbon Hot Key API (RegisterEventHotKey) | Legacy Carbon API for global hotkeys. | Works without Accessibility permission for simple shortcuts. | Deprecated. Limited to simple modifier+key combos. Cannot handle the full shortcut matrix we need. Carbon API may be removed in future macOS. |
| D. MASShortcut / HotKey library | Third-party library for global shortcut registration. | Clean API. Well-tested. | External dependency (violates Constitution: no external runtime dependencies). |

**Decision**: **Option A — CGEvent tap**

**Rationale**: CGEvent tap provides the most complete and flexible keyboard event handling. It can intercept and consume events (preventing them from reaching other apps when Pasted handles them), supports arbitrary modifier+key combinations, and is the standard approach for macOS utilities that need global keyboard control. The Accessibility permission requirement is already documented in the spec's Assumptions section. Constitution Principle II is satisfied (CGEvent is a public Apple framework). External libraries were rejected per Constitution Principle IV (no external dependencies).

**Implementation Notes**:
- Create event tap with `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue), callback: ...)`
- In the callback, check for registered shortcut combinations
- Shift+Cmd+V: Toggle strip visibility
- Cmd+1-9 (when strip hidden): Quick paste nth item
- Cmd+1-9 (when strip visible): Select and paste nth item
- Shift+Cmd+1-9: Quick paste as plain text
- Arrow keys, Return, Escape: Only active when strip is visible
- Add event tap to current run loop as a `CFRunLoopSource`
- Prompt user for Accessibility permission on first launch if not granted

---

## Decision 5: Paste Injection

**Question**: How should Pasted paste content into the active application?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. CGEvent keystroke simulation | Write the selected item to `NSPasteboard.general`, then simulate Cmd+V via `CGEvent`. | Works universally across all apps. Standard approach for clipboard managers. Simple and reliable. | Briefly overwrites the system pasteboard (must restore afterward). Requires Accessibility permission. |
| B. Accessibility API (AXUIElement) | Use AX APIs to find the focused text field and insert text directly. | Doesn't overwrite pasteboard. | Only works for text fields. Doesn't work for images, files, or rich text. Unreliable across apps. |
| C. AppleScript / osascript | Send `keystroke "v" using command down` via AppleScript. | No CGEvent setup needed. | Slower. Requires allowing automation per app. Unreliable for fast sequences. |

**Decision**: **Option A — CGEvent keystroke simulation**

**Rationale**: CGEvent-based Cmd+V simulation is the standard, universal approach used by all major macOS clipboard managers (Paste, Maccy, CopyClip, Alfred). It works for every content type (text, images, files, rich text) and every target application. The brief pasteboard overwrite is mitigated by saving and restoring the pasteboard contents before/after the simulated paste. Constitution Principle V (simplicity) strongly favors this — it is one function call versus complex AX API negotiation.

**Implementation Notes**:
- Save current `NSPasteboard.general` contents (all types)
- Write selected `ClipboardItem.rawData` to `NSPasteboard.general` with appropriate UTType
- For plain text mode: write only `public.utf8-plain-text` representation
- Simulate Cmd+V: create `CGEvent` for keyDown (keycode 9, Cmd flag) and keyUp, post to `CGEventTapLocation.cghidEventTap`
- After a short delay (~100ms), restore original pasteboard contents
- Dismiss the strip overlay before simulating the paste

---

## Decision 6: Window Management (Strip Overlay)

**Question**: How should the horizontal strip overlay be displayed?

**Options Considered**:

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A. NSPanel (floating, non-activating) | Use a borderless `NSPanel` with `.nonactivatingPanel` style, floating level. Host SwiftUI strip view via `NSHostingView`. | Doesn't steal focus from target app. Floats above all windows. Standard for utility overlays. Full control over appearance and position. | Must manage window lifecycle manually. |
| B. SwiftUI Window (WindowGroup / Window) | Use SwiftUI's native window management. | Pure SwiftUI. Less AppKit code. | SwiftUI windows activate the app, stealing focus from the target. Cannot create non-activating floating panels in pure SwiftUI. Deal-breaker for a clipboard manager. |
| C. NSPopover | Attach to the menu bar icon as a popover. | Simple setup. Familiar macOS pattern. | Limited size. Cannot be a horizontal strip across the screen. Awkward for keyboard navigation. |

**Decision**: **Option A — NSPanel (floating, non-activating)**

**Rationale**: A non-activating `NSPanel` is the only option that satisfies the core requirement: displaying the clipboard strip without stealing focus from the application the user wants to paste into. Pure SwiftUI windows activate the app, which would break the paste workflow entirely. `NSPanel` with `NSWindowLevel.floating` and `styleMask: [.nonactivatingPanel, .borderless]` is the standard approach for clipboard manager overlays. The SwiftUI strip view is hosted inside via `NSHostingView`.

**Implementation Notes**:
- Create `NSPanel(contentRect:styleMask:backing:defer:)` with `.nonactivatingPanel` and `.borderless`
- Set `panel.level = .floating` and `panel.isFloatingPanel = true`
- Set `panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` for multi-desktop and fullscreen support
- Host `ClipboardStripView` via `NSHostingView` as the panel's `contentView`
- Position: horizontally centered, near the bottom of the active screen
- Animate in/out with a brief slide-up/fade animation
- Panel background: `NSVisualEffectView` with `.hudWindow` material for the native macOS translucent look
- Dismiss on: Escape, Return (after paste), clicking outside, or losing relevance
