import AppKit
import CoreGraphics

// MARK: - Global state for CGEvent tap callback

/// Shared reference used by the C-function event tap callback.
/// Must be set before the tap is created.
private var sharedManager: KeyboardShortcutManager?

/// C-compatible callback for the CGEvent tap.
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap is disabled by the system, re-enable it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = sharedManager?.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown,
          let manager = sharedManager else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    let hasCommand = flags.contains(.maskCommand)
    let hasShift = flags.contains(.maskShift)

    // --- Shift+Cmd+V: Toggle strip ---
    if hasCommand && hasShift && keyCode == 9 { // V
        DispatchQueue.main.async {
            manager.stripPanel.toggle()
        }
        return nil // Consume the event
    }

    // --- Cmd+1-9: Quick paste (original format) ---
    // Key codes for 1-9: 18, 19, 20, 21, 23, 22, 26, 28, 25
    let digitKeyCodes: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    if hasCommand && !hasShift, let index = digitKeyCodes.firstIndex(of: keyCode) {
        DispatchQueue.main.async {
            manager.handleQuickPaste(index: index, plainText: false)
        }
        return nil
    }

    // --- Shift+Cmd+1-9: Quick paste (plain text) ---
    if hasCommand && hasShift, let index = digitKeyCodes.firstIndex(of: keyCode) {
        DispatchQueue.main.async {
            manager.handleQuickPaste(index: index, plainText: true)
        }
        return nil
    }

    // --- Strip-visible-only shortcuts ---
    // The CGEvent tap callback runs on the main run loop, so we can safely
    // assume MainActor isolation to access the strip panel state.
    var consumed = false
    MainActor.assumeIsolated {
        if manager.stripPanel.isVisible {
            switch keyCode {
            case 123: // Left arrow
                manager.stripPanel.selectPrevious()
                consumed = true
            case 124: // Right arrow
                manager.stripPanel.selectNext()
                consumed = true
            case 36: // Return
                manager.stripPanel.confirmSelection()
                consumed = true
            case 53: // Escape
                manager.stripPanel.dismiss()
                consumed = true
            default:
                break
            }
        }
    }
    if consumed { return nil }

    return Unmanaged.passRetained(event)
}

// MARK: - KeyboardShortcutManager

/// Manages a system-wide CGEvent tap for global keyboard shortcuts.
@MainActor
final class KeyboardShortcutManager {
    let stripPanel: StripPanelController
    private let store: ClipboardStore
    private let pasteService: PasteService

    /// The underlying CGEvent tap. Exposed internally for the callback to re-enable if needed.
    nonisolated(unsafe) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(stripPanel: StripPanelController, store: ClipboardStore, pasteService: PasteService) {
        self.stripPanel = stripPanel
        self.store = store
        self.pasteService = pasteService
    }

    // MARK: - Registration

    func registerShortcuts() {
        guard eventTap == nil else { return }

        sharedManager = self

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            print("[KeyboardShortcutManager] Failed to create CGEvent tap. Accessibility permission required.")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregisterShortcuts() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        sharedManager = nil
    }

    // MARK: - Quick Paste

    /// Pastes the item at the given index (0-based) from the recent clipboard history.
    func handleQuickPaste(index: Int, plainText: Bool) {
        do {
            let items = try store.fetchRecent(limit: 9)
            guard index < items.count else { return }
            let item = items[index]

            if plainText {
                pasteService.pasteAsPlainText(item)
            } else {
                pasteService.paste(item)
            }
        } catch {
            print("[KeyboardShortcutManager] Quick paste failed: \(error)")
        }
    }
}
