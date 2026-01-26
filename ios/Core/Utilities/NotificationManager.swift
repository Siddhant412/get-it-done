import Foundation
import UserNotifications

enum NotificationManager {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [Constants.reminderID])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak alive"
        content.body = "Log one tiny win today and keep the chain unbroken."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.reminderID,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Ignore errors for now; UI will still reflect preference.
        }
    }

    static func clearDailyReminder() async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [Constants.reminderID])
    }

    static func scheduleHabitReminders(
        habitID: UUID,
        title: String,
        days: [Int],
        hour: Int,
        minute: Int
    ) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = Constants.habitIdentifiers(for: habitID)
        await center.removePendingNotificationRequests(withIdentifiers: identifiers)

        guard !days.isEmpty else { return }

        let safeHour = max(0, min(hour, 23))
        let safeMinute = max(0, min(minute, 59))

        for day in days {
            var dateComponents = DateComponents()
            dateComponents.weekday = Constants.weekdayValue(from: day)
            dateComponents.hour = safeHour
            dateComponents.minute = safeMinute

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Time for your habit check-in."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: Constants.habitIdentifier(for: habitID, day: day),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Ignore errors for now; UI will still reflect preference.
            }
        }
    }

    static func clearHabitReminders(habitID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let identifiers = Constants.habitIdentifiers(for: habitID)
        await center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

private enum Constants {
    static let reminderID = "daily_streak_reminder"
    private static let habitPrefix = "habit_reminder"

    static func habitIdentifier(for habitID: UUID, day: Int) -> String {
        "\(habitPrefix)_\(habitID.uuidString)_\(day)"
    }

    static func habitIdentifiers(for habitID: UUID) -> [String] {
        (1...7).map { habitIdentifier(for: habitID, day: $0) }
    }

    static func weekdayValue(from day: Int) -> Int {
        let normalized = max(1, min(day, 7))
        // day: 1 = Monday ... 7 = Sunday, Calendar weekday: 1 = Sunday ... 7 = Saturday
        let mapping = [2, 3, 4, 5, 6, 7, 1]
        return mapping[normalized - 1]
    }
}
