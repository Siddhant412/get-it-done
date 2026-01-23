import Foundation
import SwiftData

@Model
final class UserStats: Identifiable {
    var id: UUID
    var streakDays: Int
    var focusMinutes: Int
    var streakProtected: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        streakDays: Int = 0,
        focusMinutes: Int = 0,
        streakProtected: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.streakDays = streakDays
        self.focusMinutes = focusMinutes
        self.streakProtected = streakProtected
        self.updatedAt = updatedAt
    }
}
