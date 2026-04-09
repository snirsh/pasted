import XCTest
@testable import Pasted

/// Comprehensive tests for ConflictResolver (003-icloud-sync).
/// Covers union merge, delete propagation, and last-write-wins.
final class ConflictResolverTests: XCTestCase {

    // MARK: - Helpers

    private func makeSyncRecord(
        recordName: String = UUID().uuidString,
        contentType: String = "text",
        rawData: Data? = Data("test".utf8),
        plainTextContent: String? = "test",
        capturedAt: Date = Date(),
        deviceID: String = "device-2",
        modifiedAt: Date = Date(),
        isDeleted: Bool = false
    ) -> SyncRecord {
        SyncRecord(
            recordName: recordName,
            contentType: contentType,
            rawData: rawData,
            plainTextContent: plainTextContent,
            sourceAppBundleID: nil,
            capturedAt: capturedAt,
            deviceID: deviceID,
            modifiedAt: modifiedAt,
            isDeleted: isDeleted
        )
    }

    private func makeLocalItem(
        text: String = "local",
        capturedAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            contentType: .text,
            rawData: Data(text.utf8),
            plainTextContent: text,
            capturedAt: capturedAt
        )
    }

    // MARK: - Union Merge (Both New Items Preserved)

    func testUnionMergeNewRemoteItemIsInserted() {
        // Remote has a new item that doesn't exist locally
        let remote = makeSyncRecord(
            recordName: UUID().uuidString,
            plainTextContent: "remote new item"
        )

        let resolution = ConflictResolver.resolve(local: nil, remote: remote)
        XCTAssertEqual(resolution, .insertRemote,
                       "Union merge: new remote item should be inserted locally")
    }

    func testUnionMergeExistingLocalItemIsPreservedWhenNewerThanRemote() {
        let now = Date()
        let local = makeLocalItem(text: "local item", capturedAt: now)
        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            modifiedAt: now.addingTimeInterval(-10)
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .skip,
                       "Union merge: local item newer than remote should be preserved (skip)")
    }

    func testBothNewItemsFromDifferentDevicesArePreserved() {
        // Simulate two items created on different devices while offline.
        // Each device has its own item; the other device's item is "new".
        let remoteItem = makeSyncRecord(
            recordName: UUID().uuidString,
            plainTextContent: "from device B"
        )

        // No local match for the remote item → insert
        let resolution = ConflictResolver.resolve(local: nil, remote: remoteItem)
        XCTAssertEqual(resolution, .insertRemote,
                       "Item from another device with no local match should be inserted")
    }

    // MARK: - Delete Propagation

    func testDeletePropagationRemoteDeletedRemovesLocal() {
        let local = makeLocalItem(text: "to be deleted")

        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            isDeleted: true
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .deleteLocal,
                       "Delete propagation: remote isDeleted should delete local item")
    }

    func testDeletePropagationRemoteDeletedNoLocalIsSkipped() {
        let remote = makeSyncRecord(
            recordName: UUID().uuidString,
            isDeleted: true
        )

        let resolution = ConflictResolver.resolve(local: nil, remote: remote)
        XCTAssertEqual(resolution, .skip,
                       "Delete propagation: deleted remote with no local match should skip")
    }

    func testDeleteTakesPriorityOverTimestamp() {
        // Even if local is "newer", a delete from remote should still propagate
        let now = Date()
        let local = makeLocalItem(
            text: "newer local",
            capturedAt: now.addingTimeInterval(100)
        )

        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            modifiedAt: now,
            isDeleted: true
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .deleteLocal,
                       "Delete should take priority even when local is newer")
    }

    // MARK: - Last-Write-Wins for Metadata

    func testLastWriteWinsRemoteNewerUpdatesLocal() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_700_001_000)

        let local = makeLocalItem(text: "old local", capturedAt: oldDate)
        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            modifiedAt: newDate
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .updateLocal,
                       "Last-write-wins: newer remote should update local")
    }

    func testLastWriteWinsLocalNewerSkips() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_700_001_000)

        let local = makeLocalItem(text: "newer local", capturedAt: newDate)
        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            modifiedAt: oldDate
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .skip,
                       "Last-write-wins: newer local should skip remote update")
    }

    func testLastWriteWinsEqualTimestampSkips() {
        let sameDate = Date(timeIntervalSince1970: 1_700_000_000)

        let local = makeLocalItem(text: "same time", capturedAt: sameDate)
        let remote = makeSyncRecord(
            recordName: local.id.uuidString,
            modifiedAt: sameDate
        )

        let resolution = ConflictResolver.resolve(local: local, remote: remote)
        XCTAssertEqual(resolution, .skip,
                       "Equal timestamps should skip (local version will push)")
    }
}
