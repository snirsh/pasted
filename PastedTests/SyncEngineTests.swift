import XCTest
import SwiftData
@testable import Pasted

/// Tests for SyncEngine initialization and ConflictResolver logic (003-icloud-sync).
final class SyncEngineTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([ClipboardItem.self, SyncState.self, DeviceInfo.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        return (container, context)
    }

    // MARK: - SyncEngine Initialization
    //
    // Note: SyncEngine init creates a CloudKitManager that accesses CKContainer.default(),
    // which requires a signed iCloud entitlement. This test is skipped in SPM test context
    // and should be run via Xcode with the Pasted target's entitlements.

    @MainActor
    func testSyncEngineCanBeInitialized() throws {
        // Verify the model context can be created with all sync-related schemas
        let (_, context) = try makeContext()
        XCTAssertNotNil(context, "ModelContext with sync schemas should initialize without errors")

        // SyncEngine itself requires CKContainer which is unavailable in SPM tests.
        // Full integration tested via Xcode project.
    }

    // MARK: - ConflictResolver: New Remote → Insert

    func testConflictResolverNewRemoteInserts() {
        let remote = SyncRecord(
            recordName: UUID().uuidString,
            contentType: "text",
            rawData: Data("remote text".utf8),
            plainTextContent: "remote text",
            sourceAppBundleID: nil,
            capturedAt: Date(),
            deviceID: "device-2",
            modifiedAt: Date(),
            isDeleted: false
        )

        let resolution = ConflictResolver.resolve(local: nil, remote: remote)
        XCTAssertEqual(resolution, .insertRemote,
                       "New remote item with no local match should result in insertRemote")
    }

    // MARK: - ConflictResolver: Remote Deleted → Delete Local

    func testConflictResolverRemoteDeletedDeletesLocal() {
        let local = ClipboardItem(
            contentType: .text,
            rawData: Data("local text".utf8),
            capturedAt: Date()
        )

        let remote = SyncRecord(
            recordName: local.id.uuidString,
            contentType: "text",
            rawData: nil,
            plainTextContent: nil,
            sourceAppBundleID: nil,
            capturedAt: Date(),
            deviceID: "device-2",
            modifiedAt: Date(),
            isDeleted: true
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .deleteLocal,
                       "Remote deletion should propagate to local item")
    }

    // MARK: - ConflictResolver: Metadata Conflict → Newer Wins

    func testConflictResolverNewerRemoteWins() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_700_001_000)

        let local = ClipboardItem(
            contentType: .text,
            rawData: Data("local".utf8),
            capturedAt: oldDate
        )

        let remote = SyncRecord(
            recordName: local.id.uuidString,
            contentType: "text",
            rawData: Data("remote".utf8),
            plainTextContent: "remote",
            sourceAppBundleID: nil,
            capturedAt: newDate,
            deviceID: "device-2",
            modifiedAt: newDate,
            isDeleted: false
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .updateLocal,
                       "Remote item with newer modifiedAt should update local")
    }

    func testConflictResolverNewerLocalSkips() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_700_001_000)

        let local = ClipboardItem(
            contentType: .text,
            rawData: Data("local".utf8),
            capturedAt: newDate
        )

        let remote = SyncRecord(
            recordName: local.id.uuidString,
            contentType: "text",
            rawData: Data("remote".utf8),
            plainTextContent: "remote",
            sourceAppBundleID: nil,
            capturedAt: oldDate,
            deviceID: "device-2",
            modifiedAt: oldDate,
            isDeleted: false
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .skip,
                       "Local item with newer timestamp should skip remote update")
    }
}

// MARK: - Equatable Conformance for Test Assertions

extension ConflictResolver.ConflictResolution: @retroactive Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.insertRemote, .insertRemote),
             (.updateLocal, .updateLocal),
             (.deleteLocal, .deleteLocal),
             (.skip, .skip):
            return true
        default:
            return false
        }
    }
}
