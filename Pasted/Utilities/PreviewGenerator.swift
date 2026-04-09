import AppKit
import Foundation

/// Generates JPEG preview thumbnails for clipboard items.
/// Routes to type-specific generators based on ContentType.
/// Target output: ~240x160pt (480x320px @2x Retina), JPEG at ~80% quality.
final class PreviewGenerator {

    /// Target thumbnail dimensions (points).
    static let targetWidth: CGFloat = 240
    static let targetHeight: CGFloat = 160

    /// JPEG compression quality.
    static let jpegQuality: CGFloat = 0.8

    // MARK: - Public API

    /// Generates a JPEG preview thumbnail for the given content type and raw data.
    /// Returns nil if the data is empty or cannot be previewed.
    func generatePreview(for contentType: ContentType, data: Data) -> Data? {
        guard !data.isEmpty else { return nil }

        switch contentType {
        case .text:
            return generateTextPreview(data: data)
        case .richText:
            return generateRichTextPreview(data: data)
        case .image:
            return generateImagePreview(data: data)
        case .url:
            return generateURLPreview(data: data)
        case .file:
            return generateFilePreview(data: data)
        }
    }

    // MARK: - Text Preview

    /// Renders the first ~4 lines of plain text using NSTextField snapshot,
    /// then compresses to JPEG.
    private func generateTextPreview(data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        let lines = text.components(separatedBy: .newlines)
        let previewText = lines.prefix(4).joined(separator: "\n")
        let displayText = lines.count > 4 ? previewText + "\n..." : previewText

        return renderTextToJPEG(displayText, font: .monospacedSystemFont(ofSize: 12, weight: .regular))
    }

    // MARK: - Rich Text Preview

    /// Converts RTF or HTML data to NSAttributedString, renders in a fixed-size view,
    /// and compresses to JPEG.
    private func generateRichTextPreview(data: Data) -> Data? {
        let attributedString: NSAttributedString?

        if let rtf = try? NSAttributedString(data: data,
                                              options: [.documentType: NSAttributedString.DocumentType.rtf],
                                              documentAttributes: nil) {
            attributedString = rtf
        } else if let html = try? NSAttributedString(data: data,
                                                      options: [.documentType: NSAttributedString.DocumentType.html],
                                                      documentAttributes: nil) {
            attributedString = html
        } else {
            return generateTextPreview(data: data)
        }

        guard let attrStr = attributedString else { return nil }
        return renderAttributedStringToJPEG(attrStr)
    }

    // MARK: - Image Preview

    /// Scales the image to target dimensions preserving aspect ratio,
    /// then compresses to JPEG.
    private func generateImagePreview(data: Data) -> Data? {
        guard let image = NSImage(data: data) else { return nil }

        let targetSize = aspectFitSize(
            originalSize: image.size,
            targetSize: NSSize(width: Self.targetWidth * 2, height: Self.targetHeight * 2)
        )

        let scaledImage = NSImage(size: targetSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        scaledImage.unlockFocus()

        return jpegData(from: scaledImage)
    }

    // MARK: - URL Preview

    /// Renders URL string with a link icon, compresses to JPEG.
    private func generateURLPreview(data: Data) -> Data? {
        guard let urlString = String(data: data, encoding: .utf8) else { return nil }

        let displayText = "\u{1F517} \(urlString)"
        return renderTextToJPEG(displayText, font: .systemFont(ofSize: 12))
    }

    // MARK: - File Preview

    /// Retrieves the file icon via NSWorkspace and renders with filename label,
    /// compresses to JPEG.
    private func generateFilePreview(data: Data) -> Data? {
        guard let pathString = String(data: data, encoding: .utf8) else { return nil }

        let filePath: String
        if let url = URL(string: pathString), url.isFileURL {
            filePath = url.path
        } else {
            filePath = pathString
        }

        let icon = NSWorkspace.shared.icon(forFile: filePath)
        let filename = (filePath as NSString).lastPathComponent

        let size = NSSize(width: Self.targetWidth * 2, height: Self.targetHeight * 2)
        let resultImage = NSImage(size: size)
        resultImage.lockFocus()

        let iconSize: CGFloat = 96
        let iconRect = NSRect(
            x: (size.width - iconSize) / 2,
            y: size.height - iconSize - 40,
            width: iconSize,
            height: iconSize
        )
        icon.draw(in: iconRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        let textRect = NSRect(x: 20, y: 20, width: size.width - 40, height: 40)
        (filename as NSString).draw(in: textRect, withAttributes: attrs)

        resultImage.unlockFocus()

        return jpegData(from: resultImage)
    }

    // MARK: - Rendering Helpers

    private func renderTextToJPEG(_ text: String, font: NSFont) -> Data? {
        let size = NSSize(width: Self.targetWidth * 2, height: Self.targetHeight * 2)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.textBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = NSRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32)
        (text as NSString).draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()

        return jpegData(from: image)
    }

    private func renderAttributedStringToJPEG(_ attributedString: NSAttributedString) -> Data? {
        let size = NSSize(width: Self.targetWidth * 2, height: Self.targetHeight * 2)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.textBackgroundColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        let textRect = NSRect(x: 16, y: 16, width: size.width - 32, height: size.height - 32)
        attributedString.draw(in: textRect)

        image.unlockFocus()

        return jpegData(from: image)
    }

    private func jpegData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: Self.jpegQuality])
    }

    private func aspectFitSize(originalSize: NSSize, targetSize: NSSize) -> NSSize {
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio)
        return NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
    }
}
