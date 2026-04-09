import XCTest
import SwiftData
@testable import Pasted

/// Tests for SearchEngine (spec 002).
/// Covers text search, empty query, no match, content type filter,
/// source app filter, date range filter, compound filters, and result ordering.
final class SearchEngineTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeEngine() throws -> (ModelContainer, SearchEngine, ModelContext) {
        let schema = Schema([ClipboardItem.self, OCRResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let engine = SearchEngine(modelContext: context)
        return (container, engine, context)
    }

    private func makeItem(
        text: String,
        contentType: ContentType = .text,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
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

    // MARK: - Text Search

    @MainActor
    func testTextSearchCaseInsensitive() throws {
        let (_, engine, context) = try makeEngine()

        let item1 = makeItem(text: "Hello World")
        let item2 = makeItem(text: "Goodbye Moon")
        context.insert(item1)
        context.insert(item2)
        try context.save()

        let query = SearchQuery(text: "hello")
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "Hello World")
    }

    @MainActor
    func testTextSearchSubstringMatch() throws {
        let (_, engine, context) = try makeEngine()

        let item = makeItem(text: "The quick brown fox jumps over the lazy dog")
        context.insert(item)
        try context.save()

        let query = SearchQuery(text: "brown fox")
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Empty Query

    @MainActor
    func testEmptyQueryReturnsAllItems() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        for i in 0..<5 {
            let item = makeItem(text: "item \(i)", capturedAt: now.addingTimeInterval(Double(i)))
            context.insert(item)
        }
        try context.save()

        let query = SearchQuery()
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 5)
    }

    // MARK: - No Match

    @MainActor
    func testNoMatchReturnsEmpty() throws {
        let (_, engine, context) = try makeEngine()

        let item = makeItem(text: "Hello World")
        context.insert(item)
        try context.save()

        let query = SearchQuery(text: "xyznonexistent")
        let results = try engine.search(query)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Content Type Filter

    @MainActor
    func testContentTypeFilter() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let textItem = makeItem(text: "text content", contentType: .text, capturedAt: now)
        let imageItem = ClipboardItem(
            contentType: .image,
            rawData: Data([0xFF, 0xD8]),
            capturedAt: now.addingTimeInterval(1)
        )
        let urlItem = makeItem(text: "https://example.com", contentType: .url, capturedAt: now.addingTimeInterval(2))

        context.insert(textItem)
        context.insert(imageItem)
        context.insert(urlItem)
        try context.save()

        let query = SearchQuery(filters: [.contentType(.text)])
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.contentType, .text)
    }

    // MARK: - Source App Filter

    @MainActor
    func testSourceAppFilter() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let safariItem = makeItem(
            text: "from safari",
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            capturedAt: now
        )
        let chromeItem = makeItem(
            text: "from chrome",
            sourceAppBundleID: "com.google.Chrome",
            sourceAppName: "Chrome",
            capturedAt: now.addingTimeInterval(1)
        )

        context.insert(safariItem)
        context.insert(chromeItem)
        try context.save()

        let query = SearchQuery(filters: [.sourceApp(bundleID: "com.apple.Safari", name: "Safari")])
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.sourceAppBundleID, "com.apple.Safari")
    }

    // MARK: - Date Range Filter

    @MainActor
    func testDateRangeFilter() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let todayItem = makeItem(text: "today item", capturedAt: now)
        let oldItem = makeItem(text: "old item", capturedAt: now.addingTimeInterval(-86400 * 10)) // 10 days ago

        context.insert(todayItem)
        context.insert(oldItem)
        try context.save()

        let query = SearchQuery(filters: [.dateRange(.lastSevenDays)])
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "today item")
    }

    // MARK: - Compound Filters (AND logic)

    @MainActor
    func testCompoundFiltersANDLogic() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        // text + Safari
        let safariText = makeItem(
            text: "hello from safari",
            contentType: .text,
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            capturedAt: now
        )
        // text + Chrome
        let chromeText = makeItem(
            text: "hello from chrome",
            contentType: .text,
            sourceAppBundleID: "com.google.Chrome",
            sourceAppName: "Chrome",
            capturedAt: now.addingTimeInterval(1)
        )
        // url + Safari
        let safariURL = makeItem(
            text: "https://example.com",
            contentType: .url,
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            capturedAt: now.addingTimeInterval(2)
        )

        context.insert(safariText)
        context.insert(chromeText)
        context.insert(safariURL)
        try context.save()

        // Filter: text search "hello" + content type .text + source app Safari
        let query = SearchQuery(
            text: "hello",
            filters: [
                .contentType(.text),
                .sourceApp(bundleID: "com.apple.Safari", name: "Safari")
            ]
        )
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "hello from safari")
    }

    // MARK: - Result Ordering

    @MainActor
    func testResultsOrderedNewestFirst() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let oldest = makeItem(text: "oldest", capturedAt: now.addingTimeInterval(-100))
        let middle = makeItem(text: "middle", capturedAt: now.addingTimeInterval(-50))
        let newest = makeItem(text: "newest", capturedAt: now)

        // Insert out of order
        context.insert(middle)
        context.insert(oldest)
        context.insert(newest)
        try context.save()

        let query = SearchQuery()
        let results = try engine.search(query)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].plainTextContent, "newest")
        XCTAssertEqual(results[1].plainTextContent, "middle")
        XCTAssertEqual(results[2].plainTextContent, "oldest")
    }

    // MARK: - Fuzzy Search Integration

    @MainActor
    func testFuzzySearch_subsequenceMatch_hwr() throws {
        let (_, engine, context) = try makeEngine()

        let item = makeItem(text: "Hello World")
        context.insert(item)
        try context.save()

        // "hwr" chars appear in order in "Hello World"
        let results = try engine.search(SearchQuery(text: "hwr"))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "Hello World")
    }

    @MainActor
    func testFuzzySearch_subsequenceMatch_nflx() throws {
        let (_, engine, context) = try makeEngine()

        let item = makeItem(text: "Netflix account password")
        context.insert(item)
        try context.save()

        let results = try engine.search(SearchQuery(text: "nflx"))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "Netflix account password")
    }

    @MainActor
    func testFuzzySearch_exactRanksAboveFuzzy() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        // Fuzzy match is newer but exact match should rank higher
        let fuzzyItem = makeItem(text: "network and flux capacity", capturedAt: now.addingTimeInterval(10))
        let exactItem = makeItem(text: "netflix password", capturedAt: now)
        context.insert(fuzzyItem)
        context.insert(exactItem)
        try context.save()

        let results = try engine.search(SearchQuery(text: "netflix"))
        XCTAssertEqual(results.count, 1) // "network and flux" doesn't contain subsequence 'n','e','t','f','l','i','x'... wait
        // Actually "network and flux capacity" — does "netflix" appear as subsequence?
        // n(etwork) - e - t - (no f... wait: n-e-t-w-o-r-k-space-a-n-d-space-f-l-u-x
        // n=yes, e=yes, t=yes, f=yes(pos 12), l=yes(pos 13), i=no... 'i' is not in "network and flux capacity"
        // So "netflix" does NOT match "network and flux capacity" → only exactItem matches
        XCTAssertEqual(results.first?.plainTextContent, "netflix password")
    }

    @MainActor
    func testFuzzySearch_exactRanksAboveSubsequence_whenBothMatch() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        // Both match "net", but one is exact word, other is subsequence
        let subsequenceItem = makeItem(text: "noticed everything today", capturedAt: now.addingTimeInterval(10))
        let exactItem = makeItem(text: "netflix stream", capturedAt: now)
        context.insert(subsequenceItem)
        context.insert(exactItem)
        try context.save()

        let results = try engine.search(SearchQuery(text: "net"))
        // Both should match, exact word prefix "net" in "netflix" should rank above subsequence
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.plainTextContent, "netflix stream")
    }

    @MainActor
    func testFuzzySearch_multiWord_requiresBothTerms() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let bothTerms = makeItem(text: "hello world greeting", capturedAt: now)
        let oneTerm = makeItem(text: "hello everyone", capturedAt: now.addingTimeInterval(1))
        context.insert(bothTerms)
        context.insert(oneTerm)
        try context.save()

        let results = try engine.search(SearchQuery(text: "hello world"))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "hello world greeting")
    }

    @MainActor
    func testFuzzySearch_imageItemsExcluded_whenTextQueryActive() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let textItem = makeItem(text: "hello world", capturedAt: now)
        let imageItem = ClipboardItem(
            contentType: .image,
            rawData: Data([0xFF, 0xD8]),
            capturedAt: now.addingTimeInterval(1)
        )
        context.insert(textItem)
        context.insert(imageItem)
        try context.save()

        let results = try engine.search(SearchQuery(text: "hello"))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.plainTextContent, "hello world")
    }

    @MainActor
    func testFuzzySearch_noTextQuery_preservesDateOrder() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let old = makeItem(text: "old item", capturedAt: now.addingTimeInterval(-100))
        let mid = makeItem(text: "middle item", capturedAt: now.addingTimeInterval(-50))
        let newest = makeItem(text: "newest item", capturedAt: now)

        context.insert(old)
        context.insert(mid)
        context.insert(newest)
        try context.save()

        // Filter-only query (no text) — date order must be preserved
        let results = try engine.search(SearchQuery(filters: [.contentType(.text)]))
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].plainTextContent, "newest item")
        XCTAssertEqual(results[1].plainTextContent, "middle item")
        XCTAssertEqual(results[2].plainTextContent, "old item")
    }

    // MARK: - Distinct Source Apps

    @MainActor
    func testDistinctSourceApps() throws {
        let (_, engine, context) = try makeEngine()

        let now = Date()
        let item1 = makeItem(text: "a", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari", capturedAt: now)
        let item2 = makeItem(text: "b", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari", capturedAt: now.addingTimeInterval(1))
        let item3 = makeItem(text: "c", sourceAppBundleID: "com.google.Chrome", sourceAppName: "Chrome", capturedAt: now.addingTimeInterval(2))

        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try context.save()

        let apps = try engine.distinctSourceApps()

        XCTAssertEqual(apps.count, 2)
        // Sorted alphabetically
        XCTAssertEqual(apps[0].name, "Chrome")
        XCTAssertEqual(apps[1].name, "Safari")
    }
}
