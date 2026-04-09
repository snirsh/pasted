import Foundation

/// Represents the complete user search state: text input plus active filters.
/// Used by `SearchEngine` to build compound SwiftData predicates.
struct SearchQuery: Equatable {
    var text: String
    var filters: [SearchFilter]

    init(text: String = "", filters: [SearchFilter] = []) {
        self.text = text
        self.filters = filters
    }

    /// Whether the query has no text and no filters (i.e., show all items).
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && filters.isEmpty
    }

    /// Whether the query includes a non-empty text search term.
    var hasTextQuery: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// All active content type filters.
    var contentTypeFilters: [ContentType] {
        filters.compactMap {
            if case .contentType(let type) = $0 { return type }
            return nil
        }
    }

    /// All active source app filters as (bundleID, name) tuples.
    var sourceAppFilters: [(bundleID: String, name: String)] {
        filters.compactMap {
            if case .sourceApp(let bundleID, let name) = $0 {
                return (bundleID, name)
            }
            return nil
        }
    }

    /// The active date range filter (only the first one is used).
    var dateRangeFilter: DateRange? {
        filters.compactMap {
            if case .dateRange(let range) = $0 { return range }
            return nil
        }.first
    }

    /// Returns a new query with the given filter added.
    func adding(_ filter: SearchFilter) -> SearchQuery {
        var copy = self
        // For date range, replace existing rather than accumulating
        if case .dateRange = filter {
            copy.filters.removeAll { if case .dateRange = $0 { return true }; return false }
        }
        if !copy.filters.contains(filter) {
            copy.filters.append(filter)
        }
        return copy
    }

    /// Returns a new query with the given filter removed.
    func removing(_ filter: SearchFilter) -> SearchQuery {
        var copy = self
        copy.filters.removeAll { $0 == filter }
        return copy
    }
}
