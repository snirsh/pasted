import XCTest
@testable import Pasted

/// Tests for SearchFilter, DateRange, and SearchQuery value types (spec 002).
/// Covers Hashable/Identifiable conformance, date computations, and query properties.
final class FilterTests: XCTestCase {

    // MARK: - SearchFilter Hashable

    func testSearchFilterHashableContentType() {
        let a = SearchFilter.contentType(.text)
        let b = SearchFilter.contentType(.text)
        let c = SearchFilter.contentType(.image)

        XCTAssertEqual(a, b, "Same content type filters should be equal")
        XCTAssertNotEqual(a, c, "Different content type filters should not be equal")

        var set = Set<SearchFilter>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1, "Duplicate filters should collapse in a Set")
    }

    func testSearchFilterHashableSourceApp() {
        let a = SearchFilter.sourceApp(bundleID: "com.apple.Safari", name: "Safari")
        let b = SearchFilter.sourceApp(bundleID: "com.apple.Safari", name: "Safari")
        let c = SearchFilter.sourceApp(bundleID: "com.google.Chrome", name: "Chrome")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testSearchFilterHashableDateRange() {
        let a = SearchFilter.dateRange(.today)
        let b = SearchFilter.dateRange(.today)
        let c = SearchFilter.dateRange(.yesterday)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testSearchFilterHashableDifferentCases() {
        let typeFilter = SearchFilter.contentType(.text)
        let appFilter = SearchFilter.sourceApp(bundleID: "com.test", name: "Test")
        let dateFilter = SearchFilter.dateRange(.today)

        XCTAssertNotEqual(typeFilter, appFilter)
        XCTAssertNotEqual(typeFilter, dateFilter)
        XCTAssertNotEqual(appFilter, dateFilter)
    }

    // MARK: - SearchFilter Identifiable

    func testSearchFilterIdentifiableContentType() {
        let filter = SearchFilter.contentType(.image)
        XCTAssertEqual(filter.id, "type:image")
    }

    func testSearchFilterIdentifiableSourceApp() {
        let filter = SearchFilter.sourceApp(bundleID: "com.apple.Safari", name: "Safari")
        XCTAssertEqual(filter.id, "app:com.apple.Safari")
    }

    func testSearchFilterIdentifiableDateRange() {
        let filter = SearchFilter.dateRange(.today)
        XCTAssertEqual(filter.id, "date:today")
    }

    func testSearchFilterIdentifiableUniqueness() {
        let filters: [SearchFilter] = [
            .contentType(.text),
            .contentType(.image),
            .sourceApp(bundleID: "com.apple.Safari", name: "Safari"),
            .dateRange(.today),
            .dateRange(.lastSevenDays)
        ]

        let ids = filters.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All filter IDs should be unique")
    }

    // MARK: - DateRange startDate / endDate

    func testDateRangeTodayStartDate() {
        let range = DateRange.today
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(range.startDate, expected)
    }

    func testDateRangeTodayEndDate() {
        let range = DateRange.today
        let now = Date()
        // endDate should be approximately now (within a few seconds tolerance)
        XCTAssertLessThanOrEqual(abs(range.endDate.timeIntervalSince(now)), 2.0)
    }

    func testDateRangeYesterdayStartDate() {
        let range = DateRange.yesterday
        let calendar = Calendar.current
        let expectedStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        XCTAssertEqual(range.startDate, expectedStart)
    }

    func testDateRangeYesterdayEndDate() {
        let range = DateRange.yesterday
        let expected = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(range.endDate, expected)
    }

    func testDateRangeLastSevenDaysStartDate() {
        let range = DateRange.lastSevenDays
        let calendar = Calendar.current
        let expected = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -7, to: Date())!)
        XCTAssertEqual(range.startDate, expected)
    }

    func testDateRangeLastThirtyDaysStartDate() {
        let range = DateRange.lastThirtyDays
        let calendar = Calendar.current
        let expected = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -30, to: Date())!)
        XCTAssertEqual(range.startDate, expected)
    }

    func testDateRangeCustom() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_100_000)
        let range = DateRange.custom(start: start, end: end)

        XCTAssertEqual(range.startDate, start)
        XCTAssertEqual(range.endDate, end)
    }

    func testDateRangeCustomIdentifier() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_100_000)
        let range = DateRange.custom(start: start, end: end)

        XCTAssertTrue(range.id.hasPrefix("custom:"))
        XCTAssertTrue(range.id.contains("1700000000"))
        XCTAssertTrue(range.id.contains("1700100000"))
    }

    func testDateRangePresetIdentifiers() {
        XCTAssertEqual(DateRange.today.id, "today")
        XCTAssertEqual(DateRange.yesterday.id, "yesterday")
        XCTAssertEqual(DateRange.lastSevenDays.id, "last7")
        XCTAssertEqual(DateRange.lastThirtyDays.id, "last30")
    }

    // MARK: - SearchQuery isEmpty

    func testSearchQueryIsEmptyDefault() {
        let query = SearchQuery()
        XCTAssertTrue(query.isEmpty)
    }

    func testSearchQueryIsEmptyWithWhitespaceOnly() {
        let query = SearchQuery(text: "   ")
        XCTAssertTrue(query.isEmpty, "Whitespace-only text with no filters should be empty")
    }

    func testSearchQueryIsNotEmptyWithText() {
        let query = SearchQuery(text: "hello")
        XCTAssertFalse(query.isEmpty)
    }

    func testSearchQueryIsNotEmptyWithFilters() {
        let query = SearchQuery(filters: [.contentType(.text)])
        XCTAssertFalse(query.isEmpty)
    }

    func testSearchQueryIsNotEmptyWithTextAndFilters() {
        let query = SearchQuery(text: "hello", filters: [.contentType(.text)])
        XCTAssertFalse(query.isEmpty)
    }

    // MARK: - SearchQuery hasTextQuery

    func testSearchQueryHasTextQuery() {
        XCTAssertFalse(SearchQuery().hasTextQuery)
        XCTAssertFalse(SearchQuery(text: "").hasTextQuery)
        XCTAssertFalse(SearchQuery(text: "   ").hasTextQuery)
        XCTAssertTrue(SearchQuery(text: "hello").hasTextQuery)
    }

    // MARK: - SearchQuery Computed Filter Properties

    func testSearchQueryContentTypeFilters() {
        let query = SearchQuery(filters: [
            .contentType(.text),
            .contentType(.image),
            .sourceApp(bundleID: "com.test", name: "Test"),
            .dateRange(.today)
        ])

        let types = query.contentTypeFilters
        XCTAssertEqual(types.count, 2)
        XCTAssertTrue(types.contains(.text))
        XCTAssertTrue(types.contains(.image))
    }

    func testSearchQuerySourceAppFilters() {
        let query = SearchQuery(filters: [
            .sourceApp(bundleID: "com.apple.Safari", name: "Safari"),
            .sourceApp(bundleID: "com.google.Chrome", name: "Chrome"),
            .contentType(.text)
        ])

        let apps = query.sourceAppFilters
        XCTAssertEqual(apps.count, 2)
        XCTAssertEqual(apps[0].bundleID, "com.apple.Safari")
        XCTAssertEqual(apps[0].name, "Safari")
        XCTAssertEqual(apps[1].bundleID, "com.google.Chrome")
        XCTAssertEqual(apps[1].name, "Chrome")
    }

    func testSearchQueryDateRangeFilter() {
        let query = SearchQuery(filters: [
            .contentType(.text),
            .dateRange(.lastSevenDays)
        ])

        XCTAssertEqual(query.dateRangeFilter, .lastSevenDays)
    }

    func testSearchQueryDateRangeFilterNil() {
        let query = SearchQuery(filters: [.contentType(.text)])
        XCTAssertNil(query.dateRangeFilter)
    }

    func testSearchQueryDateRangeFilterFirstOnly() {
        // If multiple date ranges are somehow present, only the first is used
        let query = SearchQuery(filters: [
            .dateRange(.today),
            .dateRange(.yesterday)
        ])

        XCTAssertEqual(query.dateRangeFilter, .today)
    }

    // MARK: - SearchQuery adding / removing

    func testSearchQueryAdding() {
        let query = SearchQuery()
        let updated = query.adding(.contentType(.text))

        XCTAssertEqual(updated.filters.count, 1)
        XCTAssertTrue(updated.filters.contains(.contentType(.text)))
    }

    func testSearchQueryAddingDateRangeReplacesExisting() {
        let query = SearchQuery(filters: [.dateRange(.today)])
        let updated = query.adding(.dateRange(.yesterday))

        XCTAssertEqual(updated.filters.count, 1)
        XCTAssertEqual(updated.dateRangeFilter, .yesterday)
    }

    func testSearchQueryRemoving() {
        let query = SearchQuery(filters: [.contentType(.text), .contentType(.image)])
        let updated = query.removing(.contentType(.text))

        XCTAssertEqual(updated.filters.count, 1)
        XCTAssertTrue(updated.filters.contains(.contentType(.image)))
    }

    func testSearchQueryAddingDuplicateDoesNotDouble() {
        let query = SearchQuery(filters: [.contentType(.text)])
        let updated = query.adding(.contentType(.text))

        XCTAssertEqual(updated.filters.count, 1)
    }
}
