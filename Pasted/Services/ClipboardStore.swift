import SwiftData
import Foundation

/// Manages CRUD operations for ClipboardItem persistence via SwiftData.
@MainActor
final class ClipboardStore {
    private let modelContext: ModelContext
    private let storageLimitBytes: Int64

    init(modelContext: ModelContext, storageLimitBytes: Int64 = 1_073_741_824) { // 1GB default
        self.modelContext = modelContext
        self.storageLimitBytes = storageLimitBytes
    }

    /// Save a new clipboard item, deduplicating consecutive identical entries (FR-011).
    func save(_ item: ClipboardItem) throws {
        // Deduplication: check if the most recent item has the same data hash
        if let mostRecent = try fetchRecent(limit: 1).first,
           mostRecent.dataHash == item.dataHash {
            return // Skip duplicate
        }

        modelContext.insert(item)
        try modelContext.save()

        // Auto-prune if storage limit exceeded (FR-009)
        try pruneIfNeeded()
    }

    /// Fetch recent items sorted by capturedAt descending.
    func fetchRecent(limit: Int, offset: Int = 0) throws -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor)
    }

    /// Fetch all items sorted by capturedAt descending.
    func fetchAll() throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Delete a specific item.
    func delete(_ item: ClipboardItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    /// Delete all items (clear history).
    func deleteAll() throws {
        let items = try fetchAll()
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    /// Calculate total storage used by all items.
    func totalByteSize() throws -> Int64 {
        let items = try fetchAll()
        return items.reduce(0) { $0 + $1.byteSize }
    }

    /// Search items matching the given query using SearchEngine.
    private lazy var searchEngine = SearchEngine(modelContext: modelContext)

    func search(_ query: SearchQuery) throws -> [ClipboardItem] {
        try searchEngine.search(query)
    }

    func distinctSourceApps() throws -> [(bundleID: String, name: String)] {
        try searchEngine.distinctSourceApps()
    }

    /// Total number of items in the store.
    func count() throws -> Int {
        let descriptor = FetchDescriptor<ClipboardItem>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Prune oldest items when storage exceeds the configured limit.
    /// Deletes in batches of 100 until storage drops below 90% of limit (hysteresis).
    private func pruneIfNeeded() throws {
        let currentSize = try totalByteSize()
        guard currentSize > storageLimitBytes else { return }

        let targetSize = Int64(Double(storageLimitBytes) * 0.9)

        // Fetch oldest items first
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )

        var remainingToFree = currentSize - targetSize
        while remainingToFree > 0 {
            descriptor.fetchLimit = 100
            let batch = try modelContext.fetch(descriptor)
            if batch.isEmpty { break }

            for item in batch {
                remainingToFree -= item.byteSize
                modelContext.delete(item)
                if remainingToFree <= 0 { break }
            }
        }

        try modelContext.save()
    }
}
