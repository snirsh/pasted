import Foundation
import CloudKit

/// Wraps CloudKit container and database operations for iCloud sync (003-icloud-sync).
/// Manages the custom record zone and subscription lifecycle.
final class CloudKitManager {

    /// CloudKit container (uses the app's default container).
    let container: CKContainer

    /// Private database where all clipboard data is stored.
    let database: CKDatabase

    /// Custom zone for clipboard items — enables change tokens and atomic commits.
    let zoneID: CKRecordZone.ID

    /// Zone name constant.
    static let zoneName = "PastedClipboardZone"

    /// Subscription ID for change notifications.
    static let subscriptionID = "pasted-clipboard-changes"

    init(container: CKContainer = .default()) {
        self.container = container
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Account Status

    /// Checks the current iCloud account status.
    /// - Returns: The CKAccountStatus for the current user.
    func checkAccountStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }

    // MARK: - Zone Management

    /// Creates the PastedClipboardZone idempotently.
    /// If the zone already exists, this is a no-op.
    func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [zone],
            recordZoneIDsToDelete: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    // Zone already exists is not a real error
                    if let ckError = error as? CKError, ckError.code == .serverRejectedRequest {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            database.add(operation)
        }
    }

    // MARK: - Subscription

    /// Creates a CKDatabaseSubscription to receive push notifications for changes.
    /// Idempotent — uses a fixed subscription ID.
    func createSubscription() async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }
}
