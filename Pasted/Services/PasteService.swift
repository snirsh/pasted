import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Injects clipboard items back into the active application via pasteboard write + simulated Cmd+V.
final class PasteService {
    /// Set by AppDelegate so we can tell the monitor to skip changes we cause.
    weak var clipboardMonitor: ClipboardMonitor?

    // MARK: - Public API

    /// Pastes the item in its original format.
    /// The item becomes the current clipboard content and is promoted to most recent.
    func paste(_ item: ClipboardItem) {
        clipboardMonitor?.skipNext()
        let pasteboard = NSPasteboard.general
        writeToPasteboard(pasteboard, data: item.rawData, contentType: item.contentType)

        // Promote to most recent in clipboard history
        item.capturedAt = Date()

        simulatePaste()
    }

    /// Pastes only the plain-text representation of the item.
    /// The plain text becomes the current clipboard content.
    func pasteAsPlainText(_ item: ClipboardItem) {
        guard let plainText = item.plainTextContent,
              let textData = plainText.data(using: .utf8) else { return }

        clipboardMonitor?.skipNext()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(textData, forType: .string)

        // Promote to most recent
        item.capturedAt = Date()

        simulatePaste()
    }

    // MARK: - Pasteboard Write

    private func writeToPasteboard(_ pasteboard: NSPasteboard, data: Data, contentType: ContentType) {
        pasteboard.clearContents()

        let type: NSPasteboard.PasteboardType
        switch contentType {
        case .text:
            type = .string
        case .richText:
            type = .rtf
        case .image:
            type = .tiff
        case .url:
            type = .URL
        case .file:
            type = .fileURL
        case .color:
            // Color items store the hex string as UTF-8 — paste as plain text
            type = .string
        }

        pasteboard.setData(data, forType: type)
    }

    // MARK: - Keystroke Simulation

    /// Simulates Cmd+V via CGEvent to trigger paste in the frontmost application.
    private func simulatePaste() {
        let keyCode: CGKeyCode = 9 // 'V' key

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
