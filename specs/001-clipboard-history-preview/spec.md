# Feature Specification: Clipboard History & Visual Preview

**Feature Branch**: `001-clipboard-history-preview`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "Core clipboard management with infinite history, visual previews, horizontal strip UI, keyboard-first navigation, and paste controls"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy and Access Clipboard History (Priority: P1)

A user copies text, images, links, or files throughout their workday. At any point, they invoke Pasted with a keyboard shortcut and see a horizontal strip of their recent clipboard items displayed as visual previews. They navigate left/right to find the item they need and press Return to paste it into the active application.

**Why this priority**: This is the foundational value proposition — without clipboard history capture and retrieval, nothing else matters. Every other feature builds on this.

**Independent Test**: Copy 5 different items (text, image, URL, file, rich text), invoke Pasted, verify all 5 appear as previews in chronological order, select one, and confirm it pastes correctly into the target app.

**Acceptance Scenarios**:

1. **Given** the user has copied 3 items (text, image, URL), **When** they press Shift+Cmd+V, **Then** a horizontal strip appears showing visual previews of all 3 items with the most recent on the left.
2. **Given** Pasted is open showing clipboard history, **When** the user presses the right arrow key, **Then** the selection moves to the next (older) item with a visible highlight.
3. **Given** an item is selected in the strip, **When** the user presses Return, **Then** the item is pasted into the previously active application and Pasted dismisses.
4. **Given** Pasted is open, **When** the user presses Escape, **Then** Pasted dismisses without pasting anything.

---

### User Story 2 - Visual Previews for All Content Types (Priority: P1)

Users copy diverse content types throughout the day — plain text, rich text, images, screenshots, URLs, and files. Each item in the clipboard history strip displays a meaningful visual preview so users can identify items at a glance without clicking into them.

**Why this priority**: Without recognizable previews, users can't efficiently find what they need in a horizontal strip — the UI becomes useless.

**Independent Test**: Copy one item of each supported type, invoke Pasted, and verify each has a distinguishable, content-appropriate preview thumbnail.

**Acceptance Scenarios**:

1. **Given** the user copies plain text, **When** it appears in the strip, **Then** it shows the first few lines of text rendered in a readable font size.
2. **Given** the user copies an image or screenshot, **When** it appears in the strip, **Then** it shows a scaled-down thumbnail of the actual image.
3. **Given** the user copies a URL, **When** it appears in the strip, **Then** it shows the URL with a link icon and, when available, the page title or favicon.
4. **Given** the user copies a file (e.g., from Finder), **When** it appears in the strip, **Then** it shows the file icon and filename.
5. **Given** the user copies rich text (HTML/RTF), **When** it appears in the strip, **Then** it shows a styled text preview preserving basic formatting.

---

### User Story 3 - Quick Paste via Number Shortcuts (Priority: P2)

Power users want to paste recently copied items without navigating the strip at all. They press Cmd+1 through Cmd+9 to instantly paste the 1st through 9th most recent clipboard items directly into the active application.

**Why this priority**: Accelerates the most common use case (pasting recent items) for keyboard-centric users, but the app is usable without it.

**Independent Test**: Copy 3 items, press Cmd+2 (without opening Pasted), and verify the second-most-recent item is pasted.

**Acceptance Scenarios**:

1. **Given** the user has copied at least 3 items, **When** they press Cmd+2 (without Pasted open), **Then** the 2nd most recent item is pasted into the active application.
2. **Given** fewer than 5 items exist in history, **When** the user presses Cmd+5, **Then** nothing happens (no error, no paste).
3. **Given** Pasted is open, **When** the user presses Cmd+1 through Cmd+9, **Then** the corresponding item is pasted and Pasted dismisses.

---

### User Story 4 - Paste as Plain Text (Priority: P2)

Users often copy rich text from web pages or documents but want to paste it without formatting into their target application. They can paste any item as plain text using a modifier key.

**Why this priority**: Essential quality-of-life feature that differentiates a clipboard manager from the system clipboard, but the app works without it.

**Independent Test**: Copy rich HTML text, invoke Pasted, select the item, press Shift+Return, and verify plain text (no formatting) is pasted.

**Acceptance Scenarios**:

1. **Given** a rich text item is selected in the strip, **When** the user presses Shift+Return, **Then** the item is pasted as plain text (all formatting stripped) into the active application.
2. **Given** an image is selected, **When** the user presses Shift+Return, **Then** nothing happens or an appropriate indication is shown (images have no plain text equivalent).
3. **Given** Pasted is not open, **When** the user presses Shift+Cmd+1 through Shift+Cmd+9, **Then** the corresponding item is pasted as plain text.

---

### User Story 5 - Persistent History Across Restarts (Priority: P1)

Clipboard history MUST survive application restarts and system reboots. Users expect their clipboard history to be available the next time they open their Mac.

**Why this priority**: Without persistence, the app loses all value every time the Mac restarts — a fundamental reliability expectation.

**Independent Test**: Copy 5 items, quit Pasted, relaunch it, invoke the strip, and verify all 5 items are still present.

**Acceptance Scenarios**:

1. **Given** the user has 100 items in history, **When** Pasted is quit and relaunched, **Then** all 100 items are present in the strip with their original previews.
2. **Given** the Mac reboots, **When** Pasted launches at login, **Then** the full clipboard history from before the reboot is available.

---

### Edge Cases

- What happens when the user copies an extremely large item (e.g., a 50MB image or a 100,000-line text file)? Items exceeding a reasonable size threshold (e.g., 50MB) are stored with a truncated preview and a size indicator. The full content is still available for pasting.
- What happens when clipboard history reaches storage limits? Oldest items are automatically pruned when local storage exceeds a configurable threshold (default: 1GB). Users are not interrupted.
- What happens when another clipboard manager is running simultaneously? Pasted monitors NSPasteboard independently. Conflicts are unlikely but if another app modifies the pasteboard, Pasted captures the result.
- What happens when the user copies sensitive content (passwords)? Handled by the Privacy & App Exclusions spec (004). Items from excluded apps are never captured.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST monitor the macOS system clipboard continuously for new content and capture each unique clipboard entry.
- **FR-002**: System MUST store clipboard entries persistently on disk, surviving application restarts and system reboots.
- **FR-003**: System MUST display a horizontal strip overlay of clipboard previews when the user presses the invocation shortcut (default: Shift+Cmd+V).
- **FR-004**: System MUST render content-appropriate visual previews for: plain text, rich text, images, URLs, and files.
- **FR-005**: System MUST support keyboard navigation of the strip: arrow keys to move, Return to paste, Escape to dismiss.
- **FR-006**: System MUST paste the selected item into the previously active application upon selection.
- **FR-007**: System MUST support quick paste shortcuts (Cmd+1 through Cmd+9) for the 9 most recent items.
- **FR-008**: System MUST support pasting items as plain text via Shift+Return (in strip) or Shift+Cmd+1-9 (quick paste).
- **FR-009**: System MUST automatically prune oldest items when storage exceeds the configured limit (default: 1GB).
- **FR-010**: System MUST launch at login and run as a background process (menu bar agent).
- **FR-011**: System MUST deduplicate consecutive identical clipboard entries.

### Key Entities

- **ClipboardItem**: Represents a single captured clipboard entry. Attributes: unique ID, content type (text/image/URL/file/rich text), raw content data, plain text representation (if applicable), preview thumbnail, source application bundle identifier, timestamp captured, byte size.
- **ClipboardHistory**: Ordered collection of ClipboardItems, sorted by capture time (newest first). Supports pagination for large histories.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can invoke Pasted and paste a previously copied item within 2 seconds of pressing the shortcut.
- **SC-002**: Clipboard history retains at least 10,000 items before automatic pruning begins.
- **SC-003**: The horizontal strip displays within 200ms of the invocation shortcut being pressed.
- **SC-004**: Visual previews for text and images are recognizable at the default strip thumbnail size (no squinting required).
- **SC-005**: 100% of clipboard content types supported by macOS NSPasteboard are captured (text, images, files, URLs, rich text).
- **SC-006**: Clipboard history is fully intact after application restart with zero data loss.

## Assumptions

- Users have macOS 14 Sonoma or later installed.
- Pasted has been granted Accessibility permissions by the user (required for global keyboard shortcuts and pasting into other apps).
- The user's Mac has sufficient disk space for clipboard history storage (default limit: 1GB).
- Only one instance of Pasted runs at a time.
- Clipboard monitoring uses NSPasteboard change count polling (standard macOS approach — no private APIs).
