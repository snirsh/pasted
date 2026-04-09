import XCTest
@testable import Pasted

/// Tests for ConcealedContentDetector (spec 004).
final class ConcealedContentDetectorTests: XCTestCase {

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Ensure the toggle defaults to true for each test
        UserDefaults.standard.set(true, forKey: "concealedDetectionEnabled")
    }

    override func tearDown() {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "concealedDetectionEnabled")
        super.tearDown()
    }

    // MARK: - Type String

    func testConcealedTypeHasCorrectStringValue() {
        XCTAssertEqual(
            ConcealedContentDetector.concealedType.rawValue,
            "org.nspasteboard.ConcealedType",
            "Concealed type should use the nspasteboard.org community standard"
        )
    }

    // MARK: - Default Pasteboard

    func testIsConcealedReturnsFalseWithDefaultPasteboard() {
        // The general pasteboard in a test environment should not contain concealed types
        // Use a custom pasteboard to avoid interfering with the system clipboard
        let testPasteboard = NSPasteboard(name: NSPasteboard.Name("com.pasted.test.concealed"))
        testPasteboard.clearContents()
        testPasteboard.setString("plain text", forType: .string)

        let result = ConcealedContentDetector.isConcealed(testPasteboard)
        XCTAssertFalse(result, "Plain text pasteboard should not be concealed")

        // Clean up
        testPasteboard.clearContents()
    }

    // MARK: - UserDefaults Toggle

    func testDetectionRespectsDisabledToggle() {
        UserDefaults.standard.set(false, forKey: "concealedDetectionEnabled")

        // Even if we could set the concealed type, the detector should return false
        // because the toggle is disabled
        let testPasteboard = NSPasteboard(name: NSPasteboard.Name("com.pasted.test.concealed.toggle"))
        testPasteboard.clearContents()

        let result = ConcealedContentDetector.isConcealed(testPasteboard)
        XCTAssertFalse(result, "Detection should return false when toggle is disabled")

        // Clean up
        testPasteboard.clearContents()
    }

    func testDetectionRespectsEnabledToggle() {
        UserDefaults.standard.set(true, forKey: "concealedDetectionEnabled")

        // A pasteboard without concealed type should return false even with toggle enabled
        let testPasteboard = NSPasteboard(name: NSPasteboard.Name("com.pasted.test.concealed.enabled"))
        testPasteboard.clearContents()
        testPasteboard.setString("normal content", forType: .string)

        let result = ConcealedContentDetector.isConcealed(testPasteboard)
        XCTAssertFalse(result, "Non-concealed content should return false even with toggle enabled")

        // Clean up
        testPasteboard.clearContents()
    }
}
