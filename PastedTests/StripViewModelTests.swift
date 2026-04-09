import XCTest
import SwiftData
@testable import Pasted

/// Tests for StripViewModel: navigation, search integration, live updates, and focus trigger.
@MainActor
final class StripViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore() throws -> ClipboardStore {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ClipboardStore(modelContext: ModelContext(container))
    }

    private func makeItem(
        text: String,
        contentType: ContentType = .text,
        sourceAppBundleID: String? = "com.example.app",
        sourceAppName: String? = "Example",
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            contentType: contentType,
            rawData: Data(text.utf8),
            plainTextContent: text,
            sourceAppBundleID: sourceAppBundleID,
            sourceAppName: sourceAppName,
            capturedAt: capturedAt
        )
    }

    // MARK: - Initial State

    func testInitialState() {
        let vm = StripViewModel()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.selectedIndex, 0)
        XCTAssertNil(vm.selectedItem)
        XCTAssertTrue(vm.searchQuery.isEmpty)
        XCTAssertEqual(vm.focusTrigger, 0)
        XCTAssertTrue(vm.availableSourceApps.isEmpty)
    }

    // MARK: - Reload

    func testReload_populatesItems() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "hello"))
        vm.reload(from: store)

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.plainTextContent, "hello")
    }

    func testReload_sortsByNewestFirst() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "older", capturedAt: base))
        try store.save(makeItem(text: "newer", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        XCTAssertEqual(vm.items[0].plainTextContent, "newer")
        XCTAssertEqual(vm.items[1].plainTextContent, "older")
    }

    func testReload_preservesSelectionByID() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        // B is index 0 (newest). Select A at index 1.
        vm.select(at: 1)
        let selectedID = vm.selectedItem?.id

        vm.reload(from: store)
        XCTAssertEqual(vm.selectedItem?.id, selectedID)
    }

    func testReload_clampsSelectionWhenItemCountShrinks() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)
        vm.select(at: 1)
        XCTAssertEqual(vm.selectedIndex, 1)

        // Delete B so only A remains — selection should clamp to 0
        try store.delete(vm.items[0]) // delete newest (B)
        vm.reload(from: store)

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testReload_skipsUpdateWhenIDsUnchanged() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "hello"))
        vm.reload(from: store)
        let firstRef = vm.items

        // Same data — IDs unchanged, array should not be replaced
        vm.reload(from: store)
        XCTAssertEqual(vm.items.map(\.id), firstRef.map(\.id))
    }

    func testReload_populatesAvailableSourceApps() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "A", sourceAppBundleID: "com.apple.safari", sourceAppName: "Safari"))
        vm.reload(from: store)

        XCTAssertFalse(vm.availableSourceApps.isEmpty)
        XCTAssertEqual(vm.availableSourceApps.first?.bundleID, "com.apple.safari")
    }

    // MARK: - Navigation: moveLeft / moveRight

    func testMoveLeft_atFirstItem_doesNothing() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "only"))
        vm.reload(from: store)

        vm.moveLeft()
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testMoveRight_atLastItem_doesNothing() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "only"))
        vm.reload(from: store)

        vm.moveRight()
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testMoveLeft_decrementsIndex() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.select(at: 1)
        vm.moveLeft()
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testMoveRight_incrementsIndex() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.moveRight()
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    // MARK: - Navigation: selectFirst / selectLast

    func testSelectFirst_jumpsToIndex0() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.select(at: 1)
        vm.selectFirst()
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testSelectLast_jumpsToLastIndex() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.selectLast()
        XCTAssertEqual(vm.selectedIndex, vm.items.count - 1)
    }

    func testSelectFirst_onEmptyItems_doesNothing() {
        let vm = StripViewModel()
        vm.selectFirst() // Should not crash
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testSelectLast_onEmptyItems_doesNothing() {
        let vm = StripViewModel()
        vm.selectLast() // Should not crash
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - Navigation: select(at:)

    func testSelectAt_validIndex_updatesSelection() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "A", capturedAt: base))
        try store.save(makeItem(text: "B", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.select(at: 1)
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func testSelectAt_negativeIndex_doesNothing() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "A"))
        vm.reload(from: store)

        vm.select(at: -1)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func testSelectAt_beyondBounds_doesNothing() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "A"))
        vm.reload(from: store)

        vm.select(at: 99)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - selectedItem

    func testSelectedItem_returnsItemAtCurrentIndex() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "target"))
        vm.reload(from: store)

        XCTAssertEqual(vm.selectedItem?.plainTextContent, "target")
    }

    func testSelectedItem_whenEmpty_isNil() {
        let vm = StripViewModel()
        XCTAssertNil(vm.selectedItem)
    }

    // MARK: - Search

    func testSearch_emptyQuery_returnsAllItems() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "apple", capturedAt: base))
        try store.save(makeItem(text: "banana", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        XCTAssertEqual(vm.items.count, 2)
    }

    func testSearch_withMatchingText_filtersResults() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "hello world", capturedAt: base))
        try store.save(makeItem(text: "goodbye", capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.searchQuery = SearchQuery(text: "hello")

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.plainTextContent, "hello world")
    }

    func testSearch_withNoMatch_returnsEmpty() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "hello"))
        vm.reload(from: store)

        vm.searchQuery = SearchQuery(text: "zzznomatch")
        XCTAssertTrue(vm.items.isEmpty)
    }

    func testSearch_clearingQuery_restoresAllItems() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "hello"))
        vm.reload(from: store)
        vm.searchQuery = SearchQuery(text: "zzznomatch")
        XCTAssertTrue(vm.items.isEmpty)

        vm.searchQuery = SearchQuery()
        XCTAssertEqual(vm.items.count, 1)
    }

    func testSearch_contentTypeFilter_filtersResults() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try store.save(makeItem(text: "text item", contentType: .text, capturedAt: base))
        try store.save(makeItem(text: "url item", contentType: .url, capturedAt: base.addingTimeInterval(10)))
        vm.reload(from: store)

        vm.searchQuery = SearchQuery(filters: [.contentType(.text)])
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.contentType, .text)
    }

    func testSearch_unchangedQuery_doesNotTriggerReload() throws {
        let store = try makeStore()
        let vm = StripViewModel()

        try store.save(makeItem(text: "hello"))
        vm.reload(from: store)

        // Setting same query value should not crash or cause issues
        vm.searchQuery = SearchQuery()
        XCTAssertEqual(vm.items.count, 1)
    }

    // MARK: - Live Updates

    func testStartAndStopLiveUpdates_doesNotCrash() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        vm.reload(from: store)

        vm.startLiveUpdates()
        vm.stopLiveUpdates()
        vm.stopLiveUpdates() // Idempotent — second stop should not crash
    }

    func testStartLiveUpdates_replacesExistingTimer() throws {
        let store = try makeStore()
        let vm = StripViewModel()
        vm.reload(from: store)

        vm.startLiveUpdates()
        vm.startLiveUpdates() // Should invalidate old timer and start fresh
        vm.stopLiveUpdates()
    }

    // MARK: - Focus Trigger

    func testFocusTrigger_initiallyZero() {
        let vm = StripViewModel()
        XCTAssertEqual(vm.focusTrigger, 0)
    }
}
