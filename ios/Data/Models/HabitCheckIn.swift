import Foundation
import SwiftData

@Model
final class HabitCheckIn: Identifiable {
    var id: UUID
    var date: Date
    var progress: Double
    var createdAt: Date

    var habit: Habit?

    init(
        id: UUID = UUID(),
        date: Date,
        progress: Double,
        createdAt: Date = Date(),
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = date
        self.progress = progress
        self.createdAt = createdAt
        self.habit = habit
    }
}
