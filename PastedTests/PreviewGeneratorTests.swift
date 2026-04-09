import XCTest
import AppKit
@testable import Pasted

/// Tests for PreviewGenerator (T024-T028, T038).
/// Verifies thumbnail generation for all content types and edge cases.
final class PreviewGeneratorTests: XCTestCase {

    private var generator: PreviewGenerator!

    override func setUp() {
        super.setUp()
        generator = PreviewGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - Text Preview (T024)

    func testTextPreviewReturnsNonNilJPEG() {
        let text = "Hello, World!\nSecond line\nThird line\nFourth line"
        let data = Data(text.utf8)

        let result = generator.generatePreview(for: .text, data: data)

        XCTAssertNotNil(result, "Text preview should return non-nil JPEG data")
        assertIsJPEG(result)
    }

    func testTextPreviewSingleLine() {
        let data = Data("Single line text".utf8)

        let result = generator.generatePreview(for: .text, data: data)

        XCTAssertNotNil(result)
        assertIsJPEG(result)
    }

    func testTextPreviewMultipleLines() {
        let lines = (1...10).map { "Line \($0): Some text content here" }
        let text = lines.joined(separator: "\n")
        let data = Data(text.utf8)

        let result = generator.generatePreview(for: .text, data: data)

        XCTAssertNotNil(result)
        assertIsJPEG(result)
    }

    // MARK: - Image Preview (T026)

    func testImagePreviewFromSmallNSImage() {
        // Create a 10x10 NSImage and convert to TIFF data
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation else {
            XCTFail("Failed to create TIFF data from test image")
            return
        }

        let result = generator.generatePreview(for: .image, data: tiffData)

        XCTAssertNotNil(result, "Image preview should return non-nil JPEG data for a valid image")
        assertIsJPEG(result)
    }

    func testImagePreviewScalesDown() {
        // Create a large 1000x1000 image
        let image = NSImage(size: NSSize(width: 1000, height: 1000))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 1000, height: 1000).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation else {
            XCTFail("Failed to create TIFF data from test image")
            return
        }

        let result = generator.generatePreview(for: .image, data: tiffData)

        XCTAssertNotNil(result)
        assertIsJPEG(result)

        // The result should be smaller than the original TIFF data
        // since it's scaled down and JPEG compressed
        if let resultData = result {
            XCTAssertLessThan(resultData.count, tiffData.count,
                              "Scaled JPEG preview should be smaller than original TIFF")
        }
    }

    func testImagePreviewFromPNGData() {
        // Create a small PNG image
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 20, height: 20).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG data from test image")
            return
        }

        let result = generator.generatePreview(for: .image, data: pngData)

        XCTAssertNotNil(result, "Image preview should handle PNG input data")
        assertIsJPEG(result)
    }

    // MARK: - URL Preview (T027)

    func testURLPreviewReturnsNonNilJPEG() {
        let urlString = "https://www.example.com/page?query=test"
        let data = Data(urlString.utf8)

        let result = generator.generatePreview(for: .url, data: data)

        XCTAssertNotNil(result, "URL preview should return non-nil JPEG data")
        assertIsJPEG(result)
    }

    func testURLPreviewWithLongURL() {
        let longURL = "https://www.example.com/" + String(repeating: "path/", count: 100)
        let data = Data(longURL.utf8)

        let result = generator.generatePreview(for: .url, data: data)

        XCTAssertNotNil(result, "URL preview should handle long URLs")
        assertIsJPEG(result)
    }

    // MARK: - File Preview (T028)

    func testFilePreviewReturnsNonNilJPEG() {
        // Use a known system path that should always exist
        let filePath = "/Applications/Safari.app"
        let data = Data(filePath.utf8)

        let result = generator.generatePreview(for: .file, data: data)

        XCTAssertNotNil(result, "File preview for /Applications/Safari.app should return non-nil JPEG data")
        assertIsJPEG(result)
    }

    func testFilePreviewWithFileURL() {
        let fileURL = "file:///Applications/Safari.app"
        let data = Data(fileURL.utf8)

        let result = generator.generatePreview(for: .file, data: data)

        XCTAssertNotNil(result, "File preview should handle file:// URL format")
        assertIsJPEG(result)
    }

    func testFilePreviewWithNonExistentPath() {
        // Even for non-existent paths, NSWorkspace.shared.icon(forFile:)
        // returns a generic icon, so preview should still be generated
        let fakePath = "/nonexistent/path/to/file.txt"
        let data = Data(fakePath.utf8)

        let result = generator.generatePreview(for: .file, data: data)

        XCTAssertNotNil(result, "File preview should return a generic icon for non-existent paths")
        assertIsJPEG(result)
    }

    // MARK: - Empty Data

    func testEmptyDataReturnsNil() {
        let emptyData = Data()

        for contentType in ContentType.allCases {
            let result = generator.generatePreview(for: contentType, data: emptyData)
            XCTAssertNil(result, "Empty data should return nil for \(contentType.rawValue)")
        }
    }

    // MARK: - Large Text (Performance / Safety)

    func testLargeTextDoesNotCrash() {
        let largeText = String(repeating: "A", count: 100_000)
        let data = Data(largeText.utf8)

        let result = generator.generatePreview(for: .text, data: data)

        XCTAssertNotNil(result, "Large text (100K characters) should still produce a preview")
        assertIsJPEG(result)
    }

    func testLargeTextWithManyLines() {
        let lines = (1...10_000).map { "Line \($0): Content" }
        let largeText = lines.joined(separator: "\n")
        let data = Data(largeText.utf8)

        let result = generator.generatePreview(for: .text, data: data)

        XCTAssertNotNil(result, "Text with many lines should still produce a preview")
        assertIsJPEG(result)
    }

    // MARK: - Rich Text Preview (T025)

    func testRichTextPreviewWithRTFData() {
        // Create minimal RTF data
        let rtfString = #"{\rtf1\ansi{\fonttbl\f0\fswiss Helvetica;}\f0\pard Hello, World!\par}"#
        let data = Data(rtfString.utf8)

        let result = generator.generatePreview(for: .richText, data: data)

        XCTAssertNotNil(result, "Rich text preview should return non-nil JPEG for valid RTF")
        assertIsJPEG(result)
    }

    func testRichTextPreviewFallsBackForInvalidData() {
        // Invalid RTF/HTML data should still attempt plain text fallback
        let data = Data("Just plain text, not RTF or HTML".utf8)

        let result = generator.generatePreview(for: .richText, data: data)

        // Should still produce a preview via plain text fallback
        XCTAssertNotNil(result, "Rich text preview should fall back to text rendering for invalid RTF/HTML")
        assertIsJPEG(result)
    }

    // MARK: - Integration-Style Tests (T038)

    func testAllContentTypesProducePreview() {
        // Text
        let textResult = generator.generatePreview(
            for: .text,
            data: Data("Hello, clipboard!".utf8)
        )
        XCTAssertNotNil(textResult, "Text should produce a preview")

        // Rich Text (RTF)
        let rtfString = #"{\rtf1\ansi Hello RTF}"#
        let richTextResult = generator.generatePreview(
            for: .richText,
            data: Data(rtfString.utf8)
        )
        XCTAssertNotNil(richTextResult, "Rich text should produce a preview")

        // Image
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        if let tiffData = image.tiffRepresentation {
            let imageResult = generator.generatePreview(for: .image, data: tiffData)
            XCTAssertNotNil(imageResult, "Image should produce a preview")
        }

        // URL
        let urlResult = generator.generatePreview(
            for: .url,
            data: Data("https://example.com".utf8)
        )
        XCTAssertNotNil(urlResult, "URL should produce a preview")

        // File
        let fileResult = generator.generatePreview(
            for: .file,
            data: Data("/Applications/Safari.app".utf8)
        )
        XCTAssertNotNil(fileResult, "File should produce a preview")
    }

    func testDifferentContentTypesProduceDifferentPreviews() {
        let textData = Data("Hello, World!".utf8)

        let textPreview = generator.generatePreview(for: .text, data: textData)
        let urlPreview = generator.generatePreview(for: .url, data: textData)

        XCTAssertNotNil(textPreview)
        XCTAssertNotNil(urlPreview)

        // Different content types with the same data should produce different previews
        // (text renders as monospaced code, URL renders with link icon)
        if let tp = textPreview, let up = urlPreview {
            XCTAssertNotEqual(tp, up,
                              "Text and URL previews for the same data should look different")
        }
    }

    // MARK: - JPEG Validation Helper

    /// Asserts that the given data starts with a JPEG SOI marker (0xFF 0xD8).
    private func assertIsJPEG(_ data: Data?, file: StaticString = #filePath, line: UInt = #line) {
        guard let data = data else {
            XCTFail("Data is nil, expected JPEG data", file: file, line: line)
            return
        }
        XCTAssertGreaterThanOrEqual(data.count, 2,
                                     "JPEG data should be at least 2 bytes", file: file, line: line)

        let header = [UInt8](data.prefix(2))
        XCTAssertEqual(header[0], 0xFF, "JPEG SOI marker first byte should be 0xFF", file: file, line: line)
        XCTAssertEqual(header[1], 0xD8, "JPEG SOI marker second byte should be 0xD8", file: file, line: line)
    }
}
