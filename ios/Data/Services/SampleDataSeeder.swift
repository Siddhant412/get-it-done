import Foundation
import SwiftData

enum SampleDataSeeder {
    private static let didSeedKey = "didSeedSampleData"

    static func seedIfNeeded(in context: ModelContext) {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            return
        }

        let hasGoals = (try? context.fetchCount(FetchDescriptor<Goal>())) ?? 0 > 0
        let hasHabits = (try? context.fetchCount(FetchDescriptor<Habit>())) ?? 0 > 0
        let hasPriorities = (try? context.fetchCount(FetchDescriptor<DailyPriority>())) ?? 0 > 0

        guard !(hasGoals || hasHabits || hasPriorities) else {
            UserDefaults.standard.set(true, forKey: didSeedKey)
            return
        }

        let goalA = Goal(
            title: "DSA Mastery",
            iconName: "function",
            colorHex: "1F6F8B",
            targetDate: Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date(),
            priority: 1,
            whyNote: "Crack interviews with consistent practice.",
            category: "Learning",
            sortOrder: 0
        )
        let milestonesA = [
            "Finish 50 medium problems",
            "Solve 10 dynamic programming sets",
            "Mock interview: 3 rounds"
        ]
        for (index, title) in milestonesA.enumerated() {
            let milestone = Milestone(title: title, sortOrder: index, goal: goalA)
            goalA.milestones.append(milestone)
        }
        context.insert(goalA)

        let goalB = Goal(
            title: "Build Skillevate MVP",
            iconName: "sparkles",
            colorHex: "C57B57",
            targetDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date(),
            priority: 2,
            whyNote: "Launch to early users this month.",
            category: "Product",
            sortOrder: 1
        )
        let milestonesB = [
            "Ship onboarding",
            "Launch focus timer",
            "Release TestFlight build"
        ]
        for (index, title) in milestonesB.enumerated() {
            let milestone = Milestone(title: title, sortOrder: index, goal: goalB)
            goalB.milestones.append(milestone)
        }
        context.insert(goalB)

        let prioritySeeds = [
            ("Ship onboarding flow", "Build | 40 min", false, goalB),
            ("LeetCode: 1 medium problem", "DSA | 25 min", true, goalA),
            ("Read 20 min", "Focus | 20 min", true, nil)
        ]
        for (index, seed) in prioritySeeds.enumerated() {
            let item = DailyPriority(
                title: seed.0,
                detail: seed.1,
                isSmallWin: seed.2,
                sortOrder: index,
                goal: seed.3
            )
            context.insert(item)
        }

        let habitSeeds = [
            ("Gym", 6, 0.8),
            ("Journal", 12, 0.6),
            ("LeetCode", 9, 0.5),
            ("Hydration", 15, 0.7)
        ]
        for (index, seed) in habitSeeds.enumerated() {
            let item = Habit(
                title: seed.0,
                streak: seed.1,
                progress: seed.2,
                sortOrder: index
            )
            context.insert(item)
        }

        let taskSeeds = [
            ("Define habit streak freeze rules", goalB),
            ("Draft streak reward visuals", goalB),
            ("Review heatmap intensity colors", goalA)
        ]
        for (index, seed) in taskSeeds.enumerated() {
            let task = TaskItem(title: seed.0, priority: index, createdAt: Date(), goal: seed.1)
            context.insert(task)
        }

        let stats = UserStats(streakDays: 14, focusMinutes: 38, streakProtected: false)
        context.insert(stats)

        let calendar = Calendar.current
        let today = Date().startOfDay
        let totalDays = 16 * 7
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today

        for offset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let cycle = offset % 10
            let intensity: Double
            switch cycle {
            case 0, 1:
                intensity = 0
            case 2:
                intensity = 0.2
            case 3:
                intensity = 0.4
            case 4:
                intensity = 0.6
            case 5:
                intensity = 0.8
            case 6:
                intensity = 1.0
            case 7:
                intensity = 0.5
            case 8:
                intensity = 0.3
            default:
                intensity = 0.7
            }
            let completedPriorities = Int((intensity * 3).rounded())
            let completedHabits = Int((intensity * 4).rounded())
            let focusMinutes = Int((intensity * 60).rounded())

            let log = DailyLog(
                date: date,
                intensity: intensity,
                completedPriorities: completedPriorities,
                totalPriorities: 3,
                completedHabits: completedHabits,
                totalHabits: 4,
                focusMinutes: focusMinutes,
                updatedAt: date
            )
            context.insert(log)
        }

        UserDefaults.standard.set(true, forKey: didSeedKey)
        #endif
    }
}
