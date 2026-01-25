import Foundation
import SwiftData

@Model
final class Milestone: Identifiable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
    var sortOrder: Int
    var createdAt: Date
    var completedAt: Date?

    var goal: Goal?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        sortOrder: Int,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        goal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.goal = goal
    }
}
