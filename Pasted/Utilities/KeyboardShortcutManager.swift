import AppKit
import CoreGraphics

// MARK: - Global state for CGEvent tap callback

/// Shared reference used by the C-function event tap callback.
/// Must be set before the tap is created.
private var sharedManager: KeyboardShortcutManager?

/// C-compatible callback for the CGEvent tap.
/// IMPORTANT: Keep this callback as lightweight as possible — the system disables
/// the tap if the callback takes >1s. Never block on the main actor here; use
/// DispatchQueue.main.async for all state mutations and read only
/// nonisolated(unsafe) fields directly.
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

    // --- Strip-visible-only shortcuts ---
    // Read the cached visibility flag — no actor isolation needed.
    guard manager.isStripVisible else {
        return Unmanaged.passRetained(event)
    }

    switch keyCode {
    case 123: // Left arrow
        DispatchQueue.main.async { manager.stripPanel.selectPrevious() }
        return nil
    case 124: // Right arrow
        DispatchQueue.main.async { manager.stripPanel.selectNext() }
        return nil
    case 36: // Return
        let shift = hasShift
        DispatchQueue.main.async {
            if shift {
                manager.stripPanel.confirmSelectionPlainText()
            } else {
                manager.stripPanel.confirmSelection()
            }
        }
        return nil
    case 53: // Escape
        DispatchQueue.main.async { manager.stripPanel.dismiss() }
        return nil
    default:
        return Unmanaged.passRetained(event)
    }
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

    /// Cached strip visibility — written on the main actor, read by the CGEvent callback
    /// without actor isolation so the callback never stalls waiting for the main actor.
    nonisolated(unsafe) var isStripVisible: Bool = false

    private var runLoopSource: CFRunLoopSource?
    private var retryCount: Int = 0
    private static let maxRetries = 5

    init(stripPanel: StripPanelController, store: ClipboardStore, pasteService: PasteService) {
        self.stripPanel = stripPanel
        self.store = store
        self.pasteService = pasteService
    }

    // MARK: - Registration

    func registerShortcuts() {
        guard eventTap == nil else { return }

        sharedManager = self

        if attemptCreateEventTap() {
            print("[KeyboardShortcutManager] CGEvent tap created successfully.")
        } else {
            // Accessibility permission may not be ready immediately at launch.
            // Retry a few times with increasing delay.
            scheduleRetry()
        }
    }

    /// Attempts to create the CGEvent tap. Returns true on success.
    private func attemptCreateEventTap() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Retries CGEvent tap creation with exponential backoff (1s, 2s, 4s, 8s, 16s).
    private func scheduleRetry() {
        guard retryCount < Self.maxRetries else {
            print("[KeyboardShortcutManager] Failed to create CGEvent tap after \(Self.maxRetries) retries. Accessibility permission required — toggle it off and on in System Settings > Privacy & Security > Accessibility.")
            return
        }

        let delay = pow(2.0, Double(retryCount)) // 1, 2, 4, 8, 16 seconds
        retryCount += 1
        print("[KeyboardShortcutManager] CGEvent tap creation failed (attempt \(retryCount)/\(Self.maxRetries)). Retrying in \(Int(delay))s...")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if self.eventTap == nil {
                if self.attemptCreateEventTap() {
                    print("[KeyboardShortcutManager] CGEvent tap created successfully on retry \(self.retryCount).")
                } else {
                    self.scheduleRetry()
                }
            }
        }
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
    /// When the strip is visible, also selects the Nth item before pasting.
    func handleQuickPaste(index: Int, plainText: Bool) {
        do {
            let items = try store.fetchRecent(limit: 9)
            guard index < items.count else { return }
            let item = items[index]

            // When strip is visible, select the item visually before pasting
            if stripPanel.isVisible {
                stripPanel.selectIndex(index)
            }

            if plainText {
                pasteService.pasteAsPlainText(item)
            } else {
                pasteService.paste(item)
            }

            // Dismiss strip after quick paste if it was visible
            if stripPanel.isVisible {
                stripPanel.dismiss()
            }
        } catch {
            print("[KeyboardShortcutManager] Quick paste failed: \(error)")
        }
    }
}
