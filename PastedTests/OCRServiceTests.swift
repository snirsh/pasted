import XCTest
import SwiftData
import AppKit
@testable import Pasted

/// Tests for OCRResult model and OCRService (spec 002).
/// Covers model initialization, text recognition with an image containing text,
/// no-text images, and empty data handling.
final class OCRServiceTests: XCTestCase {

    // MARK: - OCRResult Model

    func testOCRResultInitialization() {
        let id = UUID()
        let clipboardItemID = UUID()
        let processedAt = Date()

        let result = OCRResult(
            id: id,
            clipboardItemID: clipboardItemID,
            recognizedText: "Hello World",
            confidence: 0.95,
            language: "en",
            processedAt: processedAt
        )

        XCTAssertEqual(result.id, id)
        XCTAssertEqual(result.clipboardItemID, clipboardItemID)
        XCTAssertEqual(result.recognizedText, "Hello World")
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.processedAt, processedAt)
    }

    func testOCRResultDefaultValues() {
        let clipboardItemID = UUID()
        let beforeCreation = Date()

        let result = OCRResult(
            clipboardItemID: clipboardItemID,
            recognizedText: "Test",
            confidence: 0.8
        )

        let afterCreation = Date()

        XCTAssertNotNil(result.id)
        XCTAssertNil(result.language)
        XCTAssertGreaterThanOrEqual(result.processedAt, beforeCreation)
        XCTAssertLessThanOrEqual(result.processedAt, afterCreation)
    }

    @MainActor
    func testOCRResultPersistence() throws {
        let schema = Schema([OCRResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let id = UUID()
        let clipboardItemID = UUID()
        let result = OCRResult(
            id: id,
            clipboardItemID: clipboardItemID,
            recognizedText: "Persisted text",
            confidence: 0.9,
            language: "en"
        )

        context.insert(result)
        try context.save()

        let fetchContext = ModelContext(container)
        let descriptor = FetchDescriptor<OCRResult>()
        let fetched = try fetchContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let fetchedResult = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedResult.id, id)
        XCTAssertEqual(fetchedResult.clipboardItemID, clipboardItemID)
        XCTAssertEqual(fetchedResult.recognizedText, "Persisted text")
        XCTAssertEqual(fetchedResult.confidence, 0.9, accuracy: 0.001)
        XCTAssertEqual(fetchedResult.language, "en")
    }

    // MARK: - OCRService.recognizeText

    func testRecognizeTextWithTextImage() async throws {
        // Create a simple NSImage with drawn text
        let imageData = createImageWithText("Hello World")
        guard let data = imageData else {
            XCTFail("Failed to create test image")
            return
        }

        let clipboardItemID = UUID()
        let result = await OCRService.recognizeText(in: data, clipboardItemID: clipboardItemID)

        // Vision should recognize at least some text from the image
        // The exact recognition may vary, so we check for non-nil and non-empty
        XCTAssertNotNil(result, "OCR should return a result for an image with text")
        if let result = result {
            XCTAssertFalse(result.recognizedText.isEmpty, "Recognized text should not be empty")
            XCTAssertGreaterThan(result.confidence, 0.0, "Confidence should be positive")
            XCTAssertEqual(result.clipboardItemID, clipboardItemID)
        }
    }

    func testRecognizeTextWithEmptyDataReturnsNil() async {
        let result = await OCRService.recognizeText(in: Data())

        XCTAssertNil(result, "Empty data should return nil")
    }

    func testRecognizeTextWithInvalidDataReturnsNil() async {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let result = await OCRService.recognizeText(in: invalidData)

        XCTAssertNil(result, "Invalid image data should return nil")
    }

    func testRecognizeTextWithBlankImage() async throws {
        // Create a blank white image with no text
        let blankImage = createBlankImage()
        guard let data = blankImage else {
            XCTFail("Failed to create blank image")
            return
        }

        let result = await OCRService.recognizeText(in: data)

        // A blank image should return nil (no text observations)
        XCTAssertNil(result, "Blank image with no text should return nil")
    }

    // MARK: - Image Helpers

    /// Creates a TIFF image containing the given text drawn in a large font.
    private func createImageWithText(_ text: String) -> Data? {
        let size = NSSize(width: 400, height: 100)
        let image = NSImage(size: size)

        image.lockFocus()

        // White background
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))

        // Draw text in black
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: NSPoint(x: 20, y: 30))

        image.unlockFocus()

        return image.tiffRepresentation
    }

    /// Creates a blank white TIFF image with no text.
    private func createBlankImage() -> Data? {
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(origin: .zero, size: size))
        image.unlockFocus()

        return image.tiffRepresentation
    }
}
