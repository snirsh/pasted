import SwiftData
import Foundation

/// Identifies a device participating in iCloud sync (003-icloud-sync).
/// Each device registers itself in CloudKit; other devices discover peers during sync.
@Model
final class DeviceInfo {

    /// Unique identifier for this Pasted installation (UUID, stored in UserDefaults).
    @Attribute(.unique)
    var deviceID: String

    /// Human-readable device name (e.g., "Snir's MacBook Pro").
    var deviceName: String

    /// Pasted version string (from CFBundleShortVersionString).
    var pastedVersion: String

    /// Last time this device was seen syncing.
    var lastSeenAt: Date

    init(
        deviceID: String,
        deviceName: String,
        pastedVersion: String,
        lastSeenAt: Date = Date()
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.pastedVersion = pastedVersion
        self.lastSeenAt = lastSeenAt
    }
}
