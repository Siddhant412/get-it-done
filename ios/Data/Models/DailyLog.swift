import Foundation
import SwiftData

@Model
final class DailyLog: Identifiable {
    var id: UUID
    var date: Date
    var intensity: Double
    var completedPriorities: Int
    var totalPriorities: Int
    var completedHabits: Int
    var totalHabits: Int
    var focusMinutes: Int
    var note: String
    @Attribute(.externalStorage)
    var photoData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        intensity: Double = 0,
        completedPriorities: Int = 0,
        totalPriorities: Int = 0,
        completedHabits: Int = 0,
        totalHabits: Int = 0,
        focusMinutes: Int = 0,
        note: String = "",
        photoData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.intensity = intensity
        self.completedPriorities = completedPriorities
        self.totalPriorities = totalPriorities
        self.completedHabits = completedHabits
        self.totalHabits = totalHabits
        self.focusMinutes = focusMinutes
        self.note = note
        self.photoData = photoData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
