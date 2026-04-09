import SwiftData
import Foundation

/// An application excluded from clipboard capture.
/// Persisted via SwiftData; synced to iCloud via CloudKit.
@Model
final class AppExclusion {
    @Attribute(.unique)
    var id: UUID

    @Attribute(.unique)
    var bundleIdentifier: String

    var displayName: String
    var iconData: Data?
    var isDefault: Bool
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        iconData: Data? = nil,
        isDefault: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.iconData = iconData
        self.isDefault = isDefault
        self.dateAdded = dateAdded
    }
}
