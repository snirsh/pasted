import Foundation
import SwiftData
import CloudKit
import Network

/// Orchestrates iCloud sync: pushes local changes, fetches remote changes,
/// handles network monitoring and automatic queue draining (003-icloud-sync).
@MainActor
final class SyncEngine {

    static let shared: SyncEngine? = nil // Initialized by AppDelegate after model context is ready

    private let modelContext: ModelContext
    private let cloudKitManager: CloudKitManager
    private let stateTracker: SyncStateTracker
    private let networkMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.pasted.networkMonitor")

    private var isRunning = false
    private var isNetworkAvailable = true

    /// Maximum records per CloudKit batch operation.
    private static let batchSize = 400

    init(modelContext: ModelContext, cloudKitManager: CloudKitManager = CloudKitManager()) {
        self.modelContext = modelContext
        self.cloudKitManager = cloudKitManager
        self.stateTracker = SyncStateTracker(modelContext: modelContext)
        self.networkMonitor = NWPathMonitor()
    }

    // MARK: - Lifecycle

    /// Starts the sync engine: verifies iCloud account, creates zone/subscription,
    /// begins network monitoring, and performs an initial sync.
    func startSync() async {
        guard !isRunning else { return }
        guard UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") else { return }

        isRunning = true

        // Verify iCloud account
        let accountStatus = await cloudKitManager.checkAccountStatus()
        guard accountStatus == .available else {
            try? stateTracker.setSyncStatus(.paused, error: "iCloud account not available")
            isRunning = false
            return
        }

        // Set up CloudKit zone and subscription
        do {
            try await cloudKitManager.ensureZoneExists()
            try await cloudKitManager.createSubscription()
        } catch {
            try? stateTracker.setSyncStatus(.error, error: "Setup failed: \(error.localizedDescription)")
            isRunning = false
            return
        }

        // Start network monitoring
        startNetworkMonitoring()

        // Initial sync
        do {
            try await fetchChanges()
            try await pushChanges()
            try stateTracker.setSyncStatus(.idle)
        } catch {
            try? stateTracker.setSyncStatus(.error, error: error.localizedDescription)
        }
    }

    /// Stops the sync engine and network monitoring.
    func stopSync() {
        isRunning = false
        networkMonitor.cancel()
        try? stateTracker.setSyncStatus(.paused)
    }

    // MARK: - Push Changes

    /// Queries items with pendingUpload status and uploads them to CloudKit in batches.
    func pushChanges() async throws {
        guard isRunning, isNetworkAvailable else { return }

        try stateTracker.setSyncStatus(.syncing)

        let pendingUploadStatus = SyncStatus.pendingUpload
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.syncStatus == pendingUploadStatus }
        )
        let pendingItems = try modelContext.fetch(descriptor)

        guard !pendingItems.isEmpty else {
            try stateTracker.updateStatus()
            return
        }

        // Process in batches
        let batches = stride(from: 0, to: pendingItems.count, by: Self.batchSize).map {
            Array(pendingItems[$0..<min($0 + Self.batchSize, pendingItems.count)])
        }

        for batch in batches {
            var records: [CKRecord] = []

            for item in batch {
                if item.rawData.count > SyncRecordMapper.localOnlyThresholdBytes {
                    item.syncStatus = .localOnly
                    continue
                }

                if let record = SyncRecordMapper.toCloudKitRecord(item, zoneID: cloudKitManager.zoneID) {
                    records.append(record)
                }
            }

            guard !records.isEmpty else { continue }

            let savedRecords = try await uploadRecords(records)

            // Mark successfully uploaded items as synced
            for record in savedRecords {
                let recordName = record.recordID.recordName
                if let item = batch.first(where: { $0.id.uuidString == recordName }) {
                    item.syncStatus = .synced
                    item.cloudRecordName = recordName
                }
            }

            try modelContext.save()
        }

        try stateTracker.updateStatus()
    }

    // MARK: - Fetch Changes

    /// Fetches changes from CloudKit using the stored server change token.
    /// Processes inserts, updates, and deletions via ConflictResolver.
    func fetchChanges() async throws {
        guard isRunning, isNetworkAvailable else { return }

        try stateTracker.setSyncStatus(.syncing)

        let previousToken = SyncStateTracker.loadChangeToken()

        let (changedRecords, deletedRecordIDs, newToken) = try await fetchZoneChanges(
            since: previousToken
        )

        // Process changed records
        for ckRecord in changedRecords {
            let syncRecord = SyncRecordMapper.fromCloudKitRecord(ckRecord)

            // Look up local item by record name (which matches UUID string)
            let localItem = try findLocalItem(recordName: syncRecord.recordName)

            let resolution = ConflictResolver.resolve(local: localItem, remote: syncRecord)

            switch resolution {
            case .insertRemote:
                try insertFromRemote(syncRecord)
            case .updateLocal:
                if let localItem {
                    try updateFromRemote(localItem, with: syncRecord)
                }
            case .deleteLocal:
                if let localItem {
                    modelContext.delete(localItem)
                }
            case .skip:
                break
            }
        }

        // Process deletions
        for recordID in deletedRecordIDs {
            if let localItem = try findLocalItem(recordName: recordID.recordName) {
                modelContext.delete(localItem)
            }
        }

        try modelContext.save()

        // Persist the new change token
        if let newToken {
            SyncStateTracker.saveChangeToken(newToken)
        }

        try stateTracker.updateStatus()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied

                if !wasAvailable && self.isNetworkAvailable {
                    // Network restored — drain the queue
                    try? self.stateTracker.setSyncStatus(.idle)
                    try? await self.pushChanges()
                    try? await self.fetchChanges()
                    try? self.stateTracker.setSyncStatus(.idle)
                } else if !self.isNetworkAvailable {
                    try? self.stateTracker.setSyncStatus(.offline)
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - CloudKit Operations (Private)

    private func uploadRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(
                recordsToSave: records,
                recordIDsToDelete: nil
            )
            operation.savePolicy = .changedKeys
            operation.isAtomic = true

            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { _, result in
                if case .success(let record) = result {
                    savedRecords.append(record)
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            cloudKitManager.database.add(operation)
        }
    }

    private func fetchZoneChanges(
        since token: CKServerChangeToken?
    ) async throws -> ([CKRecord], [CKRecord.ID], CKServerChangeToken?) {
        try await withCheckedThrowingContinuation { continuation in
            let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            options.previousServerChangeToken = token

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [cloudKitManager.zoneID],
                configurationsByRecordZoneID: [cloudKitManager.zoneID: options]
            )

            var changedRecords: [CKRecord] = []
            var deletedRecordIDs: [CKRecord.ID] = []
            var newToken: CKServerChangeToken?

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    changedRecords.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
                newToken = token
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .success(let (serverChangeToken, _, _)) = result {
                    newToken = serverChangeToken
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (changedRecords, deletedRecordIDs, newToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            cloudKitManager.database.add(operation)
        }
    }

    // MARK: - Local Data Helpers

    private func findLocalItem(recordName: String) throws -> ClipboardItem? {
        guard let uuid = UUID(uuidString: recordName) else { return nil }
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func insertFromRemote(_ syncRecord: SyncRecord) throws {
        guard let contentType = ContentType(rawValue: syncRecord.contentType) else { return }

        let item = ClipboardItem(
            id: UUID(uuidString: syncRecord.recordName) ?? UUID(),
            contentType: contentType,
            rawData: syncRecord.rawData ?? Data(),
            plainTextContent: syncRecord.plainTextContent,
            sourceAppBundleID: syncRecord.sourceAppBundleID,
            capturedAt: syncRecord.capturedAt,
            syncStatus: .synced,
            cloudRecordName: syncRecord.recordName
        )
        modelContext.insert(item)
    }

    private func updateFromRemote(_ item: ClipboardItem, with syncRecord: SyncRecord) throws {
        if let contentType = ContentType(rawValue: syncRecord.contentType) {
            item.contentType = contentType
        }
        if let rawData = syncRecord.rawData {
            item.rawData = rawData
            item.byteSize = Int64(rawData.count)
        }
        item.plainTextContent = syncRecord.plainTextContent
        item.sourceAppBundleID = syncRecord.sourceAppBundleID
        item.capturedAt = syncRecord.capturedAt
        item.syncStatus = .synced
        item.cloudRecordName = syncRecord.recordName
    }
}
