import SwiftData
import Foundation

/// Executes search queries against the clipboard history using SwiftData predicates.
/// Combines text search, content type, source app, and date range filters with AND logic.
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
        let sourceApps = query.sourceAppFilters.map(\.bundleID)
        let dateStart = query.dateRangeFilter?.startDate
        let dateEnd = query.dateRangeFilter?.endDate

        // Build a compound predicate combining all active filters with AND logic.
        // SwiftData's #Predicate macro requires all branches to be known at compile time,
        // so we enumerate the combinations of active filter types.
        descriptor.predicate = buildPredicate(
            searchText: searchText,
            contentTypes: contentTypes,
            sourceApps: sourceApps,
            dateStart: dateStart,
            dateEnd: dateEnd
        )

        return try modelContext.fetch(descriptor)
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

    /// Builds a predicate from the active filter combination.
    /// Each filter dimension is optional; active dimensions combine with AND.
    private func buildPredicate(
        searchText: String?,
        contentTypes: [ContentType],
        sourceApps: [String],
        dateStart: Date?,
        dateEnd: Date?
    ) -> Predicate<ClipboardItem> {
        let hasText = searchText != nil
        let hasContentType = !contentTypes.isEmpty
        let hasSourceApp = !sourceApps.isEmpty
        let hasDate = dateStart != nil && dateEnd != nil

        // We need to handle the combinatorial explosion of optional filters.
        // SwiftData #Predicate requires compile-time known expressions.
        switch (hasText, hasContentType, hasSourceApp, hasDate) {
        // --- Single filters ---
        case (true, false, false, false):
            let text = searchText!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
            }

        case (false, true, false, false):
            let rawTypes = contentTypes.map(\.rawValue)
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
            }

        case (false, false, true, false):
            return #Predicate<ClipboardItem> { item in
                sourceApps.contains(item.sourceAppBundleID ?? "")
            }

        case (false, false, false, true):
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.capturedAt >= start && item.capturedAt <= end
            }

        // --- Two filters ---
        case (true, true, false, false):
            let text = searchText!
            let rawTypes = contentTypes.map(\.rawValue)
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && rawTypes.contains(item.contentTypeRaw)
            }

        case (true, false, true, false):
            let text = searchText!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && sourceApps.contains(item.sourceAppBundleID ?? "")
            }

        case (true, false, false, true):
            let text = searchText!
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && item.capturedAt >= start && item.capturedAt <= end
            }

        case (false, true, true, false):
            let rawTypes = contentTypes.map(\.rawValue)
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
                && sourceApps.contains(item.sourceAppBundleID ?? "")
            }

        case (false, true, false, true):
            let rawTypes = contentTypes.map(\.rawValue)
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
                && item.capturedAt >= start && item.capturedAt <= end
            }

        case (false, false, true, true):
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                sourceApps.contains(item.sourceAppBundleID ?? "")
                && item.capturedAt >= start && item.capturedAt <= end
            }

        // --- Three filters ---
        case (true, true, true, false):
            let text = searchText!
            let rawTypes = contentTypes.map(\.rawValue)
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && rawTypes.contains(item.contentTypeRaw)
                && sourceApps.contains(item.sourceAppBundleID ?? "")
            }

        case (true, true, false, true):
            let text = searchText!
            let rawTypes = contentTypes.map(\.rawValue)
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && rawTypes.contains(item.contentTypeRaw)
                && item.capturedAt >= start && item.capturedAt <= end
            }

        case (true, false, true, true):
            let text = searchText!
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && sourceApps.contains(item.sourceAppBundleID ?? "")
                && item.capturedAt >= start && item.capturedAt <= end
            }

        case (false, true, true, true):
            let rawTypes = contentTypes.map(\.rawValue)
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                rawTypes.contains(item.contentTypeRaw)
                && sourceApps.contains(item.sourceAppBundleID ?? "")
                && item.capturedAt >= start && item.capturedAt <= end
            }

        // --- All four filters ---
        case (true, true, true, true):
            let text = searchText!
            let rawTypes = contentTypes.map(\.rawValue)
            let start = dateStart!
            let end = dateEnd!
            return #Predicate<ClipboardItem> { item in
                item.plainTextContent?.localizedStandardContains(text) == true
                && rawTypes.contains(item.contentTypeRaw)
                && sourceApps.contains(item.sourceAppBundleID ?? "")
                && item.capturedAt >= start && item.capturedAt <= end
            }

        // --- No filters (should not reach here, but handle gracefully) ---
        case (false, false, false, false):
            return #Predicate<ClipboardItem> { _ in true }
        }
    }
}
