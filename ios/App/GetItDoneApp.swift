import SwiftUI
import SwiftData

@main
struct GetItDoneApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            DailyPriority.self,
            Habit.self,
            UserStats.self,
            DailyLog.self,
            Goal.self,
            Milestone.self,
            TaskItem.self
        ])
    }
}
