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
    var scheduleDays: [Int]
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    @Relationship(deleteRule: .cascade, inverse: \HabitCheckIn.habit)
    var checkIns: [HabitCheckIn]

    init(
        id: UUID = UUID(),
        title: String,
        streak: Int = 0,
        progress: Double = 0,
        sortOrder: Int,
        createdAt: Date = Date(),
        scheduleDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        checkIns: [HabitCheckIn] = []
    ) {
        self.id = id
        self.title = title
        self.streak = streak
        self.progress = progress
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.scheduleDays = scheduleDays
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.checkIns = checkIns
    }
}
