import Foundation
import SwiftData

@Model
final class FocusSession: Identifiable {
    var id: UUID
    var startDate: Date
    var durationMinutes: Int
    var note: String
    var createdAt: Date
    var task: TaskItem?

    init(
        id: UUID = UUID(),
        startDate: Date,
        durationMinutes: Int,
        note: String = "",
        createdAt: Date = Date(),
        task: TaskItem? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.note = note
        self.createdAt = createdAt
        self.task = task
    }
}
