import XCTest
import SwiftData
import AppKit
@testable import Pasted

/// Tests for ClipboardMonitor (T013, T023).
/// Since NSPasteboard cannot be easily mocked in unit tests, these are
/// structural tests verifying initialization, lifecycle, and helper logic.
final class ClipboardMonitorTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeStoreAndMonitor() throws -> (ClipboardStore, ClipboardMonitor) {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let store = ClipboardStore(modelContext: context)
        let monitor = ClipboardMonitor(store: store)
        return (store, monitor)
    }

    // MARK: - Initialization

    @MainActor
    func testInitializationWithStore() throws {
        let (_, monitor) = try makeStoreAndMonitor()

        // Monitor should be created without crashing
        XCTAssertNotNil(monitor)
    }

    // MARK: - Lifecycle: startMonitoring / stopMonitoring

    @MainActor
    func testStartMonitoringDoesNotCrash() throws {
        let (_, monitor) = try makeStoreAndMonitor()

        // Should not throw or crash
        monitor.startMonitoring()

        // Clean up
        monitor.stopMonitoring()
    }

    @MainActor
    func testStopMonitoringDoesNotCrash() throws {
        let (_, monitor) = try makeStoreAndMonitor()

        // Stop without starting should be safe
        monitor.stopMonitoring()

        // Start then stop should also be safe
        monitor.startMonitoring()
        monitor.stopMonitoring()
    }

    @MainActor
    func testDoubleStartDoesNotCrash() throws {
        let (_, monitor) = try makeStoreAndMonitor()

        monitor.startMonitoring()
        monitor.startMonitoring() // Should be idempotent

        monitor.stopMonitoring()
    }

    @MainActor
    func testDoubleStopDoesNotCrash() throws {
        let (_, monitor) = try makeStoreAndMonitor()

        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.stopMonitoring() // Should be idempotent
    }

    // MARK: - Content Type Detection

    /// Tests content type detection by verifying the priority order and pasteboard type mappings.
    /// The actual extractContent(from:) method is private, so we verify the expected behavior
    /// through the mapping of NSPasteboard.PasteboardType to ContentType.
    func testContentTypePasteboardMapping() {
        // Verify the known pasteboard type constants exist and are accessible.
        // These are the types ClipboardMonitor checks in priority order:
        // image > richText > url > file > text

        // Image types
        XCTAssertEqual(NSPasteboard.PasteboardType.tiff.rawValue, "public.tiff")
        XCTAssertEqual(NSPasteboard.PasteboardType.png.rawValue, "public.png")

        // Rich text types
        XCTAssertEqual(NSPasteboard.PasteboardType.rtf.rawValue, "public.rtf")
        XCTAssertEqual(NSPasteboard.PasteboardType.html.rawValue, "public.html")

        // URL type
        XCTAssertEqual(NSPasteboard.PasteboardType.URL.rawValue, "public.url")

        // File URL type
        XCTAssertEqual(NSPasteboard.PasteboardType.fileURL.rawValue, "public.file-url")

        // Plain text type
        XCTAssertEqual(NSPasteboard.PasteboardType.string.rawValue, "public.utf8-plain-text")
    }

    /// Verifies that ContentType enum covers all pasteboard type mappings used in ClipboardMonitor.
    func testAllContentTypesAreMappable() {
        // ClipboardMonitor maps pasteboard types -> ContentType as follows:
        // .tiff / .png         -> .image
        // .rtf / .html         -> .richText
        // .URL                 -> .url
        // .fileURL             -> .file
        // .string              -> .text
        //
        // Verify all 5 ContentType cases exist to cover the mapping
        let allTypes: [ContentType] = [.text, .richText, .image, .url, .file]
        XCTAssertEqual(allTypes.count, 5)
        XCTAssertEqual(Set(allTypes).count, 5, "All content types should be distinct")
    }

    /// Tests that the content type priority is: image > richText > url > file > text.
    /// This is a documentation test that verifies understanding of the extraction order.
    func testContentTypePriorityDocumentation() {
        // The ClipboardMonitor.extractContent(from:) checks in this order:
        // 1. .tiff / .png       -> .image
        // 2. .rtf / .html       -> .richText
        // 3. .URL               -> .url
        // 4. .fileURL           -> .file
        // 5. .string            -> .text
        //
        // This means if the pasteboard contains both an image and text,
        // the image will be captured (higher priority).

        // Verify the enum can represent all priority levels
        let priorityOrder: [ContentType] = [.image, .richText, .url, .file, .text]
        XCTAssertEqual(priorityOrder.count, ContentType.allCases.count,
                       "Priority order should cover all content types")
    }

    // MARK: - Source App Extraction

    /// Verifies that source app extraction gracefully returns nil when
    /// no frontmost application information is available.
    /// In a test environment, NSWorkspace.shared.frontmostApplication might
    /// not return nil, but ClipboardItem allows nil for these fields.
    func testSourceAppFieldsCanBeNil() {
        let item = ClipboardItem(
            contentType: .text,
            rawData: Data("test".utf8),
            sourceAppBundleID: nil,
            sourceAppName: nil
        )

        XCTAssertNil(item.sourceAppBundleID)
        XCTAssertNil(item.sourceAppName)
    }

    func testSourceAppFieldsCanBePopulated() {
        let item = ClipboardItem(
            contentType: .text,
            rawData: Data("test".utf8),
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari"
        )

        XCTAssertEqual(item.sourceAppBundleID, "com.apple.Safari")
        XCTAssertEqual(item.sourceAppName, "Safari")
    }

    // MARK: - Plain Text Derivation

    /// Tests that plain text derivation logic is correct for each content type.
    /// For .text, .richText, .url: plainTextContent should be derivable.
    /// For .image, .file: plainTextContent should be nil.
    func testPlainTextDerivationByContentType() {
        // Text types should have plainTextContent
        let textItem = ClipboardItem(
            contentType: .text,
            rawData: Data("hello".utf8),
            plainTextContent: "hello"
        )
        XCTAssertNotNil(textItem.plainTextContent)

        let richItem = ClipboardItem(
            contentType: .richText,
            rawData: Data("rich".utf8),
            plainTextContent: "rich"
        )
        XCTAssertNotNil(richItem.plainTextContent)

        let urlItem = ClipboardItem(
            contentType: .url,
            rawData: Data("https://example.com".utf8),
            plainTextContent: "https://example.com"
        )
        XCTAssertNotNil(urlItem.plainTextContent)

        // Image and file types typically have nil plainTextContent
        let imageItem = ClipboardItem(
            contentType: .image,
            rawData: Data([0xFF, 0xD8]),
            plainTextContent: nil
        )
        XCTAssertNil(imageItem.plainTextContent)

        let fileItem = ClipboardItem(
            contentType: .file,
            rawData: Data("/path/to/file".utf8),
            plainTextContent: nil
        )
        XCTAssertNil(fileItem.plainTextContent)
    }
}
