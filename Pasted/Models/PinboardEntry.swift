import SwiftData
import Foundation

/// A single item within a Pinboard, with a user-controlled display order.
@Model
final class PinboardEntry {
    @Attribute(.unique)
    var id: UUID

    var displayOrder: Int
    var addedAt: Date

    @Relationship
    var item: ClipboardItem?

    @Relationship
    var pinboard: Pinboard?

    init(item: ClipboardItem, pinboard: Pinboard, displayOrder: Int = 0) {
        self.id = UUID()
        self.displayOrder = displayOrder
        self.addedAt = Date()
        self.item = item
        self.pinboard = pinboard
    }
}
