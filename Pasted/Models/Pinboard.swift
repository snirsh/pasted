import SwiftData
import Foundation

/// A named collection of clipboard items that persist indefinitely,
/// separate from the auto-expiring clipboard history.
@Model
final class Pinboard {
    @Attribute(.unique)
    var id: UUID

    var name: String
    var displayOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var entries: [PinboardEntry] = []

    init(name: String, displayOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = Date()
    }
}
