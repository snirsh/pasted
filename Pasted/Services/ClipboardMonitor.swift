import AppKit
import Foundation

/// Polls NSPasteboard.general at a fixed interval and captures new clipboard entries.
@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int
    nonisolated(unsafe) var skipNextChange = false

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Tell the monitor to ignore the next pasteboard change
    /// (used when PasteService writes to the pasteboard for pasting).
    nonisolated func skipNext() {
        skipNextChange = true
    }

    // MARK: - Polling

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Skip changes we caused (e.g., pasting an item writes to the pasteboard)
        if skipNextChange {
            skipNextChange = false
            return
        }

        guard let (contentType, rawData) = extractContent(from: pasteboard) else { return }

        let plainText = derivePlainText(from: pasteboard, contentType: contentType)

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let sourceAppBundleID = frontmostApp?.bundleIdentifier
        let sourceAppName = frontmostApp?.localizedName

        // Generate preview thumbnail before saving so the item is complete
        let thumbnail = PreviewGenerator().generatePreview(for: contentType, data: rawData)

        let item = ClipboardItem(
            contentType: contentType,
            rawData: rawData,
            plainTextContent: plainText,
            previewThumbnail: thumbnail,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName
        )

        do {
            try store.save(item)
        } catch {
            print("[ClipboardMonitor] Failed to save item: \(error)")
        }
    }

    // MARK: - Content Extraction

    /// Extracts the highest-priority content type and its raw data from the pasteboard.
    /// Priority: image > richText > url > file > text.
    private func extractContent(from pasteboard: NSPasteboard) -> (ContentType, Data)? {
        let types = pasteboard.types ?? []

        // Image (public.tiff, public.png)
        if types.contains(.tiff), let data = pasteboard.data(forType: .tiff) {
            return (.image, data)
        }
        if types.contains(.png), let data = pasteboard.data(forType: .png) {
            return (.image, data)
        }

        // Rich text (public.rtf, public.html)
        if types.contains(.rtf), let data = pasteboard.data(forType: .rtf) {
            return (.richText, data)
        }
        if types.contains(.html), let data = pasteboard.data(forType: .html) {
            return (.richText, data)
        }

        // URL (public.url)
        if types.contains(.URL), let data = pasteboard.data(forType: .URL) {
            return (.url, data)
        }

        // File URL (public.file-url)
        if types.contains(.fileURL), let data = pasteboard.data(forType: .fileURL) {
            return (.file, data)
        }

        // Plain text (public.utf8-plain-text)
        if types.contains(.string), let data = pasteboard.data(forType: .string) {
            return (.text, data)
        }

        return nil
    }

    /// Derives a plain-text representation for text, richText, and url types.
    private func derivePlainText(from pasteboard: NSPasteboard, contentType: ContentType) -> String? {
        switch contentType {
        case .text, .richText, .url:
            return pasteboard.string(forType: .string)
        case .image, .file:
            return nil
        }
    }
}
