import Foundation
import SwiftData

@Model
final class UserStats: Identifiable {
    var id: UUID
    var streakDays: Int
    var focusMinutes: Int
    var streakProtected: Bool
    var streakFreezeTokens: Int
    var freezeTokenAllowance: Int
    var lastFreezeResetMonth: Int
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        streakDays: Int = 0,
        focusMinutes: Int = 0,
        streakProtected: Bool = false,
        streakFreezeTokens: Int = 2,
        freezeTokenAllowance: Int = 2,
        lastFreezeResetMonth: Int = Calendar.current.component(.month, from: Date()),
        reminderEnabled: Bool = false,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.streakDays = streakDays
        self.focusMinutes = focusMinutes
        self.streakProtected = streakProtected
        self.streakFreezeTokens = streakFreezeTokens
        self.freezeTokenAllowance = freezeTokenAllowance
        self.lastFreezeResetMonth = lastFreezeResetMonth
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.updatedAt = updatedAt
    }
}
