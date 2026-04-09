import XCTest
import SwiftData
@testable import Pasted

/// Tests for AppExclusionService (spec 004).
/// Uses in-memory SwiftData container for isolation.
final class AppExclusionServiceTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeService() throws -> (ModelContainer, AppExclusionService) {
        let schema = Schema([AppExclusion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let service = AppExclusionService(modelContext: context)
        return (container, service)
    }

    // MARK: - Seed Defaults

    @MainActor
    func testSeedDefaultsCreatesNineEntries() throws {
        let (_, service) = try makeService()

        service.seedDefaultsIfNeeded()

        let all = try service.fetchAll()
        XCTAssertEqual(all.count, 9, "Seeding should create 9 default exclusions")

        // All defaults should have isDefault == true
        for exclusion in all {
            XCTAssertTrue(exclusion.isDefault, "\(exclusion.displayName) should be marked as default")
        }
    }

    @MainActor
    func testSeedDefaultsIsIdempotent() throws {
        let (_, service) = try makeService()

        service.seedDefaultsIfNeeded()
        service.seedDefaultsIfNeeded()
        service.seedDefaultsIfNeeded()

        let all = try service.fetchAll()
        XCTAssertEqual(all.count, 9, "Running seedDefaultsIfNeeded multiple times should not duplicate entries")
    }

    // MARK: - isExcluded

    @MainActor
    func testIsExcludedReturnsTrueForSeededBundleID() throws {
        let (_, service) = try makeService()
        service.seedDefaultsIfNeeded()

        XCTAssertTrue(service.isExcluded("com.1password.1password"),
                      "1Password 8 should be excluded after seeding")
        XCTAssertTrue(service.isExcluded("com.bitwarden.desktop"),
                      "Bitwarden should be excluded after seeding")
    }

    @MainActor
    func testIsExcludedReturnsFalseForNonExcludedBundleID() throws {
        let (_, service) = try makeService()
        service.seedDefaultsIfNeeded()

        XCTAssertFalse(service.isExcluded("com.apple.Safari"),
                       "Safari should not be excluded")
        XCTAssertFalse(service.isExcluded("com.example.unknown"),
                       "Unknown apps should not be excluded")
    }

    @MainActor
    func testIsExcludedReturnsFalseForNil() throws {
        let (_, service) = try makeService()
        service.seedDefaultsIfNeeded()

        XCTAssertFalse(service.isExcluded(nil),
                       "nil bundle ID should not be excluded")
    }

    // MARK: - Add

    @MainActor
    func testAddCreatesNewExclusionAndUpdatesLookup() throws {
        let (_, service) = try makeService()

        try service.add(bundleID: "com.example.testapp", displayName: "Test App")

        let all = try service.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.bundleIdentifier, "com.example.testapp")
        XCTAssertEqual(all.first?.displayName, "Test App")
        XCTAssertFalse(all.first?.isDefault ?? true)

        // Verify in-memory lookup is updated
        XCTAssertTrue(service.isExcluded("com.example.testapp"))
    }

    @MainActor
    func testAddDuplicateBundleIDIsHandledGracefully() throws {
        let (_, service) = try makeService()

        try service.add(bundleID: "com.example.dup", displayName: "Dup App")

        // Adding the same bundle ID again should not crash
        XCTAssertNoThrow(
            try service.add(bundleID: "com.example.dup", displayName: "Dup App Again"),
            "Adding a duplicate bundle ID should not throw"
        )

        // Should still be excluded
        XCTAssertTrue(service.isExcluded("com.example.dup"))
    }

    // MARK: - Remove

    @MainActor
    func testRemoveDeletesExclusionAndUpdatesLookup() throws {
        let (_, service) = try makeService()

        try service.add(bundleID: "com.example.removeme", displayName: "Remove Me")
        XCTAssertTrue(service.isExcluded("com.example.removeme"))

        let all = try service.fetchAll()
        let exclusion = try XCTUnwrap(all.first { $0.bundleIdentifier == "com.example.removeme" })

        try service.remove(exclusion)

        XCTAssertFalse(service.isExcluded("com.example.removeme"),
                       "Removed bundle ID should no longer be excluded")

        let remaining = try service.fetchAll()
        XCTAssertTrue(remaining.isEmpty)
    }
}
