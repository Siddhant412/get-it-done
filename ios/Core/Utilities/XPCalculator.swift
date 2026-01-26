import Foundation

enum XPCalculator {
    static let priorityXP = 30
    static let habitXP = 25
    static let focusXPPerMinute = 1
    static let focusXPCap = 120
    static let taskBaseXP = 30
    static let taskPriorityXP = 10
    static let milestoneXP = 120
    static let levelStep = 500

    static func xpForCounts(completedPriorities: Int, completedHabits: Int, focusMinutes: Int) -> Int {
        let focusXP = min(max(focusMinutes, 0), focusXPCap) * focusXPPerMinute
        return max(0, completedPriorities) * priorityXP
            + max(0, completedHabits) * habitXP
            + focusXP
    }

    static func xpForLog(_ log: DailyLog) -> Int {
        xpForCounts(
            completedPriorities: log.completedPriorities,
            completedHabits: log.completedHabits,
            focusMinutes: log.focusMinutes
        )
    }

    static func xpForTask(_ task: TaskItem) -> Int {
        let priorityBoost = max(0, task.priority) * taskPriorityXP
        return taskBaseXP + priorityBoost
    }

    static func xpForMilestone(_ milestone: Milestone) -> Int {
        milestoneXP
    }

    static func xpForTasks(_ tasks: [TaskItem], on day: Date) -> Int {
        let start = day.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return tasks.reduce(0) { total, task in
            guard let completedAt = task.completedAt,
                  completedAt >= start && completedAt < end else {
                return total
            }
            return total + xpForTask(task)
        }
    }

    static func xpForMilestones(_ milestones: [Milestone], on day: Date) -> Int {
        let start = day.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return milestones.reduce(0) { total, milestone in
            guard let completedAt = milestone.completedAt,
                  completedAt >= start && completedAt < end else {
                return total
            }
            return total + xpForMilestone(milestone)
        }
    }

    static func totalXP(logs: [DailyLog], tasks: [TaskItem], milestones: [Milestone]) -> Int {
        let logXP = logs.reduce(0) { $0 + xpForLog($1) }
        let taskXP = tasks.reduce(0) { total, task in
            task.isCompleted ? total + xpForTask(task) : total
        }
        let milestoneXP = milestones.reduce(0) { total, milestone in
            milestone.isCompleted ? total + xpForMilestone(milestone) : total
        }
        return logXP + taskXP + milestoneXP
    }

    static func totalXP(
        logs: [DailyLog],
        tasks: [TaskItem],
        milestones: [Milestone],
        bonuses: [XPBonus]
    ) -> Int {
        totalXP(logs: logs, tasks: tasks, milestones: milestones)
            + bonuses.reduce(0) { $0 + $1.amount }
    }

    static func bonuses(on day: Date, bonuses: [XPBonus]) -> Int {
        let start = day.startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return bonuses.reduce(0) { total, bonus in
            guard bonus.createdAt >= start && bonus.createdAt < end else { return total }
            return total + bonus.amount
        }
    }

    static func level(for totalXP: Int) -> Int {
        max(1, totalXP / levelStep + 1)
    }

    static func progress(for totalXP: Int) -> XPProgress {
        let level = level(for: totalXP)
        let levelBase = (level - 1) * levelStep
        let current = max(0, totalXP - levelBase)
        let needed = levelStep
        let ratio = needed == 0 ? 0 : Double(current) / Double(needed)
        return XPProgress(level: level, current: current, needed: needed, ratio: ratio)
    }
}

struct XPProgress {
    let level: Int
    let current: Int
    let needed: Int
    let ratio: Double
}
