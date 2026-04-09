import SwiftData
import Foundation

/// Executes search queries against the clipboard history using SwiftData predicates.
/// Content type and date filters are applied in SQL.
/// Text search is applied post-fetch via FuzzyMatcher for subsequence-aware relevance ranking.
/// Source app filtering is applied in-memory: SwiftData cannot generate valid SQL
/// for `optional ?? ""` in the LHS of an IN predicate (generates TERNARY which
/// SQLite rejects). Post-filtering in Swift is correct and avoids the crash.
@MainActor
final class SearchEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Search clipboard items matching the given query.
    /// An empty query returns all items sorted by capturedAt descending.
    func search(_ query: SearchQuery) throws -> [ClipboardItem] {
        if query.isEmpty {
            return try fetchAll()
        }

        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )

        let searchText = query.hasTextQuery ? query.text.trimmingCharacters(in: .whitespaces) : nil
        let contentTypes = query.contentTypeFilters
        let dateStart = query.dateRangeFilter?.startDate
        let dateEnd = query.dateRangeFilter?.endDate

        descriptor.predicate = buildPredicate(
            contentTypes: contentTypes,
            dateStart: dateStart,
            dateEnd: dateEnd
        )

        var results = try modelContext.fetch(descriptor)

        // Post-filter by source app in Swift.
        // SQLite cannot handle `TERNARY(field != nil, field, "") IN (list)` on the LHS,
        // so we skip this dimension in the SQL predicate and apply it here instead.
        let sourceAppBundleIDs = query.sourceAppFilters.map(\.bundleID)
        if !sourceAppBundleIDs.isEmpty {
            results = results.filter { item in
                guard let id = item.sourceAppBundleID else { return false }
                return sourceAppBundleIDs.contains(id)
            }
        }

        // Post-filter and rank by fuzzy text match.
        // Text is excluded from SQL to enable subsequence matching and relevance scoring.
        // Items with no plainTextContent (e.g. images) are excluded when a text query is active.
        if let text = searchText, !text.isEmpty {
            let scored = results.compactMap { item -> (ClipboardItem, Int)? in
                guard let content = item.plainTextContent else { return nil }
                let s = FuzzyMatcher.scoreMultiWord(text, in: content)
                return s > 0 ? (item, s) : nil
            }
            // Stable sort: higher score first; ties preserve the existing date-descending order.
            results = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
        }

        return results
    }

    /// Returns distinct source apps found in the clipboard history.
    func distinctSourceApps() throws -> [(bundleID: String, name: String)] {
        let descriptor = FetchDescriptor<ClipboardItem>()
        let items = try modelContext.fetch(descriptor)

        var seen = Set<String>()
        var result: [(bundleID: String, name: String)] = []

        for item in items {
            if let bundleID = item.sourceAppBundleID,
               let name = item.sourceAppName,
               !seen.contains(bundleID) {
                seen.insert(bundleID)
                result.append((bundleID: bundleID, name: name))
            }
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Private

    private func fetchAll() throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Builds a SQL predicate for content type and date filters.
    /// Text search and source app are intentionally excluded — both are post-filtered in Swift.
    private func buildPredicate(
        contentTypes: [ContentType],
        dateStart: Date?,
        dateEnd: Date?
    ) -> Predicate<ClipboardItem> {
        let hasContentType = !contentTypes.isEmpty
        let hasDate = dateStart != nil && dateEnd != nil

        switch (hasContentType, hasDate) {
        case (true, false):
            let rawTypes = contentTypes.map(\.rawValue)
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
            }

        case (false, true):
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.capturedAt >= start && item.capturedAt <= end
            }

        case (true, true):
            let rawTypes = contentTypes.map(\.rawValue)
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
                && item.capturedAt >= start && item.capturedAt <= end
            }

        case (false, false):
            return #Predicate<ClipboardItem> { _ in true }
        }
    }
}
