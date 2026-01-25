import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserStats.updatedAt, order: .reverse) private var stats: [UserStats]
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Milestone.createdAt, order: .reverse) private var milestones: [Milestone]

    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            ProfileBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ProfileHeader()

                    XPProgressCard(totalXP: totalXP, progress: xpProgress)

                    StreakProtectionCard(
                        streakDays: currentStats?.streakDays ?? 0,
                        tokensRemaining: currentStats?.streakFreezeTokens ?? 0,
                        allowance: currentStats?.freezeTokenAllowance ?? 2
                    )

                    ReminderCard(
                        isEnabled: currentStats?.reminderEnabled ?? false,
                        reminderTime: reminderTime,
                        onToggle: handleReminderToggle,
                        onTimeChange: updateReminderTime
                    )

                    if permissionDenied {
                        Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(ProfileTheme.inkSoft)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ProfileTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            ensureStats()
        }
    }

    private var currentStats: UserStats? {
        stats.first
    }

    private var reminderTime: Date {
        let calendar = Calendar.current
        let hour = currentStats?.reminderHour ?? 9
        let minute = currentStats?.reminderMinute ?? 0
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private var totalXP: Int {
        XPCalculator.totalXP(logs: logs, tasks: tasks, milestones: milestones)
    }

    private var xpProgress: XPProgress {
        XPCalculator.progress(for: totalXP)
    }

    private func ensureStats() {
        if currentStats == nil {
            let stats = UserStats()
            modelContext.insert(stats)
        }
    }

    private func handleReminderToggle(_ isOn: Bool) {
        guard let stats = currentStats else { return }
        stats.reminderEnabled = isOn
        stats.updatedAt = Date()

        Task {
            if isOn {
                let granted = await NotificationManager.requestAuthorization()
                if granted {
                    await NotificationManager.scheduleDailyReminder(
                        hour: stats.reminderHour,
                        minute: stats.reminderMinute
                    )
                    permissionDenied = false
                } else {
                    stats.reminderEnabled = false
                    permissionDenied = true
                }
            } else {
                await NotificationManager.clearDailyReminder()
            }
        }
    }

    private func updateReminderTime(_ date: Date) {
        guard let stats = currentStats else { return }
        let calendar = Calendar.current
        stats.reminderHour = calendar.component(.hour, from: date)
        stats.reminderMinute = calendar.component(.minute, from: date)
        stats.updatedAt = Date()

        if stats.reminderEnabled {
            Task {
                await NotificationManager.scheduleDailyReminder(
                    hour: stats.reminderHour,
                    minute: stats.reminderMinute
                )
            }
        }
    }
}

private struct ProfileBackground: View {
    var body: some View {
        LinearGradient(
            colors: [ProfileTheme.backgroundTop, ProfileTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ProfileTheme.glow)
                .frame(width: 200, height: 200)
                .offset(x: 80, y: -90)
        }
    }
}

private struct ProfileHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(ProfileTheme.ink)
            Text("Control your streak, reminders, and rewards.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(ProfileTheme.inkSoft)
        }
        .padding(.top, 6)
    }
}

private struct XPProgressCard: View {
    let totalXP: Int
    let progress: XPProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XP & Level")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(ProfileTheme.ink)

            HStack(spacing: 12) {
                ProfilePill(title: "Level", value: "\(progress.level)")
                ProfilePill(title: "Total XP", value: "\(totalXP)")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(progress.current)/\(progress.needed) XP to next level")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(ProfileTheme.inkSoft)
                XPProgressBar(progress: progress.ratio)
            }
        }
        .padding(16)
        .background(ProfileTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: ProfileTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct XPProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ProfileTheme.pill)
                Capsule()
                    .fill(ProfileTheme.ink)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

private struct StreakProtectionCard: View {
    let streakDays: Int
    let tokensRemaining: Int
    let allowance: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streak protection")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(ProfileTheme.ink)

            Text("Use freeze tokens to keep streaks alive on tough days.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(ProfileTheme.inkSoft)

            HStack(spacing: 12) {
                ProfilePill(title: "Current streak", value: "\(streakDays) days")
                ProfilePill(title: "Freeze tokens", value: "\(tokensRemaining)/\(allowance)")
            }
        }
        .padding(16)
        .background(ProfileTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: ProfileTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct ReminderCard: View {
    let isEnabled: Bool
    let reminderTime: Date
    let onToggle: (Bool) -> Void
    let onTimeChange: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily reminder")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(ProfileTheme.ink)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in onToggle(newValue) }
                ))
                .labelsHidden()
            }

            Text("Get a gentle nudge to log a tiny win.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(ProfileTheme.inkSoft)

            DatePicker("Time", selection: Binding(
                get: { reminderTime },
                set: { newValue in onTimeChange(newValue) }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .disabled(!isEnabled)
        }
        .padding(16)
        .background(ProfileTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: ProfileTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct ProfilePill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(ProfileTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(ProfileTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(ProfileTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum ProfileTheme {
    static let backgroundTop = Color(red: 0.96, green: 0.94, blue: 0.98)
    static let backgroundBottom = Color(red: 0.98, green: 0.98, blue: 0.95)
    static let glow = Color(red: 0.84, green: 0.84, blue: 0.95, opacity: 0.5)
    static let card = AppPalette.card
    static let pill = Color(red: 0.93, green: 0.92, blue: 0.96)
    static let ink = AppPalette.ink
    static let inkSoft = AppPalette.inkSoft
    static let shadow = AppPalette.shadow
}
