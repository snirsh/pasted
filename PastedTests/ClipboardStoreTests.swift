import XCTest
import SwiftData
@testable import Pasted

/// Tests for ClipboardStore (T012, T039, T040, T045).
/// Covers save/fetch, deduplication (FR-011), delete, deleteAll,
/// pagination, ordering, auto-pruning, and persistence.
final class ClipboardStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an in-memory ModelContainer and returns both it and a ClipboardStore.
    @MainActor
    private func makeStore(storageLimitBytes: Int64 = 1_073_741_824) throws -> (ModelContainer, ClipboardStore) {
        let schema = Schema([ClipboardItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let store = ClipboardStore(modelContext: context, storageLimitBytes: storageLimitBytes)
        return (container, store)
    }

    /// Creates a ClipboardItem with the given text content and a specific timestamp.
    private func makeItem(
        text: String,
        capturedAt: Date = Date(),
        contentType: ContentType = .text
    ) -> ClipboardItem {
        ClipboardItem(
            contentType: contentType,
            rawData: Data(text.utf8),
            plainTextContent: text,
            capturedAt: capturedAt
        )
    }

    // MARK: - Save and Fetch

    @MainActor
    func testSaveAndFetchRecent() throws {
        let (_, store) = try makeStore()

        let now = Date()
        let item1 = makeItem(text: "first", capturedAt: now.addingTimeInterval(-2))
        let item2 = makeItem(text: "second", capturedAt: now.addingTimeInterval(-1))
        let item3 = makeItem(text: "third", capturedAt: now)

        try store.save(item1)
        try store.save(item2)
        try store.save(item3)

        let fetched = try store.fetchRecent(limit: 10)

        XCTAssertEqual(fetched.count, 3)
        // Newest first
        XCTAssertEqual(fetched[0].plainTextContent, "third")
        XCTAssertEqual(fetched[1].plainTextContent, "second")
        XCTAssertEqual(fetched[2].plainTextContent, "first")
    }

    @MainActor
    func testFetchRecentReturnsNewestFirst() throws {
        let (_, store) = try makeStore()

        let now = Date()
        for i in 0..<5 {
            let item = makeItem(
                text: "item \(i)",
                capturedAt: now.addingTimeInterval(Double(i))
            )
            try store.save(item)
        }

        let fetched = try store.fetchRecent(limit: 5)

        XCTAssertEqual(fetched.count, 5)
        // Verify descending order by capturedAt
        for i in 0..<(fetched.count - 1) {
            XCTAssertGreaterThanOrEqual(fetched[i].capturedAt, fetched[i + 1].capturedAt,
                                        "Items should be ordered newest first")
        }
    }

    // MARK: - Deduplication (FR-011)

    @MainActor
    func testDeduplicationSkipsConsecutiveDuplicate() throws {
        let (_, store) = try makeStore()

        let now = Date()
        let item1 = makeItem(text: "duplicate", capturedAt: now)
        let item2 = makeItem(text: "duplicate", capturedAt: now.addingTimeInterval(1))

        try store.save(item1)
        try store.save(item2)

        let count = try store.count()
        XCTAssertEqual(count, 1, "Consecutive duplicate should be skipped")

        let fetched = try store.fetchAll()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.plainTextContent, "duplicate")
    }

    @MainActor
    func testDeduplicationAllowsNonConsecutiveDuplicates() throws {
        let (_, store) = try makeStore()

        let now = Date()
        let itemA1 = makeItem(text: "A", capturedAt: now)
        let itemB = makeItem(text: "B", capturedAt: now.addingTimeInterval(1))
        let itemA2 = makeItem(text: "A", capturedAt: now.addingTimeInterval(2))

        try store.save(itemA1) // A is most recent
        try store.save(itemB)  // B is most recent, different from A
        try store.save(itemA2) // A again, but most recent is B, so it should be saved

        let count = try store.count()
        XCTAssertEqual(count, 3, "Non-consecutive duplicate 'A' should be saved since 'B' intervened")

        let fetched = try store.fetchRecent(limit: 10)
        XCTAssertEqual(fetched[0].plainTextContent, "A")
        XCTAssertEqual(fetched[1].plainTextContent, "B")
        XCTAssertEqual(fetched[2].plainTextContent, "A")
    }

    @MainActor
    func testDeduplicationComparesDataHashNotText() throws {
        let (_, store) = try makeStore()

        let now = Date()
        // Same text but different content types still have the same rawData,
        // so they should be deduplicated
        let item1 = ClipboardItem(
            contentType: .text,
            rawData: Data("same".utf8),
            capturedAt: now
        )
        let item2 = ClipboardItem(
            contentType: .url,
            rawData: Data("same".utf8),
            capturedAt: now.addingTimeInterval(1)
        )

        try store.save(item1)
        try store.save(item2)

        // dataHash is based on rawData only, so these are duplicates
        let count = try store.count()
        XCTAssertEqual(count, 1, "Items with same rawData should be deduplicated regardless of contentType")
    }

    // MARK: - Delete

    @MainActor
    func testDeleteRemovesItem() throws {
        let (_, store) = try makeStore()

        let item = makeItem(text: "to delete")
        try store.save(item)

        XCTAssertEqual(try store.count(), 1)

        try store.delete(item)

        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty, "Item should be deleted")
        XCTAssertEqual(try store.count(), 0)
    }

    @MainActor
    func testDeleteOnlyRemovesSpecifiedItem() throws {
        let (_, store) = try makeStore()

        let now = Date()
        let item1 = makeItem(text: "keep", capturedAt: now)
        let item2 = makeItem(text: "delete me", capturedAt: now.addingTimeInterval(1))

        try store.save(item1)
        try store.save(item2)

        XCTAssertEqual(try store.count(), 2)

        try store.delete(item2)

        let remaining = try store.fetchAll()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.plainTextContent, "keep")
    }

    // MARK: - Delete All

    @MainActor
    func testDeleteAllClearsAllItems() throws {
        let (_, store) = try makeStore()

        let now = Date()
        for i in 0..<5 {
            let item = makeItem(text: "item \(i)", capturedAt: now.addingTimeInterval(Double(i)))
            try store.save(item)
        }

        XCTAssertEqual(try store.count(), 5)

        try store.deleteAll()

        XCTAssertEqual(try store.count(), 0)
        let all = try store.fetchAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Fetch with Limit and Offset

    @MainActor
    func testFetchRecentWithLimitAndOffset() throws {
        let (_, store) = try makeStore()

        let now = Date()
        // Save 10 items with sequential timestamps
        for i in 0..<10 {
            let item = makeItem(
                text: "item \(i)",
                capturedAt: now.addingTimeInterval(Double(i))
            )
            try store.save(item)
        }

        // Items sorted newest first: item9, item8, item7, item6, item5, item4, item3, item2, item1, item0
        // offset 2, limit 3 => item7, item6, item5 (indices 2, 3, 4 in the sorted result)
        let fetched = try store.fetchRecent(limit: 3, offset: 2)

        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].plainTextContent, "item 7")
        XCTAssertEqual(fetched[1].plainTextContent, "item 6")
        XCTAssertEqual(fetched[2].plainTextContent, "item 5")
    }

    @MainActor
    func testFetchRecentLimitExceedsCount() throws {
        let (_, store) = try makeStore()

        let now = Date()
        try store.save(makeItem(text: "only one", capturedAt: now))

        let fetched = try store.fetchRecent(limit: 100)
        XCTAssertEqual(fetched.count, 1)
    }

    @MainActor
    func testFetchRecentOffsetBeyondCount() throws {
        let (_, store) = try makeStore()

        let now = Date()
        for i in 0..<3 {
            try store.save(makeItem(text: "item \(i)", capturedAt: now.addingTimeInterval(Double(i))))
        }

        let fetched = try store.fetchRecent(limit: 10, offset: 100)
        XCTAssertTrue(fetched.isEmpty, "Offset beyond item count should return empty")
    }

    // MARK: - Ordering

    @MainActor
    func testFetchAllReturnsNewestFirst() throws {
        let (_, store) = try makeStore()

        let now = Date()
        let oldest = makeItem(text: "oldest", capturedAt: now.addingTimeInterval(-100))
        let middle = makeItem(text: "middle", capturedAt: now.addingTimeInterval(-50))
        let newest = makeItem(text: "newest", capturedAt: now)

        // Insert in random order
        try store.save(middle)
        try store.save(oldest)
        try store.save(newest)

        let all = try store.fetchAll()

        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].plainTextContent, "newest")
        XCTAssertEqual(all[1].plainTextContent, "middle")
        XCTAssertEqual(all[2].plainTextContent, "oldest")
    }

    // MARK: - Auto-Pruning

    @MainActor
    func testAutoPruningRemovesOldestItemsWhenOverLimit() throws {
        // Storage limit of 1KB
        let storageLimitBytes: Int64 = 1024
        let (_, store) = try makeStore(storageLimitBytes: storageLimitBytes)

        let baseDate = Date(timeIntervalSince1970: 1_000_000)

        // Create items each ~300 bytes with UNIQUE data to avoid deduplication.
        // 4 * 300 = 1200 bytes > 1024 limit, so pruning should kick in.
        for i in 0..<4 {
            let uniqueText = String(repeating: Character(Unicode.Scalar(65 + i)!), count: 300)
            let item = ClipboardItem(
                contentType: .text,
                rawData: Data(uniqueText.utf8),
                plainTextContent: "item \(i)",
                capturedAt: baseDate.addingTimeInterval(Double(i))
            )
            try store.save(item)
        }

        // After saving 4 items (4 * 300 = 1200 bytes > 1024 limit),
        // pruning should kick in and remove oldest until under 90% of limit (921 bytes).
        // That means we need to remove at least 1200 - 921 = 279 bytes = 1 item.
        let totalSize = try store.totalByteSize()
        let target = Int64(Double(storageLimitBytes) * 0.9)

        XCTAssertLessThanOrEqual(totalSize, storageLimitBytes,
                                  "Total size should be at or under the limit after pruning")
        XCTAssertLessThanOrEqual(totalSize, target,
                                  "Total size should be at or under 90% of limit (hysteresis)")

        // Verify oldest items were removed, newest remain
        let remaining = try store.fetchAll()
        XCTAssertGreaterThan(remaining.count, 0, "Should still have some items")
        XCTAssertLessThan(remaining.count, 4, "At least one old item should have been pruned")

        // The remaining items should be the newest ones
        // The oldest item (baseDate + 0) should have been pruned
        let oldestSurvivingDate = remaining.map(\.capturedAt).min()!
        XCTAssertGreaterThan(oldestSurvivingDate, baseDate,
                             "The oldest item (baseDate) should have been pruned")
    }

    @MainActor
    func testNoPruningWhenUnderLimit() throws {
        let storageLimitBytes: Int64 = 100_000
        let (_, store) = try makeStore(storageLimitBytes: storageLimitBytes)

        let now = Date()
        for i in 0..<3 {
            let item = makeItem(text: "small \(i)", capturedAt: now.addingTimeInterval(Double(i)))
            try store.save(item)
        }

        XCTAssertEqual(try store.count(), 3, "No items should be pruned when under limit")
    }

    // MARK: - Total Byte Size and Count

    @MainActor
    func testTotalByteSizeIsAccurate() throws {
        let (_, store) = try makeStore()

        let data1 = Data(repeating: 0x01, count: 100)
        let data2 = Data(repeating: 0x02, count: 200)

        let now = Date()
        let item1 = ClipboardItem(contentType: .text, rawData: data1, capturedAt: now)
        let item2 = ClipboardItem(contentType: .text, rawData: data2, capturedAt: now.addingTimeInterval(1))

        try store.save(item1)
        try store.save(item2)

        let totalSize = try store.totalByteSize()
        XCTAssertEqual(totalSize, 300)
    }

    @MainActor
    func testCountReturnsCorrectNumber() throws {
        let (_, store) = try makeStore()

        XCTAssertEqual(try store.count(), 0)

        let now = Date()
        for i in 0..<7 {
            let item = makeItem(text: "count test \(i)", capturedAt: now.addingTimeInterval(Double(i)))
            try store.save(item)
        }

        XCTAssertEqual(try store.count(), 7)
    }

    // MARK: - Persistence

    @MainActor
    func testPersistenceAcrossContexts() throws {
        let (container, store) = try makeStore()

        let now = Date()
        let item1 = makeItem(text: "persisted 1", capturedAt: now)
        let item2 = makeItem(text: "persisted 2", capturedAt: now.addingTimeInterval(1))

        try store.save(item1)
        try store.save(item2)

        // Create a new ModelContext from the same container
        let newContext = ModelContext(container)
        let newStore = ClipboardStore(modelContext: newContext)

        let fetched = try newStore.fetchAll()
        XCTAssertEqual(fetched.count, 2, "Items should persist across ModelContext instances on the same container")

        let texts = Set(fetched.compactMap(\.plainTextContent))
        XCTAssertTrue(texts.contains("persisted 1"))
        XCTAssertTrue(texts.contains("persisted 2"))
    }

    @MainActor
    func testPersistencePreservesAllFields() throws {
        let (container, store) = try makeStore()

        let id = UUID()
        let rawData = Data("full field test".utf8)
        let thumbnail = Data([0xFF, 0xD8])
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let item = ClipboardItem(
            id: id,
            contentType: .url,
            rawData: rawData,
            plainTextContent: "https://example.com",
            previewThumbnail: thumbnail,
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            capturedAt: capturedAt
        )

        try store.save(item)

        // Fetch from new context
        let newContext = ModelContext(container)
        let descriptor = FetchDescriptor<ClipboardItem>()
        let fetched = try newContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let fetchedItem = try XCTUnwrap(fetched.first)
        XCTAssertEqual(fetchedItem.id, id)
        XCTAssertEqual(fetchedItem.contentType, .url)
        XCTAssertEqual(fetchedItem.rawData, rawData)
        XCTAssertEqual(fetchedItem.plainTextContent, "https://example.com")
        XCTAssertEqual(fetchedItem.previewThumbnail, thumbnail)
        XCTAssertEqual(fetchedItem.sourceAppBundleID, "com.apple.Safari")
        XCTAssertEqual(fetchedItem.sourceAppName, "Safari")
        XCTAssertEqual(fetchedItem.capturedAt, capturedAt)
        XCTAssertEqual(fetchedItem.byteSize, Int64(rawData.count))
    }
}
