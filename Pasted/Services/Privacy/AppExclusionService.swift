import SwiftData
import Foundation

/// Manages the app exclusion list for clipboard privacy.
///
/// Maintains an in-memory `Set<String>` of excluded bundle identifiers for
/// O(1) lookup on the clipboard monitor hot path. Persists exclusions via
/// SwiftData for durability and iCloud sync.
@MainActor
final class AppExclusionService {
    private let modelContext: ModelContext
    private var excludedBundleIDs: Set<String> = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        rebuildLookup()
    }

    // MARK: - Seeding

    /// Inserts the default exclusion list on first launch.
    /// Idempotent: does nothing if any exclusion already exists.
    func seedDefaultsIfNeeded() {
        let descriptor = FetchDescriptor<AppExclusion>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for entry in DefaultExclusionList.entries {
            let exclusion = AppExclusion(
                bundleIdentifier: entry.bundleID,
                displayName: entry.displayName,
                isDefault: true
            )
            modelContext.insert(exclusion)
        }

        try? modelContext.save()
        rebuildLookup()
    }

    // MARK: - Lookup

    /// Returns `true` if the given bundle identifier is excluded.
    /// Returns `false` for `nil` input (unknown source app).
    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    // MARK: - CRUD

    /// Adds a new app exclusion. Duplicate bundle IDs are handled gracefully
    /// (SwiftData's unique constraint causes an upsert / no-op).
    func add(bundleID: String, displayName: String, iconData: Data? = nil, isDefault: Bool = false) throws {
        let exclusion = AppExclusion(
            bundleIdentifier: bundleID,
            displayName: displayName,
            iconData: iconData,
            isDefault: isDefault
        )
        modelContext.insert(exclusion)
        try modelContext.save()
        rebuildLookup()
    }

    /// Removes an existing exclusion.
    func remove(_ exclusion: AppExclusion) throws {
        modelContext.delete(exclusion)
        try modelContext.save()
        rebuildLookup()
    }

    /// Fetches all persisted exclusions.
    func fetchAll() throws -> [AppExclusion] {
        let descriptor = FetchDescriptor<AppExclusion>(
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Private

    /// Rebuilds the in-memory lookup set from SwiftData.
    private func rebuildLookup() {
        let descriptor = FetchDescriptor<AppExclusion>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        excludedBundleIDs = Set(all.map(\.bundleIdentifier))
    }
}
