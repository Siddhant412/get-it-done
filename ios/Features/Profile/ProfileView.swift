import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserStats.updatedAt, order: .reverse) private var stats: [UserStats]
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Milestone.createdAt, order: .reverse) private var milestones: [Milestone]
    @Query(sort: \XPBonus.createdAt, order: .reverse) private var bonuses: [XPBonus]

    @State private var permissionDenied = false
    @State private var showXPHistory = false

    var body: some View {
        ZStack {
            ProfileBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ProfileHeader()

                    XPProgressCard(
                        totalXP: totalXP,
                        progress: xpProgress,
                        onViewHistory: { showXPHistory = true }
                    )

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
        .sheet(isPresented: $showXPHistory) {
            XPHistoryView(
                logs: logs,
                tasks: tasks,
                milestones: milestones,
                bonuses: bonuses
            )
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
        XPCalculator.totalXP(logs: logs, tasks: tasks, milestones: milestones, bonuses: bonuses)
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
    let onViewHistory: () -> Void

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

            Button("View XP history", action: onViewHistory)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.inkSoft)
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

private struct XPHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [DailyLog]
    let tasks: [TaskItem]
    let milestones: [Milestone]
    let bonuses: [XPBonus]

    var body: some View {
        NavigationStack {
            List {
                if summaries.isEmpty {
                    Text("No XP activity yet.")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summaries) { summary in
                        Section {
                            XPHistoryRow(summary: summary)

                            if summary.bonusXP > 0 {
                                XPBonusRow(title: "Quest bonuses", value: summary.bonusXP)
                            }
                        } header: {
                            XPHistoryHeader(date: summary.date, total: summary.totalXP)
                        }
                    }
                }
            }
            .navigationTitle("XP history")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var summaries: [XPDailySummary] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay

        var daySet: Set<Date> = []
        logs.filter { $0.date >= startDate }.forEach { daySet.insert($0.date.startOfDay) }
        tasks.forEach { task in
            if let completedAt = task.completedAt, completedAt >= startDate {
                daySet.insert(completedAt.startOfDay)
            }
        }
        milestones.forEach { milestone in
            if let completedAt = milestone.completedAt, completedAt >= startDate {
                daySet.insert(completedAt.startOfDay)
            }
        }
        bonuses.forEach { bonus in
            if bonus.createdAt >= startDate {
                daySet.insert(bonus.createdAt.startOfDay)
            }
        }

        let sortedDays = daySet.sorted(by: >)
        return sortedDays.map { day in
            let logXP = logs.filter { $0.date.startOfDay == day }.reduce(0) { $0 + XPCalculator.xpForLog($1) }
            let taskXP = tasks.reduce(0) { total, task in
                guard let completedAt = task.completedAt,
                      completedAt.startOfDay == day else { return total }
                return total + XPCalculator.xpForTask(task)
            }
            let milestoneXP = milestones.reduce(0) { total, milestone in
                guard let completedAt = milestone.completedAt,
                      completedAt.startOfDay == day else { return total }
                return total + XPCalculator.xpForMilestone(milestone)
            }
            let bonusXP = bonuses.reduce(0) { total, bonus in
                guard bonus.createdAt.startOfDay == day else { return total }
                return total + bonus.amount
            }
            return XPDailySummary(
                date: day,
                logXP: logXP,
                taskXP: taskXP,
                milestoneXP: milestoneXP,
                bonusXP: bonusXP
            )
        }
    }
}

private struct XPHistoryHeader: View {
    let date: Date
    let total: Int

    var body: some View {
        HStack {
            Text(XPDateFormatter.long.string(from: date))
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.inkSoft)
            Spacer()
            Text("\(total) XP")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.inkSoft)
        }
    }
}

private struct XPHistoryRow: View {
    let summary: XPDailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            XPBreakdownRow(title: "Daily progress", value: summary.logXP)
            XPBreakdownRow(title: "Tasks", value: summary.taskXP)
            XPBreakdownRow(title: "Milestones", value: summary.milestoneXP)
        }
    }
}

private struct XPBonusRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.inkSoft)
            Spacer()
            Text("+\(value) XP")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.ink)
        }
    }
}

private struct XPBreakdownRow: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.inkSoft)
            Spacer()
            Text("\(value) XP")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(ProfileTheme.ink)
        }
    }
}

private struct XPDailySummary: Identifiable {
    let date: Date
    let logXP: Int
    let taskXP: Int
    let milestoneXP: Int
    let bonusXP: Int

    var id: Date { date }

    var totalXP: Int {
        logXP + taskXP + milestoneXP + bonusXP
    }
}

private enum XPDateFormatter {
    static let long: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
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
