import Foundation
import AppKit

/// Manages keyboard-driven navigation state within the clipboard strip.
/// Translates key events into selection movements and actions.
final class StripNavigationHandler: ObservableObject {
    @Published var selectedIndex: Int?
    var itemCount: Int = 0

    // MARK: - Directional Navigation

    func moveLeft() {
        guard itemCount > 0 else { return }
        if let current = selectedIndex {
            selectedIndex = max(current - 1, 0)
        } else {
            selectedIndex = 0
        }
    }

    func moveRight() {
        guard itemCount > 0 else { return }
        if let current = selectedIndex {
            selectedIndex = min(current + 1, itemCount - 1)
        } else {
            selectedIndex = 0
        }
    }

    func selectFirst() {
        guard itemCount > 0 else { return }
        selectedIndex = 0
    }

    func selectLast() {
        guard itemCount > 0 else { return }
        selectedIndex = itemCount - 1
    }

    // MARK: - Key Event Handling

    /// Result of handling a key event, indicating what action the strip should take.
    enum Action {
        case none
        case dismiss
        case paste
        case pastePlainText
    }

    /// Processes an NSEvent key-down and returns the resulting action.
    /// Returns `.none` if the key was not handled.
    func handleKeyEvent(_ event: NSEvent) -> Action {
        guard event.type == .keyDown else { return .none }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch keyCode {
        // Escape (keyCode 53)
        case 53:
            return .dismiss

        // Return (keyCode 36)
        case 36:
            if modifiers.contains(.shift) {
                return .pastePlainText
            }
            return .paste

        // Left arrow (keyCode 123)
        case 123:
            if modifiers.contains(.command) {
                selectFirst()
            } else {
                moveLeft()
            }
            return .none

        // Right arrow (keyCode 124)
        case 124:
            if modifiers.contains(.command) {
                selectLast()
            } else {
                moveRight()
            }
            return .none

        // Up arrow (keyCode 126) — Cmd+Up = first item
        case 126:
            if modifiers.contains(.command) {
                selectFirst()
            }
            return .none

        // Down arrow (keyCode 125) — Cmd+Down = last item
        case 125:
            if modifiers.contains(.command) {
                selectLast()
            }
            return .none

        default:
            return .none
        }
    }
}
