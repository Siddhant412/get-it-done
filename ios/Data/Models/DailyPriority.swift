import Foundation
import SwiftData

@Model
final class DailyPriority: Identifiable {
    var id: UUID
    var title: String
    var detail: String
    var isSmallWin: Bool
    var isCompleted: Bool
    var sortOrder: Int
    var createdAt: Date
    var goal: Goal?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        isSmallWin: Bool,
        isCompleted: Bool = false,
        sortOrder: Int,
        createdAt: Date = Date(),
        goal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isSmallWin = isSmallWin
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.goal = goal
    }
}
