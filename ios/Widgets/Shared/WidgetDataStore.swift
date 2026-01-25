import Foundation
import WidgetKit

struct WidgetSnapshot: Codable {
    let date: Date
    let streakDays: Int
    let todayProgress: Double
    let topPriorities: [String]

    static let placeholder = WidgetSnapshot(
        date: Date(),
        streakDays: 7,
        todayProgress: 0.6,
        topPriorities: ["Ship focus timer", "LeetCode 1 problem", "Read 20 min"]
    )
}

enum WidgetDataStore {
    private enum Keys {
        static let snapshot = "widget_snapshot_v1"
    }

    static let appGroupID = "group.com.siddhant.getitdone"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func save(_ snapshot: WidgetSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Keys.snapshot)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: Keys.snapshot),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}
