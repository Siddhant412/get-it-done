import Foundation
import SwiftData

@Model
final class TaskItem: Identifiable {
    var id: UUID
    var title: String
    var detail: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: Int
    var createdAt: Date

    var goal: Goal?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: Int = 0,
        createdAt: Date = Date(),
        goal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.priority = priority
        self.createdAt = createdAt
        self.goal = goal
    }
}
