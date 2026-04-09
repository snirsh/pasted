import AppKit
import CoreGraphics
import UniformTypeIdentifiers

/// Injects clipboard items back into the active application via pasteboard write + simulated Cmd+V.
final class PasteService {

    // MARK: - Public API

    /// Pastes the item in its original format.
    func paste(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        let previousContents = savePasteboard(pasteboard)

        writeToPasteboard(pasteboard, data: item.rawData, contentType: item.contentType)
        simulatePaste()

        // Restore previous pasteboard contents after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restorePasteboard(pasteboard, contents: previousContents)
        }
    }

    /// Pastes only the plain-text representation of the item.
    func pasteAsPlainText(_ item: ClipboardItem) {
        guard let plainText = item.plainTextContent,
              let textData = plainText.data(using: .utf8) else { return }

        let pasteboard = NSPasteboard.general
        let previousContents = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setData(textData, forType: .string)
        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restorePasteboard(pasteboard, contents: previousContents)
        }
    }

    // MARK: - Pasteboard Save / Restore

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        var snapshot: [[NSPasteboard.PasteboardType: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            snapshot.append(itemData)
        }
        return PasteboardSnapshot(items: snapshot)
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, contents: PasteboardSnapshot) {
        pasteboard.clearContents()
        for itemData in contents.items {
            let pbItem = NSPasteboardItem()
            for (type, data) in itemData {
                pbItem.setData(data, forType: type)
            }
            pasteboard.writeObjects([pbItem])
        }
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
