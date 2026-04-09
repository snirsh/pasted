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
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
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

        if skipNextChange {
            skipNextChange = false
            return
        }

        guard let (contentType, rawData, hasAlpha) = extractContent(from: pasteboard) else { return }

        let plainText = derivePlainText(from: pasteboard, contentType: contentType, rawData: rawData)

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let sourceAppBundleID = frontmostApp?.bundleIdentifier
        let sourceAppName = frontmostApp?.localizedName

        // URL and color items don't need JPEG thumbnails — they render live
        let thumbnail: Data?
        if contentType == .url || contentType == .color {
            thumbnail = nil
        } else {
            thumbnail = PreviewGenerator().generatePreview(for: contentType, data: rawData)
        }

        let item = ClipboardItem(
            contentType: contentType,
            rawData: rawData,
            plainTextContent: plainText,
            previewThumbnail: thumbnail,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName,
            hasAlpha: hasAlpha
        )

        do {
            try store.save(item)
        } catch {
            print("[ClipboardMonitor] Failed to save item: \(error)")
        }
    }

    // MARK: - Content Extraction

    /// Extracts the highest-priority content type, raw data, and alpha flag from the pasteboard.
    /// Priority: color > image > richText > url > file > text.
    private func extractContent(from pasteboard: NSPasteboard) -> (ContentType, Data, Bool)? {
        let types = pasteboard.types ?? []

        // Color (com.apple.color-pb) — checked before image to avoid NSColor being
        // misclassified as binary data
        let colorPBType = NSPasteboard.PasteboardType("com.apple.color-pb")
        if types.contains(colorPBType),
           let colorData = pasteboard.data(forType: colorPBType),
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData),
           let hex = hexString(from: nsColor) {
            // Store hex as raw data so it pastes as plain text
            let hexData = Data(hex.utf8)
            return (.color, hexData, false)
        }

        // Image (public.tiff, public.png)
        if types.contains(.tiff), let data = pasteboard.data(forType: .tiff) {
            let alpha = imageHasAlpha(data: data, type: .tiff)
            return (.image, data, alpha)
        }
        if types.contains(.png), let data = pasteboard.data(forType: .png) {
            let alpha = imageHasAlpha(data: data, type: .png)
            return (.image, data, alpha)
        }

        // Rich text (public.rtf, public.html)
        if types.contains(.rtf), let data = pasteboard.data(forType: .rtf) {
            return (.richText, data, false)
        }
        if types.contains(.html), let data = pasteboard.data(forType: .html) {
            return (.richText, data, false)
        }

        // URL (public.url)
        if types.contains(.URL), let data = pasteboard.data(forType: .URL) {
            return (.url, data, false)
        }

        // File URL (public.file-url)
        if types.contains(.fileURL), let data = pasteboard.data(forType: .fileURL) {
            return (.file, data, false)
        }

        // Plain text (public.utf8-plain-text)
        if types.contains(.string), let data = pasteboard.data(forType: .string) {
            return (.text, data, false)
        }

        return nil
    }

    /// Derives a plain-text representation for display and search.
    private func derivePlainText(from pasteboard: NSPasteboard, contentType: ContentType, rawData: Data) -> String? {
        switch contentType {
        case .color:
            // rawData for color is already the hex string
            return String(data: rawData, encoding: .utf8)
        case .text, .richText, .url:
            return pasteboard.string(forType: .string)
        case .image, .file:
            return nil
        }
    }

    // MARK: - Helpers

    /// Converts an NSColor to a "#RRGGBB" hex string using sRGB color space.
    private func hexString(from color: NSColor) -> String? {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        let r = UInt8((srgb.redComponent   * 255).rounded(.toNearestOrAwayFromZero))
        let g = UInt8((srgb.greenComponent * 255).rounded(.toNearestOrAwayFromZero))
        let b = UInt8((srgb.blueComponent  * 255).rounded(.toNearestOrAwayFromZero))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Returns true if the image data has an alpha channel.
    private func imageHasAlpha(data: Data, type: NSPasteboard.PasteboardType) -> Bool {
        guard let image = NSImage(data: data),
              let rep = image.representations.first as? NSBitmapImageRep else {
            return false
        }
        return rep.hasAlpha
    }
}
