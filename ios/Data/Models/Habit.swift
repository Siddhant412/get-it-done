import Foundation
import SwiftData

@Model
final class Habit: Identifiable {
    var id: UUID
    var title: String
    var streak: Int
    var progress: Double
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        streak: Int = 0,
        progress: Double = 0,
        sortOrder: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.streak = streak
        self.progress = progress
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
