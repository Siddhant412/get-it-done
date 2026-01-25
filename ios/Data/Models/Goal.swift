import Foundation
import SwiftData

@Model
final class Goal: Identifiable {
    var id: UUID
    var title: String
    var iconName: String
    var colorHex: String
    var startDate: Date
    var targetDate: Date
    var priority: Int
    var whyNote: String
    var category: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Milestone.goal)
    var milestones: [Milestone]

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.goal)
    var tasks: [TaskItem]

    @Relationship(deleteRule: .nullify, inverse: \DailyPriority.goal)
    var priorities: [DailyPriority]

    init(
        id: UUID = UUID(),
        title: String,
        iconName: String = "flag.fill",
        colorHex: String = "2F6F6C",
        startDate: Date = Date(),
        targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        priority: Int = 1,
        whyNote: String = "",
        category: String = "General",
        sortOrder: Int,
        createdAt: Date = Date(),
        milestones: [Milestone] = [],
        tasks: [TaskItem] = [],
        priorities: [DailyPriority] = []
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.colorHex = colorHex
        self.startDate = startDate
        self.targetDate = targetDate
        self.priority = priority
        self.whyNote = whyNote
        self.category = category
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.milestones = milestones
        self.tasks = tasks
        self.priorities = priorities
    }
}

extension Goal {
    var completionRatio: Double {
        let milestoneCount = milestones.count
        let taskCount = tasks.count
        let total = milestoneCount + taskCount
        guard total > 0 else { return 0 }

        let completedMilestones = milestones.filter { $0.isCompleted }.count
        let completedTasks = tasks.filter { $0.isCompleted }.count
        return Double(completedMilestones + completedTasks) / Double(total)
    }

    var progressSummary: String {
        let milestoneSummary = milestones.isEmpty
            ? nil
            : "\(milestones.filter { $0.isCompleted }.count)/\(milestones.count) milestones"
        let taskSummary = tasks.isEmpty
            ? nil
            : "\(tasks.filter { $0.isCompleted }.count)/\(tasks.count) tasks"

        let parts = [milestoneSummary, taskSummary].compactMap { $0 }
        return parts.isEmpty ? "No milestones or tasks yet" : parts.joined(separator: " • ")
    }
}
